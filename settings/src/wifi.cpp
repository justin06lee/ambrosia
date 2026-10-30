#include "wifi.h"

#include <NetworkManagerQt/AccessPoint>
#include <NetworkManagerQt/ActiveConnection>
#include <NetworkManagerQt/Connection>
#include <NetworkManagerQt/ConnectionSettings>
#include <NetworkManagerQt/IpConfig>
#include <NetworkManagerQt/Ipv4Setting>
#include <NetworkManagerQt/Ipv6Setting>
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/Settings>
#include <NetworkManagerQt/Utils>
#include <NetworkManagerQt/WirelessNetwork>
#include <NetworkManagerQt/WirelessSetting>
#include <QClipboard>
#include <QDBusPendingCallWatcher>
#include <QGuiApplication>
#include <QUuid>

#include <algorithm>

using namespace NetworkManager;

namespace
{
// Signal as System Settings draws it, in three bars.
int bars(int strength)
{
    return strength >= 67 ? 3 : strength >= 34 ? 2 : 1;
}

// What joining a network takes: "none", "owe" (encrypted, no password),
// "wep", "wpa" (WPA/WPA2 Personal), "sae" (WPA3 Personal) or "enterprise".
QString securityOf(const WirelessDevice::Ptr &device, const AccessPoint::Ptr &ap)
{
    if (!ap)
        return QStringLiteral("none");
    switch (findBestWirelessSecurity(device->wirelessCapabilities(), true, ap->mode() == AccessPoint::Adhoc,
                                     ap->capabilities(), ap->wpaFlags(), ap->rsnFlags())) {
    case OWE:
        return QStringLiteral("owe");
    case StaticWep:
        return QStringLiteral("wep");
    case WpaPsk:
    case Wpa2Psk:
        return QStringLiteral("wpa");
    case SAE:
        return QStringLiteral("sae");
    case DynamicWep:
    case Leap:
    case WpaEap:
    case Wpa2Eap:
    case Wpa3SuiteB192:
        return QStringLiteral("enterprise");
    default:
        return QStringLiteral("none");
    }
}

bool secured(const QString &security)
{
    return security != QLatin1String("none") && security != QLatin1String("owe");
}

// The saved connections for networks (infrastructure Wi-Fi), by name.
QHash<QString, Connection::Ptr> savedNetworks()
{
    QHash<QString, Connection::Ptr> saved;
    for (const Connection::Ptr &connection : listConnections()) {
        const ConnectionSettings::Ptr settings = connection->settings();
        if (settings->connectionType() != ConnectionSettings::Wireless)
            continue;
        const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
        if (wireless->mode() == WirelessSetting::Infrastructure)
            saved.insert(QString::fromUtf8(wireless->ssid()), connection);
    }
    return saved;
}

// A new connection to `ssid` with what its security needs.
NMVariantMapMap connectionFor(const QString &ssid, const QString &security, const QString &password, const QString &user, bool hidden)
{
    NMVariantMapMap map;
    map[QStringLiteral("connection")] = {
        {QStringLiteral("id"), ssid},
        {QStringLiteral("uuid"), QUuid::createUuid().toString(QUuid::WithoutBraces)},
        {QStringLiteral("type"), QStringLiteral("802-11-wireless")},
    };
    QVariantMap wireless{{QStringLiteral("ssid"), ssid.toUtf8()}, {QStringLiteral("mode"), QStringLiteral("infrastructure")}};
    if (hidden)
        wireless.insert(QStringLiteral("hidden"), true);
    map[QStringLiteral("802-11-wireless")] = wireless;
    // Secrets are kept by the system for every user, as a Mac keeps them
    // in its System keychain.
    // Without a password, NetworkManager asks the session's secret agent.
    if (security == QLatin1String("wpa") || security == QLatin1String("sae")) {
        QVariantMap wpa{{QStringLiteral("key-mgmt"), security == QLatin1String("sae") ? QStringLiteral("sae") : QStringLiteral("wpa-psk")}};
        if (!password.isEmpty())
            wpa.insert(QStringLiteral("psk"), password);
        map[QStringLiteral("802-11-wireless-security")] = wpa;
    } else if (security == QLatin1String("wep")) {
        QVariantMap wep{{QStringLiteral("key-mgmt"), QStringLiteral("none")}, {QStringLiteral("wep-key-type"), 1}};
        if (!password.isEmpty())
            wep.insert(QStringLiteral("wep-key0"), password);
        map[QStringLiteral("802-11-wireless-security")] = wep;
    } else if (security == QLatin1String("owe")) {
        map[QStringLiteral("802-11-wireless-security")] = {{QStringLiteral("key-mgmt"), QStringLiteral("owe")}};
    } else if (security == QLatin1String("enterprise")) {
        // A name and password, as a Mac asks: PEAP with MSCHAPv2 inside,
        // what most such networks take.
        map[QStringLiteral("802-11-wireless-security")] = {{QStringLiteral("key-mgmt"), QStringLiteral("wpa-eap")}};
        QVariantMap eap{
            {QStringLiteral("eap"), QStringList{QStringLiteral("peap")}},
            {QStringLiteral("phase2-auth"), QStringLiteral("mschapv2")},
            {QStringLiteral("identity"), user},
        };
        if (!password.isEmpty())
            eap.insert(QStringLiteral("password"), password);
        map[QStringLiteral("802-1x")] = eap;
    }
    map[QStringLiteral("ipv4")] = {{QStringLiteral("method"), QStringLiteral("auto")}};
    map[QStringLiteral("ipv6")] = {{QStringLiteral("method"), QStringLiteral("auto")}};
    return map;
}
}

WiFi::WiFi(QObject *parent)
    : QObject(parent)
{
    // Names and strengths change in bursts: the lists are made again once
    // a burst is over.
    m_refresh.setSingleShot(true);
    m_refresh.setInterval(150);
    connect(&m_refresh, &QTimer::timeout, this, &WiFi::refresh);
    m_rescan.setInterval(10000);
    connect(&m_rescan, &QTimer::timeout, this, &WiFi::scan);

    connect(notifier(), &Notifier::wirelessEnabledChanged, this, &WiFi::enabledChanged);
    connect(notifier(), &Notifier::wirelessHardwareEnabledChanged, this, &WiFi::enabledChanged);
    connect(notifier(), &Notifier::deviceAdded, this, &WiFi::findDevice);
    connect(notifier(), &Notifier::deviceRemoved, this, &WiFi::findDevice);
    connect(settingsNotifier(), &SettingsNotifier::connectionAdded, &m_refresh, qOverload<>(&QTimer::start));
    connect(settingsNotifier(), &SettingsNotifier::connectionRemoved, &m_refresh, qOverload<>(&QTimer::start));
    findDevice();
}

// The Wi-Fi device: the one in use if there are more (a second card),
// else the first; one sharing a hotspot only if there is no other.
void WiFi::findDevice()
{
    const auto rank = [](const WirelessDevice::Ptr &device) {
        return (device->mode() != WirelessDevice::ApMode ? 2 : 0) + (device->activeConnection() ? 1 : 0);
    };
    WirelessDevice::Ptr found;
    for (const Device::Ptr &device : networkInterfaces()) {
        if (device->type() != Device::Wifi)
            continue;
        const auto wireless = device.objectCast<WirelessDevice>();
        if (!found || rank(wireless) > rank(found))
            found = wireless;
    }
    // A test radio, by its interface's name.
    if (const QString name = qEnvironmentVariable("AMBROSIA_WIFI_DEVICE"); !name.isEmpty()) {
        for (const Device::Ptr &device : networkInterfaces()) {
            if (device->type() == Device::Wifi && device->interfaceName() == name)
                found = device.objectCast<WirelessDevice>();
        }
    }
    if (found == m_device)
        return;
    if (m_device)
        m_device->disconnect(this);
    m_device = found;
    if (m_device) {
        auto later = [this] { m_refresh.start(); };
        connect(m_device.data(), &WirelessDevice::networkAppeared, this, [this](const QString &ssid) {
            watchNetwork(ssid);
            m_refresh.start();
        });
        connect(m_device.data(), &WirelessDevice::networkDisappeared, this, later);
        connect(m_device.data(), &WirelessDevice::activeAccessPointChanged, this, later);
        connect(m_device.data(), &Device::activeConnectionChanged, this, later);
        connect(m_device.data(), &Device::stateChanged, this, [this](Device::State state, Device::State, Device::StateChangeReason reason) {
            deviceStateChanged(state, reason);
            m_refresh.start();
            Q_EMIT detailsChanged();
        });
        connect(m_device.data(), &Device::ipV4ConfigChanged, this, &WiFi::detailsChanged);
        connect(m_device.data(), &WirelessDevice::lastScanChanged, this, [this] {
            if (m_scanning) {
                m_scanning = false;
                Q_EMIT scanningChanged();
            }
            m_refresh.start();
        });
        for (const WirelessNetwork::Ptr &network : m_device->networks())
            watchNetwork(network->ssid());
    }
    Q_EMIT deviceChanged();
    refresh();
}

void WiFi::watchNetwork(const QString &ssid)
{
    if (const WirelessNetwork::Ptr network = m_device ? m_device->findNetwork(ssid) : WirelessNetwork::Ptr())
        connect(network.data(), &WirelessNetwork::signalStrengthChanged, &m_refresh, qOverload<>(&QTimer::start), Qt::UniqueConnection);
}

bool WiFi::enabled() const
{
    return isWirelessEnabled();
}

bool WiFi::blocked() const
{
    return !isWirelessHardwareEnabled();
}

void WiFi::setEnabled(bool on)
{
    setWirelessEnabled(on);
}

void WiFi::setWatching(bool on)
{
    if (m_watching == on)
        return;
    m_watching = on;
    Q_EMIT watchingChanged();
    if (on) {
        scan();
        m_rescan.start();
    } else {
        m_rescan.stop();
    }
}

void WiFi::scan()
{
    if (!m_device || !enabled())
        return;
    auto *watcher = new QDBusPendingCallWatcher(m_device->requestScan(), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        // Too soon after the last one, NetworkManager says no: what it has is fresh.
        if (call->isError() && m_scanning) {
            m_scanning = false;
            Q_EMIT scanningChanged();
        }
        call->deleteLater();
    });
    if (!m_scanning) {
        m_scanning = true;
        Q_EMIT scanningChanged();
    }
}

void WiFi::refresh()
{
    QVariantMap current;
    QVariantList known, others;
    if (m_device && enabled()) {
        const QHash<QString, Connection::Ptr> saved = savedNetworks();
        const ActiveConnection::Ptr active = m_device->activeConnection();
        QString activeSsid;
        if (active && active->connection()) {
            const auto wireless = active->connection()->settings()->setting(Setting::Wireless).staticCast<WirelessSetting>();
            activeSsid = wireless ? QString::fromUtf8(wireless->ssid()) : QString();
        }
        for (const WirelessNetwork::Ptr &network : m_device->networks()) {
            const QString ssid = network->ssid();
            if (ssid.isEmpty())
                continue;
            const QString security = securityOf(m_device, network->referenceAccessPoint());
            const Connection::Ptr connection = saved.value(ssid);
            const bool isCurrent = ssid == activeSsid;
            const QVariantMap row{
                {QStringLiteral("ssid"), ssid},
                {QStringLiteral("bars"), bars(network->signalStrength())},
                {QStringLiteral("security"), security},
                {QStringLiteral("secure"), secured(security)},
                {QStringLiteral("uuid"), connection ? connection->uuid() : QString()},
                {QStringLiteral("current"), isCurrent},
            };
            if (isCurrent) {
                current = row;
                current.insert(QStringLiteral("uuid"), active->connection()->uuid());
                current.insert(QStringLiteral("state"), active->state() == ActiveConnection::Activated ? QStringLiteral("connected") : QStringLiteral("connecting"));
            }
            (connection || isCurrent ? known : others) << row;
        }
        const auto byName = [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("ssid")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("ssid")).toString()) < 0;
        };
        std::sort(known.begin(), known.end(), byName);
        std::sort(others.begin(), others.end(), byName);
    }
    if (current == m_current && known == m_known && others == m_others)
        return;
    m_current = current;
    m_known = known;
    m_others = others;
    Q_EMIT networksChanged();
}

void WiFi::join(const QString &ssid, const QString &password, const QString &user)
{
    if (!m_device)
        return;
    const WirelessNetwork::Ptr network = m_device->findNetwork(ssid);
    const AccessPoint::Ptr ap = network ? network->referenceAccessPoint() : AccessPoint::Ptr();
    const QString apPath = ap ? ap->uni() : QStringLiteral("/");
    m_joining = ssid;
    m_madePath.clear();

    if (const Connection::Ptr connection = savedNetworks().value(ssid)) {
        // Known: as it was saved, with a new password if one was asked for.
        if (!password.isEmpty()) {
            NMVariantMapMap map = connection->settings()->toMap();
            const QString security = securityOf(m_device, ap);
            if (security == QLatin1String("enterprise"))
                map[QStringLiteral("802-1x")].insert(QStringLiteral("password"), password);
            else if (security == QLatin1String("wep"))
                map[QStringLiteral("802-11-wireless-security")].insert(QStringLiteral("wep-key0"), password);
            else
                map[QStringLiteral("802-11-wireless-security")].insert(QStringLiteral("psk"), password);
            connection->update(map).waitForFinished();
        }
        activateConnection(connection->path(), m_device->uni(), apPath);
        return;
    }
    activate(connectionFor(ssid, securityOf(m_device, ap), password, user, false), ssid, apPath);
}

void WiFi::joinHidden(const QString &ssid, const QString &security, const QString &password, const QString &user)
{
    if (!m_device || ssid.isEmpty())
        return;
    m_joining = ssid;
    m_madePath.clear();
    activate(connectionFor(ssid, security, password, user, true), ssid, QStringLiteral("/"));
}

void WiFi::activate(const NMVariantMapMap &settings, const QString &ssid, const QString &accessPoint)
{
    auto *watcher = new QDBusPendingCallWatcher(addAndActivateConnection(settings, m_device->uni(), accessPoint), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, ssid](QDBusPendingCallWatcher *call) {
        QDBusPendingReply<QDBusObjectPath, QDBusObjectPath> reply = *call;
        if (reply.isError()) {
            if (m_joining == ssid)
                m_joining.clear();
            Q_EMIT joinFailed(ssid, false);
        } else if (m_joining == ssid) {
            m_madePath = reply.argumentAt<0>().path();
        }
        call->deleteLater();
    });
}

// A join that fails takes back the connection made for it, and says if
// it was the password.
void WiFi::deviceStateChanged(int state, int reason)
{
    if (m_joining.isEmpty())
        return;
    if (state == Device::Activated) {
        m_joining.clear();
        m_madePath.clear();
        return;
    }
    if (state != Device::Failed)
        return;
    const bool password = reason == Device::NoSecretsReason || reason == Device::AuthSupplicantDisconnectReason
        || reason == Device::AuthSupplicantTimeoutReason;
    if (!m_madePath.isEmpty()) {
        if (const Connection::Ptr made = findConnection(m_madePath))
            made->remove();
    }
    const QString ssid = m_joining;
    m_joining.clear();
    m_madePath.clear();
    Q_EMIT joinFailed(ssid, password);
}

void WiFi::leave()
{
    if (m_device)
        m_device->disconnectInterface();
}

void WiFi::forget(const QString &uuid)
{
    if (const Connection::Ptr connection = findConnectionByUuid(uuid))
        connection->remove();
}

QVariantMap WiFi::details(const QString &uuid) const
{
    const Connection::Ptr connection = findConnectionByUuid(uuid);
    if (!connection)
        return {};
    const ConnectionSettings::Ptr settings = connection->settings();
    const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
    const auto ipv4 = settings->setting(Setting::Ipv4).staticCast<Ipv4Setting>();
    const auto ipv6 = settings->setting(Setting::Ipv6).staticCast<Ipv6Setting>();
    const QString cloned = wireless->assignedMacAddress();
    const auto strings = [](const QList<QHostAddress> &addresses) {
        QStringList list;
        for (const QHostAddress &address : addresses)
            list << address.toString();
        return list;
    };
    QVariantMap details{
        {QStringLiteral("ssid"), QString::fromUtf8(wireless->ssid())},
        {QStringLiteral("autoJoin"), settings->autoconnect()},
        {QStringLiteral("lowData"), settings->metered() == ConnectionSettings::MeteredYes},
        {QStringLiteral("privateAddress"),
         cloned == QLatin1String("random") ? QStringLiteral("rotating") : cloned == QLatin1String("stable") ? QStringLiteral("fixed") : QStringLiteral("off")},
        {QStringLiteral("mtu"), wireless->mtu()},
        {QStringLiteral("ipv4Method"),
         ipv4->method() == Ipv4Setting::Manual ? QStringLiteral("manual") : ipv4->method() == Ipv4Setting::Disabled ? QStringLiteral("off") : QStringLiteral("dhcp")},
        {QStringLiteral("clientId"), ipv4->dhcpClientId()},
        {QStringLiteral("ipv6Method"),
         ipv6->method() == Ipv6Setting::LinkLocal                                             ? QStringLiteral("link-local")
             : ipv6->method() == Ipv6Setting::Ignored || ipv6->method() == Ipv6Setting::ConfigDisabled ? QStringLiteral("off")
                                                                                              : QStringLiteral("auto")},
        {QStringLiteral("dnsServers"), strings(ipv4->dns()) + strings(ipv6->dns())},
        {QStringLiteral("searchDomains"), ipv4->dnsSearch()},
    };
    if (!ipv4->addressData().isEmpty() || !ipv4->addresses().isEmpty()) {
        IpAddress manual;
        if (!ipv4->addressData().isEmpty()) {
            const QVariantMap data = ipv4->addressData().first();
            manual.setIp(QHostAddress(data.value(QStringLiteral("address")).toString()));
            manual.setPrefixLength(data.value(QStringLiteral("prefix")).toInt());
        } else {
            manual = ipv4->addresses().first();
        }
        details.insert(QStringLiteral("manualIp"), manual.ip().toString());
        details.insert(QStringLiteral("manualSubnet"), manual.netmask().toString());
        details.insert(QStringLiteral("manualRouter"), ipv4->gateway());
    }
    if (!m_device)
        return details;
    details.insert(QStringLiteral("address"), m_device->hardwareAddress());
    details.insert(QStringLiteral("mac"), m_device->permanentHardwareAddress());
    const ActiveConnection::Ptr active = m_device->activeConnection();
    if (!active || !active->connection() || active->connection()->uuid() != uuid)
        return details;
    const IpConfig ip = m_device->ipV4Config();
    if (!ip.addresses().isEmpty()) {
        const IpAddress first = ip.addresses().first();
        details.insert(QStringLiteral("ip"), first.ip().toString());
        details.insert(QStringLiteral("subnet"), first.netmask().toString());
    }
    details.insert(QStringLiteral("router"), ip.gateway());
    const IpConfig ip6 = m_device->ipV6Config();
    details.insert(QStringLiteral("ipv6Router"), ip6.gateway());
    QVariantList addresses;
    for (const IpAddress &address : ip6.addresses()) {
        if (!address.ip().isLinkLocal())
            addresses << QVariantMap{{QStringLiteral("address"), address.ip().toString()}, {QStringLiteral("prefix"), address.prefixLength()}};
    }
    details.insert(QStringLiteral("ipv6"), addresses);
    details.insert(QStringLiteral("dns"), strings(ip.nameservers()) + strings(ip6.nameservers()));
    details.insert(QStringLiteral("domains"), ip.searches() + ip.domains());
    return details;
}

void WiFi::applyDetails(const QString &uuid, const QVariantMap &changes)
{
    const Connection::Ptr connection = findConnectionByUuid(uuid);
    if (!connection || changes.isEmpty())
        return;
    const ConnectionSettings::Ptr settings = connection->settings();
    const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
    const auto ipv4 = settings->setting(Setting::Ipv4).staticCast<Ipv4Setting>();
    const auto ipv6 = settings->setting(Setting::Ipv6).staticCast<Ipv6Setting>();
    const auto has = [&changes](const char *key) { return changes.contains(QLatin1String(key)); };
    const auto text = [&changes](const char *key) { return changes.value(QLatin1String(key)).toString(); };

    if (has("autoJoin"))
        settings->setAutoconnect(changes.value(QStringLiteral("autoJoin")).toBool());
    if (has("lowData"))
        settings->setMetered(changes.value(QStringLiteral("lowData")).toBool() ? ConnectionSettings::MeteredYes : ConnectionSettings::MeteredUnknown);
    // A private address: off is the computer's own, fixed is one of its
    // own for this network, rotating a new one each time.
    if (has("privateAddress"))
        wireless->setAssignedMacAddress(text("privateAddress") == QLatin1String("rotating") ? QStringLiteral("random")
                                            : text("privateAddress") == QLatin1String("fixed") ? QStringLiteral("stable")
                                                                                               : QStringLiteral("permanent"));
    if (has("mtu"))
        wireless->setMtu(changes.value(QStringLiteral("mtu")).toUInt());
    if (has("ipv4Method") || has("manualIp") || has("manualSubnet") || has("manualRouter")) {
        const QString method = has("ipv4Method") ? text("ipv4Method") : details(uuid).value(QStringLiteral("ipv4Method")).toString();
        ipv4->setMethod(method == QLatin1String("manual") ? Ipv4Setting::Manual : method == QLatin1String("off") ? Ipv4Setting::Disabled : Ipv4Setting::Automatic);
        if (method == QLatin1String("manual")) {
            const QVariantMap now = details(uuid);
            const auto value = [&](const char *key) { return has(key) ? text(key) : now.value(QLatin1String(key)).toString(); };
            // NetworkManager reads address-data over the old addresses list.
            IpAddress address;
            address.setIp(QHostAddress(value("manualIp")));
            address.setNetmask(QHostAddress(value("manualSubnet")));
            ipv4->setAddresses({});
            ipv4->setAddressData({QVariantMap{{QStringLiteral("address"), address.ip().toString()},
                                              {QStringLiteral("prefix"), static_cast<uint>(address.prefixLength())}}});
            ipv4->setGateway(value("manualRouter"));
        } else {
            ipv4->setAddresses({});
            ipv4->setAddressData({});
            ipv4->setGateway({});
        }
    }
    if (has("clientId"))
        ipv4->setDhcpClientId(text("clientId"));
    if (has("ipv6Method")) {
        const QString method = text("ipv6Method");
        ipv6->setMethod(method == QLatin1String("link-local") ? Ipv6Setting::LinkLocal : method == QLatin1String("off") ? Ipv6Setting::Ignored : Ipv6Setting::Automatic);
    }
    // Servers typed in replace the network's own, as on a Mac.
    if (has("dnsServers")) {
        QList<QHostAddress> v4, v6;
        for (const QString &server : changes.value(QStringLiteral("dnsServers")).toStringList()) {
            const QHostAddress address(server);
            (address.protocol() == QAbstractSocket::IPv6Protocol ? v6 : v4) << address;
        }
        ipv4->setDns(v4);
        ipv6->setDns(v6);
        ipv4->setIgnoreAutoDns(!v4.isEmpty() || !v6.isEmpty());
        ipv6->setIgnoreAutoDns(!v4.isEmpty() || !v6.isEmpty());
    }
    if (has("searchDomains"))
        ipv4->setDnsSearch(changes.value(QStringLiteral("searchDomains")).toStringList());

    const NMVariantMapMap map = settings->toMap();
    const bool rejoin = has("privateAddress") || has("mtu");
    auto *watcher = new QDBusPendingCallWatcher(connection->update(map), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, uuid, map, rejoin, connection](QDBusPendingCallWatcher *call) {
        if (call->isError())
            qWarning("Settings: couldn't save %s: %s", qPrintable(uuid), qPrintable(call->error().message()));
        const ActiveConnection::Ptr active = m_device ? m_device->activeConnection() : ActiveConnection::Ptr();
        if (!call->isError() && active && active->connection() && active->connection()->uuid() == uuid) {
            if (rejoin)
                activateConnection(connection->path(), m_device->uni(), QStringLiteral("/"));
            else
                m_device->reapplyConnection(map, 0, 0);
        }
        call->deleteLater();
        Q_EMIT detailsChanged();
    });
}

void WiFi::copyPassword(const QString &uuid)
{
    const Connection::Ptr connection = findConnectionByUuid(uuid);
    if (!connection)
        return;
    static const QString security = QStringLiteral("802-11-wireless-security");
    auto *watcher = new QDBusPendingCallWatcher(connection->secrets(security), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [uuid](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<NMVariantMapMap> reply = *call;
        call->deleteLater();
        if (reply.isError()) {
            qWarning("Settings: no password for %s: %s", qPrintable(uuid), qPrintable(reply.error().message()));
            return;
        }
        const QString password = reply.value().value(security).value(QStringLiteral("psk")).toString();
        if (password.isEmpty())
            qWarning("Settings: no password saved for %s", qPrintable(uuid));
        else
            QGuiApplication::clipboard()->setText(password);
    });
}
