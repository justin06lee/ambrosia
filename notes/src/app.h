#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the window can't do from QML: the system's appearance, the window's
// shadow (KWin draws it), the Save panel for a PDF, and a second launch
// bringing the first forward.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.Notes")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // Drawn with no screen (a grab on a machine without one): a mask draws
    // nothing there, so windows leave their corner masks off.
    Q_PROPERTY(bool offscreen READ offscreen CONSTANT)
    // For grabs: what to show over the window (format: the Format menu).
    Q_PROPERTY(QString show READ show CONSTANT)
    // The clock has twenty-four hours here, not twice twelve.
    Q_PROPERTY(bool hour24 READ hour24 CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the window to this PNG once shown, then quit
        QString show;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    bool offscreen() const;
    QString show() const { return m_options.show; }
    bool hour24() const;

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // The window is up: with --grab it is saved a little later and the app
    // leaves.
    Q_INVOKABLE void shown(QQuickWindow *window);
    Q_INVOKABLE void activate(QQuickWindow *window);

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
