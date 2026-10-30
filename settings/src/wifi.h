#pragma once

#include <NetworkManagerQt/WirelessDevice>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Wi-Fi, on NetworkManager (NetworkManagerQt): the radio on or off; the
// network in use and how far joining it has got; the networks in range,
// those with a saved connection apart, by name as System Settings lists
// them; joining one (with its password, or a hidden one by name),
// leaving and forgetting one; and a saved network's options: auto-join,
// low data mode (metered), a private address (a cloned MAC), and its
// addresses while in use.
class WiFi : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // A Wi-Fi device is there at all.
    Q_PROPERTY(bool available READ available NOTIFY deviceChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    // Off by a hardware switch: the radio can't be turned on from here.
    Q_PROPERTY(bool blocked READ blocked NOTIFY enabledChanged)
    // {ssid, state ("connecting" or "connected"), secure, bars, uuid} of
    // the network in use, or {} for none.
    Q_PROPERTY(QVariantMap current READ current NOTIFY networksChanged)
    // [{ssid, bars (1 to 3), secure, security, uuid, current}] in range:
    // those this computer has joined before, then the rest; by name.
    Q_PROPERTY(QVariantList known READ known NOTIFY networksChanged)
    Q_PROPERTY(QVariantList others READ others NOTIFY networksChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    // While the page shows: looks for networks every so often.
    Q_PROPERTY(bool watching READ watching WRITE setWatching NOTIFY watchingChanged)

public:
    explicit WiFi(QObject *parent = nullptr);

    bool available() const { return !m_device.isNull(); }
    bool enabled() const;
    bool blocked() const;
    QVariantMap current() const { return m_current; }
    QVariantList known() const { return m_known; }
    QVariantList others() const { return m_others; }
    bool scanning() const { return m_scanning; }
    bool watching() const { return m_watching; }
    void setWatching(bool on);

    Q_INVOKABLE void setEnabled(bool on);
    Q_INVOKABLE void scan();
    // Joins a network in range: a known one as it was saved, an open one
    // as it is, a secured one with `password` (and `user`, for a network
    // of a company's, 802.1X). A failure says so through joinFailed.
    Q_INVOKABLE void join(const QString &ssid, const QString &password = {}, const QString &user = {});
    // A network that doesn't say its name: security is "none", "wpa"
    // (WPA/WPA2 Personal), "sae" (WPA3 Personal) or "enterprise".
    Q_INVOKABLE void joinHidden(const QString &ssid, const QString &security, const QString &password, const QString &user = {});
    Q_INVOKABLE void leave(); // the network in use
    Q_INVOKABLE void forget(const QString &uuid);

    // A saved network's settings, as its Details… sheet shows them:
    // {ssid, autoJoin, lowData, privateAddress ("off", "fixed" or
    // "rotating"), address (this computer's on it), mac (its own), mtu (0:
    // standard), ipv4Method ("dhcp", "manual" or "off") with manualIp,
    // manualSubnet, manualRouter and clientId; ipv6Method ("auto",
    // "link-local" or "off"); dnsServers [] and searchDomains [] typed in;
    // and while in use ip, subnet, router, ipv6Router, ipv6 [{address,
    // prefix}], dns [] and domains [] as they are}.
    Q_INVOKABLE QVariantMap details(const QString &uuid) const;
    // The sheet's OK: changes holds the keys above that changed. In use,
    // the network takes them at once (joined again for a new address or
    // MTU, as on a Mac).
    Q_INVOKABLE void applyDetails(const QString &uuid, const QVariantMap &changes);
    // A known network's password, onto the clipboard.
    Q_INVOKABLE void copyPassword(const QString &uuid);

Q_SIGNALS:
    void deviceChanged();
    void enabledChanged();
    void networksChanged();
    void scanningChanged();
    void watchingChanged();
    void detailsChanged();
    // Joining `ssid` failed; `password` if what it needs is its password
    // (none given, or the wrong one).
    void joinFailed(const QString &ssid, bool password);

private:
    void findDevice();
    void watchNetwork(const QString &ssid);
    void refresh();
    void deviceStateChanged(int state, int reason);
    void activate(const NMVariantMapMap &settings, const QString &ssid, const QString &accessPoint);

    NetworkManager::WirelessDevice::Ptr m_device;
    QTimer m_refresh;
    QTimer m_rescan;
    QVariantMap m_current;
    QVariantList m_known;
    QVariantList m_others;
    bool m_scanning = false;
    bool m_watching = false;
    // A join under way: the network, and the connection made for it (to
    // take back if it fails: nothing is saved of a network never joined).
    QString m_joining;
    QString m_madePath;
};
