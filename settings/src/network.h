#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Network, on NetworkManager (NetworkManagerQt): the computer's network
// services as System Settings lists them — its Ethernet ports, Wi-Fi,
// phones that share their connection over Bluetooth and mobile broadband
// modems, each with whether it's connected — and the VPNs NetworkManager
// holds. Interfaces run outside NetworkManager (a VPN's own tunnel,
// containers' bridges) aren't services here, as on a Mac.
class Network : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{id, name, kind, state}]: kind "ethernet", "wifi", "bluetooth" or
    // "modem"; state "connected", "connecting", "off" (Wi-Fi's radio) or
    // "disconnected". Those connected first (System Settings' top box),
    // the rest after (Other Services); each in the order a Mac keeps its
    // services: wired, Wi-Fi, the rest.
    Q_PROPERTY(QVariantList connected READ connected NOTIFY servicesChanged)
    Q_PROPERTY(QVariantList others READ others NOTIFY servicesChanged)
    // {state} of the VPNs together, as System Settings' one VPN row: any
    // connected, connecting, or none; {} when there are none.
    Q_PROPERTY(QVariantMap vpn READ vpn NOTIFY servicesChanged)

public:
    explicit Network(QObject *parent = nullptr);

    QVariantList connected() const { return m_connected; }
    QVariantList others() const { return m_others; }
    QVariantMap vpn() const { return m_vpn; }

Q_SIGNALS:
    void servicesChanged();

private:
    void watch();
    void refresh();

    QTimer m_refresh;
    QVariantList m_connected;
    QVariantList m_others;
    QVariantMap m_vpn;
};
