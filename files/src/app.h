#pragma once

#include <QColor>
#include <QObject>
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

public:
    struct Options {
        QString appearance; // "light" or "dark" to force one
        QString grab;       // save the first window to this PNG once loaded, then quit
        QString view;       // the first window's view
        QSize size;         // the first window's size
        bool bench = false; // print how long the first folder took, then quit
    };

    App(QQmlEngine *engine, const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    QString view() const { return m_options.view; }

    Q_INVOKABLE void openWindow(const QUrl &url);
    Q_INVOKABLE void openFile(const QUrl &url);
    // Gives a frameless Files window KWin's shadow, for its corner radius.
    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // A window's first folder is on screen: grab or report it if asked to.
    Q_INVOKABLE void shown(QQuickWindow *window, double loadMs);

public Q_SLOTS:
    // org.ambrosia.Files.Open: another launch hands its folders over.
    Q_SCRIPTABLE void Open(const QStringList &urls);

Q_SIGNALS:
    void appearanceChanged();

private:
    QQmlEngine *m_engine;
    Options m_options;
    bool m_first = true;
    static App *s_instance;
};
