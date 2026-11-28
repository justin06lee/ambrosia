#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QSize>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QQmlEngine;
class QJSEngine;

// The application: opens Finder windows (from the command line, from a
// second launch over D-Bus, from QML), opens files in their apps, and tells
// QML the appearance. One process serves every window.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.Files")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    Q_PROPERTY(QString view READ view CONSTANT)
    Q_PROPERTY(QStringList expand READ expand CONSTANT)
    Q_PROPERTY(QString select READ select CONSTANT)
    Q_PROPERTY(bool active READ active CONSTANT)
    // "floating" (the inset glass panel) or "flush" (the stub along the edge).
    Q_PROPERTY(QString sidebar READ sidebar CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" to force one
        QString grab;       // save the first window to this PNG once loaded, then quit
        QString view;       // the first window's view
        QSize size;         // the first window's size
        bool bench = false; // print how long the first folder took, then quit
        QStringList expand; // folders (paths in the first folder) to open in place, for grabs
        QString select;     // the item to select in the first folder, for grabs
        bool active = false; // draw the first window active, for grabs
        QString sidebar;    // which sidebar windows have
        QString panel;      // the first window as an Open or Save panel: open, folder, save
    };

    App(QQmlEngine *engine, const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);
    static App *instance() { return s_instance; }
    // Tells or asks by an alert of ours (kit/AlertWindow.qml), from
    // anywhere in the app: `what` is { heading, detail, buttons, secret,
    // icon } (Files' own icon unless one is named), `then` hears the
    // button's role and what was typed. With no QML to draw it, Qt's own
    // box says the words and `then` hears "".
    static void tell(QVariantMap what, std::function<void(const QString &role, const QString &typed)> then = {});

    bool dark() const;
    QColor accent() const;
    QString view() const { return m_options.view; }
    QStringList expand() const { return m_options.expand; }
    QString select() const { return m_options.select; }
    bool active() const { return m_options.active; }
    QString sidebar() const { return m_options.sidebar; }

    // select: the name of an item to select once the folder is read.
    Q_INVOKABLE void openWindow(const QUrl &url, const QString &select = QString());
    // Each item's folder in a window, the item selected (one window a
    // folder): what "Show in Folder" asks through FileManager1 below.
    void showItems(const QStringList &uris);
    Q_INVOKABLE void openFile(const QUrl &url);
    // Whether opening this file expands it: an archive whose app is
    // Archive Utility (ours, org.ambrosia.archive), not one the user gave
    // to another app.
    Q_INVOKABLE bool expands(const QUrl &url) const;
    // The apps that open this kind of thing, the one that does by default
    // first: each a map of name, id (its desktop file's) and icon.
    Q_INVOKABLE QVariantList appsFor(const QUrl &url) const;
    // Opens them in that app; with no id, KDE's window for choosing one.
    Q_INVOKABLE void openWith(const QList<QUrl> &urls, const QString &id);
    // Get Info (⌘I): the item's Info window, brought forward if it's open.
    Q_INVOKABLE void openInfo(const QUrl &url);
    // An Open or Save panel (Portal): a Finder window with `panel` set, not
    // shown yet, so it can be put over the window that asked first.
    QQuickWindow *openPanel(const QUrl &folder, const QVariantMap &panel);
    // Whether a panel's filter takes a file by its name: any of the globs,
    // or a type that is one of the MIME types (image/* for a whole family).
    Q_INVOKABLE bool accepts(const QString &name, const QStringList &globs, const QStringList &mimes) const;
    // Whether a Save would write over something.
    Q_INVOKABLE bool exists(const QUrl &url) const;
    // The room left on the disk a folder is on, as the status bar says it:
    // "31.34 GB". Empty for a place that isn't on a disk.
    Q_INVOKABLE QString roomOn(const QUrl &url) const;
    // The progress window, for the copies and moves in FileOps.jobs: made
    // when one has run for a second; it closes itself after the last.
    void openProgress();
    // The keys held now (Qt.AltModifier ...), for what a drop does.
    Q_INVOKABLE int modifiers() const;
    // Gives a frameless Files window KWin's shadow, for its corner radius.
    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // A window's first folder is on screen: grab or report it if asked to.
    Q_INVOKABLE void shown(QQuickWindow *window, double loadMs, double firstMs);

public Q_SLOTS:
    // org.ambrosia.Files.Open: another launch hands its folders over.
    Q_SCRIPTABLE void Open(const QStringList &urls);
    // org.ambrosia.Files.Trash: the Dock's Trash hands over what's dropped
    // on it, so Edit > Undo in Files puts it back, as in Finder.
    Q_SCRIPTABLE void Trash(const QStringList &urls);
    // org.ambrosia.Files.Expand: archives opened from anywhere (the
    // Archive Utility desktop entry, `ambrosia-files --unarchive`) are
    // expanded beside themselves, with no window.
    Q_SCRIPTABLE void Expand(const QStringList &urls);
    // org.ambrosia.Files.Find: the shell's Search asks the index for the
    // items whose names have every word of the query, best first, at most
    // limit of them. Two strings for each: its path (a folder's ends in a
    // slash), then the thumbnail the cache already holds of it, or "".
    Q_SCRIPTABLE QStringList Find(const QString &query, int limit);

Q_SIGNALS:
    void appearanceChanged();

private:
    QQmlEngine *m_engine;
    Options m_options;
    bool m_first = true;
    QList<QPointer<QQuickWindow>> m_infos;
    QPointer<QQuickWindow> m_progress;
    static App *s_instance;
};

// org.freedesktop.FileManager1, which apps call for "Show in Folder" (a
// browser's downloads, the shell's Search): Files answers it while it runs,
// which is from login, so they show the item here and not in Dolphin.
class FileManager1 : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")

public:
    explicit FileManager1(App *app);

public Q_SLOTS:
    Q_SCRIPTABLE void ShowFolders(const QStringList &uris, const QString &startupId);
    Q_SCRIPTABLE void ShowItems(const QStringList &uris, const QString &startupId);
    Q_SCRIPTABLE void ShowItemProperties(const QStringList &uris, const QString &startupId);

private:
    App *m_app;
};
