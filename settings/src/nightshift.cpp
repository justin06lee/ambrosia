#include "nightshift.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDateTime>
#include <QProcess>
#include <QTime>

namespace
{
// Warmth runs from the display's own white to KWin's warm end.
constexpr int kCoolest = 6500;
constexpr int kWarmest = 2700;
const auto kTimer = QStringLiteral("ambrosia-night-until");

KSharedConfigPtr kwinrc()
{
    return KSharedConfig::openConfig(QStringLiteral("kwinrc"), KConfig::SimpleConfig);
}

KConfigGroup kept()
{
    return KSharedConfig::openConfig(QStringLiteral("ambrosiarc"))->group(QStringLiteral("Night Shift"));
}

// When night is: KDE's night-time service, which KWin's DarkLight mode follows.
KSharedConfigPtr nightTime()
{
    return KSharedConfig::openConfig(QStringLiteral("knighttimerc"), KConfig::SimpleConfig);
}

// Its times are "HH:mm:ss", ours "HH:mm".
QString shown(const QString &stored, const QString &fallback)
{
    const QTime time = QTime::fromString(stored, Qt::ISODate);
    return time.isValid() ? time.toString(QStringLiteral("HH:mm")) : fallback;
}

QString stored(const QString &time)
{
    return QTime::fromString(time, QStringLiteral("HH:mm")).toString(Qt::ISODate);
}
}

NightShift::NightShift(QObject *parent)
    : QObject(parent)
{
    read();
}

void NightShift::read()
{
    KSharedConfigPtr config = kwinrc();
    config->reparseConfiguration();
    const KConfigGroup group = config->group(QStringLiteral("NightColor"));
    const bool active = group.readEntry("Active", false);
    m_manual = active && group.readEntry("Mode", QString()) == QLatin1String("Constant");
    KSharedConfigPtr night = nightTime();
    night->reparseConfiguration();
    const bool times = night->group(QStringLiteral("General")).readEntry("Source", QString()) == QLatin1String("Times");
    if (m_manual)
        m_schedule = kept().readEntry("Schedule", QStringLiteral("off"));
    else
        m_schedule = !active ? QStringLiteral("off") : times ? QStringLiteral("custom") : QStringLiteral("sunset");
    const KConfigGroup hours = night->group(QStringLiteral("Times"));
    m_from = shown(hours.readEntry("SunsetStart", QString()), m_from);
    m_to = shown(hours.readEntry("SunriseStart", QString()), m_to);
    const int temperature = group.readEntry("NightTemperature", 4600);
    m_warmth = qBound(0.0, double(kCoolest - temperature) / (kCoolest - kWarmest), 1.0);
}

void NightShift::write()
{
    KSharedConfigPtr config = kwinrc();
    KConfigGroup group = config->group(QStringLiteral("NightColor"));
    // KWin hears of it from the Notify flag (a KConfigWatcher); reconfigure
    // doesn't reach Night Light.
    group.writeEntry("Active", m_manual || m_schedule != QLatin1String("off"), KConfig::Notify);
    group.writeEntry("Mode", m_manual ? QStringLiteral("Constant") : QStringLiteral("DarkLight"), KConfig::Notify);
    group.writeEntry("NightTemperature", int(kCoolest - m_warmth * (kCoolest - kWarmest)), KConfig::Notify);
    group.sync();
    if (m_schedule != QLatin1String("off")) {
        KSharedConfigPtr night = nightTime();
        KConfigGroup general = night->group(QStringLiteral("General"));
        general.writeEntry("Source", m_schedule == QLatin1String("custom") ? QStringLiteral("Times") : QStringLiteral("Location"), KConfig::Notify);
        KConfigGroup hours = night->group(QStringLiteral("Times"));
        hours.writeEntry("SunsetStart", stored(m_from), KConfig::Notify);
        hours.writeEntry("SunriseStart", stored(m_to), KConfig::Notify);
        night->sync();
    }
    KConfigGroup ours = kept();
    ours.writeEntry("Schedule", m_schedule);
    ours.sync();
    Q_EMIT changed();
}

void NightShift::setSchedule(const QString &schedule)
{
    if (m_schedule == schedule)
        return;
    m_schedule = schedule;
    write();
}

void NightShift::setTimes(const QString &from, const QString &to)
{
    if (!QTime::fromString(from, QStringLiteral("HH:mm")).isValid() || !QTime::fromString(to, QStringLiteral("HH:mm")).isValid())
        return;
    m_from = from;
    m_to = to;
    write();
}

void NightShift::setManual(bool on)
{
    if (m_manual == on)
        return;
    m_manual = on;
    QProcess::execute(QStringLiteral("systemctl"), {QStringLiteral("--user"), QStringLiteral("stop"), kTimer + QStringLiteral(".timer")});
    write();
    if (!on)
        return;
    // Tomorrow at six, the schedule again.
    const QString at = QDateTime(QDate::currentDate().addDays(1), QTime(6, 0)).toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"));
    const bool scheduled = m_schedule != QLatin1String("off");
    const QString back = QStringLiteral("kwriteconfig6 --file kwinrc --group NightColor --key Mode DarkLight --notify && "
                                        "kwriteconfig6 --file kwinrc --group NightColor --key Active %1 --notify")
                             .arg(scheduled ? QStringLiteral("true") : QStringLiteral("false"));
    QProcess::startDetached(QStringLiteral("systemd-run"),
                            {QStringLiteral("--user"), QStringLiteral("--unit=") + kTimer, QStringLiteral("--on-calendar=") + at, QStringLiteral("sh"), QStringLiteral("-c"), back});
}

void NightShift::setWarmth(double warmth)
{
    m_warmth = warmth;
    write();
}
