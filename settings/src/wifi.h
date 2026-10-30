#pragma once

#include <NetworkManagerQt/WirelessDevice>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Wi-Fi, on NetworkManager (NetworkManagerQt): the radio on or off; the
// network in use and how far joining it has got; the networks in range,
// those with a saved connection apart, by name as System Settings lists
// them; joining one (with its password), adding one by name (Other…),
// leaving and forgetting one; every network saved here (Advanced…); and a
// saved network's options: auto-join, low data mode (metered), a private
// address (a cloned MAC), and its addresses while in use.
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
    // those this computer has joined before, then the rest; by name. The
    // rest leave out networks of an old kind (WEP, WPA) unless showLegacy.
    Q_PROPERTY(QVariantList known READ known NOTIFY networksChanged)
    Q_PROPERTY(QVariantList others READ others NOTIFY networksChanged)
    // [{ssid, secure, security, uuid}]: every network saved here, in range
    // or not, by name. security is "none", "owe", "wep", "dynamic-wep",
    // "wpa-wpa2" (WPA/WPA2 Personal), "wpa" (WPA2/WPA3 Personal), "sae"
    // (WPA3 Personal), "enterprise" (WPA2 Enterprise), "wpa-wpa2-enterprise"
    // (WPA/WPA2 Enterprise) or "enterprise3" (WPA3 Enterprise).
    Q_PROPERTY(QVariantList saved READ saved NOTIFY networksChanged)
    // Networks of an old kind shown too, in the lists (Advanced…), kept in
    // ambrosiarc.
    Q_PROPERTY(bool showLegacy READ showLegacy WRITE setShowLegacy NOTIFY showLegacyChanged)
    // The card's own address, as Advanced… shows it.
    Q_PROPERTY(QString address READ address NOTIFY deviceChanged)
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
    QVariantList saved() const { return m_saved; }
    bool showLegacy() const { return m_showLegacy; }
    void setShowLegacy(bool on);
    QString address() const;
    bool scanning() const { return m_scanning; }
    bool watching() const { return m_watching; }
    void setWatching(bool on);

    Q_INVOKABLE void setEnabled(bool on);
    Q_INVOKABLE void scan();
    // Joins a network in range: a known one as it was saved, an open one
    // as it is, a secured one with `password` (and `user`, for a network
    // of a company's, 802.1X). A failure says so through joinFailed.
    Q_INVOKABLE void join(const QString &ssid, const QString &password = {}, const QString &user = {});
    // A network by its name (one that doesn't say it, or isn't in range),
    // saved as a Mac adds a Wi-Fi profile, then joined; kept if joining
    // fails. security is one of saved's.
    Q_INVOKABLE void addNetwork(const QString &ssid, const QString &security, const QString &password, const QString &user = {});
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
    // The private address ("off", "fixed" or "rotating") a network not yet
    // joined will be joined with (its ⋯), kept in ambrosiarc until it is.
    Q_INVOKABLE QString privateAddressFor(const QString &ssid) const;
    Q_INVOKABLE void setPrivateAddressFor(const QString &ssid, const QString &mode);
    // A known network's password, onto the clipboard.
    Q_INVOKABLE void copyPassword(const QString &uuid);

Q_SIGNALS:
    void deviceChanged();
    void enabledChanged();
    void networksChanged();
    void scanningChanged();
    void watchingChanged();
    void showLegacyChanged();
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
    QVariantList m_saved;
    bool m_showLegacy = false;
    bool m_scanning = false;
    bool m_watching = false;
    // A join under way: the network, and the connection made for it (to
    // take back if it fails: nothing is saved of a network never joined).
    QString m_joining;
    QString m_madePath;
};
