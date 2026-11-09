#include "bluetooth.h"

#include <QRegularExpression>

#include <BluezQt/Adapter>
#include <BluezQt/Battery>
#include <BluezQt/Device>
#include <BluezQt/InitManagerJob>
#include <BluezQt/Manager>
#include <BluezQt/PendingCall>
#include <BluezQt/Rfkill>

#include <QDir>

#include <algorithm>

using namespace BluezQt;

namespace
{
// The glyph for a device, by what it says it is.
QString kindOf(Device::Type type)
{
    switch (type) {
    case Device::Phone:
    case Device::Modem:
        return QStringLiteral("phone");
    case Device::Computer:
    case Device::Network:
        return QStringLiteral("computer");
    case Device::Headset:
    case Device::Headphones:
        return QStringLiteral("headphones");
    case Device::AudioVideo:
        return QStringLiteral("speaker");
    case Device::Keyboard:
        return QStringLiteral("keyboard");
    case Device::Mouse:
        return QStringLiteral("mouse");
    case Device::Joypad:
    case Device::Toy:
        return QStringLiteral("gamepad");
    case Device::Wearable:
        return QStringLiteral("watch");
    default:
        return QStringLiteral("device");
    }
}
}

Bluetooth::Bluetooth(QObject *parent)
    : QObject(parent)
    , m_manager(new Manager(this))
    , m_controller(!QDir(QStringLiteral("/sys/class/bluetooth")).entryList({QStringLiteral("hci*")}, QDir::Dirs | QDir::System).isEmpty())
{
    m_refresh.setSingleShot(true);
    m_refresh.setInterval(0);
    connect(&m_refresh, &QTimer::timeout, this, &Bluetooth::refresh);
    m_renew.setInterval(120 * 1000);
    connect(&m_renew, &QTimer::timeout, this, [this] {
        if (m_adapter)
            m_adapter->setDiscoverable(true);
    });

    InitManagerJob *job = m_manager->init();
    connect(job, &InitManagerJob::result, this, [this](InitManagerJob *job) {
        if (job->error())
            qWarning("Settings: no Bluetooth: %s", qPrintable(job->errorText()));
        else
            setUp();
        m_ready = true;
        Q_EMIT adapterChanged();
    });
    job->start();
}

Bluetooth::~Bluetooth()
{
    stopLooking();
}

void Bluetooth::setUp()
{
    auto later = [this] { m_refresh.start(); };
    connect(m_manager, &Manager::adapterAdded, this, &Bluetooth::findAdapter);
    connect(m_manager, &Manager::adapterRemoved, this, &Bluetooth::findAdapter);
    connect(m_manager, &Manager::usableAdapterChanged, this, &Bluetooth::findAdapter);
    connect(m_manager, &Manager::bluetoothBlockedChanged, this, &Bluetooth::enabledChanged);
    connect(m_manager->rfkill(), &Rfkill::stateChanged, this, &Bluetooth::enabledChanged);
    connect(m_manager, &Manager::deviceAdded, this, later);
    connect(m_manager, &Manager::deviceRemoved, this, later);
    connect(m_manager, &Manager::deviceChanged, this, later);
    findAdapter();
}

// The adapter: the one in use if there are more, else the first; a test
// one by its name (AMBROSIA_BT_ADAPTER=hci1).
void Bluetooth::findAdapter()
{
    AdapterPtr found = m_manager->usableAdapter();
    const QList<AdapterPtr> adapters = m_manager->adapters();
    if (!found && !adapters.isEmpty())
        found = adapters.first();
    if (const QString name = qEnvironmentVariable("AMBROSIA_BT_ADAPTER"); !name.isEmpty()) {
        for (const AdapterPtr &adapter : adapters) {
            if (adapter->ubi().endsWith(QLatin1Char('/') + name))
                found = adapter;
        }
    }
    if (found == m_adapter)
        return;
    stopLooking();
    if (m_adapter)
        m_adapter->disconnect(this);
    m_adapter = found;
    if (m_adapter) {
        connect(m_adapter.data(), &Adapter::poweredChanged, this, [this](bool powered) {
            if (!powered)
                m_renew.stop(); // discovery ends with it
            Q_EMIT enabledChanged();
            m_refresh.start();
            look();
        });
        connect(m_adapter.data(), &Adapter::nameChanged, this, &Bluetooth::adapterChanged);
        connect(m_adapter.data(), &Adapter::discoveringChanged, this, &Bluetooth::discoveringChanged);
    }
    Q_EMIT adapterChanged();
    Q_EMIT enabledChanged();
    Q_EMIT discoveringChanged();
    look();
    m_refresh.start();
}

bool Bluetooth::enabled() const
{
    return m_adapter && m_adapter->isPowered() && !m_manager->isBluetoothBlocked();
}

bool Bluetooth::blocked() const
{
    return m_manager->rfkill() && m_manager->rfkill()->state() == Rfkill::HardBlocked;
}

QString Bluetooth::name() const
{
    return m_adapter ? m_adapter->name() : QString();
}

bool Bluetooth::discovering() const
{
    return m_adapter && m_adapter->isDiscovering();
}

// Off, as KDE does it, blocks the radio (which outlasts a restart); on
// unblocks it and powers the adapter.
void Bluetooth::setEnabled(bool on)
{
    if (on) {
        if (m_manager->isBluetoothBlocked())
            m_manager->setBluetoothBlocked(false);
        if (m_adapter)
            m_adapter->setPowered(true);
    } else {
        m_manager->setBluetoothBlocked(true);
    }
}

void Bluetooth::setWatching(bool on)
{
    if (on == m_watching)
        return;
    m_watching = on;
    if (on)
        look();
    else
        stopLooking();
    Q_EMIT watchingChanged();
}

// While watching and on: discovering, and discoverable.
void Bluetooth::look()
{
    if (!m_watching || !m_adapter || !m_adapter->isPowered() || m_renew.isActive())
        return;
    m_wasDiscoverable = m_adapter->isDiscoverable();
    m_adapter->setDiscoverable(true);
    m_adapter->startDiscovery();
    m_renew.start();
}

// Leaves the adapter as it found it.
void Bluetooth::stopLooking()
{
    if (!m_renew.isActive())
        return;
    m_renew.stop();
    if (m_adapter && m_adapter->isPowered()) {
        m_adapter->stopDiscovery();
        if (!m_wasDiscoverable)
            m_adapter->setDiscoverable(false);
    }
}

void Bluetooth::refresh()
{
    QVariantList devices, nearby;
    if (m_adapter && enabled()) {
        for (const DevicePtr &device : m_adapter->devices()) {
            const bool paired = device->isPaired();
            if (!paired && device->remoteName().isEmpty())
                continue; // nameless: System Settings doesn't list them either
            connect(device.data(), &Device::batteryChanged, &m_refresh, qOverload<>(&QTimer::start), Qt::UniqueConnection);
            const BatteryPtr battery = device->battery();
            if (battery)
                connect(battery.data(), &Battery::percentageChanged, &m_refresh, qOverload<>(&QTimer::start), Qt::UniqueConnection);
            const QVariantMap row{
                {QStringLiteral("address"), device->address()},
                {QStringLiteral("name"), device->name()},
                {QStringLiteral("kind"), kindOf(device->type())},
                {QStringLiteral("connected"), device->isConnected()},
                {QStringLiteral("busy"), m_busy.contains(device->address())},
                {QStringLiteral("battery"), battery ? battery->percentage() : -1},
            };
            (paired ? devices : nearby) << row;
        }
        const auto byName = [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
        };
        std::sort(devices.begin(), devices.end(), byName);
        std::sort(nearby.begin(), nearby.end(), byName);
    }
    if (devices == m_devices && nearby == m_nearby)
        return;
    m_devices = devices;
    m_nearby = nearby;
    Q_EMIT devicesChanged();
}

void Bluetooth::connectDevice(const QString &address)
{
    const DevicePtr device = m_adapter ? m_adapter->deviceForAddress(address) : DevicePtr();
    if (!device || m_busy.contains(address))
        return;
    m_busy.insert(address);
    m_refresh.start();
    if (device->isPaired()) {
        connectPaired(device);
        return;
    }
    // Pairing asks the session's agent for a code, if the device wants one.
    PendingCall *call = device->pair();
    connect(call, &PendingCall::finished, this, [this, device](PendingCall *call) {
        if (call->error()) {
            qWarning("Settings: pairing with %s failed: %s", qPrintable(device->name()), qPrintable(call->errorText()));
            done(device->address(), false, device->name());
            return;
        }
        device->setTrusted(true);
        connectPaired(device);
    });
}

void Bluetooth::connectPaired(const DevicePtr &device)
{
    PendingCall *call = device->connectToDevice();
    connect(call, &PendingCall::finished, this, [this, device](PendingCall *call) {
        // Some (a keyboard, a mouse) are connected by pairing already.
        const bool ok = !call->error() || device->isConnected();
        if (!ok)
            qWarning("Settings: connecting %s failed: %s", qPrintable(device->name()), qPrintable(call->errorText()));
        done(device->address(), ok, device->name());
    });
}

void Bluetooth::done(const QString &address, bool ok, const QString &name)
{
    m_busy.remove(address);
    m_refresh.start();
    if (!ok)
        Q_EMIT failed(address, name);
}

void Bluetooth::disconnectDevice(const QString &address)
{
    if (const DevicePtr device = m_adapter ? m_adapter->deviceForAddress(address) : DevicePtr())
        device->disconnectFromDevice();
}

void Bluetooth::rename(const QString &address, const QString &name)
{
    const DevicePtr device = m_adapter ? m_adapter->deviceForAddress(address) : DevicePtr();
    if (device && !name.trimmed().isEmpty())
        device->setName(name.trimmed());
}

void Bluetooth::forget(const QString &address)
{
    if (const DevicePtr device = m_adapter ? m_adapter->deviceForAddress(address) : DevicePtr())
        m_adapter->removeDevice(device);
}

QVariantMap Bluetooth::details(const QString &address) const
{
    const DevicePtr device = m_adapter ? m_adapter->deviceForAddress(address) : DevicePtr();
    if (!device)
        return {};
    const BatteryPtr battery = device->battery();
    // Its firmware's version, from the Device ID it gives (modalias
    // bluetooth:v…p…dVVVV): 0x0100 is 1.0.0, as System Settings writes it.
    QString version;
    if (const auto match = QRegularExpression(QStringLiteral("d([0-9A-Fa-f]{4})$")).match(device->modalias()); match.hasMatch()) {
        const uint d = match.captured(1).toUInt(nullptr, 16);
        version = QStringLiteral("%1.%2.%3").arg(d >> 8).arg((d >> 4) & 0xf).arg(d & 0xf);
    }
    return {
        {QStringLiteral("name"), device->name()},
        {QStringLiteral("version"), version},
        {QStringLiteral("address"), device->address()},
        {QStringLiteral("kind"), kindOf(device->type())},
        {QStringLiteral("connected"), device->isConnected()},
        {QStringLiteral("paired"), device->isPaired()},
        {QStringLiteral("battery"), battery ? battery->percentage() : -1},
    };
}
