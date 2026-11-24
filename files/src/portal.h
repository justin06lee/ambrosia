#pragma once

#include <QDBusContext>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QVariantMap>

class App;

// Every app's Open and Save: the desktop portal's file chooser
// (org.freedesktop.impl.portal.FileChooser), which xdg-desktop-portal asks
// in an Ambrosia session (session/xdg/xdg-desktop-portal/portals.conf). A
// request opens a Files window as a panel (FinderWindow's `panel`): the
// same sidebar, views and search, with Cancel and Open or Save under them,
// over the window of the app that asked. Its answer goes back when a
// choice is made or the panel is closed.
class Portal : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.FileChooser")

public:
    explicit Portal(App *app);

    // What FinderWindow's `panel` takes, from a request's options: kind
    // ("open", "folder", "save" or "saveFiles"), title, accept (the default
    // button's word), multiple, name (a save's suggested name), filters
    // ([{text, globs, mimes}]) and filter (the one chosen, -1 for none).
    static QVariantMap panelFor(const QString &kind, const QString &title, const QVariantMap &options);
    // Where a panel starts: the folder the request names, or its file's;
    // failing that the folder the last panel chose in, or Documents.
    static QUrl folderFor(const QVariantMap &options);
    // A stand-in request for --panel (grabs, and looking a panel over).
    static QVariantMap samplePanel(const QString &kind);

public Q_SLOTS:
    Q_SCRIPTABLE void OpenFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                               const QVariantMap &options);
    Q_SCRIPTABLE void SaveFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                               const QVariantMap &options);
    Q_SCRIPTABLE void SaveFiles(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                                const QVariantMap &options);

private:
    void ask(const QString &kind, const QDBusObjectPath &handle, const QString &parent, const QString &title, const QVariantMap &options);

    App *m_app;
};

// One request under way: the panel's window, the call to answer, and the
// request's own object on the bus (org.freedesktop.impl.portal.Request),
// whose Close is the app giving up on the dialog.
class PanelRequest : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Request")

public:
    PanelRequest(QQuickWindow *window, const QDBusMessage &call, const QString &path, const QVariantMap &options, QObject *parent);
    ~PanelRequest() override;

public Q_SLOTS:
    Q_SCRIPTABLE void Close();
    // The panel's choice (FinderWindow.panelAccepted): the items' URLs, and
    // which of the request's filters was showing.
    void accepted(const QVariant &urls, int filter);

private:
    void answer(uint response, const QVariantMap &results);

    QPointer<QQuickWindow> m_window;
    QDBusMessage m_call;
    QString m_path;
    QVariantMap m_options;
    bool m_done = false;
};
