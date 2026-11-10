#pragma once

#include "kwininput.h"

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Mouse: every mouse KWin has, all set alike as the Mac sets its mice
// (KWinInput), and the double-click speed every app reads (kdeglobals).
class Mouse : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool available READ available NOTIFY changed)
    // 0 (slow) .. 1 (fast): libinput's acceleration, -1 .. 1.
    Q_PROPERTY(qreal speed READ speed WRITE setSpeed NOTIFY changed)
    Q_PROPERTY(bool naturalScroll READ naturalScroll WRITE setNaturalScroll NOTIFY changed)
    // The secondary click on the left button.
    Q_PROPERTY(bool leftHanded READ leftHanded WRITE setLeftHanded NOTIFY changed)
    // 0 .. 1: scroll factor 0.25 .. 4, on a log scale (1 in the middle).
    Q_PROPERTY(qreal scrollSpeed READ scrollSpeed WRITE setScrollSpeed NOTIFY changed)
    // Pointer acceleration (Advanced…): libinput's adaptive profile, or flat.
    Q_PROPERTY(bool acceleration READ acceleration WRITE setAcceleration NOTIFY changed)
    // 0 (slow) .. 1 (fast): 1000 .. 150 ms between clicks.
    Q_PROPERTY(qreal doubleClick READ doubleClick WRITE setDoubleClick NOTIFY changed)

public:
    explicit Mouse(QObject *parent = nullptr);

    bool available() const { return !m_mice.isEmpty(); }
    qreal speed() const;
    void setSpeed(qreal value);
    bool naturalScroll() const;
    void setNaturalScroll(bool on);
    bool leftHanded() const;
    void setLeftHanded(bool on);
    qreal scrollSpeed() const;
    void setScrollSpeed(qreal value);
    bool acceleration() const;
    void setAcceleration(bool on);
    qreal doubleClick() const;
    void setDoubleClick(qreal value);

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();

private:
    void setAll(const char *name, const QVariant &value);

    // The mice: KWin's pointers that aren't touchpads, tablets or touch screens.
    KWinInput m_mice{KWinInput::Mice};
};
