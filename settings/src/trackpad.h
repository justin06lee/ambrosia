#pragma once

#include "kwininput.h"

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Trackpad: every touchpad KWin has, all set alike (KWinInput): tracking
// speed, where the secondary click is, tap to click and natural scrolling.
// What a pad can't do (a click method it lacks, tapping) isn't offered.
class Trackpad : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool available READ available NOTIFY changed)
    // 0 (slow) .. 1 (fast): libinput's acceleration, -1 .. 1.
    Q_PROPERTY(qreal speed READ speed WRITE setSpeed NOTIFY changed)
    // "twoFingers" (a click or tap with two fingers; libinput's clickfinger)
    // or "corner" (a click in the bottom right corner; its button areas).
    Q_PROPERTY(QString secondaryClick READ secondaryClick WRITE setSecondaryClick NOTIFY changed)
    Q_PROPERTY(bool twoFingerClick READ twoFingerClick NOTIFY changed)
    Q_PROPERTY(bool cornerClick READ cornerClick NOTIFY changed)
    Q_PROPERTY(bool canTap READ canTap NOTIFY changed)
    Q_PROPERTY(bool tapToClick READ tapToClick WRITE setTapToClick NOTIFY changed)
    Q_PROPERTY(bool naturalScroll READ naturalScroll WRITE setNaturalScroll NOTIFY changed)

public:
    explicit Trackpad(QObject *parent = nullptr);

    bool available() const { return !m_pads.isEmpty(); }
    qreal speed() const;
    void setSpeed(qreal value);
    QString secondaryClick() const;
    void setSecondaryClick(const QString &where);
    bool twoFingerClick() const;
    bool cornerClick() const;
    bool canTap() const;
    bool tapToClick() const;
    void setTapToClick(bool on);
    bool naturalScroll() const;
    void setNaturalScroll(bool on);

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();

private:
    void setAll(const char *name, const QVariant &value);

    KWinInput m_pads{KWinInput::Touchpads};
};
