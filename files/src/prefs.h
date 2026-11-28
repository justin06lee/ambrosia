#pragma once

#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What Files' Settings window sets (Finder Settings on a Mac), kept in
// ~/.config/ambrosia/files.conf and read live by every window of the one
// process: which folder a new window shows, which items the sidebar lists,
// the warnings, folders kept on top, and where a search looks first.
// "Remove items from the Trash after 30 days" is KDE's own trash setting
// (ktrashrc), so every app's trashing honors it; Files also sweeps the
// Trash itself (FileOps::sweepTrash), as nothing else does between trashes.
class Prefs : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // "recents", "home", "desktop", "documents", "downloads" or "computer".
    Q_PROPERTY(QString newWindow READ newWindow WRITE setNewWindow NOTIFY changed)
    Q_PROPERTY(QUrl newWindowUrl READ newWindowUrl NOTIFY changed)
    // The sidebar's items that show, by id (Places::sections names them).
    Q_PROPERTY(QStringList sidebarItems READ sidebarItems NOTIFY sidebarChanged)
    Q_PROPERTY(bool warnExtension READ warnExtension WRITE setWarnExtension NOTIFY changed)
    // View ▸ Show Path Bar and Show Status Bar: every window's, and kept,
    // as Finder's. Neither shows until asked for, as on a Mac.
    // View ▸ Hide Sidebar, the same way.
    Q_PROPERTY(bool sidebar READ sidebar WRITE setSidebar NOTIFY changed)
    Q_PROPERTY(bool pathBar READ pathBar WRITE setPathBar NOTIFY changed)
    Q_PROPERTY(bool statusBar READ statusBar WRITE setStatusBar NOTIFY changed)
    Q_PROPERTY(bool warnEmptyTrash READ warnEmptyTrash WRITE setWarnEmptyTrash NOTIFY changed)
    Q_PROPERTY(bool trashExpires READ trashExpires WRITE setTrashExpires NOTIFY changed)
    Q_PROPERTY(bool foldersFirst READ foldersFirst WRITE setFoldersFirst NOTIFY foldersFirstChanged)
    // "computer", "folder" or "previous" (the scope the last search had).
    Q_PROPERTY(QString searchScope READ searchScope WRITE setSearchScope NOTIFY changed)
    // The Settings window's tab, kept while Files runs.
    Q_PROPERTY(int tab MEMBER m_tab NOTIFY changed)

public:
    static Prefs *instance();
    static Prefs *create(QQmlEngine *, QJSEngine *);

    QString newWindow() const;
    void setNewWindow(const QString &place);
    QUrl newWindowUrl() const;

    QStringList sidebarItems() const;
    Q_INVOKABLE bool sidebarShows(const QString &id) const;
    Q_INVOKABLE void setSidebarShows(const QString &id, bool shows);

    bool warnExtension() const;
    void setWarnExtension(bool on);
    bool sidebar() const;
    void setSidebar(bool on);
    bool pathBar() const;
    void setPathBar(bool on);
    bool statusBar() const;
    void setStatusBar(bool on);
    bool warnEmptyTrash() const;
    void setWarnEmptyTrash(bool on);
    bool trashExpires() const;
    void setTrashExpires(bool on);
    bool foldersFirst() const;
    void setFoldersFirst(bool on);
    QString searchScope() const;
    void setSearchScope(const QString &scope);

    // Where a search starts looking ("computer" or "folder"), and the
    // scope a search was given, for "previous".
    Q_INVOKABLE QString startScope() const;
    Q_INVOKABLE void usedScope(const QString &scope);

    // Days a trashed item is kept while trashExpires.
    static constexpr int trashDays = 30;

Q_SIGNALS:
    void changed();
    void sidebarChanged();
    void foldersFirstChanged();
    void trashExpiresChanged();

private:
    explicit Prefs(QObject *parent = nullptr);
    void set(const QString &key, const QVariant &value);

    mutable QSettings m_settings;
    int m_tab = 0;
};
