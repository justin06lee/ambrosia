#include "sound.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <PulseAudioQt/Context>
#include <PulseAudioQt/Port>
#include <PulseAudioQt/Server>
#include <PulseAudioQt/Sink>
#include <PulseAudioQt/Source>
#include <PulseAudioQt/StreamRestore>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <pulse/context.h>
#include <pulse/stream.h>

#include <algorithm>

using namespace PulseAudioQt;

namespace
{
const QString alertRole = QStringLiteral("sink-input-by-media-role:event");

qreal fraction(qint64 volume)
{
    return std::clamp(qreal(volume) / qreal(normalVolume()), 0.0, 1.0);
}

qint64 volumeOf(qreal fraction)
{
    return qRound64(std::clamp(fraction, 0.0, 1.0) * qreal(normalVolume()));
}

// A device's name without the profile PipeWire appends ("Built-in Audio
// Analog Stereo" is "Built-in Audio").
QString title(const Device *device)
{
    static const QRegularExpression profile(QStringLiteral(R"(\s+(Analog|Digital|Pro)?\s*(Stereo|Mono|Surround [0-9.]+)(\s+\(.*\))?$)"));
    QString text = device->description();
    text.remove(profile);
    return text.isEmpty() ? device->description() : text;
}

// The Type column, in System Settings' words.
QString kind(const Device *device)
{
    const QString bus = device->pulseProperties().value(QStringLiteral("device.bus")).toString();
    if (device->isVirtualDevice())
        return Sound::tr("Virtual");
    if (bus == QLatin1String("bluetooth"))
        return Sound::tr("Bluetooth");
    if (bus == QLatin1String("usb"))
        return Sound::tr("USB");
    const Port *port = device->ports().value(int(device->activePortIndex()));
    if (port && port->type() == Port::HDMI)
        return Sound::tr("HDMI");
    if (port && port->type() == Port::Headphones)
        return Sound::tr("Headphone port");
    return Sound::tr("Built-in");
}

bool isMonitor(const Source *source)
{
    return source->pulseProperties().value(QStringLiteral("device.class")).toString() == QLatin1String("monitor");
}

QVariantMap row(const Device *device)
{
    return {{QStringLiteral("name"), device->name()},
            {QStringLiteral("title"), title(device)},
            {QStringLiteral("kind"), kind(device)},
            {QStringLiteral("current"), device->isDefault()}};
}

bool isLeft(const QString &channel)
{
    return channel.contains(QLatin1String("left"));
}

bool isRight(const QString &channel)
{
    return channel.contains(QLatin1String("right"));
}

void readCallback(pa_stream *stream, size_t, void *self)
{
    const void *data = nullptr;
    size_t bytes = 0;
    if (pa_stream_peek(stream, &data, &bytes) < 0)
        return;
    if (!data) {
        if (bytes)
            pa_stream_drop(stream);
        return;
    }
    const float level = static_cast<const float *>(data)[bytes / sizeof(float) - 1];
    pa_stream_drop(stream);
    static_cast<Sound *>(self)->peak(level);
}
}

Sound::Sound(QObject *parent)
    : QObject(parent)
{
    Context::setApplicationId(QStringLiteral("org.ambrosia.settings"));
    Context *context = Context::instance();

    connect(context, &Context::sinkAdded, this, [this](Sink *sink) {
        watch(sink, true);
        Q_EMIT devicesChanged();
    });
    connect(context, &Context::sinkRemoved, this, &Sound::devicesChanged);
    connect(context, &Context::sourceAdded, this, [this](Source *source) {
        watch(source, false);
        Q_EMIT devicesChanged();
    });
    connect(context, &Context::sourceRemoved, this, &Sound::devicesChanged);
    connect(context, &Context::streamRestoreAdded, this, &Sound::watchAlerts);
    connect(context, &Context::streamRestoreRemoved, this, &Sound::alertChanged);
    connect(context, &Context::stateChanged, this, &Sound::reconnectLevel);
    connect(context->server(), &Server::defaultSinkChanged, this, [this] {
        Q_EMIT devicesChanged();
        Q_EMIT outputChanged();
    });
    connect(context->server(), &Server::defaultSourceChanged, this, [this] {
        Q_EMIT devicesChanged();
        Q_EMIT inputChanged();
        reconnectLevel();
    });
    for (Sink *sink : context->sinks())
        watch(sink, true);
    for (Source *source : context->sources())
        watch(source, false);
    for (StreamRestore *restore : context->streamRestores())
        watchAlerts(restore);

    // The sound themes: each folder of a sounds directory with an index.theme.
    QStringList seen;
    for (const QString &dir : QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("sounds"), QStandardPaths::LocateDirectory)) {
        for (const QString &name : QDir(dir).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            const QString index = dir + QLatin1Char('/') + name + QStringLiteral("/index.theme");
            if (seen.contains(name) || !QFile::exists(index))
                continue;
            QSettings theme(index, QSettings::IniFormat);
            theme.beginGroup(QStringLiteral("Sound Theme"));
            if (theme.value(QStringLiteral("Hidden")).toBool())
                continue;
            seen << name;
            m_themes << QVariantMap{{QStringLiteral("name"), name}, {QStringLiteral("title"), theme.value(QStringLiteral("Name"), name).toString()}};
        }
    }
    std::sort(m_themes.begin(), m_themes.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("title")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("title")).toString()) < 0;
    });
}

Sound::~Sound()
{
    stopLevel();
}

void Sound::watch(Device *device, bool isOutput)
{
    auto changed = isOutput ? &Sound::outputChanged : &Sound::inputChanged;
    connect(device, &Device::volumeChanged, this, changed);
    connect(device, &Device::mutedChanged, this, changed);
    connect(device, &Device::channelVolumesChanged, this, changed);
    connect(device, &Device::descriptionChanged, this, &Sound::devicesChanged);
    connect(device, &Device::activePortIndexChanged, this, &Sound::devicesChanged);
    connect(device, &Device::defaultChanged, this, &Sound::devicesChanged);
}

void Sound::watchAlerts(StreamRestore *restore)
{
    if (restore->name() != alertRole)
        return;
    connect(restore, &StreamRestore::volumeChanged, this, &Sound::alertChanged);
    connect(restore, &StreamRestore::deviceChanged, this, &Sound::alertChanged);
    Q_EMIT alertChanged();
}

Sink *Sound::output() const
{
    return Context::instance()->server()->defaultSink();
}

Source *Sound::input() const
{
    return Context::instance()->server()->defaultSource();
}

StreamRestore *Sound::alerts() const
{
    const QList<StreamRestore *> restores = Context::instance()->streamRestores();
    const auto it = std::find_if(restores.begin(), restores.end(), [](StreamRestore *restore) {
        return restore->name() == alertRole;
    });
    return it == restores.end() ? nullptr : *it;
}

QVariantList Sound::outputs() const
{
    QVariantList list;
    for (const Sink *sink : Context::instance()->sinks())
        list << row(sink);
    return list;
}

QVariantList Sound::inputs() const
{
    QVariantList list;
    for (const Source *source : Context::instance()->sources()) {
        if (!isMonitor(source))
            list << row(source);
    }
    return list;
}

qreal Sound::outputVolume() const
{
    return output() ? fraction(output()->volume()) : 0;
}

bool Sound::outputMuted() const
{
    return output() && output()->isMuted();
}

bool Sound::hasBalance() const
{
    const Sink *sink = output();
    if (!sink)
        return false;
    const QStringList channels = sink->rawChannels();
    return std::any_of(channels.begin(), channels.end(), isLeft) && std::any_of(channels.begin(), channels.end(), isRight);
}

qreal Sound::balance() const
{
    if (!hasBalance())
        return 0.5;
    const QStringList channels = output()->rawChannels();
    const QList<qint64> volumes = output()->channelVolumes();
    qint64 left = 0, right = 0;
    for (int i = 0; i < channels.size() && i < volumes.size(); ++i) {
        if (isLeft(channels[i]))
            left = std::max(left, volumes[i]);
        else if (isRight(channels[i]))
            right = std::max(right, volumes[i]);
    }
    if (left == right)
        return 0.5;
    return right < left ? 0.5 * qreal(right) / qreal(left) : 1 - 0.5 * qreal(left) / qreal(right);
}

qreal Sound::inputVolume() const
{
    return input() ? fraction(input()->volume()) : 0;
}

qreal Sound::alertVolume() const
{
    return alerts() ? fraction(alerts()->volume()) : 0;
}

QString Sound::alertDevice() const
{
    return alerts() ? alerts()->device() : QString();
}

QString Sound::theme() const
{
    return KSharedConfig::openConfig(QStringLiteral("kdeglobals"))->group(QStringLiteral("Sounds")).readEntry("Theme", QStringLiteral("ocean"));
}

bool Sound::feedback() const
{
    return KSharedConfig::openConfig(QStringLiteral("plasmaparc"))->group(QStringLiteral("General")).readEntry("AudioFeedback", true);
}

void Sound::setDefaultOutput(const QString &name)
{
    Context::instance()->setDefaultSink(name);
}

void Sound::setDefaultInput(const QString &name)
{
    Context::instance()->setDefaultSource(name);
}

void Sound::setOutputVolume(qreal volume)
{
    if (Sink *sink = output()) {
        sink->setVolume(volumeOf(volume));
        if (sink->isMuted() && volume > 0)
            sink->setMuted(false);
    }
}

void Sound::setOutputMuted(bool muted)
{
    if (Sink *sink = output())
        sink->setMuted(muted);
}

void Sound::setBalance(qreal balance)
{
    if (!hasBalance())
        return;
    Sink *sink = output();
    const qint64 loudest = sink->volume();
    const qint64 left = balance > 0.5 ? qRound64(loudest * (2 - 2 * balance)) : loudest;
    const qint64 right = balance < 0.5 ? qRound64(loudest * 2 * balance) : loudest;
    QList<qint64> volumes;
    for (const QString &channel : sink->rawChannels())
        volumes << (isLeft(channel) ? left : isRight(channel) ? right : loudest);
    sink->setChannelVolumes(volumes);
}

void Sound::setInputVolume(qreal volume)
{
    if (Source *source = input())
        source->setVolume(volumeOf(volume));
}

void Sound::setAlertVolume(qreal volume)
{
    if (StreamRestore *restore = alerts())
        restore->setVolume(volumeOf(volume));
}

void Sound::setAlertDevice(const QString &name)
{
    if (StreamRestore *restore = alerts())
        restore->setDevice(name);
}

void Sound::setTheme(const QString &name)
{
    KConfigGroup group = KSharedConfig::openConfig(QStringLiteral("kdeglobals"))->group(QStringLiteral("Sounds"));
    group.writeEntry("Theme", name, KConfig::Notify);
    group.sync();
    Q_EMIT themeChanged();
    playAlert();
}

void Sound::setFeedback(bool on)
{
    KConfigGroup group = KSharedConfig::openConfig(QStringLiteral("plasmaparc"))->group(QStringLiteral("General"));
    group.writeEntry("AudioFeedback", on, KConfig::Notify);
    group.sync();
    Q_EMIT feedbackChanged();
}

void Sound::playAlert()
{
    // The theme's bell, else its warning, else the freedesktop theme's.
    for (const QString &name : {theme(), QStringLiteral("freedesktop")}) {
        for (const char *sound : {"bell", "dialog-warning"}) {
            for (const char *type : {"oga", "ogg", "wav"}) {
                const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                            QStringLiteral("sounds/%1/stereo/%2.%3").arg(name, QLatin1String(sound), QLatin1String(type)));
                if (!path.isEmpty()) {
                    // As an alert plays: through the server, in the event role.
                    QProcess::startDetached(QStringLiteral("paplay"), {QStringLiteral("--property=media.role=event"), path});
                    return;
                }
            }
        }
    }
}

void Sound::setMonitoring(bool on)
{
    if (m_monitoring == on)
        return;
    m_monitoring = on;
    Q_EMIT monitoringChanged();
    reconnectLevel();
}

void Sound::reconnectLevel()
{
    const Source *source = input();
    if (m_stream && source && source->name() == m_streamSource && m_monitoring)
        return;
    stopLevel();
    pa_context *context = Context::instance()->context();
    if (!m_monitoring || !source || !context || pa_context_get_state(context) != PA_CONTEXT_READY)
        return;
    // A peak-detecting record stream of one float, 25 times a second.
    const pa_sample_spec spec{PA_SAMPLE_FLOAT32, 25, 1};
    pa_buffer_attr attributes{};
    attributes.maxlength = uint32_t(-1);
    attributes.fragsize = sizeof(float);
    pa_proplist *properties = pa_proplist_new();
    pa_proplist_sets(properties, PA_PROP_APPLICATION_ID, "org.ambrosia.settings");
    m_stream = pa_stream_new_with_proplist(context, "Input level", &spec, nullptr, properties);
    pa_proplist_free(properties);
    if (!m_stream)
        return;
    m_streamSource = source->name();
    pa_stream_set_read_callback(m_stream, readCallback, this);
    const auto flags = pa_stream_flags_t(PA_STREAM_DONT_MOVE | PA_STREAM_PEAK_DETECT | PA_STREAM_ADJUST_LATENCY);
    if (pa_stream_connect_record(m_stream, m_streamSource.toUtf8().constData(), &attributes, flags) < 0)
        stopLevel();
}

void Sound::stopLevel()
{
    if (m_stream) {
        pa_stream_set_read_callback(m_stream, nullptr, nullptr);
        pa_stream_disconnect(m_stream);
        pa_stream_unref(m_stream);
        m_stream = nullptr;
    }
    m_streamSource.clear();
    if (m_level != 0) {
        m_level = 0;
        Q_EMIT inputLevelChanged();
    }
}

void Sound::peak(float level)
{
    const qreal value = std::clamp(qreal(level), 0.0, 1.0);
    if (qAbs(value - m_level) < 0.005)
        return;
    m_level = value;
    Q_EMIT inputLevelChanged();
}
