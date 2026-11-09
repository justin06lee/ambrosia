#include "windowing.h"

#include <KApplicationTrader>
#include <KConfigGroup>
#include <KService>
#include <KSharedConfig>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDir>
#include <QSet>
#include <QStandardPaths>
#include <QVariantMap>

using namespace Qt::StringLiterals;

namespace
{
KSharedConfigPtr kwinrc()
{
    const KSharedConfigPtr config = KSharedConfig::openConfig(u"kwinrc"_s);
    config->reparseConfiguration();
    return config;
}

void callKWin(const QString &path, const QString &interface, const QString &method, const QVariantList &arguments = {})
{
    QDBusMessage message = QDBusMessage::createMethodCall(u"org.kde.KWin"_s, path, interface, method);
    message.setArguments(arguments);
    QDBusConnection::sessionBus().asyncCall(message);
}

void reconfigure()
{
    callKWin(u"/KWin"_s, u"org.kde.KWin"_s, u"reconfigure"_s);
}

void reconfigureEffect(const QString &effect)
{
    callKWin(u"/Effects"_s, u"org.kde.kwin.Effects"_s, u"reconfigureEffect"_s, {effect});
}

void write(const QString &group, const QString &key, const QVariant &value)
{
    KConfigGroup settings = kwinrc()->group(group);
    settings.writeEntry(key, value, KConfig::Notify);
    settings.sync();
}

// KWin's numbers for the corners (ElectricBorder); 9 is none.
int borderNumber(const QString &corner)
{
    return corner == "TopRight"_L1 ? 1 : corner == "BottomRight"_L1 ? 3 : corner == "BottomLeft"_L1 ? 5 : 7;
}
constexpr int noBorder = 9;

QList<int> borders(const QString &group, const QString &key)
{
    return kwinrc()->group(group).readEntry(key, QList<int>{});
}

void setBorder(const QString &group, const QString &key, int border, bool on)
{
    QList<int> list = borders(group, key);
    list.removeAll(noBorder);
    list.removeAll(border);
    if (on)
        list.append(border);
    if (list.isEmpty())
        list.append(noBorder);
    KConfigGroup settings = kwinrc()->group(group);
    settings.writeEntry(key, list, KConfig::Notify);
    settings.sync();
}

const auto overview = u"Effect-overview"_s;
const auto windowView = u"Effect-windowview"_s;

KConfigGroup defaultApplications()
{
    const KSharedConfigPtr config = KSharedConfig::openConfig(u"mimeapps.list"_s, KConfig::SimpleConfig, QStandardPaths::GenericConfigLocation);
    config->reparseConfiguration();
    return config->group(u"Default Applications"_s);
}

QString currentBrowser()
{
    // The user's own choice, or, on a system where they haven't made one yet,
    // whichever browser their links open in.
    const QString chosen = defaultApplications().readEntry("x-scheme-handler/https", QString());
    if (!chosen.isEmpty())
        return chosen;
    const KService::Ptr service = KApplicationTrader::preferredService(u"x-scheme-handler/https"_s);
    return service ? service->storageId() : QString();
}
}

Windowing::Windowing(QObject *parent)
    : QObject(parent)
    , m_browser(currentBrowser())
{
}

QString Windowing::minimizeEffect() const
{
    return kwinrc()->group(u"Plugins"_s).readEntry("magiclampEnabled", false) ? u"genie"_s : u"scale"_s;
}

void Windowing::setMinimizeEffect(const QString &effect)
{
    const bool genie = effect == "genie"_L1;
    write(u"Plugins"_s, u"magiclampEnabled"_s, genie);
    write(u"Plugins"_s, u"squashEnabled"_s, !genie);
    callKWin(u"/Effects"_s, u"org.kde.kwin.Effects"_s, genie ? u"unloadEffect"_s : u"loadEffect"_s, {u"squash"_s});
    callKWin(u"/Effects"_s, u"org.kde.kwin.Effects"_s, genie ? u"loadEffect"_s : u"unloadEffect"_s, {u"magiclamp"_s});
    Q_EMIT changed();
}

QString Windowing::titleBarDoubleClick() const
{
    return kwinrc()->group(u"Windows"_s).readEntry("TitlebarDoubleClickCommand", u"Maximize"_s);
}

void Windowing::setTitleBarDoubleClick(const QString &command)
{
    write(u"Windows"_s, u"TitlebarDoubleClickCommand"_s, command);
    reconfigure();
    Q_EMIT changed();
}

bool Windowing::tileAtEdges() const
{
    return kwinrc()->group(u"Windows"_s).readEntry("ElectricBorderTiling", true);
}

void Windowing::setTileAtEdges(bool on)
{
    write(u"Windows"_s, u"ElectricBorderTiling"_s, on);
    reconfigure();
    Q_EMIT changed();
}

bool Windowing::fillAtTop() const
{
    return kwinrc()->group(u"Windows"_s).readEntry("ElectricBorderMaximize", true);
}

void Windowing::setFillAtTop(bool on)
{
    write(u"Windows"_s, u"ElectricBorderMaximize"_s, on);
    reconfigure();
    Q_EMIT changed();
}

QVariantList Windowing::browsers() const
{
    QVariantList browsers;
    QSet<QString> seen;
    const QStringList folders = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const QString &folder : folders) {
        const QStringList files = QDir(folder).entryList({u"*.desktop"_s}, QDir::Files, QDir::Name);
        for (const QString &file : files) {
            if (seen.contains(file))
                continue;
            seen.insert(file);
            const KSharedConfigPtr desktop = KSharedConfig::openConfig(folder + u'/' + file, KConfig::SimpleConfig);
            const KConfigGroup entry = desktop->group(u"Desktop Entry"_s);
            if (entry.readEntry("NoDisplay", false) || !entry.readEntry("MimeType").contains("x-scheme-handler/https"_L1))
                continue;
            browsers.append(QVariantMap{{u"text"_s, entry.readEntry("Name")}, {u"value"_s, file}});
        }
    }
    return browsers;
}

QString Windowing::browser() const
{
    return m_browser;
}

void Windowing::setBrowser(const QString &desktopFile)
{
    // As KDE's own default-applications module does; xdg-settings fails here,
    // wanting the kwriteconfig of an older Plasma.
    KConfigGroup defaults = defaultApplications();
    for (const auto type : {"x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"})
        defaults.writeEntry(type, desktopFile);
    defaults.sync();
    KConfigGroup general = KSharedConfig::openConfig(u"kdeglobals"_s)->group(u"General"_s);
    general.writeEntry("BrowserApplication", desktopFile, KConfig::Notify);
    general.sync();
    m_browser = currentBrowser();
    Q_EMIT changed();
}

QString Windowing::hotCorner(const QString &corner) const
{
    const int border = borderNumber(corner);
    if (borders(overview, u"BorderActivate"_s).contains(border))
        return u"overview"_s;
    if (borders(windowView, u"BorderActivateClass"_s).contains(border))
        return u"windows"_s;
    const QString action = kwinrc()->group(u"ElectricBorders"_s).readEntry(corner, QString()).toLower();
    return action == "showdesktop"_L1 ? u"desktop"_s : action == "lockscreen"_L1 ? u"lock"_s : u"none"_s;
}

void Windowing::setHotCorner(const QString &corner, const QString &action)
{
    const int border = borderNumber(corner);
    setBorder(overview, u"BorderActivate"_s, border, action == "overview"_L1);
    setBorder(windowView, u"BorderActivateClass"_s, border, action == "windows"_L1);
    write(u"ElectricBorders"_s, corner,
          action == "desktop"_L1 ? u"ShowDesktop"_s : action == "lock"_L1 ? u"LockScreen"_s : u"None"_s);
    reconfigure();
    reconfigureEffect(u"overview"_s);
    reconfigureEffect(u"windowview"_s);
    Q_EMIT changed();
}
