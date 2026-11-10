#include "access.h"

#include "dryrun.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusMessage>
#include <algorithm>
#include <cmath>

using namespace Qt::StringLiterals;

namespace
{
// Opened without the globals: a kdeglobals written with them in is never
// saved (see mouse.cpp), and these files are read fresh each time.
KSharedConfigPtr file(const QString &name)
{
    KSharedConfigPtr config = KSharedConfig::openConfig(name, KConfig::NoGlobals);
    config->reparseConfiguration();
    return config;
}

void effect(const char *method, const char *name)
{
    QDBusMessage call = QDBusMessage::createMethodCall(u"org.kde.KWin"_s, u"/Effects"_s, u"org.kde.kwin.Effects"_s, QLatin1String(method));
    call.setArguments({QLatin1String(name)});
    QDBusConnection::sessionBus().call(call, QDBus::Block, 3000);
}

// Running apps read kdeglobals again on KGlobalSettings' signal
// (SettingsChanged, of the given category), as KDE's modules send it.
void notifyApps(int category)
{
    QDBusMessage signal = QDBusMessage::createSignal(u"/KGlobalSettings"_s, u"org.kde.KGlobalSettings"_s, u"notifyChange"_s);
    signal.setArguments({3, category});
    QDBusConnection::sessionBus().send(signal);
}

// "Meta+Ctrl" as the keys a person presses: ⌃⌘ (Command is the Super key).
QString glyphs(QString keys)
{
    if (keys.isEmpty() || keys == u"none")
        return {};
    QString modifiers;
    const std::pair<QLatin1String, QChar> names[] = {
        {QLatin1String("Ctrl"), QChar(0x2303)}, {QLatin1String("Control"), QChar(0x2303)}, {QLatin1String("Alt"), QChar(0x2325)},
        {QLatin1String("Shift"), QChar(0x21E7)}, {QLatin1String("Meta"), QChar(0x2318)},
    };
    QStringList parts = keys.split(u'+', Qt::SkipEmptyParts);
    if (keys.endsWith(u"++"))
        parts.append(u"+"_s);
    QString key;
    for (const QString &part : std::as_const(parts)) {
        bool modifier = false;
        for (const auto &[name, glyph] : names) {
            if (part == name) {
                if (!modifiers.contains(glyph))
                    modifiers += glyph;
                modifier = true;
            }
        }
        if (!modifier)
            key = part;
    }
    // In the Mac's order: ⌃⌥⇧⌘.
    QString ordered;
    for (const QChar glyph : {QChar(0x2303), QChar(0x2325), QChar(0x21E7), QChar(0x2318)}) {
        if (modifiers.contains(glyph))
            ordered += glyph;
    }
    return ordered + key;
}

// KWin's keys for one of its actions: kglobalshortcutsrc keeps "keys,default
// keys,name" once any was changed; before that the default holds.
QString shortcut(const char *action, const QString &byDefault)
{
    const QString entry = file(u"kglobalshortcutsrc"_s)->group(u"kwin"_s).readEntry(action, QString());
    if (entry.isEmpty())
        return glyphs(byDefault);
    QString keys = entry.section(u',', 0, 0);
    // Several keys for one action are tab-separated: the first.
    keys = keys.section(u'\t', 0, 0);
    return glyphs(keys);
}
}

Access::Access(QObject *parent)
    : QObject(parent)
{
}

void Access::read()
{
    Q_EMIT changed();
}

bool Access::plugin(const char *key, bool byDefault) const
{
    return file(u"kwinrc"_s)->group(u"Plugins"_s).readEntry(key, byDefault);
}

// kwinrc says whether KWin loads an effect; a running KWin is told as well.
void Access::setPlugin(const char *key, const char *name, bool on)
{
    if (!dryRun(qPrintable(u"%1 KWin's %2 effect"_s.arg(on ? u"load"_s : u"unload"_s, QLatin1String(name))))) {
        KConfigGroup group = file(u"kwinrc"_s)->group(u"Plugins"_s);
        group.writeEntry(key, on, KConfig::Notify);
        group.sync();
        effect(on ? "loadEffect" : "unloadEffect", name);
    }
    Q_EMIT changed();
}

bool Access::access(const char *group, const char *key) const
{
    return file(u"kaccessrc"_s)->group(QLatin1String(group)).readEntry(key, false);
}

void Access::setAccess(const char *group, const char *key, bool on)
{
    if (!dryRun(qPrintable(u"set kaccessrc's %1 to %2"_s.arg(QLatin1String(key), on ? u"on"_s : u"off"_s)))) {
        KConfigGroup config = file(u"kaccessrc"_s)->group(QLatin1String(group));
        config.writeEntry(key, on, KConfig::Notify);
        config.sync();
    }
    Q_EMIT changed();
}

bool Access::zoom() const
{
    return plugin("zoomEnabled", true) || plugin("magnifierEnabled", false);
}
QString Access::zoomStyle() const
{
    return plugin("magnifierEnabled", false) ? u"lens"_s : u"full"_s;
}
void Access::setZoom(bool on)
{
    const bool lens = zoomStyle() == u"lens";
    if (!on) {
        // Off keeps the style: the lens stays chosen, unloaded, in ambrosiarc.
        KConfigGroup ours = file(u"ambrosiarc"_s)->group(u"Accessibility"_s);
        if (!dryRun("remember the zoom style")) {
            ours.writeEntry("ZoomLens", lens);
            ours.sync();
        }
        if (plugin("zoomEnabled", true))
            setPlugin("zoomEnabled", "zoom", false);
        if (plugin("magnifierEnabled", false))
            setPlugin("magnifierEnabled", "magnifier", false);
        return;
    }
    const bool wantLens = file(u"ambrosiarc"_s)->group(u"Accessibility"_s).readEntry("ZoomLens", false);
    setPlugin(wantLens ? "magnifierEnabled" : "zoomEnabled", wantLens ? "magnifier" : "zoom", true);
}
void Access::setZoomStyle(const QString &style)
{
    const bool lens = style == u"lens";
    if (!zoom() || lens == (zoomStyle() == u"lens"))
        return;
    // One at a time: both answer the same keys.
    setPlugin(lens ? "zoomEnabled" : "magnifierEnabled", lens ? "zoom" : "magnifier", false);
    setPlugin(lens ? "magnifierEnabled" : "zoomEnabled", lens ? "magnifier" : "zoom", true);
}
QString Access::zoomInKeys() const
{
    return shortcut("view_zoom_in", u"Meta+="_s);
}
QString Access::zoomOutKeys() const
{
    return shortcut("view_zoom_out", u"Meta+-"_s);
}
QString Access::scrollZoomKeys() const
{
    return glyphs(file(u"kwinrc"_s)->group(u"Effect-zoom"_s).readEntry("PointerAxisGestureModifiers", u"Meta+Control"_s));
}

bool Access::colorFilters() const
{
    return plugin("colorblindnesscorrectionEnabled", false);
}
void Access::setColorFilters(bool on)
{
    setPlugin("colorblindnesscorrectionEnabled", "colorblindnesscorrection", on);
}
int Access::colorFilter() const
{
    return file(u"kwinrc"_s)->group(u"Effect-colorblindnesscorrection"_s).readEntry("Mode", 0);
}
void Access::setColorFilter(int mode)
{
    if (mode == colorFilter())
        return;
    if (!dryRun("set KWin's color filter")) {
        KConfigGroup group = file(u"kwinrc"_s)->group(u"Effect-colorblindnesscorrection"_s);
        group.writeEntry("Mode", std::clamp(mode, 0, 2), KConfig::Notify);
        group.sync();
        if (colorFilters())
            effect("reconfigureEffect", "colorblindnesscorrection");
    }
    Q_EMIT changed();
}

qreal Access::pointerSize() const
{
    const int size = file(u"kcminputrc"_s)->group(u"Mouse"_s).readEntry("cursorSize", 24);
    return std::clamp((size - 24) / 48.0, 0.0, 1.0);
}
void Access::setPointerSize(qreal value)
{
    // In twelves, the sizes cursor themes are drawn at: 24 … 72.
    const int size = 24 + 12 * int(std::lround(std::clamp(value, 0.0, 1.0) * 4));
    if (!dryRun(qPrintable(u"set the pointer's size to %1 (kcminputrc)"_s.arg(size)))) {
        KConfigGroup group = file(u"kcminputrc"_s)->group(u"Mouse"_s);
        group.writeEntry("cursorSize", size, KConfig::Notify);
        group.sync();
    }
    Q_EMIT changed();
}

bool Access::shakeToLocate() const
{
    return plugin("shakecursorEnabled", true);
}
void Access::setShakeToLocate(bool on)
{
    setPlugin("shakecursorEnabled", "shakecursor", on);
}

bool Access::reduceMotion() const
{
    return file(u"kdeglobals"_s)->group(u"KDE"_s).readEntry("AnimationDurationFactor", 1.0) == 0.0;
}
void Access::setReduceMotion(bool on)
{
    if (!dryRun("set the animation speed (kdeglobals)")) {
        KConfigGroup group = file(u"kdeglobals"_s)->group(u"KDE"_s);
        if (on)
            group.writeEntry("AnimationDurationFactor", 0.0, KConfig::Notify);
        else
            group.deleteEntry("AnimationDurationFactor", KConfig::Notify);
        group.sync();
        notifyApps(4); // SETTINGS_STYLE
    }
    Q_EMIT changed();
}

bool Access::steadyCursor() const
{
    return file(u"kdeglobals"_s)->group(u"KDE"_s).readEntry("CursorBlinkRate", 1000) == 0;
}
void Access::setSteadyCursor(bool on)
{
    if (!dryRun("set the text cursor's blinking (kdeglobals)")) {
        KConfigGroup group = file(u"kdeglobals"_s)->group(u"KDE"_s);
        if (on)
            group.writeEntry("CursorBlinkRate", 0, KConfig::Notify);
        else
            group.deleteEntry("CursorBlinkRate", KConfig::Notify);
        group.sync();
        notifyApps(4);
    }
    Q_EMIT changed();
}

bool Access::flashScreen() const
{
    return access("Bell", "VisibleBell");
}
void Access::setFlashScreen(bool on)
{
    setAccess("Bell", "VisibleBell", on);
}
bool Access::stickyKeys() const
{
    return access("Keyboard", "StickyKeys");
}
void Access::setStickyKeys(bool on)
{
    setAccess("Keyboard", "StickyKeys", on);
}
bool Access::slowKeys() const
{
    return access("Keyboard", "SlowKeys");
}
void Access::setSlowKeys(bool on)
{
    setAccess("Keyboard", "SlowKeys", on);
}
bool Access::mouseKeys() const
{
    return access("Mouse", "MouseKeys");
}
void Access::setMouseKeys(bool on)
{
    setAccess("Mouse", "MouseKeys", on);
}
