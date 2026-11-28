#include "prefs.h"

#include "places.h"

#include <KConfig>
#include <KConfigGroup>

#include <QJSEngine>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

namespace {

// The sidebar as it is before anyone chooses: a Mac's leaves Movies, Music
// and Pictures out too.
const QStringList defaultSidebar{u"recents"_s, u"applications"_s, u"desktop"_s, u"documents"_s, u"downloads"_s, u"home"_s,
                                 u"computer"_s, u"disks"_s, u"external"_s, u"trash"_s, u"tags"_s};

// The home Trash, as KDE's trash names it in ktrashrc.
QString trashGroup()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + u"/Trash"_s;
}

}

Prefs *Prefs::instance()
{
    static Prefs *prefs = new Prefs;
    return prefs;
}

Prefs *Prefs::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

Prefs::Prefs(QObject *parent)
    : QObject(parent)
    , m_settings(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/ambrosia/files.conf"_s, QSettings::IniFormat)
{
}

void Prefs::set(const QString &key, const QVariant &value)
{
    if (m_settings.value(key) == value)
        return;
    m_settings.setValue(key, value);
    Q_EMIT changed();
}

QString Prefs::newWindow() const
{
    return m_settings.value(u"newWindow"_s, u"home"_s).toString();
}

void Prefs::setNewWindow(const QString &place)
{
    set(u"newWindow"_s, place);
}

QUrl Prefs::newWindowUrl() const
{
    const QUrl url = Places::urlOf(newWindow());
    return url.isValid() ? url : Places::urlOf(u"home"_s);
}

QStringList Prefs::sidebarItems() const
{
    return m_settings.value(u"sidebarItems"_s, defaultSidebar).toStringList();
}

bool Prefs::sidebarShows(const QString &id) const
{
    return sidebarItems().contains(id);
}

void Prefs::setSidebarShows(const QString &id, bool shows)
{
    QStringList items = sidebarItems();
    if (items.contains(id) == shows)
        return;
    if (shows)
        items << id;
    else
        items.removeAll(id);
    m_settings.setValue(u"sidebarItems"_s, items);
    Q_EMIT sidebarChanged();
}

bool Prefs::warnExtension() const
{
    return m_settings.value(u"warnExtension"_s, true).toBool();
}

void Prefs::setWarnExtension(bool on)
{
    set(u"warnExtension"_s, on);
}

bool Prefs::sidebar() const
{
    return m_settings.value(u"sidebar"_s, true).toBool();
}

void Prefs::setSidebar(bool on)
{
    set(u"sidebar"_s, on);
}

bool Prefs::pathBar() const
{
    return m_settings.value(u"pathBar"_s, false).toBool();
}

void Prefs::setPathBar(bool on)
{
    set(u"pathBar"_s, on);
}

bool Prefs::statusBar() const
{
    return m_settings.value(u"statusBar"_s, false).toBool();
}

void Prefs::setStatusBar(bool on)
{
    set(u"statusBar"_s, on);
}

bool Prefs::warnEmptyTrash() const
{
    return m_settings.value(u"warnEmptyTrash"_s, true).toBool();
}

void Prefs::setWarnEmptyTrash(bool on)
{
    set(u"warnEmptyTrash"_s, on);
}

bool Prefs::trashExpires() const
{
    const KConfig config(u"ktrashrc"_s, KConfig::SimpleConfig);
    const KConfigGroup group = config.group(trashGroup());
    return group.readEntry("UseTimeLimit", false) && group.readEntry("Days", 7) == trashDays;
}

void Prefs::setTrashExpires(bool on)
{
    if (trashExpires() == on)
        return;
    KConfig config(u"ktrashrc"_s, KConfig::SimpleConfig);
    KConfigGroup group = config.group(trashGroup());
    group.writeEntry("UseTimeLimit", on);
    if (on)
        group.writeEntry("Days", trashDays);
    config.sync();
    Q_EMIT changed();
    Q_EMIT trashExpiresChanged();
}

bool Prefs::foldersFirst() const
{
    return m_settings.value(u"foldersFirst"_s, false).toBool();
}

void Prefs::setFoldersFirst(bool on)
{
    if (foldersFirst() == on)
        return;
    m_settings.setValue(u"foldersFirst"_s, on);
    Q_EMIT foldersFirstChanged();
}

QString Prefs::searchScope() const
{
    return m_settings.value(u"searchScope"_s, u"computer"_s).toString();
}

void Prefs::setSearchScope(const QString &scope)
{
    set(u"searchScope"_s, scope);
}

QString Prefs::startScope() const
{
    const QString scope = searchScope();
    if (scope == "previous"_L1)
        return m_settings.value(u"lastSearchScope"_s, u"computer"_s).toString();
    return scope == "folder"_L1 ? scope : u"computer"_s;
}

void Prefs::usedScope(const QString &scope)
{
    if (m_settings.value(u"lastSearchScope"_s) != scope)
        m_settings.setValue(u"lastSearchScope"_s, scope);
}
