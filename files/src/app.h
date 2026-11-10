#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QSize>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

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
    };

    App(QQmlEngine *engine, const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

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
    // Get Info (⌘I): the item's Info window, brought forward if it's open.
    Q_INVOKABLE void openInfo(const QUrl &url);
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
