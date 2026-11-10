#include "trackpad.h"

#include <algorithm>

using namespace Qt::StringLiterals;

Trackpad::Trackpad(QObject *parent)
    : QObject(parent)
{
    read();
}

void Trackpad::read()
{
    m_pads.read();
    Q_EMIT changed();
}

void Trackpad::setAll(const char *name, const QVariant &value)
{
    m_pads.setAll(name, value);
    Q_EMIT changed();
}

qreal Trackpad::speed() const
{
    return (m_pads.first("pointerAcceleration", "supportsPointerAcceleration").toDouble() + 1) / 2;
}
void Trackpad::setSpeed(qreal value)
{
    setAll("pointerAcceleration", std::clamp(value, 0.0, 1.0) * 2 - 1);
}

QString Trackpad::secondaryClick() const
{
    return m_pads.first("clickMethodAreas", "supportsClickMethodAreas").toBool() ? u"corner"_s : u"twoFingers"_s;
}
void Trackpad::setSecondaryClick(const QString &where)
{
    setAll(where == u"corner" ? "clickMethodAreas" : "clickMethodClickfinger", true);
}
bool Trackpad::twoFingerClick() const
{
    return m_pads.any("supportsClickMethodClickfinger");
}
bool Trackpad::cornerClick() const
{
    return m_pads.any("supportsClickMethodAreas");
}

bool Trackpad::canTap() const
{
    return m_pads.first("tapFingerCount").toInt() > 0;
}
bool Trackpad::tapToClick() const
{
    return m_pads.first("tapToClick").toBool();
}
void Trackpad::setTapToClick(bool on)
{
    setAll("tapToClick", on);
}

bool Trackpad::naturalScroll() const
{
    return m_pads.first("naturalScroll", "supportsNaturalScroll").toBool();
}
void Trackpad::setNaturalScroll(bool on)
{
    setAll("naturalScroll", on);
}

QString Trackpad::dragging() const
{
    if (!m_pads.first("tapAndDrag").toBool())
        return QStringLiteral("off");
    return m_pads.first("tapDragLock").toBool() ? QStringLiteral("lock") : QStringLiteral("tap");
}
void Trackpad::setDragging(const QString &how)
{
    setAll("tapAndDrag", how != QLatin1String("off"));
    setAll("tapDragLock", how == QLatin1String("lock"));
}
