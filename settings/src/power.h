#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Battery (Energy with none) and Lock Screen: Low Power Mode
// (power-profiles-daemon, which PowerDevil switches with the power source),
// sleeping and the display turning off when idle (PowerDevil's powerdevilrc,
// which it's told to reread), the battery (UPower) and when a password is
// needed after the display turns off (kscreenlocker's kscreenlockerrc).
class Power : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool hasBattery READ hasBattery NOTIFY hasBatteryChanged)
    Q_PROPERTY(bool onBattery READ onBattery NOTIFY changed)
    // Low Power Mode: on a desktop on or off (the profile now); with a
    // battery "never", "always", "battery" or "adapter" (PowerDevil's
    // profile for each source).
    Q_PROPERTY(bool lowPowerAvailable READ lowPowerAvailable NOTIFY changed)
    Q_PROPERTY(bool lowPower READ lowPower WRITE setLowPower NOTIFY changed)
    Q_PROPERTY(QString lowPowerMode READ lowPowerMode WRITE setLowPowerMode NOTIFY changed)
    // Whether the computer can sleep at all (logind), and whether it stays
    // awake on power when idle with the display off.
    Q_PROPERTY(bool canSleep READ canSleep NOTIFY changed)
    Q_PROPERTY(bool preventSleep READ preventSleep WRITE setPreventSleep NOTIFY changed)
    // The battery: its charge, what it's doing, its health (the most it
    // holds against new, -1 unknown), a charge limit where the firmware has one.
    Q_PROPERTY(int percentage READ percentage NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(int capacity READ capacity NOTIFY changed)
    Q_PROPERTY(bool chargeLimitSupported READ chargeLimitSupported NOTIFY changed)
    Q_PROPERTY(bool chargeLimit READ chargeLimit WRITE setChargeLimit NOTIFY changed)
    Q_PROPERTY(int chargeLimitPercent READ chargeLimitPercent NOTIFY changed)
    // Seconds idle before the display turns off, on power and on battery; 0 never.
    Q_PROPERTY(int displayOffAdapter READ displayOffAdapter NOTIFY changed)
    Q_PROPERTY(int displayOffBattery READ displayOffBattery NOTIFY changed)
    // Seconds after the display turns off that a password is needed; -1 never.
    Q_PROPERTY(int requirePasswordAfter READ requirePasswordAfter WRITE setRequirePasswordAfter NOTIFY changed)

public:
    explicit Power(QObject *parent = nullptr);

    bool hasBattery() const { return !m_battery.isEmpty(); }
    bool onBattery() const { return m_onBattery; }
    bool lowPowerAvailable() const { return m_lowPowerAvailable; }
    bool lowPower() const { return m_profile == u"power-saver"; }
    void setLowPower(bool on);
    QString lowPowerMode() const;
    void setLowPowerMode(const QString &mode);
    bool canSleep() const { return m_canSleep; }
    bool preventSleep() const;
    void setPreventSleep(bool on);
    int percentage() const { return m_percentage; }
    QString state() const { return m_state; }
    int capacity() const { return m_capacity; }
    bool chargeLimitSupported() const { return m_chargeLimitSupported; }
    bool chargeLimit() const { return m_chargeLimit; }
    void setChargeLimit(bool on);
    int chargeLimitPercent() const { return m_chargeLimitPercent; }
    int displayOffAdapter() const;
    int displayOffBattery() const;
    int requirePasswordAfter() const;
    void setRequirePasswordAfter(int seconds);

    // The display's idle time before it turns off, "AC" or "Battery"; 0 never.
    Q_INVOKABLE void setDisplayOff(const QString &source, int seconds);
    // The battery's level over the last `hours`: [{time (ms), level, charging}],
    // oldest first.
    Q_INVOKABLE QVariantList history(int hours) const;

public Q_SLOTS:
    // Everything again, as other programs may have changed it.
    void read();

Q_SIGNALS:
    void changed();
    // Apart, as the sidebar names the pane by it.
    void hasBatteryChanged();

private:
    // Set once constructed: a change read while QML is still creating us
    // (Panes asking Power for the battery) mustn't loop back into it.
    bool m_ready = false;
    int displayOff(const QString &source) const;
    void applyLock();
    void setProfileNow(const QString &profile);
    void tellPowerDevil();
    // Everything shown, to tell whether a read changed any of it.
    QVariantList snapshot() const;
    QVariantList m_last;

    QString m_battery;
    bool m_onBattery = false;
    bool m_lowPowerAvailable = false;
    QString m_profile;
    bool m_canSleep = false;
    bool m_vm = false;
    int m_percentage = 0;
    QString m_state;
    int m_capacity = -1;
    bool m_chargeLimitSupported = false;
    bool m_chargeLimit = false;
    int m_chargeLimitPercent = 0;
};
