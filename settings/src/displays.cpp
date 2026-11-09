#include "displays.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <KScreen/Config>
#include <KScreen/ConfigMonitor>
#include <KScreen/EDID>
#include <KScreen/GetConfigOperation>
#include <KScreen/Mode>
#include <KScreen/Output>
#include <KScreen/SetConfigOperation>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QtEndian>

#include <algorithm>
#include <cmath>

using namespace KScreen;

namespace
{
const QString brightnessService = QStringLiteral("org.kde.ScreenBrightness");
const QString brightnessPath = QStringLiteral("/org/kde/ScreenBrightness");

// The Mac's choices run from "Larger Text" to "More Space"; KWin's scale
// gives the same, each looking like the mode's size divided by it. None
// smaller than a Mac offers (1024 wide).
constexpr double scales[] = {2.0, 1.75, 1.5, 1.25, 1.0};

QString nameOf(const OutputPtr &output)
{
    if (output->type() == Output::Panel)
        return QStringLiteral("Built-in Display");
    const QString model = output->edid() ? output->edid()->name().trimmed() : QString();
    return model.isEmpty() ? QStringLiteral("Display") : model;
}

QString hertz(float rate)
{
    const double rounded = std::round(rate);
    return (std::abs(rate - rounded) < 0.005 ? QString::number(int(rounded)) : QString::number(rate, 'f', 2))
        + QStringLiteral(" Hertz");
}

QString rotationName(Output::Rotation rotation)
{
    switch (rotation) {
    case Output::Right:
        return QStringLiteral("90");
    case Output::Inverted:
        return QStringLiteral("180");
    case Output::Left:
        return QStringLiteral("270");
    default:
        return QStringLiteral("0");
    }
}

// An ICC profile's own name (its 'desc' tag, in a v2 or v4 profile), else
// its file's.
QString profileName(const QString &path)
{
    QFile file(path);
    const QByteArray icc = file.open(QIODevice::ReadOnly) ? file.read(1 << 20) : QByteArray();
    const auto u32 = [&](qsizetype at) { return at + 4 <= icc.size() ? qFromBigEndian<quint32>(icc.constData() + at) : 0u; };
    const quint32 tags = u32(128);
    for (quint32 i = 0; i < tags && i < 256; ++i) {
        const qsizetype entry = 132 + 12 * i;
        if (icc.mid(entry, 4) != "desc")
            continue;
        const qsizetype at = u32(entry + 4);
        if (icc.mid(at, 4) == "desc") {
            const QString text = QString::fromLatin1(icc.mid(at + 12, u32(at + 8))).trimmed().remove(QChar(0));
            if (!text.isEmpty())
                return text;
        } else if (icc.mid(at, 4) == "mluc" && u32(at + 8) > 0) {
            const QByteArray utf16 = icc.mid(at + u32(at + 24), u32(at + 20));
            QString text;
            for (qsizetype c = 0; c + 1 < utf16.size(); c += 2)
                text += QChar(qFromBigEndian<quint16>(utf16.constData() + c));
            if (!text.trimmed().isEmpty())
                return text.trimmed();
        }
        break;
    }
    return QFileInfo(path).completeBaseName();
}

// ICC profiles installed for anyone or for this user, by name.
QVariantList iccProfiles()
{
    QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("icc"), QStandardPaths::LocateDirectory);
    dirs << QStringLiteral("/usr/share/color/icc") << QStringLiteral("/var/lib/colord/icc");
    QVariantList profiles;
    QSet<QString> seen;
    for (const QString &dir : std::as_const(dirs)) {
        for (const QFileInfo &file : QDir(dir).entryInfoList({QStringLiteral("*.icc"), QStringLiteral("*.icm")}, QDir::Files)) {
            if (seen.contains(file.canonicalFilePath()))
                continue;
            seen.insert(file.canonicalFilePath());
            profiles.append(QVariantMap{{QStringLiteral("id"), file.absoluteFilePath()}, {QStringLiteral("name"), profileName(file.absoluteFilePath())}});
        }
    }
    std::sort(profiles.begin(), profiles.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return profiles;
}
}

namespace
{
KConfigGroup preferences()
{
    return KSharedConfig::openConfig(QStringLiteral("ambrosiarc"))->group(QStringLiteral("Displays"));
}
}

Displays::Displays(QObject *parent)
    : QObject(parent)
{
    m_showAsList = preferences().readEntry("ShowResolutionsAsList", false);
    auto *get = new GetConfigOperation();
    connect(get, &ConfigOperation::finished, this, [this](ConfigOperation *op) {
        if (op->hasError()) {
            qWarning("Settings: no display configuration: %s", qPrintable(op->errorString()));
            return;
        }
        m_config = qobject_cast<GetConfigOperation *>(op)->config();
        ConfigMonitor::instance()->addConfig(m_config);
        connect(ConfigMonitor::instance(), &ConfigMonitor::configurationChanged, this, &Displays::readBrightness);
        readBrightness();
    });

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(brightnessService, QString(), QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"),
                this, SLOT(readBrightness()));
    bus.connect(brightnessService, brightnessPath, brightnessService, QStringLiteral("DisplayAdded"), this, SLOT(readBrightness()));
    bus.connect(brightnessService, brightnessPath, brightnessService, QStringLiteral("DisplayRemoved"), this, SLOT(readBrightness()));
}

OutputPtr Displays::output(int id) const
{
    return m_config ? m_config->output(id) : OutputPtr();
}

// Which of the brightness service's displays is which output: the built-in
// one by being built in, the others by the model their label carries.
void Displays::readBrightness()
{
    m_brightness.clear();
    if (!m_config)
        return;
    QDBusInterface service(brightnessService, brightnessPath, brightnessService);
    const QStringList names = service.isValid() ? service.property("DisplaysDBusNames").toStringList() : QStringList();
    QList<QVariantMap> unclaimed;
    for (const QString &name : names) {
        const QString path = brightnessPath + QLatin1Char('/') + name;
        QDBusInterface display(brightnessService, path, QStringLiteral("org.kde.ScreenBrightness.Display"));
        const int max = display.property("MaxBrightness").toInt();
        if (max <= 0)
            continue;
        unclaimed.append({{QStringLiteral("path"), path},
                          {QStringLiteral("label"), display.property("Label")},
                          {QStringLiteral("internal"), display.property("IsInternal")},
                          {QStringLiteral("max"), max},
                          {QStringLiteral("value"), display.property("Brightness").toInt() / double(max)}});
    }
    for (const OutputPtr &output : m_config->outputs()) {
        if (!output->isConnected() || !output->isEnabled())
            continue;
        const bool builtIn = output->type() == Output::Panel;
        const QString model = output->edid() ? output->edid()->name().trimmed() : QString();
        for (auto it = unclaimed.begin(); it != unclaimed.end(); ++it) {
            const bool internal = it->value(QStringLiteral("internal")).toBool();
            if (builtIn ? internal : (!internal && !model.isEmpty() && it->value(QStringLiteral("label")).toString().contains(model))) {
                m_brightness.insert(output->id(), *it);
                unclaimed.erase(it);
                break;
            }
        }
    }
    refresh();
}

void Displays::refresh()
{
    QList<OutputPtr> outputs;
    for (const OutputPtr &output : m_config->outputs()) {
        if (output->isConnected() && output->isEnabled() && output->currentMode())
            outputs.append(output);
    }
    std::sort(outputs.begin(), outputs.end(), [](const OutputPtr &a, const OutputPtr &b) { return a->priority() < b->priority(); });

    QVariantList list;
    for (const OutputPtr &output : std::as_const(outputs)) {
        const ModePtr mode = output->currentMode();
        const QSize size = mode->size();
        const bool builtIn = output->type() == Output::Panel;

        QVariantList choices;
        for (const double scale : scales) {
            const int width = std::lround(size.width() / scale);
            if (width >= 1024 || scale == 1.0)
                choices.append(QVariantMap{{QStringLiteral("scale"), scale},
                                           {QStringLiteral("width"), width},
                                           {QStringLiteral("height"), int(std::lround(size.height() / scale))}});
        }
        // KWin's own default: the scale that brings the display to the
        // density meant for it (a laptop's is seen closer than a desk's).
        double defaultScale = 1.0;
        if (output->sizeMm().height() > 0) {
            const double dpi = size.height() / (output->sizeMm().height() / 25.4);
            const double wanted = dpi / (builtIn ? 125.0 : 96.0);
            for (const QVariant &choice : std::as_const(choices)) {
                const double scale = choice.toMap().value(QStringLiteral("scale")).toDouble();
                if (std::abs(scale - wanted) < std::abs(defaultScale - wanted))
                    defaultScale = scale;
            }
        }

        // The rates the mode's size comes in, fastest first.
        QList<ModePtr> modes;
        for (const ModePtr &other : output->modes()) {
            if (other->size() == size)
                modes.append(other);
        }
        std::sort(modes.begin(), modes.end(), [](const ModePtr &a, const ModePtr &b) { return a->refreshRate() > b->refreshRate(); });
        QVariantList rates;
        QSet<QString> texts;
        for (const ModePtr &other : std::as_const(modes)) {
            const QString text = hertz(other->refreshRate());
            if (other->id() != mode->id() && texts.contains(text))
                continue;
            texts.insert(text);
            rates.append(QVariantMap{{QStringLiteral("id"), other->id()}, {QStringLiteral("text"), text}});
        }

        QVariantList profiles{QVariantMap{{QStringLiteral("id"), QStringLiteral("srgb")}, {QStringLiteral("name"), QStringLiteral("sRGB IEC61966-2.1")}}};
        if (output->capabilities() & Output::Capability::BuiltInColorProfile)
            profiles.append(QVariantMap{{QStringLiteral("id"), QStringLiteral("edid")}, {QStringLiteral("name"), nameOf(output)}});
        if (output->capabilities() & Output::Capability::IccProfile)
            profiles += iccProfiles();
        QString profile = QStringLiteral("srgb");
        if (output->colorProfileSource() == Output::ColorProfileSource::EDID)
            profile = QStringLiteral("edid");
        else if (output->colorProfileSource() == Output::ColorProfileSource::ICC && !output->iccProfilePath().isEmpty())
            profile = output->iccProfilePath();

        const QVariantMap brightness = m_brightness.value(output->id());
        list.append(QVariantMap{
            {QStringLiteral("id"), output->id()},
            {QStringLiteral("name"), nameOf(output)},
            {QStringLiteral("builtIn"), builtIn},
            {QStringLiteral("scale"), output->scale()},
            {QStringLiteral("scales"), choices},
            {QStringLiteral("defaultScale"), defaultScale},
            {QStringLiteral("rate"), mode->id()},
            {QStringLiteral("rates"), rates},
            {QStringLiteral("rotation"), rotationName(output->rotation())},
            {QStringLiteral("profile"), profile},
            {QStringLiteral("profiles"), profiles},
            {QStringLiteral("dimmable"), !brightness.isEmpty()},
            {QStringLiteral("brightness"), brightness.value(QStringLiteral("value"), 1.0)},
        });
    }
    if (list == m_list)
        return;
    m_list = list;
    Q_EMIT changed();
}

void Displays::apply()
{
    auto *set = new SetConfigOperation(m_config);
    connect(set, &ConfigOperation::finished, this, [](ConfigOperation *op) {
        if (op->hasError())
            qWarning("Settings: the displays didn't change: %s", qPrintable(op->errorString()));
    });
}

void Displays::setShowAsList(bool on)
{
    if (m_showAsList == on)
        return;
    m_showAsList = on;
    KConfigGroup group = preferences();
    group.writeEntry("ShowResolutionsAsList", on);
    group.sync();
    Q_EMIT showAsListChanged();
}

void Displays::setScale(int id, double scale)
{
    if (const OutputPtr out = output(id); out && !qFuzzyCompare(out->scale(), scale)) {
        out->setScale(scale);
        apply();
    }
}

void Displays::setRate(int id, const QString &modeId)
{
    if (const OutputPtr out = output(id); out && out->mode(modeId) && out->currentModeId() != modeId) {
        out->setCurrentModeId(modeId);
        apply();
    }
}

void Displays::setRotation(int id, const QString &rotation)
{
    const OutputPtr out = output(id);
    if (!out)
        return;
    const Output::Rotation wanted = rotation == QLatin1String("90") ? Output::Right
        : rotation == QLatin1String("180")                           ? Output::Inverted
        : rotation == QLatin1String("270")                           ? Output::Left
                                                                     : Output::None;
    if (out->rotation() != wanted) {
        out->setRotation(wanted);
        apply();
    }
}

void Displays::setProfile(int id, const QString &profile)
{
    const OutputPtr out = output(id);
    if (!out)
        return;
    if (profile == QLatin1String("srgb")) {
        out->setColorProfileSource(Output::ColorProfileSource::sRGB);
    } else if (profile == QLatin1String("edid")) {
        out->setColorProfileSource(Output::ColorProfileSource::EDID);
    } else {
        out->setIccProfilePath(profile);
        out->setColorProfileSource(Output::ColorProfileSource::ICC);
    }
    apply();
}

void Displays::setBrightness(int id, double value)
{
    const QVariantMap display = m_brightness.value(id);
    if (display.isEmpty())
        return;
    QDBusMessage call = QDBusMessage::createMethodCall(brightnessService, display.value(QStringLiteral("path")).toString(),
                                                       QStringLiteral("org.kde.ScreenBrightness.Display"), QStringLiteral("SetBrightness"));
    call << int(std::lround(std::clamp(value, 0.0, 1.0) * display.value(QStringLiteral("max")).toInt())) << 0u;
    QDBusConnection::sessionBus().asyncCall(call);
}
