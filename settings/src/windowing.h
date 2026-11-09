#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// How windows behave, KWin's (kwinrc, which it's told to reread): the effect
// a window minimizes with, a double-click on a title bar, dragging to the
// screen's edges, and what its corners do. And the default web browser.
class Windowing : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // "genie" (KWin's Magic Lamp) or "scale" (its Squash).
    Q_PROPERTY(QString minimizeEffect READ minimizeEffect WRITE setMinimizeEffect NOTIFY changed)
    // "Maximize", "Minimize" or "Nothing", as KWin's option has them.
    Q_PROPERTY(QString titleBarDoubleClick READ titleBarDoubleClick WRITE setTitleBarDoubleClick NOTIFY changed)
    Q_PROPERTY(bool tileAtEdges READ tileAtEdges WRITE setTileAtEdges NOTIFY changed)
    Q_PROPERTY(bool fillAtTop READ fillAtTop WRITE setFillAtTop NOTIFY changed)
    // [{text, value}] for a pop-up, each browser's desktop file its value.
    Q_PROPERTY(QVariantList browsers READ browsers CONSTANT)
    Q_PROPERTY(QString browser READ browser WRITE setBrowser NOTIFY changed)

public:
    explicit Windowing(QObject *parent = nullptr);

    QString minimizeEffect() const;
    void setMinimizeEffect(const QString &effect);
    QString titleBarDoubleClick() const;
    void setTitleBarDoubleClick(const QString &command);
    bool tileAtEdges() const;
    void setTileAtEdges(bool on);
    bool fillAtTop() const;
    void setFillAtTop(bool on);
    QVariantList browsers() const;
    QString browser() const;
    void setBrowser(const QString &desktopFile);

    // A corner, "TopLeft", "TopRight", "BottomLeft" or "BottomRight": what
    // pushing into it does, "none", "overview", "windows", "desktop" or "lock".
    Q_INVOKABLE QString hotCorner(const QString &corner) const;
    Q_INVOKABLE void setHotCorner(const QString &corner, const QString &action);

Q_SIGNALS:
    void changed();

private:
    QString m_browser;
};
