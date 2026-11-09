#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Keyboard: how keys repeat (kcminputrc, which KWin watches), the keyboard's
// backlight where UPower has one, and the input sources (kxkbrc, else the
// system's layout from localed).
class Keyboard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // The Mac's steps: repeat 0 (off) to 7 (fastest), delay 0 (longest) to 5.
    Q_PROPERTY(int repeatStep READ repeatStep WRITE setRepeatStep NOTIFY changed)
    Q_PROPERTY(int delayStep READ delayStep WRITE setDelayStep NOTIFY changed)
    Q_PROPERTY(bool backlight READ backlight NOTIFY changed)
    // 0..1.
    Q_PROPERTY(qreal brightness READ brightness WRITE setBrightness NOTIFY changed)
    Q_PROPERTY(QString inputSources READ inputSources NOTIFY changed)

public:
    explicit Keyboard(QObject *parent = nullptr);

    int repeatStep() const;
    void setRepeatStep(int step);
    int delayStep() const;
    void setDelayStep(int step);
    bool backlight() const { return m_maxBrightness > 0; }
    qreal brightness() const;
    void setBrightness(qreal value);
    QString inputSources() const;

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();

private:
    int m_maxBrightness = 0;
    int m_brightness = 0;
};
