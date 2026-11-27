#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QStringList>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the windows can't do from QML: the system's appearance, each
// window's shadow (KWin draws it), showing a file in Files, and a second
// launch handing over the font files it was asked to open.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.FontBook")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // Drawn with no screen (a grab on a machine without one): a mask draws
    // nothing there, so windows leave their corner masks off.
    Q_PROPERTY(bool offscreen READ offscreen CONSTANT)
    // The font files it was started with.
    Q_PROPERTY(QList<QUrl> files READ files CONSTANT)
    // For grabs: the view to open on ("" leaves it be), a typeface whose
    // page to open, and whether the info pane shows.
    Q_PROPERTY(QString view READ view CONSTANT)
    Q_PROPERTY(QString family READ family CONSTANT)
    Q_PROPERTY(bool info READ info CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the window to this PNG once shown, then quit
        QString view;
        QString family;
        QList<QUrl> files;
        bool info = false;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    bool offscreen() const;
    QList<QUrl> files() const { return m_options.files; }
    QString view() const { return m_options.view; }
    QString family() const { return m_options.family; }
    bool info() const { return m_options.info; }

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // A window is up: with --grab, the one to photograph (a font file's
    // preview when one was asked for) is saved a little later and the app
    // leaves.
    Q_INVOKABLE void shown(QQuickWindow *window, bool preview);
    Q_INVOKABLE void activate(QQuickWindow *window);
    // Show a file in its folder, in Files (org.freedesktop.FileManager1).
    Q_INVOKABLE void reveal(const QString &path);
    // The Open panel, for font files to add: addRequested with those
    // chosen.
    Q_INVOKABLE void chooseFonts();

public Q_SLOTS:
    // A second launch: open these font files (none: bring the window
    // forward).
    Q_SCRIPTABLE void Open(const QStringList &files, const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void openRequested(const QList<QUrl> &files);
    void addRequested(const QList<QUrl> &files);

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
    bool m_choosing = false;
};
