#include "disks.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusUnixFileDescriptor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QStorageInfo>
#include <QSysInfo>

#include <memory>

namespace {

using Interfaces = QMap<QString, QVariantMap>;
using Objects = QMap<QDBusObjectPath, Interfaces>;

const QString Service = QStringLiteral("org.freedesktop.UDisks2");
const QString Root = QStringLiteral("/org/freedesktop/UDisks2");
const QString Manager = QStringLiteral("/org/freedesktop/UDisks2/Manager");
const QString ManagerI = QStringLiteral("org.freedesktop.UDisks2.Manager");
const QString BlockI = QStringLiteral("org.freedesktop.UDisks2.Block");
const QString DriveI = QStringLiteral("org.freedesktop.UDisks2.Drive");
const QString AtaI = QStringLiteral("org.freedesktop.UDisks2.Drive.Ata");
const QString NvmeI = QStringLiteral("org.freedesktop.UDisks2.NVMe.Controller");
const QString FilesystemI = QStringLiteral("org.freedesktop.UDisks2.Filesystem");
const QString PartitionI = QStringLiteral("org.freedesktop.UDisks2.Partition");
const QString TableI = QStringLiteral("org.freedesktop.UDisks2.PartitionTable");
const QString LoopI = QStringLiteral("org.freedesktop.UDisks2.Loop");
const QString EncryptedI = QStringLiteral("org.freedesktop.UDisks2.Encrypted");
const QString SwapI = QStringLiteral("org.freedesktop.UDisks2.Swapspace");

// The file systems asked about: which can be made and which checked here.
const QStringList Known = {QStringLiteral("ext4"),  QStringLiteral("ext3"), QStringLiteral("ext2"), QStringLiteral("exfat"), QStringLiteral("vfat"),
                           QStringLiteral("btrfs"), QStringLiteral("xfs"),  QStringLiteral("ntfs"), QStringLiteral("f2fs")};
// Those whose files have owners: the one erasing owns the new volume.
const QStringList Owned = {QStringLiteral("ext4"), QStringLiteral("ext3"), QStringLiteral("ext2"), QStringLiteral("btrfs"), QStringLiteral("xfs"), QStringLiteral("f2fs")};

// A path or a name UDisks2 sends as bytes ending in a zero, or as a string.
QString text(const QVariant &value)
{
    if (value.metaType().id() == QMetaType::QByteArray)
        return QString::fromLocal8Bit(value.toByteArray().constData());
    return value.toString();
}

// An object's path; "/" is UDisks2's none.
QString pathOf(const QVariant &value)
{
    const QString path = value.value<QDBusObjectPath>().path();
    return path == QLatin1String("/") ? QString() : path;
}

QString osRelease(const QString &key)
{
    for (const QString &path : {QStringLiteral("/etc/os-release"), QStringLiteral("/usr/lib/os-release")}) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        const QStringList lines = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'));
        for (const QString &line : lines) {
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

// UDisks2's own words, without the error's name in front.
QString detailOf(const QDBusMessage &reply)
{
    QString message = reply.errorMessage();
    if (message.startsWith(QLatin1String("GDBus.Error:"))) {
        const int colon = message.indexOf(QLatin1String(": "));
        if (colon > 0)
            message = message.mid(colon + 2);
    }
    return message.trimmed();
}

QVariantMap none()
{
    return {};
}

}

Q_DECLARE_METATYPE(Interfaces)
Q_DECLARE_METATYPE(Objects)

Disks *Disks::s_instance = nullptr;

Disks::Disks(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
    qDBusRegisterMetaType<Interfaces>();
    qDBusRegisterMetaType<Objects>();

    // Whatever changes (a disk plugged in, a volume mounted, a job under
    // way), the disks are read again a moment later, once.
    m_later.setSingleShot(true);
    m_later.setInterval(200);
    connect(&m_later, &QTimer::timeout, this, &Disks::load);
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.connect(Service, Root, QStringLiteral("org.freedesktop.DBus.ObjectManager"), QStringLiteral("InterfacesAdded"), &m_later, SLOT(start()));
    bus.connect(Service, Root, QStringLiteral("org.freedesktop.DBus.ObjectManager"), QStringLiteral("InterfacesRemoved"), &m_later, SLOT(start()));
    // Every object's properties: no path names them all.
    bus.connect(Service, QString(), QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"), &m_later, SLOT(start()));
    load();
    readTools();
}

Disks *Disks::create(QQmlEngine *, QJSEngine *)
{
    return instance();
}

Disks *Disks::instance()
{
    if (!s_instance)
        new Disks(qApp);
    return s_instance;
}

QString Disks::system() const
{
    const QString name = osRelease(QStringLiteral("NAME"));
    if (name.isEmpty())
        return {};
    QString version = osRelease(QStringLiteral("VERSION_ID"));
    if (version.isEmpty())
        version = osRelease(QStringLiteral("BUILD_ID"));
    const QString kernel = QSysInfo::kernelVersion();
    return name + (version.isEmpty() ? QString() : QLatin1Char(' ') + version) + (kernel.isEmpty() ? QString() : QStringLiteral(" (") + kernel + QLatin1Char(')'));
}

void Disks::refresh()
{
    m_later.start();
}

void Disks::load()
{
    if (m_loading) {
        m_again = true;
        return;
    }
    m_loading = true;
    call({Root, QStringLiteral("org.freedesktop.DBus.ObjectManager"), QStringLiteral("GetManagedObjects"), {}}, [this](const QDBusMessage &reply) {
        m_loading = false;
        parsed(reply);
        if (m_again) {
            m_again = false;
            m_later.start();
        }
    });
}

void Disks::parsed(const QDBusMessage &reply)
{
    QVariantList blocks;
    QVariantList drives;
    const bool answered = reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty();
    if (answered) {
        const Objects objects = qdbus_cast<Objects>(reply.arguments().constFirst());
        for (auto object = objects.constBegin(); object != objects.constEnd(); ++object) {
            const QString path = object.key().path();
            const Interfaces &interfaces = object.value();
            if (interfaces.contains(BlockI)) {
                const QVariantMap block = interfaces.value(BlockI);
                QVariantMap map;
                map[QStringLiteral("path")] = path;
                map[QStringLiteral("device")] = text(block.value(QStringLiteral("Device")));
                map[QStringLiteral("drive")] = pathOf(block.value(QStringLiteral("Drive")));
                map[QStringLiteral("size")] = block.value(QStringLiteral("Size")).toDouble();
                map[QStringLiteral("usage")] = block.value(QStringLiteral("IdUsage")).toString();
                map[QStringLiteral("type")] = block.value(QStringLiteral("IdType")).toString();
                map[QStringLiteral("version")] = block.value(QStringLiteral("IdVersion")).toString();
                map[QStringLiteral("label")] = block.value(QStringLiteral("IdLabel")).toString();
                map[QStringLiteral("uuid")] = block.value(QStringLiteral("IdUUID")).toString();
                map[QStringLiteral("readOnly")] = block.value(QStringLiteral("ReadOnly")).toBool();
                map[QStringLiteral("hintIgnore")] = block.value(QStringLiteral("HintIgnore")).toBool();
                map[QStringLiteral("backing")] = pathOf(block.value(QStringLiteral("CryptoBackingDevice")));

                QStringList mounts;
                const bool filesystem = interfaces.contains(FilesystemI);
                if (filesystem) {
                    const QList<QByteArray> points = qdbus_cast<QList<QByteArray>>(interfaces.value(FilesystemI).value(QStringLiteral("MountPoints")));
                    for (const QByteArray &point : points)
                        mounts << QString::fromLocal8Bit(point.constData());
                }
                map[QStringLiteral("filesystem")] = filesystem;
                map[QStringLiteral("mounts")] = mounts;
                double total = 0, free = 0, available = 0;
                bool mountedReadOnly = false;
                if (!mounts.isEmpty()) {
                    const QStorageInfo storage(mounts.constFirst());
                    if (storage.isValid()) {
                        total = double(storage.bytesTotal());
                        free = double(storage.bytesFree());
                        available = double(storage.bytesAvailable());
                        mountedReadOnly = storage.isReadOnly();
                    }
                }
                map[QStringLiteral("total")] = total;
                map[QStringLiteral("free")] = free;
                map[QStringLiteral("available")] = available;
                map[QStringLiteral("mountedReadOnly")] = mountedReadOnly;

                const bool partitioned = interfaces.contains(TableI);
                map[QStringLiteral("partitioned")] = partitioned;
                map[QStringLiteral("table")] = partitioned ? interfaces.value(TableI).value(QStringLiteral("Type")).toString() : QString();

                const bool partition = interfaces.contains(PartitionI);
                const QVariantMap part = interfaces.value(PartitionI);
                map[QStringLiteral("partition")] = partition;
                map[QStringLiteral("number")] = part.value(QStringLiteral("Number")).toUInt();
                map[QStringLiteral("partName")] = part.value(QStringLiteral("Name")).toString();
                map[QStringLiteral("partType")] = part.value(QStringLiteral("Type")).toString();
                map[QStringLiteral("partTable")] = pathOf(part.value(QStringLiteral("Table")));
                map[QStringLiteral("offset")] = part.value(QStringLiteral("Offset")).toDouble();
                map[QStringLiteral("container")] = part.value(QStringLiteral("IsContainer")).toBool();

                const bool loop = interfaces.contains(LoopI);
                map[QStringLiteral("loop")] = loop;
                map[QStringLiteral("backingFile")] = loop ? text(interfaces.value(LoopI).value(QStringLiteral("BackingFile"))) : QString();

                const bool encrypted = interfaces.contains(EncryptedI);
                map[QStringLiteral("encrypted")] = encrypted;
                map[QStringLiteral("cleartext")] = encrypted ? pathOf(interfaces.value(EncryptedI).value(QStringLiteral("CleartextDevice"))) : QString();
                map[QStringLiteral("swapActive")] = interfaces.value(SwapI).value(QStringLiteral("Active")).toBool();
                // Another device stands on this one (a logical volume, a
                // RAID, an opened encrypted volume): the kernel lists them.
                const QString name = map.value(QStringLiteral("device")).toString().section(QLatin1Char('/'), -1);
                map[QStringLiteral("held")] = !name.isEmpty() && !QDir(QStringLiteral("/sys/class/block/") + name + QStringLiteral("/holders")).isEmpty();
                blocks << map;
            }
            if (interfaces.contains(DriveI)) {
                const QVariantMap drive = interfaces.value(DriveI);
                QVariantMap map;
                map[QStringLiteral("path")] = path;
                map[QStringLiteral("model")] = drive.value(QStringLiteral("Model")).toString().trimmed();
                map[QStringLiteral("vendor")] = drive.value(QStringLiteral("Vendor")).toString().trimmed();
                map[QStringLiteral("serial")] = drive.value(QStringLiteral("Serial")).toString();
                map[QStringLiteral("revision")] = drive.value(QStringLiteral("Revision")).toString();
                map[QStringLiteral("size")] = drive.value(QStringLiteral("Size")).toDouble();
                map[QStringLiteral("bus")] = drive.value(QStringLiteral("ConnectionBus")).toString();
                map[QStringLiteral("removable")] = drive.value(QStringLiteral("Removable")).toBool();
                map[QStringLiteral("mediaRemovable")] = drive.value(QStringLiteral("MediaRemovable")).toBool();
                map[QStringLiteral("ejectable")] = drive.value(QStringLiteral("Ejectable")).toBool();
                map[QStringLiteral("canPowerOff")] = drive.value(QStringLiteral("CanPowerOff")).toBool();
                map[QStringLiteral("optical")] = drive.value(QStringLiteral("Optical")).toBool();
                map[QStringLiteral("rotation")] = drive.value(QStringLiteral("RotationRate")).toInt();
                map[QStringLiteral("mediaAvailable")] = drive.value(QStringLiteral("MediaAvailable")).toBool();
                QString smart = QStringLiteral("unsupported");
                if (interfaces.contains(AtaI)) {
                    const QVariantMap ata = interfaces.value(AtaI);
                    if (ata.value(QStringLiteral("SmartSupported")).toBool() && ata.value(QStringLiteral("SmartEnabled")).toBool())
                        smart = ata.value(QStringLiteral("SmartFailing")).toBool() ? QStringLiteral("failing") : QStringLiteral("verified");
                } else if (interfaces.contains(NvmeI)) {
                    smart = interfaces.value(NvmeI).value(QStringLiteral("SmartCriticalWarning")).toStringList().isEmpty() ? QStringLiteral("verified") : QStringLiteral("failing");
                }
                map[QStringLiteral("smart")] = smart;
                drives << map;
            }
        }
    }
    const bool first = !m_ready;
    m_ready = true;
    if (first || answered != m_available || blocks != m_blocks || drives != m_drives) {
        m_available = answered;
        m_blocks = blocks;
        m_drives = drives;
        Q_EMIT changed();
    }
    mountNew();
}

// Which file systems can be made and checked: UDisks2 knows which tools
// are installed.
void Disks::readTools()
{
    auto left = std::make_shared<int>(2 * Known.size());
    auto formats = std::make_shared<QStringList>();
    auto checkable = std::make_shared<QStringList>();
    auto settle = [this, left, formats, checkable] {
        if (--*left > 0)
            return;
        // In the order asked, whatever order the answers came in.
        QStringList made, checked;
        for (const QString &type : Known) {
            if (formats->contains(type))
                made << type;
            if (checkable->contains(type))
                checked << type;
        }
        m_formats = made;
        m_checkable = checked;
        Q_EMIT toolsChanged();
    };
    for (const QString &type : Known) {
        call({Manager, ManagerI, QStringLiteral("CanFormat"), {type}}, [type, formats, settle](const QDBusMessage &reply) {
            if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
                const QDBusArgument argument = reply.arguments().constFirst().value<QDBusArgument>();
                bool can = false;
                QString tool;
                argument.beginStructure();
                argument >> can >> tool;
                argument.endStructure();
                if (can)
                    formats->append(type);
            }
            settle();
        });
        call({Manager, ManagerI, QStringLiteral("CanCheck"), {type}}, [type, checkable, settle](const QDBusMessage &reply) {
            if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
                const QDBusArgument argument = reply.arguments().constFirst().value<QDBusArgument>();
                bool can = false;
                QString tool;
                argument.beginStructure();
                argument >> can >> tool;
                argument.endStructure();
                if (can)
                    checkable->append(type);
            }
            settle();
        });
    }
}

void Disks::call(const Step &step, std::function<void(const QDBusMessage &)> then)
{
    QDBusMessage message = QDBusMessage::createMethodCall(Service, step.path, step.interface, step.method);
    message.setArguments(step.arguments);
    message.setInteractiveAuthorizationAllowed(true);
    // Erasing a large disk takes as long as it takes.
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 24 * 60 * 60 * 1000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [then](QDBusPendingCallWatcher *finished) {
        finished->deleteLater();
        then(finished->reply());
    });
}

QString Disks::codeOf(const QDBusMessage &reply)
{
    const QString name = reply.errorName();
    if (name.endsWith(QLatin1String("NotAuthorizedDismissed")))
        return QStringLiteral("dismissed");
    if (name.contains(QLatin1String("NotAuthorized")) || name.endsWith(QLatin1String("AccessDenied")))
        return QStringLiteral("denied");
    if (name.endsWith(QLatin1String("DeviceBusy")))
        return QStringLiteral("busy");
    return QStringLiteral("other");
}

// One step after another; the first that fails ends it. A volume that
// turns out not to be mounted, when unmounting it, is no failure.
void Disks::run(QList<Step> steps, Done done)
{
    if (steps.isEmpty()) {
        done(true, {}, {}, QDBusMessage());
        return;
    }
    const Step step = steps.takeFirst();
    call(step, [this, step, steps, done](const QDBusMessage &reply) {
        const bool error = reply.type() == QDBusMessage::ErrorMessage;
        const bool harmless = error && step.method == QLatin1String("Unmount") && reply.errorName().endsWith(QLatin1String("NotMounted"));
        if (error && !harmless) {
            done(false, codeOf(reply), detailOf(reply), reply);
            return;
        }
        if (steps.isEmpty())
            done(true, {}, {}, reply);
        else
            run(steps, done);
    });
}

QList<Disks::Step> Disks::letGo(const QStringList &filesystems, const QStringList &lock)
{
    QList<Step> steps;
    for (const QString &filesystem : filesystems)
        steps << Step{filesystem, FilesystemI, QStringLiteral("Unmount"), {none()}};
    for (const QString &block : lock)
        steps << Step{block, EncryptedI, QStringLiteral("Lock"), {none()}};
    return steps;
}

void Disks::mount(const QStringList &filesystems)
{
    QList<Step> steps;
    for (const QString &filesystem : filesystems)
        steps << Step{filesystem, FilesystemI, QStringLiteral("Mount"), {none()}};
    run(steps, [this](bool ok, const QString &code, const QString &detail, const QDBusMessage &) {
        if (!ok && code != QLatin1String("dismissed"))
            Q_EMIT failed(QStringLiteral("mount"), code, detail);
        m_later.start();
    });
}

void Disks::unmount(const QStringList &filesystems, const QStringList &lock)
{
    run(letGo(filesystems, lock), [this](bool ok, const QString &code, const QString &detail, const QDBusMessage &) {
        if (!ok && code != QLatin1String("dismissed"))
            Q_EMIT failed(QStringLiteral("unmount"), code, detail);
        m_later.start();
    });
}

void Disks::unlock(const QString &block, const QString &passphrase)
{
    call({block, EncryptedI, QStringLiteral("Unlock"), {passphrase, none()}}, [this, block](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ErrorMessage) {
            Q_EMIT unlockDone(block, false, codeOf(reply), detailOf(reply));
            return;
        }
        const QString inside = reply.arguments().isEmpty() ? QString() : reply.arguments().constFirst().value<QDBusObjectPath>().path();
        Q_EMIT unlockDone(block, true, {}, {});
        // What is inside is mounted once UDisks2 has seen it is a file
        // system: asked for now, it may not have its interface yet.
        m_fresh = inside;
        m_freshSince.start();
        m_freshAsked.clear();
        m_later.start();
    });
}

void Disks::eject(const QStringList &filesystems, const QStringList &lock, const QString &disk, const QString &drive, const QString &how)
{
    QList<Step> steps = letGo(filesystems, lock);
    if (how == QLatin1String("loop") && !disk.isEmpty())
        steps << Step{disk, LoopI, QStringLiteral("Delete"), {none()}};
    else if (how == QLatin1String("off") && !drive.isEmpty())
        steps << Step{drive, DriveI, QStringLiteral("PowerOff"), {none()}};
    else if (how == QLatin1String("eject") && !drive.isEmpty())
        steps << Step{drive, DriveI, QStringLiteral("Eject"), {none()}};
    run(steps, [this](bool ok, const QString &code, const QString &detail, const QDBusMessage &) {
        if (!ok && code != QLatin1String("dismissed"))
            Q_EMIT failed(QStringLiteral("eject"), code, detail);
        m_later.start();
    });
}

void Disks::firstAid(const QString &filesystem, bool mounted)
{
    // Whatever came of it, a volume that was mounted is mounted again
    // before the last word.
    auto finish = [this, filesystem, mounted](bool ok, const QString &code, const QString &detail) {
        auto last = [this, ok, code, detail] {
            Q_EMIT firstAidLine(ok ? QStringLiteral("Operation successful.") : QStringLiteral("Operation failed."));
            Q_EMIT firstAidDone(ok, code, detail);
            m_later.start();
        };
        if (!mounted) {
            last();
            return;
        }
        Q_EMIT firstAidLine(QStringLiteral("Restoring the original state found as mounted."));
        call({filesystem, FilesystemI, QStringLiteral("Mount"), {none()}}, [last](const QDBusMessage &) { last(); });
    };
    auto check = [this, filesystem, finish] {
        Q_EMIT firstAidLine(QStringLiteral("Verifying file system."));
        call({filesystem, FilesystemI, QStringLiteral("Check"), {none()}}, [this, filesystem, finish](const QDBusMessage &reply) {
            if (reply.type() == QDBusMessage::ErrorMessage) {
                Q_EMIT firstAidLine(QStringLiteral("The file system could not be verified."));
                finish(false, codeOf(reply), detailOf(reply));
                return;
            }
            if (!reply.arguments().isEmpty() && reply.arguments().constFirst().toBool()) {
                Q_EMIT firstAidLine(QStringLiteral("The volume appears to be OK."));
                finish(true, {}, {});
                return;
            }
            Q_EMIT firstAidLine(QStringLiteral("The volume was found corrupt and needs to be repaired."));
            Q_EMIT firstAidLine(QStringLiteral("Repairing file system."));
            call({filesystem, FilesystemI, QStringLiteral("Repair"), {none()}}, [this, finish](const QDBusMessage &repaired) {
                if (repaired.type() == QDBusMessage::ErrorMessage) {
                    Q_EMIT firstAidLine(QStringLiteral("The volume could not be repaired."));
                    finish(false, codeOf(repaired), detailOf(repaired));
                    return;
                }
                const bool fixed = !repaired.arguments().isEmpty() && repaired.arguments().constFirst().toBool();
                Q_EMIT firstAidLine(fixed ? QStringLiteral("The volume was repaired successfully.") : QStringLiteral("The volume could not be repaired."));
                finish(fixed, fixed ? QString() : QStringLiteral("other"), {});
            });
        });
    };
    if (!mounted) {
        check();
        return;
    }
    call({filesystem, FilesystemI, QStringLiteral("Unmount"), {none()}}, [this, check](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ErrorMessage && !reply.errorName().endsWith(QLatin1String("NotMounted"))) {
            Q_EMIT firstAidLine(QStringLiteral("Volume could not be unmounted."));
            Q_EMIT firstAidLine(QStringLiteral("Operation failed."));
            Q_EMIT firstAidDone(false, codeOf(reply), detailOf(reply));
            m_later.start();
            return;
        }
        Q_EMIT firstAidLine(QStringLiteral("Volume was successfully unmounted."));
        check();
    });
}

void Disks::erase(const QString &block, const QStringList &filesystems, const QStringList &lock, const QString &format, const QString &name, const QString &scheme)
{
    QVariantMap made;
    if (!name.isEmpty())
        made[QStringLiteral("label")] = name;
    if (Owned.contains(format))
        made[QStringLiteral("take-ownership")] = true;

    // The new volume is mounted, as a Mac leaves one; that failing is no
    // failure of the erase.
    auto mountIt = [this](const QString &volume) {
        call({volume, FilesystemI, QStringLiteral("Mount"), {none()}}, [this](const QDBusMessage &) {
            Q_EMIT eraseDone(true, {}, {});
            m_later.start();
        });
    };
    auto fail = [this](const QString &code, const QString &detail) {
        Q_EMIT eraseDone(false, code, detail);
        m_later.start();
    };

    QList<Step> steps = letGo(filesystems, lock);
    if (scheme.isEmpty()) {
        QVariantMap options = made;
        options[QStringLiteral("update-partition-type")] = true;
        steps << Step{block, BlockI, QStringLiteral("Format"), {format, options}};
        run(steps, [block, mountIt, fail](bool ok, const QString &code, const QString &detail, const QDBusMessage &) {
            if (ok)
                mountIt(block);
            else
                fail(code, detail);
        });
        return;
    }
    // A new partition map, then one partition over all of it. The map's
    // interface can be a moment behind the format's answer: asked again a
    // few times before giving up.
    steps << Step{block, BlockI, QStringLiteral("Format"), {scheme, none()}};
    run(steps, [this, block, scheme, format, name, made, mountIt, fail](bool ok, const QString &code, const QString &detail, const QDBusMessage &) {
        if (!ok) {
            fail(code, detail);
            return;
        }
        auto tries = std::make_shared<int>(0);
        auto create = std::make_shared<std::function<void()>>();
        *create = [this, block, scheme, format, name, made, mountIt, fail, tries, create] {
            const QVariantList arguments = {QVariant::fromValue<qulonglong>(0), QVariant::fromValue<qulonglong>(0), QString(),
                                            scheme == QLatin1String("gpt") ? name : QString(), none(), format, made};
            call({block, TableI, QStringLiteral("CreatePartitionAndFormat"), arguments}, [this, mountIt, fail, tries, create](const QDBusMessage &reply) {
                if (reply.type() == QDBusMessage::ErrorMessage) {
                    const bool early = reply.errorName().startsWith(QLatin1String("org.freedesktop.DBus.Error.Unknown"));
                    if (early && ++*tries < 8) {
                        QTimer::singleShot(400, this, [create] { (*create)(); });
                        return;
                    }
                    fail(codeOf(reply), detailOf(reply));
                    *create = nullptr;
                    return;
                }
                const QString volume = reply.arguments().isEmpty() ? QString() : reply.arguments().constFirst().value<QDBusObjectPath>().path();
                *create = nullptr;
                if (volume.isEmpty()) {
                    Q_EMIT eraseDone(true, {}, {});
                    m_later.start();
                } else {
                    mountIt(volume);
                }
            });
        };
        (*create)();
    });
}

void Disks::attach(const QUrl &file)
{
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    const QString real = QFileInfo(path).canonicalFilePath();
    // Open already: its volumes are mounted if they aren't.
    for (const QVariant &entry : std::as_const(m_blocks)) {
        const QVariantMap block = entry.toMap();
        if (block.value(QStringLiteral("loop")).toBool() && !real.isEmpty() && block.value(QStringLiteral("backingFile")).toString() == real) {
            m_fresh = block.value(QStringLiteral("path")).toString();
            m_freshSince.start();
            m_freshAsked.clear();
            Q_EMIT attached(m_fresh);
            mountNew();
            return;
        }
    }
    QFile image(path);
    // An ISO is never written to; nor is a file that can't be.
    bool readOnly = path.endsWith(QLatin1String(".iso"), Qt::CaseInsensitive);
    if (readOnly || !image.open(QIODevice::ReadWrite)) {
        readOnly = true;
        if (!image.open(QIODevice::ReadOnly)) {
            Q_EMIT failed(QStringLiteral("attach"), QStringLiteral("other"), image.errorString());
            return;
        }
    }
    QVariantMap options;
    options[QStringLiteral("read-only")] = readOnly;
    const QDBusUnixFileDescriptor descriptor(image.handle());
    call({Manager, ManagerI, QStringLiteral("LoopSetup"), {QVariant::fromValue(descriptor), options}}, [this](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ErrorMessage) {
            if (codeOf(reply) != QLatin1String("dismissed"))
                Q_EMIT failed(QStringLiteral("attach"), codeOf(reply), detailOf(reply));
            return;
        }
        m_fresh = reply.arguments().isEmpty() ? QString() : reply.arguments().constFirst().value<QDBusObjectPath>().path();
        m_freshSince.start();
        m_freshAsked.clear();
        Q_EMIT attached(m_fresh);
        m_later.start();
    });
}

// The volumes of what was just opened (a disk image, an encrypted
// volume's inside) are mounted as UDisks2 comes to know them.
void Disks::mountNew()
{
    if (m_fresh.isEmpty())
        return;
    if (m_freshSince.elapsed() > 6000) {
        m_fresh.clear();
        return;
    }
    for (const QVariant &entry : std::as_const(m_blocks)) {
        const QVariantMap block = entry.toMap();
        const QString path = block.value(QStringLiteral("path")).toString();
        if (path != m_fresh && block.value(QStringLiteral("partTable")).toString() != m_fresh)
            continue;
        if (!block.value(QStringLiteral("filesystem")).toBool() || block.value(QStringLiteral("hintIgnore")).toBool()
            || !block.value(QStringLiteral("mounts")).toStringList().isEmpty() || m_freshAsked.contains(path))
            continue;
        m_freshAsked.insert(path);
        call({path, FilesystemI, QStringLiteral("Mount"), {none()}}, [this](const QDBusMessage &) { m_later.start(); });
    }
    // Its partitions may be a moment behind it: looked for again.
    QTimer::singleShot(700, &m_later, qOverload<>(&QTimer::start));
}
