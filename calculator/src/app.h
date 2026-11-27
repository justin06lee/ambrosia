#pragma once

#include <QObject>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the window can't do from QML: its shadow (KWin draws it), the
// clipboard, and a picture of itself for checking (--grab).
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Draw the window as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // Keys to press as it opens ("2+3×4="), for grabs.
    Q_PROPERTY(QString keys READ keys CONSTANT)

public:
    struct Options {
        QString grab;        // save the window to this PNG once shown, then quit
        QString keys;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool active() const { return m_options.active; }
    QString keys() const { return m_options.keys; }

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    Q_INVOKABLE void shown(QQuickWindow *window);
    Q_INVOKABLE void copy(const QString &text);
    Q_INVOKABLE QString clipboard() const;

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
};
