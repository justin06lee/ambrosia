#include "about.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QRegularExpression>
#include <QScreen>
#include <QStorageInfo>
#include <QTextStream>

#include <cmath>

namespace {

const QString hostnamed = QStringLiteral("org.freedesktop.hostname1");
const QString hostnamedPath = QStringLiteral("/org/freedesktop/hostname1");

QString readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
}

// KEY=value from os-release, quotes taken off.
QString osRelease(const QString &key)
{
    for (const QString &path : {QStringLiteral("/etc/os-release"), QStringLiteral("/usr/lib/os-release")}) {
        const QString text = readFile(path);
        if (text.isEmpty())
            continue;
        for (const QString &line : text.split(QLatin1Char('\n'))) {
            if (line.startsWith(key + QLatin1Char('='))) {
                QString value = line.mid(key.size() + 1).trimmed();
                if (value.size() >= 2 && (value.startsWith(QLatin1Char('"')) || value.startsWith(QLatin1Char('\''))))
                    value = value.mid(1, value.size() - 2);
                return value;
            }
        }
        return {};
    }
    return {};
}

// A maker's name as people say it: "Dell Inc." is Dell.
QString shortMaker(QString name)
{
    static const QRegularExpression suffix(QStringLiteral(",?\\s+(Inc\\.?|Corporation|Corp\\.?|Co\\.,?\\s*Ltd\\.?|Ltd\\.?|LLC|GmbH|AG|S\\.A\\.|Technology|Computer)$"),
                                           QRegularExpression::CaseInsensitiveOption);
    for (QString before; before != name;) {
        before = name;
        name.remove(suffix);
    }
    return name.trimmed();
}

// Firmware that never had its model filled in.
bool placeholder(const QString &value)
{
    static const QStringList junk = {QStringLiteral("to be filled by o.e.m."), QStringLiteral("system product name"),
                                     QStringLiteral("default string"), QStringLiteral("not applicable"), QStringLiteral("none"),
                                     QStringLiteral("o.e.m."), QStringLiteral("system manufacturer")};
    return value.isEmpty() || junk.contains(value.toLower());
}

// The processor's name without the trademarks and clock speed:
// "Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz" is an Intel Core i7-10700.
QString chipName()
{
    const QString info = readFile(QStringLiteral("/proc/cpuinfo"));
    for (const QString &line : info.split(QLatin1Char('\n'))) {
        if (!line.startsWith(QLatin1String("model name")))
            continue;
        QString name = line.section(QLatin1Char(':'), 1).trimmed();
        static const QRegularExpression noise(QStringLiteral("\\((R|TM|tm)\\)|\\s+CPU\\b|\\s*@.*$|\\s+\\d+-Core Processor|\\s+Processor\\b|\\s+with Radeon.*$"));
        name.remove(noise);
        return name.simplified();
    }
    return {};
}

// The memory installed, as it is sold: the kernel keeps some for itself,
// so 15.3 GiB in use is 16 GB.
QString memorySize()
{
    const QString info = readFile(QStringLiteral("/proc/meminfo"));
    static const QRegularExpression total(QStringLiteral("MemTotal:\\s+(\\d+) kB"));
    const auto m = total.match(info);
    if (!m.hasMatch())
        return {};
    const double gib = m.captured(1).toDouble() / (1024.0 * 1024.0);
    static const int sizes[] = {1, 2, 3, 4, 6, 8, 12, 16, 18, 24, 32, 36, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048};
    for (int size : sizes) {
        if (size >= gib)
            return QStringLiteral("%1 GB").arg(size);
    }
    return QStringLiteral("%1 GB").arg(std::ceil(gib));
}

// The graphics processors: each DRM card's PCI ids, named from pci.ids
// ("NVIDIA GeForce RTX 3070", "Intel UHD Graphics 630").
QStringList graphicsNames()
{
    struct Card {
        QString vendor, device;
    };
    QList<Card> cards;
    const QDir drm(QStringLiteral("/sys/class/drm"));
    static const QRegularExpression card(QStringLiteral("^card\\d+$"));
    for (const QString &name : drm.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::System, QDir::Name)) {
        if (!card.match(name).hasMatch())
            continue;
        const QString base = drm.filePath(name) + QStringLiteral("/device/");
        const Card c{readFile(base + QStringLiteral("vendor")).mid(2).toLower(), readFile(base + QStringLiteral("device")).mid(2).toLower()};
        if (c.vendor.size() != 4 || c.device.size() != 4)
            continue; // not on PCI (simpledrm)
        if (std::none_of(cards.begin(), cards.end(), [&](const Card &o) { return o.vendor == c.vendor && o.device == c.device; }))
            cards << c;
    }
    if (cards.isEmpty())
        return {};

    static const QHash<QString, QString> makers = {{QStringLiteral("10de"), QStringLiteral("NVIDIA")},
                                                   {QStringLiteral("8086"), QStringLiteral("Intel")},
                                                   {QStringLiteral("1002"), QStringLiteral("AMD")},
                                                   {QStringLiteral("1022"), QStringLiteral("AMD")}};
    QHash<QString, QString> names; // "vendor:device" → name
    QFile ids(QStringLiteral("/usr/share/hwdata/pci.ids"));
    if (ids.open(QIODevice::ReadOnly)) {
        QTextStream in(&ids);
        QString vendor, maker;
        bool wanted = false;
        while (!in.atEnd()) {
            const QString line = in.readLine();
            if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
                continue;
            if (!line.startsWith(QLatin1Char('\t'))) {
                if (line.startsWith(QLatin1String("C "))) // device classes follow the vendors
                    break;
                vendor = line.left(4);
                wanted = std::any_of(cards.begin(), cards.end(), [&](const Card &c) { return c.vendor == vendor; });
                maker = makers.value(vendor, shortMaker(line.mid(6)));
            } else if (wanted && !line.startsWith(QLatin1String("\t\t"))) {
                const QString device = line.mid(1, 4);
                QString name = line.mid(7);
                // "GA104 [GeForce RTX 3070]": the chip's code name, then what it's sold as.
                static const QRegularExpression sold(QStringLiteral("\\[([^\\]]+)\\]"));
                if (const auto m = sold.match(name); m.hasMatch())
                    name = m.captured(1);
                names.insert(vendor + QLatin1Char(':') + device, maker + QLatin1Char(' ') + name);
            }
        }
    }
    QStringList out;
    for (const Card &c : cards) {
        if (const QString name = names.value(c.vendor + QLatin1Char(':') + c.device); !name.isEmpty())
            out << name;
    }
    return out;
}

// Our own version, from the package that installed the system:
// 0.1.0.r221.7c7bbcd-1 is version 0.1.0, build r221.
QString packageVersion()
{
    const QDir local(QStringLiteral("/var/lib/pacman/local"));
    for (const QString &package : {QStringLiteral("ambrosia-desktop"), QStringLiteral("ambrosia-settings")}) {
        for (const QString &dir : local.entryList({package + QStringLiteral("-*")}, QDir::Dirs)) {
            const QStringList desc = readFile(local.filePath(dir) + QStringLiteral("/desc")).split(QLatin1Char('\n'));
            const qsizetype at = desc.indexOf(QStringLiteral("%NAME%"));
            if (at < 0 || desc.value(at + 1) != package)
                continue;
            const QString version = desc.value(desc.indexOf(QStringLiteral("%VERSION%")) + 1);
            static const QRegularExpression build(QStringLiteral("^(\\d+(?:\\.\\d+)*)\\.r(\\d+)\\."));
            if (const auto m = build.match(version); m.hasMatch())
                return QStringLiteral("%1 (r%2)").arg(m.captured(1), m.captured(2));
            return version.section(QLatin1Char('-'), 0, 0);
        }
    }
    const QString id = osRelease(QStringLiteral("VERSION_ID"));
    return id.isEmpty() ? osRelease(QStringLiteral("BUILD_ID")) : id;
}

// Bytes as System Settings writes them: decimal units, two places.
QString bytesText(qint64 bytes)
{
    const double gb = bytes / 1e9;
    if (gb >= 1000)
        return QStringLiteral("%1 TB").arg(gb / 1000, 0, 'f', 2);
    return QStringLiteral("%1 GB").arg(gb, 0, 'f', 2);
}

}

About::About(QObject *parent)
    : QObject(parent)
{
    QDBusInterface host(hostnamed, hostnamedPath, hostnamed, QDBusConnection::systemBus());
    const QString vendor = host.property("HardwareVendor").toString();
    const QString model = host.property("HardwareModel").toString();
    m_model = placeholder(model) ? QStringLiteral("Computer") : model;
    m_maker = placeholder(vendor) ? QString() : shortMaker(vendor);
    static const QStringList portable = {QStringLiteral("laptop"), QStringLiteral("convertible"), QStringLiteral("tablet")};
    m_laptop = portable.contains(host.property("Chassis").toString());
    readName();
    QDBusConnection::systemBus().connect(hostnamed, hostnamedPath, QStringLiteral("org.freedesktop.DBus.Properties"),
                                         QStringLiteral("PropertiesChanged"), this,
                                         SLOT(hostnameChanged(QString, QVariantMap, QStringList)));

    m_chip = chipName();
    m_memory = memorySize();
    m_graphics = graphicsNames();
    m_systemName = osRelease(QStringLiteral("NAME"));
    if (m_systemName.isEmpty())
        m_systemName = QStringLiteral("Linux");
    m_systemVersion = packageVersion();
    m_volumeName = QStorageInfo::root().name();
    if (m_volumeName.isEmpty())
        m_volumeName = m_systemName;

    connect(qGuiApp, &QGuiApplication::screenAdded, this, &About::displaysChanged);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &About::displaysChanged);
}

void About::readName()
{
    QDBusInterface host(hostnamed, hostnamedPath, hostnamed, QDBusConnection::systemBus());
    QString name = host.property("PrettyHostname").toString();
    if (name.isEmpty())
        name = host.property("Hostname").toString();
    if (name != m_name) {
        m_name = name;
        Q_EMIT computerNameChanged();
    }
}

void About::hostnameChanged(const QString &, const QVariantMap &, const QStringList &)
{
    readName();
}

void About::setComputerName(const QString &name)
{
    const QString wanted = name.trimmed();
    if (wanted.isEmpty() || wanted == m_name) {
        Q_EMIT computerNameChanged(); // puts the field back
        return;
    }
    QDBusMessage call = QDBusMessage::createMethodCall(hostnamed, hostnamedPath, hostnamed, QStringLiteral("SetPrettyHostname"));
    call << wanted << true;
    call.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call, 120000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        if (w->isError())
            qWarning().noquote() << "Settings: the computer keeps its name:" << w->error().message();
        readName();
        Q_EMIT computerNameChanged();
        w->deleteLater();
    });
}

QVariantList About::displays() const
{
    QVariantList out;
    for (QScreen *screen : QGuiApplication::screens()) {
        static const QRegularExpression builtIn(QStringLiteral("^(eDP|LVDS|DSI)"));
        QString name = builtIn.match(screen->name()).hasMatch() ? QStringLiteral("Built-in Display") : screen->model().trimmed();
        if (name.isEmpty())
            name = QStringLiteral("Display");
        const QSize pixels = (QSizeF(screen->size()) * screen->devicePixelRatio()).toSize();
        QString detail = QStringLiteral("%1 × %2").arg(pixels.width()).arg(pixels.height());
        const QSizeF mm = screen->physicalSize();
        if (mm.width() > 0 && mm.height() > 0) {
            const double inches = std::hypot(mm.width(), mm.height()) / 25.4;
            detail = QStringLiteral("%1-inch (%2)").arg(QString::number(std::round(inches * 10) / 10, 'g', 4), detail);
        }
        out << QVariantMap{{QStringLiteral("name"), name}, {QStringLiteral("detail"), detail}};
    }
    return out;
}

QString About::volumeSpace() const
{
    Q_UNUSED(m_spaceTick);
    const QStorageInfo root = QStorageInfo::root();
    return QStringLiteral("%1 available of %2").arg(bytesText(root.bytesAvailable()), bytesText(root.bytesTotal()));
}

void About::readVersion()
{
    m_systemVersion = packageVersion();
    Q_EMIT systemVersionChanged();
}

void About::refresh()
{
    ++m_spaceTick;
    Q_EMIT volumeSpaceChanged();
}
