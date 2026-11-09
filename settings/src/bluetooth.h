#pragma once

#include <BluezQt/Types>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Bluetooth, on BlueZ (BluezQt): the radio on or off; this computer's name
// as others see it, discoverable while the pane is open as System Settings
// makes a Mac; the devices paired with it (My Devices) and the named ones
// in range (Nearby Devices), by name; pairing and connecting one,
// disconnecting, renaming and forgetting one. Pairing asks for codes
// through the session's agent (bluedevil's).
class Bluetooth : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // An adapter is there at all (until BlueZ has answered: a controller
    // the kernel knows).
    Q_PROPERTY(bool available READ available NOTIFY adapterChanged)
    // BlueZ has answered.
    Q_PROPERTY(bool ready READ ready NOTIFY adapterChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    // Off by a hardware switch: the radio can't be turned on from here.
    Q_PROPERTY(bool blocked READ blocked NOTIFY enabledChanged)
    Q_PROPERTY(QString name READ name NOTIFY adapterChanged)
    // [{address, name, kind (its glyph), connected, busy (being paired or
    // connected from here), battery (percent, or -1)}], by name.
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList nearby READ nearby NOTIFY devicesChanged)
    Q_PROPERTY(bool discovering READ discovering NOTIFY discoveringChanged)
    // While the page shows: looks for devices and lets them find this one.
    Q_PROPERTY(bool watching READ watching WRITE setWatching NOTIFY watchingChanged)

public:
    explicit Bluetooth(QObject *parent = nullptr);
    ~Bluetooth() override;

    bool available() const { return m_ready ? !m_adapter.isNull() : m_controller; }
    bool ready() const { return m_ready; }
    bool enabled() const;
    bool blocked() const;
    QString name() const;
    QVariantList devices() const { return m_devices; }
    QVariantList nearby() const { return m_nearby; }
    bool discovering() const;
    bool watching() const { return m_watching; }
    void setWatching(bool on);

    Q_INVOKABLE void setEnabled(bool on);
    // Pairs first if it isn't paired. A failure says so through failed.
    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);
    Q_INVOKABLE void rename(const QString &address, const QString &name);
    Q_INVOKABLE void forget(const QString &address);
    // {name, address, kind, connected, paired, battery}
    Q_INVOKABLE QVariantMap details(const QString &address) const;

Q_SIGNALS:
    void adapterChanged();
    void enabledChanged();
    void devicesChanged();
    void discoveringChanged();
    void watchingChanged();
    void failed(const QString &address, const QString &name);

private:
    void setUp();
    void findAdapter();
    void refresh();
    void look();
    void stopLooking();
    void connectPaired(const BluezQt::DevicePtr &device);
    void done(const QString &address, bool ok, const QString &name);

    BluezQt::Manager *m_manager;
    BluezQt::AdapterPtr m_adapter;
    QTimer m_refresh;
    // Discoverable runs out (after 3 minutes, as BlueZ is set up): renewed
    // while the page shows.
    QTimer m_renew;
    QVariantList m_devices;
    QVariantList m_nearby;
    QSet<QString> m_busy;
    bool m_watching = false;
    bool m_ready = false;
    bool m_controller = false;
    bool m_wasDiscoverable = false;
};
