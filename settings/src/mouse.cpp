#include "mouse.h"

#include "dryrun.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusVariant>
#include <cmath>

using namespace Qt::StringLiterals;

namespace
{
const auto kwin = u"org.kde.KWin"_s;
const auto device = u"org.kde.KWin.InputDevice"_s;

KConfigGroup kdeGroup()
{
    static KSharedConfigPtr config = KSharedConfig::openConfig(u"kdeglobals"_s, KConfig::NoGlobals);
    config->reparseConfiguration();
    return config->group(u"KDE"_s);
}
}

Mouse::Mouse(QObject *parent)
    : QObject(parent)
{
    read();
}

void Mouse::read()
{
    m_devices.clear();
    QDBusInterface manager(kwin, u"/org/kde/KWin/InputDevice"_s, u"org.kde.KWin.InputDeviceManager"_s);
    const QStringList names = manager.property("devicesSysNames").toStringList();
    for (const QString &name : names) {
        const QString path = u"/org/kde/KWin/InputDevice/"_s + name;
        QDBusInterface each(kwin, path, device);
        if (each.property("pointer").toBool() && !each.property("touchpad").toBool() && !each.property("tabletTool").toBool()
            && !each.property("touch").toBool())
            m_devices.append(path);
    }
    Q_EMIT changed();
}

QVariant Mouse::first(const char *name) const
{
    if (m_devices.isEmpty())
        return {};
    QDBusInterface each(kwin, m_devices.first(), device);
    return each.property(name);
}

void Mouse::setAll(const char *name, const QVariant &value)
{
    if (dryRun(qPrintable(u"set every mouse's "_s + QLatin1String(name) + u" (KWin)"_s))) {
        Q_EMIT changed();
        return;
    }
    for (const QString &path : std::as_const(m_devices)) {
        QDBusMessage set = QDBusMessage::createMethodCall(kwin, path, u"org.freedesktop.DBus.Properties"_s, u"Set"_s);
        set.setArguments({device, QLatin1String(name), QVariant::fromValue(QDBusVariant(value))});
        QDBusConnection::sessionBus().call(set, QDBus::Block, 2000);
    }
    Q_EMIT changed();
}

qreal Mouse::speed() const
{
    return (first("pointerAcceleration").toDouble() + 1) / 2;
}
void Mouse::setSpeed(qreal value)
{
    setAll("pointerAcceleration", std::clamp(value, 0.0, 1.0) * 2 - 1);
}
bool Mouse::naturalScroll() const
{
    return first("naturalScroll").toBool();
}
void Mouse::setNaturalScroll(bool on)
{
    setAll("naturalScroll", on);
}
bool Mouse::leftHanded() const
{
    return first("leftHanded").toBool();
}
void Mouse::setLeftHanded(bool on)
{
    setAll("leftHanded", on);
}
qreal Mouse::scrollSpeed() const
{
    const double factor = first("scrollFactor").toDouble();
    return factor > 0 ? std::clamp((std::log2(factor) + 2) / 4, 0.0, 1.0) : 0.5;
}
void Mouse::setScrollSpeed(qreal value)
{
    setAll("scrollFactor", std::round(std::exp2(std::clamp(value, 0.0, 1.0) * 4 - 2) * 100) / 100);
}
bool Mouse::acceleration() const
{
    return !first("pointerAccelerationProfileFlat").toBool();
}
void Mouse::setAcceleration(bool on)
{
    setAll(on ? "pointerAccelerationProfileAdaptive" : "pointerAccelerationProfileFlat", true);
}

qreal Mouse::doubleClick() const
{
    const int interval = kdeGroup().readEntry("DoubleClickInterval", 400);
    return std::clamp((1000.0 - interval) / 850.0, 0.0, 1.0);
}
void Mouse::setDoubleClick(qreal value)
{
    const int interval = qRound(1000 - std::clamp(value, 0.0, 1.0) * 850);
    if (!dryRun(qPrintable(u"set the double-click interval to %1 ms (kdeglobals)"_s.arg(interval)))) {
        KConfigGroup group = kdeGroup();
        // No KConfig::Global: this file is kdeglobals, opened without the
        // globals, and such a write would never reach the disk.
        group.writeEntry("DoubleClickInterval", interval, KConfig::Notify);
        group.sync();
        // Running apps re-read it on KGlobalSettings' signal, as KDE's module sends:
        // SettingsChanged (3), SETTINGS_MOUSE (0).
        QDBusMessage signal = QDBusMessage::createSignal(u"/KGlobalSettings"_s, u"org.kde.KGlobalSettings"_s, u"notifyChange"_s);
        signal.setArguments({3, 0});
        QDBusConnection::sessionBus().send(signal);
    }
    Q_EMIT changed();
}
