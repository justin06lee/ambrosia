#include "kwininput.h"

#include "dryrun.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusVariant>

using namespace Qt::StringLiterals;

namespace
{
const auto kwin = u"org.kde.KWin"_s;
const auto device = u"org.kde.KWin.InputDevice"_s;
}

void KWinInput::read()
{
    m_devices.clear();
    QDBusInterface manager(kwin, u"/org/kde/KWin/InputDevice"_s, u"org.kde.KWin.InputDeviceManager"_s);
    const QStringList names = manager.property("devicesSysNames").toStringList();
    for (const QString &name : names) {
        const QString path = u"/org/kde/KWin/InputDevice/"_s + name;
        QDBusInterface each(kwin, path, device);
        const bool touchpad = each.property("touchpad").toBool();
        const bool mouse = each.property("pointer").toBool() && !touchpad && !each.property("tabletTool").toBool() && !each.property("touch").toBool();
        if (m_kind == Touchpads ? touchpad : mouse)
            m_devices.append(path);
    }
}

QVariant KWinInput::first(const char *name, const char *supports) const
{
    for (const QString &path : m_devices) {
        QDBusInterface each(kwin, path, device);
        if (!supports || each.property(supports).toBool())
            return each.property(name);
    }
    return {};
}

bool KWinInput::any(const char *name) const
{
    for (const QString &path : m_devices) {
        if (QDBusInterface(kwin, path, device).property(name).toBool())
            return true;
    }
    return false;
}

void KWinInput::setAll(const char *name, const QVariant &value)
{
    const QLatin1String kind(m_kind == Touchpads ? "trackpad" : "mouse");
    if (dryRun(qPrintable(u"set every "_s + kind + u"'s "_s + QLatin1String(name) + u" (KWin)"_s)))
        return;
    for (const QString &path : std::as_const(m_devices)) {
        QDBusMessage set = QDBusMessage::createMethodCall(kwin, path, u"org.freedesktop.DBus.Properties"_s, u"Set"_s);
        set.setArguments({device, QLatin1String(name), QVariant::fromValue(QDBusVariant(value))});
        QDBusConnection::sessionBus().call(set, QDBus::Block, 2000);
    }
}
