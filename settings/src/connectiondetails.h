#pragma once

#include <NetworkManagerQt/Connection>
#include <NetworkManagerQt/Device>

#include <QVariantMap>
#include <functional>

// A saved connection's settings, as a Details… sheet shows them, for Wi-Fi
// and the other services alike. `device` is the one it's used on.
namespace ConnectionDetails
{
// {name, ssid (a Wi-Fi network's), autoJoin, lowData, privateAddress ("off",
// "fixed" or "rotating"), address (this computer's on it), mac (its own), mtu
// (0: standard), ipv4Method ("dhcp", "manual" or "off") with manualIp,
// manualSubnet, manualRouter and clientId; ipv6Method ("auto", "link-local"
// or "off"); dnsServers [] and searchDomains [] typed in; and while in use
// ip, subnet, router, ipv6Router, ipv6 [{address, prefix}], dns [] and
// domains [] as they are}.
QVariantMap read(const NetworkManager::Connection::Ptr &connection, const NetworkManager::Device::Ptr &device);
// The sheet's OK: changes holds the keys above that changed. In use, it takes
// them at once (joined again for a new address or MTU, as on a Mac). `done`
// runs on `context` once saved.
void apply(const NetworkManager::Connection::Ptr &connection, const NetworkManager::Device::Ptr &device, const QVariantMap &changes, QObject *context, std::function<void()> done);
}
