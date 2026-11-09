#include "keyboard.h"

#include "dryrun.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFile>
#include <QRegularExpression>
#include <cmath>

using namespace Qt::StringLiterals;

namespace
{
// The Mac's key repeat intervals and delays, in its 15 ms units (its
// KeyRepeat and InitialKeyRepeat steps), as KDE's repeats a second and ms.
constexpr int repeatTicks[] = {120, 90, 60, 30, 12, 6, 2};
constexpr int delayTicks[] = {120, 94, 68, 35, 25, 15};

KConfigGroup keyboardGroup()
{
    static KSharedConfigPtr config = KSharedConfig::openConfig(u"kcminputrc"_s, KConfig::NoGlobals);
    config->reparseConfiguration();
    return config->group(u"Keyboard"_s);
}

const auto upower = u"org.freedesktop.UPower"_s;
const auto backlightPath = u"/org/freedesktop/UPower/KbdBacklight"_s;
const auto backlightInterface = u"org.freedesktop.UPower.KbdBacklight"_s;

// "us" → "English (US)", from xkb's own list.
QString layoutName(const QString &layout, const QString &variant)
{
    QFile list(u"/usr/share/X11/xkb/rules/evdev.lst"_s);
    if (!list.open(QIODevice::ReadOnly))
        return layout;
    QString section;
    QString found;
    const QStringList lines = QString::fromUtf8(list.readAll()).split(u'\n');
    for (const QString &line : lines) {
        if (line.startsWith(u'!')) {
            section = line.mid(1).trimmed();
            continue;
        }
        const QString trimmed = line.trimmed();
        const int gap = trimmed.indexOf(QRegularExpression(u"\\s"_s));
        if (gap < 0)
            continue;
        const QString key = trimmed.left(gap);
        const QString name = trimmed.mid(gap).trimmed();
        if (variant.isEmpty() && section == u"layout" && key == layout)
            return name;
        if (!variant.isEmpty() && section == u"variant" && key == variant && name.startsWith(layout + u':'))
            found = name.mid(layout.size() + 1).trimmed();
    }
    return found.isEmpty() ? layout : found;
}
}

Keyboard::Keyboard(QObject *parent)
    : QObject(parent)
{
    read();
}

void Keyboard::read()
{
    QDBusInterface light(upower, backlightPath, backlightInterface, QDBusConnection::systemBus());
    const QDBusReply<int> max = light.call(u"GetMaxBrightness"_s);
    m_maxBrightness = max.isValid() ? max.value() : 0;
    const QDBusReply<int> now = light.call(u"GetBrightness"_s);
    m_brightness = now.isValid() ? now.value() : 0;
    Q_EMIT changed();
}

// The step nearest what's set (on a log scale: rates far apart), so a value
// KDE's own module chose still shows.
int Keyboard::repeatStep() const
{
    const KConfigGroup group = keyboardGroup();
    if (group.readEntry("KeyRepeat", u"repeat"_s) != u"repeat")
        return 0;
    const double rate = group.readEntry("RepeatRate", 25.0);
    int best = 1;
    for (int i = 0; i < 7; ++i)
        if (std::abs(std::log(1000.0 / (15 * repeatTicks[i])) - std::log(rate)) < std::abs(std::log(1000.0 / (15 * repeatTicks[best - 1])) - std::log(rate)))
            best = i + 1;
    return best;
}

void Keyboard::setRepeatStep(int step)
{
    step = std::clamp(step, 0, 7);
    if (step == repeatStep())
        return;
    if (!dryRun(qPrintable(u"set key repeat to step %1 (kcminputrc)"_s.arg(step)))) {
        KConfigGroup group = keyboardGroup();
        group.writeEntry("KeyRepeat", step == 0 ? u"nothing"_s : u"repeat"_s, KConfig::Notify);
        if (step > 0)
            group.writeEntry("RepeatRate", std::round(100000.0 / (15 * repeatTicks[step - 1])) / 100, KConfig::Notify);
        group.sync();
    }
    Q_EMIT changed();
}

int Keyboard::delayStep() const
{
    const int delay = keyboardGroup().readEntry("RepeatDelay", 600);
    int best = 0;
    for (int i = 0; i < 6; ++i)
        if (std::abs(delayTicks[i] * 15 - delay) < std::abs(delayTicks[best] * 15 - delay))
            best = i;
    return best;
}

void Keyboard::setDelayStep(int step)
{
    step = std::clamp(step, 0, 5);
    if (step == delayStep())
        return;
    if (!dryRun(qPrintable(u"set the delay until repeat to %1 ms (kcminputrc)"_s.arg(delayTicks[step] * 15)))) {
        KConfigGroup group = keyboardGroup();
        group.writeEntry("RepeatDelay", delayTicks[step] * 15, KConfig::Notify);
        group.sync();
    }
    Q_EMIT changed();
}

qreal Keyboard::brightness() const
{
    return m_maxBrightness > 0 ? qreal(m_brightness) / m_maxBrightness : 0;
}

void Keyboard::setBrightness(qreal value)
{
    if (m_maxBrightness <= 0)
        return;
    const int level = qRound(std::clamp(value, 0.0, 1.0) * m_maxBrightness);
    if (level == m_brightness)
        return;
    m_brightness = level;
    if (!dryRun("set the keyboard's backlight (UPower)")) {
        QDBusInterface light(upower, backlightPath, backlightInterface, QDBusConnection::systemBus());
        light.asyncCall(u"SetBrightness"_s, level);
    }
    Q_EMIT changed();
}

// The layouts in use, as the Mac names its sources: "A and B", "A, B and C".
QString Keyboard::inputSources() const
{
    KSharedConfigPtr kxkb = KSharedConfig::openConfig(u"kxkbrc"_s, KConfig::NoGlobals);
    kxkb->reparseConfiguration();
    const KConfigGroup layout = kxkb->group(u"Layout"_s);
    QStringList layouts = layout.readEntry("Use", false) ? layout.readEntry("LayoutList", QString()).split(u',', Qt::SkipEmptyParts) : QStringList();
    QStringList variants = layout.readEntry("VariantList", QString()).split(u',');
    if (layouts.isEmpty()) {
        QDBusInterface localed(u"org.freedesktop.locale1"_s, u"/org/freedesktop/locale1"_s, u"org.freedesktop.locale1"_s, QDBusConnection::systemBus());
        layouts = localed.property("X11Layout").toString().split(u',', Qt::SkipEmptyParts);
        variants = localed.property("X11Variant").toString().split(u',');
    }
    if (layouts.isEmpty())
        layouts = {u"us"_s};
    QStringList names;
    for (int i = 0; i < layouts.size(); ++i)
        names.append(layoutName(layouts.at(i).trimmed(), variants.value(i).trimmed()));
    if (names.size() == 1)
        return names.first();
    const QString last = names.takeLast();
    return tr("%1 and %2").arg(names.join(u", "_s), last);
}
