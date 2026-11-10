#include "places.h"
#include "tags.h"

#include <Solid/DeviceNotifier>
#include <Solid/OpticalDrive>
#include <Solid/StorageAccess>
#include <Solid/StorageDrive>
#include <Solid/StorageVolume>

#include <QDir>
#include <QMessageBox>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTimer>

#include <algorithm>

namespace {

QVariantMap item(const QString &name, const QUrl &url, const QString &glyph)
{
    return {{QStringLiteral("name"), name}, {QStringLiteral("url"), url}, {QStringLiteral("glyph"), glyph}};
}

QVariantMap section(const QString &title, const QVariantList &items)
{
    return {{QStringLiteral("title"), title}, {QStringLiteral("items"), items}};
}

QUrl standard(QStandardPaths::StandardLocation location)
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(location));
}

// Whether a volume mounted here is the system's own: the disk it starts
// from (the computer's row is that one), the one the home is on, and what
// is mounted in the system's folders. Other disks are mounted under
// /run/media, /mnt or a folder of someone's own choosing.
bool systemMount(const QString &path)
{
    const QString home = QDir::homePath();
    if (path == QLatin1String("/") || home == path || home.startsWith(path + QLatin1Char('/')))
        return true;
    if (path.startsWith(QLatin1String("/run/media/")))
        return false;
    static const QStringList folders{
        QStringLiteral("boot"), QStringLiteral("efi"),  QStringLiteral("usr"), QStringLiteral("var"), QStringLiteral("etc"),
        QStringLiteral("opt"),  QStringLiteral("srv"),  QStringLiteral("tmp"), QStringLiteral("nix"), QStringLiteral("run"),
        QStringLiteral("proc"), QStringLiteral("sys"),  QStringLiteral("dev"), QStringLiteral("root"),
    };
    const QString top = path.section(QLatin1Char('/'), 1, 1);
    return top.startsWith(QLatin1Char('.')) || folders.contains(top);
}

QString nameOf(const Solid::Device &device)
{
    const auto *volume = device.as<Solid::StorageVolume>();
    return volume && !volume->label().isEmpty() ? volume->label() : device.description();
}

// Where a volume is mounted, or "" while it isn't.
QString mountOf(const Solid::Device &device)
{
    const auto *access = device.as<Solid::StorageAccess>();
    return access && access->isAccessible() ? access->filePath() : QString();
}

void alert(const QString &text, const QString &detail)
{
    auto *box = new QMessageBox(QMessageBox::Warning, QStringLiteral("Files"), text, QMessageBox::Ok);
    box->setInformativeText(detail);
    box->setAttribute(Qt::WA_DeleteOnClose);
    box->open();
}

}

Places::Places(QObject *parent)
    : QObject(parent)
{
    connect(Tags::instance(), &Tags::listChanged, this, &Places::sectionsChanged);
    // The disks come a moment after the window: asking Solid for them is a
    // round trip to UDisks, which a first frame shouldn't wait for.
    QTimer::singleShot(0, this, &Places::listVolumes);
}

QString Places::computer() const
{
    return QSysInfo::machineHostName();
}

QUrl Places::place(const QString &name) const
{
    if (name == QLatin1String("recents"))
        return QUrl(QStringLiteral("recentlyused:/files"));
    if (name == QLatin1String("desktop"))
        return standard(QStandardPaths::DesktopLocation);
    if (name == QLatin1String("documents"))
        return standard(QStandardPaths::DocumentsLocation);
    if (name == QLatin1String("downloads"))
        return standard(QStandardPaths::DownloadLocation);
    if (name == QLatin1String("home"))
        return QUrl::fromLocalFile(QDir::homePath());
    if (name == QLatin1String("computer"))
        return QUrl::fromLocalFile(QStringLiteral("/"));
    if (name == QLatin1String("trash"))
        return QUrl(QStringLiteral("trash:/"));
    return {};
}

QVariantList Places::sections() const
{
    QVariantList favorites;
    favorites << item(QStringLiteral("Desktop"), place(QStringLiteral("desktop")), QStringLiteral("desktop"))
              << item(QStringLiteral("Documents"), place(QStringLiteral("documents")), QStringLiteral("documents"))
              << item(QStringLiteral("Downloads"), place(QStringLiteral("downloads")), QStringLiteral("downloads"));
    QVariantList locations;
    locations << item(QDir(QDir::homePath()).dirName(), place(QStringLiteral("home")), QStringLiteral("home"))
              << item(computer(), place(QStringLiteral("computer")), QStringLiteral("drive"));
    for (const Volume &v : m_volumes) {
        const QString mount = mountOf(v.device);
        if (!v.device.isValid() || (!mount.isEmpty() && systemMount(mount)))
            continue; // gone (the list is about to be read again), or the system's
        QVariantMap drive{
            {QStringLiteral("name"), nameOf(v.device)},
            {QStringLiteral("glyph"), v.removable ? QStringLiteral("external") : QStringLiteral("drive")},
            {QStringLiteral("volume"), v.device.udi()},
            {QStringLiteral("ejectable"), !mount.isEmpty()},
            {QStringLiteral("busy"), v.busy},
        };
        if (!mount.isEmpty())
            drive.insert(QStringLiteral("url"), QUrl::fromLocalFile(mount));
        locations << drive;
    }
    locations << item(QStringLiteral("Trash"), place(QStringLiteral("trash")), QStringLiteral("trash"));
    // A tag lists what has it: a search for it.
    QVariantList tags;
    for (const QVariant &tag : Tags::instance()->all()) {
        QVariantMap map = tag.toMap();
        QUrl url(QStringLiteral("search:"));
        url.setQuery(QStringLiteral("tag=") + QString::fromLatin1(QUrl::toPercentEncoding(map.value(QStringLiteral("name")).toString())));
        map.insert(QStringLiteral("url"), url);
        tags << map;
    }
    return {
        section(QString(), {item(QStringLiteral("Recents"), place(QStringLiteral("recents")), QStringLiteral("recents"))}),
        section(QStringLiteral("Favorites"), favorites),
        section(QStringLiteral("Locations"), locations),
        section(QStringLiteral("Tags"), tags),
    };
}

void Places::listVolumes()
{
    if (!m_watching) {
        m_watching = true;
        // Plugging a drive in adds several devices in a row (the drive, the
        // disk, each volume): one reread once they are all there.
        auto *later = new QTimer(this);
        later->setSingleShot(true);
        later->setInterval(150);
        connect(later, &QTimer::timeout, this, &Places::listVolumes);
        auto *notifier = Solid::DeviceNotifier::instance();
        connect(notifier, &Solid::DeviceNotifier::deviceAdded, later, qOverload<>(&QTimer::start));
        connect(notifier, &Solid::DeviceNotifier::deviceRemoved, later, qOverload<>(&QTimer::start));
    }
    QList<Volume> volumes;
    for (const Solid::Device &device : Solid::Device::listFromType(Solid::DeviceInterface::StorageAccess)) {
        const auto *volume = device.as<Solid::StorageVolume>();
        const auto *access = device.as<Solid::StorageAccess>();
        if (!volume || !access || volume->isIgnored() || volume->usage() != Solid::StorageVolume::FileSystem)
            continue;
        Volume v{device};
        if (const Volume *before = find(device.udi()))
            v.busy = before->busy;
        // Once each: Solid makes a device's interfaces anew when it changes
        // (a card taken out of its reader), and keeps them otherwise.
        connect(access, &Solid::StorageAccess::accessibilityChanged, this, &Places::sectionsChanged, Qt::UniqueConnection);
        connect(access, &Solid::StorageAccess::setupDone, this, &Places::setupDone, Qt::UniqueConnection);
        connect(access, &Solid::StorageAccess::teardownDone, this, &Places::teardownDone, Qt::UniqueConnection);
        for (Solid::Device up = device; up.isValid(); up = up.parent()) {
            if (const auto *drive = up.as<Solid::StorageDrive>()) {
                v.removable = drive->isRemovable() || drive->isHotpluggable();
                break;
            }
        }
        volumes << v;
    }
    std::stable_sort(volumes.begin(), volumes.end(), [](const Volume &a, const Volume &b) {
        return nameOf(a.device).compare(nameOf(b.device), Qt::CaseInsensitive) < 0;
    });
    m_volumes = volumes;
    Q_EMIT sectionsChanged();
}

Places::Volume *Places::find(const QString &udi)
{
    for (Volume &v : m_volumes)
        if (v.device.udi() == udi)
            return &v;
    return nullptr;
}

void Places::open(const QString &udi)
{
    Volume *v = find(udi);
    if (!v || v->busy)
        return;
    const QString mount = mountOf(v->device);
    if (!mount.isEmpty()) {
        Q_EMIT opened(udi, QUrl::fromLocalFile(mount));
        return;
    }
    auto *access = v->device.as<Solid::StorageAccess>();
    if (!access || !access->setup())
        return;
    v->busy = true;
    Q_EMIT sectionsChanged();
}

void Places::setupDone(Solid::ErrorType error, const QVariant &data, const QString &udi)
{
    Volume *v = find(udi);
    if (!v)
        return;
    // Any app can mount it: only the one asked for here opens.
    const bool asked = v->busy;
    v->busy = false;
    Q_EMIT sectionsChanged();
    if (!asked)
        return;
    const QString mount = mountOf(v->device);
    if (error == Solid::NoError && !mount.isEmpty())
        Q_EMIT opened(udi, QUrl::fromLocalFile(mount));
    else if (error != Solid::NoError && error != Solid::UserCanceled)
        alert(QStringLiteral("The disk “%1” couldn’t be opened.").arg(nameOf(v->device)), data.toString());
}

void Places::eject(const QString &udi)
{
    Volume *v = find(udi);
    if (!v || v->busy)
        return;
    const QString mount = mountOf(v->device);
    auto *access = v->device.as<Solid::StorageAccess>();
    if (mount.isEmpty() || !access)
        return;
    Q_EMIT ejecting(QUrl::fromLocalFile(mount));
    if (!access->teardown())
        return;
    v->busy = true;
    Q_EMIT sectionsChanged();
}

void Places::teardownDone(Solid::ErrorType error, const QVariant &data, const QString &udi)
{
    Volume *v = find(udi);
    if (!v)
        return;
    const bool asked = v->busy;
    v->busy = false;
    Q_EMIT sectionsChanged();
    if (!asked)
        return;
    if (error == Solid::DeviceBusy) {
        alert(QStringLiteral("The disk “%1” wasn’t ejected because one or more programs may be using it.").arg(nameOf(v->device)), QString());
    } else if (error != Solid::NoError && error != Solid::UserCanceled) {
        alert(QStringLiteral("The disk “%1” couldn’t be ejected.").arg(nameOf(v->device)), data.toString());
    } else if (error == Solid::NoError) {
        // Solid ejects a card and powers a drive down itself; a disc's tray
        // is left to whoever asked.
        for (Solid::Device up = v->device; up.isValid(); up = up.parent()) {
            if (auto *disc = up.as<Solid::OpticalDrive>()) {
                disc->eject();
                break;
            }
        }
    }
}

QVariantMap Places::volumeOf(const QUrl &url) const
{
    if (!url.isLocalFile())
        return {};
    const QString path = url.toLocalFile();
    QVariantMap found;
    qsizetype longest = 0;
    for (const Volume &v : m_volumes) {
        const QString mount = mountOf(v.device);
        if (mount.size() <= longest || systemMount(mount) || !(path == mount || path.startsWith(mount + QLatin1Char('/'))))
            continue;
        longest = mount.size();
        found = item(nameOf(v.device), QUrl::fromLocalFile(mount), v.removable ? QStringLiteral("external") : QStringLiteral("drive"));
    }
    return found;
}
