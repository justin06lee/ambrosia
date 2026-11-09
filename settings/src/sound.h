#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

struct pa_stream;
namespace PulseAudioQt
{
class Device;
class Sink;
class Source;
class StreamRestore;
}

// Sound, on PipeWire through its PulseAudio server (pulseaudio-qt): the
// output and input devices and which is in use, their volume, mute and
// balance; alerts' volume and device (the "event" role, as KDE's
// notifications play them) and sound theme; plasma-pa's volume-change
// feedback; and the input's level while the Input tab shows it.
class Sound : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{name, title, kind, current}], in the server's order; no monitors.
    Q_PROPERTY(QVariantList outputs READ outputs NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList inputs READ inputs NOTIFY devicesChanged)
    // 0 to 1 for 0 to 100%.
    Q_PROPERTY(qreal outputVolume READ outputVolume NOTIFY outputChanged)
    Q_PROPERTY(bool outputMuted READ outputMuted NOTIFY outputChanged)
    // 0 left, 0.5 centred, 1 right; only for a device with a left and a right.
    Q_PROPERTY(qreal balance READ balance NOTIFY outputChanged)
    Q_PROPERTY(bool hasBalance READ hasBalance NOTIFY outputChanged)
    Q_PROPERTY(qreal inputVolume READ inputVolume NOTIFY inputChanged)
    Q_PROPERTY(qreal inputLevel READ inputLevel NOTIFY inputLevelChanged)
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY monitoringChanged)
    // Alerts' own volume and device, kept by the server for the "event" role.
    Q_PROPERTY(bool hasAlerts READ hasAlerts NOTIFY alertChanged)
    Q_PROPERTY(qreal alertVolume READ alertVolume NOTIFY alertChanged)
    // The output alerts play through: "" for whichever is in use.
    Q_PROPERTY(QString alertDevice READ alertDevice NOTIFY alertChanged)
    // [{name, title}] of the installed sound themes, and the one in use.
    Q_PROPERTY(QVariantList themes READ themes CONSTANT)
    Q_PROPERTY(QString theme READ theme NOTIFY themeChanged)
    Q_PROPERTY(bool feedback READ feedback NOTIFY feedbackChanged)

public:
    explicit Sound(QObject *parent = nullptr);
    ~Sound() override;

    QVariantList outputs() const;
    QVariantList inputs() const;
    qreal outputVolume() const;
    bool outputMuted() const;
    qreal balance() const;
    bool hasBalance() const;
    qreal inputVolume() const;
    qreal inputLevel() const { return m_level; }
    bool monitoring() const { return m_monitoring; }
    void setMonitoring(bool on);
    bool hasAlerts() const { return alerts() != nullptr; }
    qreal alertVolume() const;
    QString alertDevice() const;
    QVariantList themes() const { return m_themes; }
    QString theme() const;
    bool feedback() const;

    Q_INVOKABLE void setDefaultOutput(const QString &name);
    Q_INVOKABLE void setDefaultInput(const QString &name);
    Q_INVOKABLE void setOutputVolume(qreal volume);
    Q_INVOKABLE void setOutputMuted(bool muted);
    Q_INVOKABLE void setBalance(qreal balance);
    Q_INVOKABLE void setInputVolume(qreal volume);
    Q_INVOKABLE void setAlertVolume(qreal volume);
    Q_INVOKABLE void setAlertDevice(const QString &name);
    Q_INVOKABLE void setTheme(const QString &name);
    Q_INVOKABLE void setFeedback(bool on);
    // Plays the alert sound of the theme in use, as an alert plays.
    Q_INVOKABLE void playAlert();

    // The peak-detect stream's callback.
    void peak(float level);

Q_SIGNALS:
    void devicesChanged();
    void outputChanged();
    void inputChanged();
    void inputLevelChanged();
    void monitoringChanged();
    void alertChanged();
    void themeChanged();
    void feedbackChanged();

private:
    PulseAudioQt::Sink *output() const;
    PulseAudioQt::Source *input() const;
    PulseAudioQt::StreamRestore *alerts() const;
    void watch(PulseAudioQt::Device *device, bool isOutput);
    void watchAlerts(PulseAudioQt::StreamRestore *restore);
    void reconnectLevel();
    void stopLevel();

    QVariantList m_themes;
    bool m_monitoring = false;
    qreal m_level = 0;
    pa_stream *m_stream = nullptr;
    QString m_streamSource;
};
