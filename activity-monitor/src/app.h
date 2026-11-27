#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the windows can't do from QML: the system's appearance, each
// window's shadow (KWin draws it), the clipboard, showing a file in Files,
// and a second launch asking for the window.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.ActivityMonitor")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // Drawn with no screen (a grab on a machine without one): a mask draws
    // nothing there, so windows leave their corner masks off.
    Q_PROPERTY(bool offscreen READ offscreen CONSTANT)
    // For grabs: the tab to open on ("" leaves it be) and a process whose
    // inspector to open and photograph (-1 none).
    Q_PROPERTY(QString tab READ tab CONSTANT)
    Q_PROPERTY(int inspect READ inspect CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the window to this PNG once shown, then quit
        QString tab;
        int inspect = -1;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    bool offscreen() const;
    QString tab() const { return m_options.tab; }
    int inspect() const { return m_options.inspect; }

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // A window is up: with --grab, the one to photograph (the inspector
    // when one was asked for) is saved a little later and the app leaves.
    Q_INVOKABLE void shown(QQuickWindow *window, bool inspector);
    Q_INVOKABLE void activate(QQuickWindow *window);
    Q_INVOKABLE void copy(const QString &text);
    // Show a file in its folder, in Files (org.freedesktop.FileManager1).
    Q_INVOKABLE void reveal(const QString &path);

public Q_SLOTS:
    // A second launch: bring the window forward.
    Q_SCRIPTABLE void Show(const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void showRequested();

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
};
