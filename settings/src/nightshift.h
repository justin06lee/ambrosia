#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Night Shift, on KWin's Night Light (kwinrc [NightColor]) and KDE's night-time
// service, which says when night is (knighttimerc): its schedule, and on until
// tomorrow. KWin has no "until": the schedule is kept in ambrosiarc,
// and a one-off systemd timer puts it back at six; after a reboot before then
// it stays on until turned off.
class NightShift : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // "off", "custom" or "sunset".
    Q_PROPERTY(QString schedule READ schedule WRITE setSchedule NOTIFY changed)
    // Custom's times, "HH:mm".
    Q_PROPERTY(QString from READ from NOTIFY changed)
    Q_PROPERTY(QString to READ to NOTIFY changed)
    Q_PROPERTY(bool manual READ manual WRITE setManual NOTIFY changed)
    // 0 (less warm) to 1 (more warm).
    Q_PROPERTY(double warmth READ warmth WRITE setWarmth NOTIFY changed)

public:
    explicit NightShift(QObject *parent = nullptr);

    QString schedule() const { return m_schedule; }
    void setSchedule(const QString &schedule);
    QString from() const { return m_from; }
    QString to() const { return m_to; }
    Q_INVOKABLE void setTimes(const QString &from, const QString &to);
    bool manual() const { return m_manual; }
    void setManual(bool on);
    double warmth() const { return m_warmth; }
    void setWarmth(double warmth);

Q_SIGNALS:
    void changed();

private:
    void read();
    void write();

    QString m_schedule = QStringLiteral("off");
    QString m_from = QStringLiteral("22:00");
    QString m_to = QStringLiteral("07:00");
    bool m_manual = false;
    double m_warmth = 0.5;
};
