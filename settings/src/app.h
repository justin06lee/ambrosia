#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// The application: tells QML the appearance and what this computer has
// (a battery, a mouse, a trackpad, the KDE modules standing in for panes
// not built yet), opens those modules, and takes a second launch's pane
// over D-Bus. One process, one window, as System Settings.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.Settings")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    Q_PROPERTY(QString pane READ pane CONSTANT)
    Q_PROPERTY(bool active READ active CONSTANT)
    Q_PROPERTY(bool hasBattery READ hasBattery CONSTANT)
    Q_PROPERTY(bool hasMouse READ hasMouse CONSTANT)
    Q_PROPERTY(bool hasTrackpad READ hasTrackpad CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" to force one
        QString pane;       // the pane to open first
        QString grab;       // save the window to this PNG once its pane is shown, then quit
        bool active = false; // draw the window active, for grabs
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    QString pane() const { return m_options.pane; }
    bool active() const { return m_options.active; }
    bool hasBattery() const { return m_battery; }
    bool hasMouse() const { return m_mouse; }
    bool hasTrackpad() const { return m_trackpad; }

    // Whether KDE's System Settings module NAME is installed, and opening
    // it in its own window (kcmshell6), for a pane of ours not built yet.
    Q_INVOKABLE bool hasModule(const QString &name) const;
    Q_INVOKABLE void openModule(const QString &name);
    // Whether PROGRAM is installed, and starting it (System Report…).
    Q_INVOKABLE bool has(const QString &program) const;
    Q_INVOKABLE void run(const QString &program, const QStringList &arguments = {});
    // Gives the frameless window KWin's shadow, for its corner radius.
    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // The first pane is on screen: grab it if asked to.
    Q_INVOKABLE void shown(QQuickWindow *window);
    // Brings the window forward, with the token a second launch handed over.
    Q_INVOKABLE void activate(QQuickWindow *window);
    // The zoom light: fills the screen's height at the window's width, or
    // gives it back its size, as System Settings' zoom does.
    Q_INVOKABLE void zoom(QQuickWindow *window);

public Q_SLOTS:
    // org.ambrosia.Settings.Show: another launch asks for a pane (empty for
    // the one shown), with its activation token so the window can come forward.
    Q_SCRIPTABLE void Show(const QString &pane, const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void showRequested(const QString &pane);

private:
    Options m_options;
    bool m_battery = false;
    bool m_mouse = false;
    bool m_trackpad = false;
    bool m_grabbed = false;
    static App *s_instance;
};
