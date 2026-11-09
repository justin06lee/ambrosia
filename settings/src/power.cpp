#include "power.h"

#include "dryrun.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDateTime>
#include <algorithm>

using namespace Qt::StringLiterals;

struct HistoryItem {
    uint time = 0;
    double value = 0;
    uint state = 0;
};
const QDBusArgument &operator>>(const QDBusArgument &argument, HistoryItem &item)
{
    argument.beginStructure();
    argument >> item.time >> item.value >> item.state;
    argument.endStructure();
    return argument;
}
QDBusArgument &operator<<(QDBusArgument &argument, const HistoryItem &item)
{
    argument.beginStructure();
    argument << item.time << item.value << item.state;
    argument.endStructure();
    return argument;
}

Q_DECLARE_METATYPE(HistoryItem)

namespace
{
const auto upower = u"org.freedesktop.UPower"_s;
const auto upowerPath = u"/org/freedesktop/UPower"_s;
const auto device = u"org.freedesktop.UPower.Device"_s;
const auto profiles = u"org.freedesktop.UPower.PowerProfiles"_s;
const auto profilesPath = u"/org/freedesktop/UPower/PowerProfiles"_s;
const auto properties = u"org.freedesktop.DBus.Properties"_s;
const auto powerSaver = u"power-saver"_s;

QVariant busProperty(const QString &service, const QString &path, const QString &interface, const QString &name)
{
    QDBusMessage get = QDBusMessage::createMethodCall(service, path, properties, u"Get"_s);
    get.setArguments({interface, name});
    const QDBusReply<QDBusVariant> reply = QDBusConnection::systemBus().call(get, QDBus::Block, 3000);
    return reply.isValid() ? reply.value().variant() : QVariant();
}

KSharedConfigPtr powerdevilrc()
{
    static KSharedConfigPtr config = KSharedConfig::openConfig(u"powerdevilrc"_s, KConfig::SimpleConfig);
    return config;
}
KConfigGroup profileGroup(const QString &source, const QString &group)
{
    return KConfigGroup(powerdevilrc(), source).group(group);
}
KSharedConfigPtr kscreenlockerrc()
{
    static KSharedConfigPtr config = KSharedConfig::openConfig(u"kscreenlockerrc"_s, KConfig::SimpleConfig);
    return config;
}

// PowerDevil's own defaults (powerdevilsettingsdefaults.cpp, 6.8) for what
// it hasn't been told: the display off after 10 minutes on power, 5 on
// battery, 2 on low battery; dimmed at half that; sleep after 15, 10 and 5.
int defaultDisplayOff(const QString &source)
{
    return source == u"AC" ? 600 : source == u"Battery" ? 300 : 120;
}
int defaultSleepAfter(const QString &source)
{
    return source == u"AC" ? 900 : source == u"Battery" ? 600 : 300;
}
}

Power::Power(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<HistoryItem>();
    qDBusRegisterMetaType<QList<HistoryItem>>();
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.connect(upower, upowerPath, properties, u"PropertiesChanged"_s, this, SLOT(read()));
    bus.connect(profiles, profilesPath, properties, u"PropertiesChanged"_s, this, SLOT(read()));
    // A battery added or taken out, and each device's changes.
    bus.connect(upower, upowerPath, upower, u"DeviceAdded"_s, this, SLOT(read()));
    bus.connect(upower, upowerPath, upower, u"DeviceRemoved"_s, this, SLOT(read()));
    bus.connect(upower, QString(), properties, u"PropertiesChanged"_s, this, SLOT(read()));
    m_vm = !busProperty(u"org.freedesktop.systemd1"_s, u"/org/freedesktop/systemd1"_s, u"org.freedesktop.systemd1.Manager"_s, u"Virtualization"_s)
                .toString()
                .isEmpty();
    read();
    m_ready = true;
}

void Power::read()
{
    // What another program changed in them since.
    powerdevilrc()->reparseConfiguration();
    kscreenlockerrc()->reparseConfiguration();
    QDBusInterface manager(upower, upowerPath, upower, QDBusConnection::systemBus());
    m_battery.clear();
    const QDBusReply<QList<QDBusObjectPath>> devices = manager.call(u"EnumerateDevices"_s);
    if (devices.isValid()) {
        for (const QDBusObjectPath &path : devices.value()) {
            // A battery that powers the computer (type 2), not a mouse's.
            if (busProperty(upower, path.path(), device, u"Type"_s).toUInt() == 2
                && busProperty(upower, path.path(), device, u"PowerSupply"_s).toBool()) {
                m_battery = path.path();
                break;
            }
        }
    }
    m_onBattery = busProperty(upower, upowerPath, upower, u"OnBattery"_s).toBool();
    if (!m_battery.isEmpty()) {
        m_percentage = qRound(busProperty(upower, m_battery, device, u"Percentage"_s).toDouble());
        static const QStringList states = {u"unknown"_s, u"charging"_s, u"discharging"_s, u"empty"_s, u"full"_s, u"pending"_s, u"discharging"_s};
        m_state = states.value(busProperty(upower, m_battery, device, u"State"_s).toInt(), u"unknown"_s);
        const double capacity = busProperty(upower, m_battery, device, u"Capacity"_s).toDouble();
        m_capacity = capacity > 0 ? qRound(capacity) : -1;
        m_chargeLimitSupported = busProperty(upower, m_battery, device, u"ChargeThresholdSupported"_s).toBool();
        m_chargeLimit = busProperty(upower, m_battery, device, u"ChargeThresholdEnabled"_s).toBool();
        m_chargeLimitPercent = busProperty(upower, m_battery, device, u"ChargeEndThreshold"_s).toInt();
    }

    const QVariant active = busProperty(profiles, profilesPath, profiles, u"ActiveProfile"_s);
    m_profile = active.toString();
    m_lowPowerAvailable = active.isValid();

    QDBusInterface logind(u"org.freedesktop.login1"_s, u"/org/freedesktop/login1"_s, u"org.freedesktop.login1.Manager"_s, QDBusConnection::systemBus());
    const QDBusReply<QString> can = logind.call(u"CanSuspend"_s);
    m_canSleep = can.isValid() && (can.value() == u"yes" || can.value() == u"challenge");
    const bool hadBattery = !m_last.isEmpty() && m_last.first().toBool();
    const QVariantList now = snapshot();
    if (now == m_last)
        return;
    m_last = now;
    if (!m_ready)
        return;
    if (hadBattery != hasBattery())
        Q_EMIT hasBatteryChanged();
    Q_EMIT changed();
}

QVariantList Power::snapshot() const
{
    return {hasBattery(), m_onBattery, m_lowPowerAvailable, m_profile, m_canSleep, m_percentage, m_state, m_capacity,
            m_chargeLimitSupported, m_chargeLimit, m_chargeLimitPercent, lowPowerMode(), preventSleep(),
            displayOffAdapter(), displayOffBattery(), requirePasswordAfter()};
}

void Power::setProfileNow(const QString &profile)
{
    if (profile == m_profile || !m_lowPowerAvailable)
        return;
    if (dryRun(qPrintable(u"switch the power profile to "_s + profile + u" (power-profiles-daemon)"_s)))
        return;
    QDBusMessage set = QDBusMessage::createMethodCall(profiles, profilesPath, properties, u"Set"_s);
    set.setArguments({profiles, u"ActiveProfile"_s, QVariant::fromValue(QDBusVariant(profile))});
    set.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(set), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (watcher->isError())
            qWarning("Settings: power-profiles-daemon: %s", qPrintable(watcher->error().message()));
        read();
    });
}

void Power::setLowPower(bool on)
{
    setProfileNow(on ? powerSaver : u"balanced"_s);
}

QString Power::lowPowerMode() const
{
    const bool adapter = profileGroup(u"AC"_s, u"Performance"_s).readEntry("PowerProfile", QString()) == powerSaver;
    const bool battery = profileGroup(u"Battery"_s, u"Performance"_s).readEntry("PowerProfile", QString()) == powerSaver;
    return adapter && battery ? u"always"_s : battery ? u"battery"_s : adapter ? u"adapter"_s : u"never"_s;
}

// Each source's profile, which PowerDevil switches to when it changes; low
// battery as battery. Where the mode doesn't save power, the profile isn't
// held (another can be chosen from the menu bar), but it leaves power saver.
void Power::setLowPowerMode(const QString &mode)
{
    if (mode == lowPowerMode())
        return;
    const bool adapter = mode == u"always" || mode == u"adapter";
    const bool battery = mode == u"always" || mode == u"battery";
    if (!dryRun(qPrintable(u"set Low Power Mode to "_s + mode + u" (powerdevilrc)"_s))) {
        profileGroup(u"AC"_s, u"Performance"_s).writeEntry("PowerProfile", adapter ? powerSaver : (mode == u"never" ? QString() : u"balanced"_s));
        for (const auto &source : {u"Battery"_s, u"LowBattery"_s})
            profileGroup(source, u"Performance"_s).writeEntry("PowerProfile", battery ? powerSaver : (mode == u"never" ? QString() : u"balanced"_s));
        powerdevilrc()->sync();
        tellPowerDevil();
    }
    const bool now = m_onBattery ? battery : adapter;
    if (now)
        setProfileNow(powerSaver);
    else if (m_profile == powerSaver)
        setProfileNow(u"balanced"_s);
    Q_EMIT changed();
}

// Idle on power with the display off, the computer sleeps unless this is on:
// PowerDevil's sleep when idle, after its own wait.
bool Power::preventSleep() const
{
    const unsigned fallback = (m_vm || !m_canSleep) ? 0 : 1;
    return profileGroup(u"AC"_s, u"SuspendAndShutdown"_s).readEntry("AutoSuspendAction", fallback) == 0;
}

void Power::setPreventSleep(bool on)
{
    if (on == preventSleep())
        return;
    if (!dryRun(on ? "never sleep when idle on power (powerdevilrc)" : "sleep when idle on power (powerdevilrc)")) {
        KConfigGroup group = profileGroup(u"AC"_s, u"SuspendAndShutdown"_s);
        group.writeEntry("AutoSuspendAction", on ? 0u : 1u);
        if (!on && !group.hasKey("AutoSuspendIdleTimeoutSec"))
            group.writeEntry("AutoSuspendIdleTimeoutSec", defaultSleepAfter(u"AC"_s));
        powerdevilrc()->sync();
        tellPowerDevil();
    }
    Q_EMIT changed();
}

void Power::setChargeLimit(bool on)
{
    if (on == m_chargeLimit || m_battery.isEmpty())
        return;
    if (dryRun(on ? "turn the battery's charge limit on (UPower)" : "turn the battery's charge limit off (UPower)"))
        return;
    QDBusMessage call = QDBusMessage::createMethodCall(upower, m_battery, device, u"EnableChargeThreshold"_s);
    call.setArguments({on});
    call.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (watcher->isError())
            qWarning("Settings: UPower: %s", qPrintable(watcher->error().message()));
        read();
    });
}

int Power::displayOff(const QString &source) const
{
    const KConfigGroup group = profileGroup(source, u"Display"_s);
    if (!group.readEntry("TurnOffDisplayWhenIdle", true))
        return 0;
    return group.readEntry("TurnOffDisplayIdleTimeoutSec", defaultDisplayOff(source));
}
int Power::displayOffAdapter() const
{
    return displayOff(u"AC"_s);
}
int Power::displayOffBattery() const
{
    return displayOff(u"Battery"_s);
}

// The display turns off after `seconds`, dimming at half that as PowerDevil's
// defaults do; never, and it doesn't dim either. Battery stands for low battery too.
void Power::setDisplayOff(const QString &source, int seconds)
{
    if (seconds == displayOff(source))
        return;
    if (!dryRun(qPrintable(u"turn the display off after %1 s on %2 (powerdevilrc)"_s.arg(seconds).arg(source)))) {
        const QStringList sources = source == u"AC" ? QStringList{u"AC"_s} : QStringList{u"Battery"_s, u"LowBattery"_s};
        for (const QString &each : sources) {
            KConfigGroup group = profileGroup(each, u"Display"_s);
            group.writeEntry("TurnOffDisplayWhenIdle", seconds > 0);
            group.writeEntry("DimDisplayWhenIdle", seconds > 0);
            if (seconds > 0) {
                group.writeEntry("TurnOffDisplayIdleTimeoutSec", seconds);
                group.writeEntry("DimDisplayIdleTimeoutSec", std::max(seconds / 2, 15));
            }
        }
        powerdevilrc()->sync();
        tellPowerDevil();
    }
    // The lock follows the display.
    if (!qEnvironmentVariableIsSet("AMBROSIA_SETTINGS_DRYRUN"))
        applyLock();
    Q_EMIT changed();
}

void Power::tellPowerDevil()
{
    QDBusMessage refresh = QDBusMessage::createMethodCall(u"org.kde.Solid.PowerManagement"_s, u"/org/kde/Solid/PowerManagement"_s,
                                                          u"org.kde.Solid.PowerManagement"_s, u"refreshStatus"_s);
    QDBusConnection::sessionBus().asyncCall(refresh);
}

// The display that turns off first: the lock counts from it.
namespace
{
int firstOff(int adapter, int battery, bool hasBattery)
{
    if (!hasBattery)
        return adapter;
    if (adapter == 0 || battery == 0)
        return std::max(adapter, battery);
    return std::min(adapter, battery);
}
}

// kscreenlocker locks after the idle time it's given, asking for a password
// once its grace is over; the Mac counts from the display turning off. So
// the lock comes when the display goes off and the grace is the wait, for
// waits under a minute; for longer, the lock comes that much later. Never:
// no lock when idle nor on waking. The display never turning off: no lock
// when idle, only on waking. The wait is kept beside them, as it can't be
// told from them then.
int Power::requirePasswordAfter() const
{
    const KSharedConfigPtr config = kscreenlockerrc();
    const KConfigGroup ours = config->group(u"Ambrosia"_s);
    if (ours.hasKey("RequirePasswordAfterSec"))
        return ours.readEntry("RequirePasswordAfterSec", 0);
    const KConfigGroup daemon = config->group(u"Daemon"_s);
    if (!daemon.readEntry("Autolock", true))
        return daemon.readEntry("LockOnResume", true) ? 0 : -1;
    const int off = firstOff(displayOffAdapter(), displayOffBattery(), hasBattery());
    const int locks = qRound(daemon.readEntry("Timeout", 5.0) * 60) + daemon.readEntry("LockGrace", 5);
    return std::max(0, locks - off);
}

void Power::setRequirePasswordAfter(int seconds)
{
    if (seconds == requirePasswordAfter())
        return;
    if (dryRun(qPrintable(u"require a password %1 s after the display turns off (kscreenlockerrc)"_s.arg(seconds)))) {
        Q_EMIT changed();
        return;
    }
    kscreenlockerrc()->group(u"Ambrosia"_s).writeEntry("RequirePasswordAfterSec", seconds);
    applyLock();
    Q_EMIT changed();
}

void Power::applyLock()
{
    const KSharedConfigPtr config = kscreenlockerrc();
    if (!config->group(u"Ambrosia"_s).hasKey("RequirePasswordAfterSec"))
        return;
    const int wait = config->group(u"Ambrosia"_s).readEntry("RequirePasswordAfterSec", 0);
    const int off = firstOff(displayOffAdapter(), displayOffBattery(), hasBattery());
    KConfigGroup daemon = config->group(u"Daemon"_s);
    daemon.writeEntry("Autolock", wait >= 0 && off > 0, KConfig::Notify);
    daemon.writeEntry("LockOnResume", wait >= 0, KConfig::Notify);
    if (wait >= 0 && off > 0) {
        daemon.writeEntry("Timeout", (wait < 60 ? off : off + wait) / 60.0, KConfig::Notify);
        daemon.writeEntry("LockGrace", wait < 60 ? wait : 0, KConfig::Notify);
    }
    config->sync();
    QDBusMessage configure = QDBusMessage::createMethodCall(u"org.kde.screensaver"_s, u"/ScreenSaver"_s, u"org.kde.screensaver"_s, u"configure"_s);
    QDBusConnection::sessionBus().asyncCall(configure);
}

QVariantList Power::history(int hours) const
{
    QVariantList list;
    if (m_battery.isEmpty())
        return list;
    QDBusMessage call = QDBusMessage::createMethodCall(upower, m_battery, device, u"GetHistory"_s);
    call.setArguments({u"charge"_s, uint(hours * 3600), uint(hours * 12)});
    const QDBusReply<QList<HistoryItem>> reply = QDBusConnection::systemBus().call(call, QDBus::Block, 3000);
    if (!reply.isValid())
        return list;
    QList<HistoryItem> items = reply.value();
    std::sort(items.begin(), items.end(), [](const HistoryItem &a, const HistoryItem &b) {
        return a.time < b.time;
    });
    for (const HistoryItem &item : items)
        list.append(QVariantMap{{u"time"_s, qint64(item.time) * 1000}, {u"level"_s, item.value}, {u"charging"_s, item.state == 1 || item.state == 4}});
    return list;
}
