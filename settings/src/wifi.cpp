#include "wifi.h"

#include "connectiondetails.h"

#include <KConfigGroup>
#include <KSharedConfig>
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
#include <NetworkManagerQt/WirelessSecuritySetting>
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

// The best way into a network that this card has.
WirelessSecurityType bestSecurity(const WirelessDevice::Ptr &device, const AccessPoint::Ptr &ap)
{
    return findBestWirelessSecurity(device->wirelessCapabilities(), true, ap->mode() == AccessPoint::Adhoc, ap->capabilities(),
                                    ap->wpaFlags(), ap->rsnFlags());
}

// What joining a network takes: "none", "owe" (encrypted, no password),
// "wep", "wpa" (WPA2/WPA3 Personal), "sae" (WPA3 Personal) or "enterprise".
QString securityOf(const WirelessDevice::Ptr &device, const AccessPoint::Ptr &ap)
{
    if (!ap)
        return QStringLiteral("none");
    switch (bestSecurity(device, ap)) {
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

// A network of an old kind, which a Mac lists only if asked to: WEP, or
// WPA without WPA2.
bool legacy(const WirelessDevice::Ptr &device, const AccessPoint::Ptr &ap)
{
    if (!ap)
        return false;
    switch (bestSecurity(device, ap)) {
    case StaticWep:
    case DynamicWep:
    case Leap:
    case WpaPsk:
    case WpaEap:
        return true;
    default:
        return false;
    }
}

// A saved network's security, by NetworkManager's key management and
// protocols: wpa-psk is WPA2 and WPA3 Personal both (WPA/WPA2 with proto
// wpa too), sae WPA3 only; wpa-eap is WPA2 Enterprise (WPA/WPA2 with proto
// wpa too), or WPA3 Enterprise with pmf required; suite B WPA3 only.
QString savedSecurity(const ConnectionSettings::Ptr &settings)
{
    const auto security = settings->setting(Setting::WirelessSecurity).staticCast<WirelessSecuritySetting>();
    switch (security ? security->keyMgmt() : WirelessSecuritySetting::Unknown) {
    case WirelessSecuritySetting::Wep:
        return QStringLiteral("wep");
    case WirelessSecuritySetting::Ieee8021x:
        return QStringLiteral("dynamic-wep");
    case WirelessSecuritySetting::WpaPsk:
        return security->proto().contains(WirelessSecuritySetting::Wpa) ? QStringLiteral("wpa-wpa2") : QStringLiteral("wpa");
    case WirelessSecuritySetting::SAE:
        return QStringLiteral("sae");
    case WirelessSecuritySetting::WpaEap:
        if (security->pmf() == WirelessSecuritySetting::RequiredPmf)
            return QStringLiteral("enterprise3");
        return security->proto().contains(WirelessSecuritySetting::Wpa) ? QStringLiteral("wpa-wpa2-enterprise") : QStringLiteral("enterprise");
    case WirelessSecuritySetting::WpaEapSuiteB192:
        return QStringLiteral("enterprise3");
    case WirelessSecuritySetting::OWE:
        return QStringLiteral("owe");
    default:
        return QStringLiteral("none");
    }
}

KConfigGroup preferences()
{
    return KSharedConfig::openConfig(QStringLiteral("ambrosiarc"))->group(QStringLiteral("Wi-Fi"));
}

// The private addresses chosen for networks not joined yet, by name.
KConfigGroup privateAddresses()
{
    return KSharedConfig::openConfig(QStringLiteral("ambrosiarc"))->group(QStringLiteral("Wi-Fi Private Addresses"));
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
    const QString privateAddress = privateAddresses().readEntry(ssid, QString());
    if (!privateAddress.isEmpty())
        wireless.insert(QStringLiteral("assigned-mac-address"), privateAddress == QLatin1String("rotating") ? QStringLiteral("random") : QStringLiteral("stable"));
    map[QStringLiteral("802-11-wireless")] = wireless;
    // Secrets are kept by the system for every user, as a Mac keeps them
    // in its System keychain.
    // Without a password, NetworkManager asks the session's secret agent.
    if (security == QLatin1String("wpa") || security == QLatin1String("wpa-wpa2") || security == QLatin1String("sae")) {
        QVariantMap wpa{{QStringLiteral("key-mgmt"), security == QLatin1String("sae") ? QStringLiteral("sae") : QStringLiteral("wpa-psk")}};
        if (security == QLatin1String("wpa-wpa2"))
            wpa.insert(QStringLiteral("proto"), QStringList{QStringLiteral("wpa"), QStringLiteral("rsn")});
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
    } else if (security == QLatin1String("enterprise") || security == QLatin1String("wpa-wpa2-enterprise")
               || security == QLatin1String("enterprise3") || security == QLatin1String("dynamic-wep")) {
        // A name and password, as a Mac asks: PEAP with MSCHAPv2 inside,
        // what most such networks take.
        QVariantMap key{{QStringLiteral("key-mgmt"), security == QLatin1String("dynamic-wep") ? QStringLiteral("ieee8021x") : QStringLiteral("wpa-eap")}};
        if (security == QLatin1String("wpa-wpa2-enterprise"))
            key.insert(QStringLiteral("proto"), QStringList{QStringLiteral("wpa"), QStringLiteral("rsn")});
        if (security == QLatin1String("enterprise3"))
            key.insert(QStringLiteral("pmf"), static_cast<int>(WirelessSecuritySetting::RequiredPmf));
        map[QStringLiteral("802-11-wireless-security")] = key;
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
    m_showLegacy = preferences().readEntry("ShowLegacyNetworks", false);
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

void WiFi::setShowLegacy(bool on)
{
    if (m_showLegacy == on)
        return;
    m_showLegacy = on;
    KConfigGroup group = preferences();
    group.writeEntry("ShowLegacyNetworks", on);
    group.sync();
    Q_EMIT showLegacyChanged();
    refresh();
}

QString WiFi::address() const
{
    if (!m_device)
        return {};
    const QString own = m_device->permanentHardwareAddress();
    return (own.isEmpty() ? m_device->hardwareAddress() : own).toLower();
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
    QVariantList known, others, saved;
    const auto byName = [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("ssid")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("ssid")).toString()) < 0;
    };
    for (const Connection::Ptr &connection : listConnections()) {
        const ConnectionSettings::Ptr settings = connection->settings();
        if (settings->connectionType() != ConnectionSettings::Wireless)
            continue;
        const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
        if (wireless->mode() != WirelessSetting::Infrastructure)
            continue;
        const QString security = savedSecurity(settings);
        saved << QVariantMap{
            {QStringLiteral("ssid"), QString::fromUtf8(wireless->ssid())},
            {QStringLiteral("uuid"), connection->uuid()},
            {QStringLiteral("security"), security},
            {QStringLiteral("secure"), secured(security)},
        };
    }
    std::sort(saved.begin(), saved.end(), byName);
    if (m_device && enabled()) {
        const QHash<QString, Connection::Ptr> savedByName = savedNetworks();
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
            const Connection::Ptr connection = savedByName.value(ssid);
            const bool isCurrent = ssid == activeSsid;
            if (!connection && !isCurrent && !m_showLegacy && legacy(m_device, network->referenceAccessPoint()))
                continue;
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
        std::sort(known.begin(), known.end(), byName);
        std::sort(others.begin(), others.end(), byName);
    }
    if (current == m_current && known == m_known && others == m_others && saved == m_saved)
        return;
    m_current = current;
    m_known = known;
    m_others = others;
    m_saved = saved;
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

void WiFi::addNetwork(const QString &ssid, const QString &security, const QString &password, const QString &user)
{
    if (ssid.isEmpty())
        return;
    auto *watcher = new QDBusPendingCallWatcher(addConnection(connectionFor(ssid, security, password, user, true)), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, ssid](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QDBusObjectPath> reply = *call;
        call->deleteLater();
        if (reply.isError()) {
            qWarning("Settings: couldn't add %s: %s", qPrintable(ssid), qPrintable(reply.error().message()));
            return;
        }
        if (m_device && enabled())
            activateConnection(reply.value().path(), m_device->uni(), QStringLiteral("/"));
    });
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
        // The connection keeps it now.
        KConfigGroup kept = privateAddresses();
        kept.deleteEntry(m_joining);
        kept.sync();
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

QString WiFi::privateAddressFor(const QString &ssid) const
{
    return privateAddresses().readEntry(ssid, QStringLiteral("off"));
}

void WiFi::setPrivateAddressFor(const QString &ssid, const QString &mode)
{
    KConfigGroup kept = privateAddresses();
    if (mode == QLatin1String("off"))
        kept.deleteEntry(ssid);
    else
        kept.writeEntry(ssid, mode);
    kept.sync();
}

QVariantMap WiFi::details(const QString &uuid) const
{
    return ConnectionDetails::read(findConnectionByUuid(uuid), m_device);
}

void WiFi::applyDetails(const QString &uuid, const QVariantMap &changes)
{
    ConnectionDetails::apply(findConnectionByUuid(uuid), m_device, changes, this, [this] { Q_EMIT detailsChanged(); });
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
