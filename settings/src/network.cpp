#include "network.h"

#include <NetworkManagerQt/ActiveConnection>
#include <NetworkManagerQt/BluetoothDevice>
#include <NetworkManagerQt/Connection>
#include <NetworkManagerQt/ConnectionSettings>
#include <NetworkManagerQt/Device>
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/Settings>

#include <algorithm>

using namespace NetworkManager;

namespace
{
// A Mac's services in its order: wired, Wi-Fi, the rest; -1 for an
// interface that isn't one.
int kindOrder(Device::Type type)
{
    switch (type) {
    case Device::Ethernet:
        return 0;
    case Device::Wifi:
        return 1;
    case Device::Bluetooth:
        return 2;
    case Device::Modem:
        return 3;
    default:
        return -1;
    }
}

QString kindOf(Device::Type type)
{
    switch (type) {
    case Device::Ethernet:
        return QStringLiteral("ethernet");
    case Device::Wifi:
        return QStringLiteral("wifi");
    case Device::Bluetooth:
        return QStringLiteral("bluetooth");
    default:
        return QStringLiteral("modem");
    }
}

// What System Settings would call it: a port by what it is ("Ethernet",
// "USB Ethernet"; numbered when there are more), a phone by its name.
QString baseName(const Device::Ptr &device)
{
    switch (device->type()) {
    case Device::Ethernet:
        // Udi is the interface's place in sysfs.
        if (device->udi().contains(QLatin1String("/usb")))
            return QStringLiteral("USB Ethernet");
        if (device->udi().contains(QLatin1String("/thunderbolt")))
            return QStringLiteral("Thunderbolt Ethernet");
        return QStringLiteral("Ethernet");
    case Device::Wifi:
        return QStringLiteral("Wi‑Fi");
    case Device::Bluetooth: {
        const QString name = device.objectCast<BluetoothDevice>()->name();
        return name.isEmpty() ? QStringLiteral("Bluetooth PAN") : name;
    }
    default:
        return QStringLiteral("Cellular");
    }
}

QString stateOf(const Device::Ptr &device)
{
    if (device->type() == Device::Wifi && !isWirelessEnabled())
        return QStringLiteral("off");
    switch (device->state()) {
    case Device::Activated:
        return QStringLiteral("connected");
    case Device::Preparing:
    case Device::ConfiguringHardware:
    case Device::NeedAuth:
    case Device::ConfiguringIp:
    case Device::CheckingIp:
    case Device::WaitingForSecondaries:
        return QStringLiteral("connecting");
    default:
        return QStringLiteral("disconnected");
    }
}

bool isVpn(ConnectionSettings::ConnectionType type)
{
    return type == ConnectionSettings::Vpn || type == ConnectionSettings::WireGuard;
}
}

Network::Network(QObject *parent)
    : QObject(parent)
{
    // Changes come in bursts (a connection activating steps through its
    // states); one look after them.
    m_refresh.setSingleShot(true);
    m_refresh.setInterval(100);
    connect(&m_refresh, &QTimer::timeout, this, &Network::refresh);

    const auto later = qOverload<>(&QTimer::start);
    connect(notifier(), &Notifier::deviceAdded, &m_refresh, later);
    connect(notifier(), &Notifier::deviceRemoved, &m_refresh, later);
    connect(notifier(), &Notifier::wirelessEnabledChanged, &m_refresh, later);
    connect(notifier(), &Notifier::activeConnectionsChanged, &m_refresh, later);
    connect(settingsNotifier(), &SettingsNotifier::connectionAdded, &m_refresh, later);
    connect(settingsNotifier(), &SettingsNotifier::connectionRemoved, &m_refresh, later);
    refresh();
}

// Each device's and active VPN's state, once each.
void Network::watch()
{
    const auto later = qOverload<>(&QTimer::start);
    for (const Device::Ptr &device : networkInterfaces())
        connect(device.data(), &Device::stateChanged, &m_refresh, later, Qt::UniqueConnection);
    for (const ActiveConnection::Ptr &active : activeConnections()) {
        if (isVpn(active->type()))
            connect(active.data(), &ActiveConnection::stateChanged, &m_refresh, later, Qt::UniqueConnection);
    }
}

void Network::refresh()
{
    watch();

    Device::List devices;
    for (const Device::Ptr &device : networkInterfaces()) {
        if (device->managed() && kindOrder(device->type()) >= 0)
            devices.append(device);
    }
    std::sort(devices.begin(), devices.end(), [](const Device::Ptr &a, const Device::Ptr &b) {
        if (kindOrder(a->type()) != kindOrder(b->type()))
            return kindOrder(a->type()) < kindOrder(b->type());
        return a->interfaceName() < b->interfaceName();
    });

    QVariantList connected, others;
    QHash<QString, int> named;
    for (const Device::Ptr &device : devices) {
        QString name = baseName(device);
        if (const int n = ++named[name]; n > 1)
            name += QLatin1Char(' ') + QString::number(n);
        const QVariantMap service{
            {QStringLiteral("id"), device->uni()},
            {QStringLiteral("name"), name},
            {QStringLiteral("kind"), kindOf(device->type())},
            {QStringLiteral("state"), stateOf(device)},
        };
        (service.value(QStringLiteral("state")) == QLatin1String("connected") ? connected : others).append(service);
    }

    QVariantMap vpn;
    for (const Connection::Ptr &connection : listConnections()) {
        if (isVpn(connection->settings()->connectionType())) {
            vpn.insert(QStringLiteral("state"), QStringLiteral("disconnected"));
            break;
        }
    }
    if (!vpn.isEmpty()) {
        for (const ActiveConnection::Ptr &active : activeConnections()) {
            if (!isVpn(active->type()))
                continue;
            if (active->state() == ActiveConnection::Activated) {
                vpn.insert(QStringLiteral("state"), QStringLiteral("connected"));
                break;
            }
            if (active->state() == ActiveConnection::Activating)
                vpn.insert(QStringLiteral("state"), QStringLiteral("connecting"));
        }
    }

    if (connected == m_connected && others == m_others && vpn == m_vpn)
        return;
    m_connected = connected;
    m_others = others;
    m_vpn = vpn;
    Q_EMIT servicesChanged();
}
