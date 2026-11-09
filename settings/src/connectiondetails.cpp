#include "connectiondetails.h"

#include <NetworkManagerQt/ActiveConnection>
#include <NetworkManagerQt/ConnectionSettings>
#include <NetworkManagerQt/Ipv4Setting>
#include <NetworkManagerQt/Ipv6Setting>
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/WiredDevice>
#include <NetworkManagerQt/WiredSetting>
#include <NetworkManagerQt/WirelessDevice>
#include <NetworkManagerQt/WirelessSetting>

#include <QDBusPendingCallWatcher>
#include <QHostAddress>

using namespace NetworkManager;

QVariantMap ConnectionDetails::read(const Connection::Ptr &connection, const Device::Ptr &device)
{
    if (!connection)
        return {};
    const QString uuid = connection->uuid();
    const ConnectionSettings::Ptr settings = connection->settings();
    const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
    const auto wired = settings->setting(Setting::Wired).staticCast<WiredSetting>();
    const auto ipv4 = settings->setting(Setting::Ipv4).staticCast<Ipv4Setting>();
    const auto ipv6 = settings->setting(Setting::Ipv6).staticCast<Ipv6Setting>();
    const QString cloned = wireless ? wireless->assignedMacAddress() : QString();
    const auto strings = [](const QList<QHostAddress> &addresses) {
        QStringList list;
        for (const QHostAddress &address : addresses)
            list << address.toString();
        return list;
    };
    QVariantMap details{
        {QStringLiteral("name"), settings->id()},
        {QStringLiteral("autoJoin"), settings->autoconnect()},
        {QStringLiteral("lowData"), settings->metered() == ConnectionSettings::MeteredYes},
        {QStringLiteral("privateAddress"),
         cloned == QLatin1String("random") ? QStringLiteral("rotating") : cloned == QLatin1String("stable") ? QStringLiteral("fixed") : QStringLiteral("off")},
        {QStringLiteral("mtu"), wireless ? wireless->mtu() : wired ? wired->mtu() : 0},
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
    if (wireless)
        details.insert(QStringLiteral("ssid"), QString::fromUtf8(wireless->ssid()));
    if (!device)
        return details;
    QString current, own;
    if (const auto radio = device.objectCast<WirelessDevice>()) {
        current = radio->hardwareAddress();
        own = radio->permanentHardwareAddress();
    } else if (const auto port = device.objectCast<WiredDevice>()) {
        current = port->hardwareAddress();
        own = port->permanentHardwareAddress();
    }
    details.insert(QStringLiteral("address"), current);
    details.insert(QStringLiteral("mac"), own);
    const ActiveConnection::Ptr active = device->activeConnection();
    if (!active || !active->connection() || active->connection()->uuid() != uuid)
        return details;
    const IpConfig ip = device->ipV4Config();
    if (!ip.addresses().isEmpty()) {
        const IpAddress first = ip.addresses().first();
        details.insert(QStringLiteral("ip"), first.ip().toString());
        details.insert(QStringLiteral("subnet"), first.netmask().toString());
    }
    details.insert(QStringLiteral("router"), ip.gateway());
    const IpConfig ip6 = device->ipV6Config();
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

void ConnectionDetails::apply(const Connection::Ptr &connection, const Device::Ptr &device, const QVariantMap &changes, QObject *context, std::function<void()> done)
{
    if (!connection || changes.isEmpty())
        return;
    const QString uuid = connection->uuid();
    const ConnectionSettings::Ptr settings = connection->settings();
    const auto wireless = settings->setting(Setting::Wireless).staticCast<WirelessSetting>();
    const auto wired = settings->setting(Setting::Wired).staticCast<WiredSetting>();
    const auto ipv4 = settings->setting(Setting::Ipv4).staticCast<Ipv4Setting>();
    const auto ipv6 = settings->setting(Setting::Ipv6).staticCast<Ipv6Setting>();
    const auto has = [&changes](const char *key) { return changes.contains(QLatin1String(key)); };
    const auto text = [&changes](const char *key) { return changes.value(QLatin1String(key)).toString(); };

    if (has("name"))
        settings->setId(text("name"));
    if (has("autoJoin"))
        settings->setAutoconnect(changes.value(QStringLiteral("autoJoin")).toBool());
    if (has("lowData"))
        settings->setMetered(changes.value(QStringLiteral("lowData")).toBool() ? ConnectionSettings::MeteredYes : ConnectionSettings::MeteredUnknown);
    // A private address: off is the computer's own, fixed is one of its
    // own for this network, rotating a new one each time.
    if (has("privateAddress") && wireless)
        wireless->setAssignedMacAddress(text("privateAddress") == QLatin1String("rotating") ? QStringLiteral("random")
                                            : text("privateAddress") == QLatin1String("fixed") ? QStringLiteral("stable")
                                                                                               : QStringLiteral("permanent"));
    if (has("mtu")) {
        if (wireless)
            wireless->setMtu(changes.value(QStringLiteral("mtu")).toUInt());
        else if (wired)
            wired->setMtu(changes.value(QStringLiteral("mtu")).toUInt());
    }
    if (has("ipv4Method") || has("manualIp") || has("manualSubnet") || has("manualRouter")) {
        const QString method = has("ipv4Method") ? text("ipv4Method") : read(connection, device).value(QStringLiteral("ipv4Method")).toString();
        ipv4->setMethod(method == QLatin1String("manual") ? Ipv4Setting::Manual : method == QLatin1String("off") ? Ipv4Setting::Disabled : Ipv4Setting::Automatic);
        if (method == QLatin1String("manual")) {
            const QVariantMap now = read(connection, device);
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
    auto *watcher = new QDBusPendingCallWatcher(connection->update(map), context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [uuid, map, rejoin, connection, device, done](QDBusPendingCallWatcher *call) {
        if (call->isError())
            qWarning("Settings: couldn't save %s: %s", qPrintable(uuid), qPrintable(call->error().message()));
        const ActiveConnection::Ptr active = device ? device->activeConnection() : ActiveConnection::Ptr();
        if (!call->isError() && active && active->connection() && active->connection()->uuid() == uuid) {
            if (rejoin)
                activateConnection(connection->path(), device->uni(), QStringLiteral("/"));
            else
                device->reapplyConnection(map, 0, 0);
        }
        call->deleteLater();
        done();
    });
}
