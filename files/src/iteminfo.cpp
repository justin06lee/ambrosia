#include "iteminfo.h"
#include "format.h"
#include "tags.h"
#include "thumbnailer.h"

#include <KApplicationTrader>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QLocale>
#include <QMimeDatabase>
#include <QStandardPaths>
#include <QSysInfo>
#include <QThreadPool>

#include <cerrno>
#include <cstring>
#include <string>
#include <vector>

#include <dirent.h>
#include <fcntl.h>
#include <grp.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/xattr.h>
#include <unistd.h>

namespace {

const char commentKey[] = "user.xdg.comment";

// Where a URL's item is on this computer: its own path, or for the home
// Trash (trash:/0-name/...), the file KIO keeps it in.
QString localPath(const QUrl &url)
{
    if (url.isLocalFile())
        return url.toLocalFile();
    if (url.scheme() == QLatin1String("trash") && url.path().startsWith(QLatin1String("/0-")))
        return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QLatin1String("/Trash/files/") + url.path().mid(3);
    return {};
}

// Opens a file to read without marking it read: what a preview reads
// mustn't change when it was last opened (O_NOATIME, for one's own files).
bool openQuietly(QFile &file, const QByteArray &native)
{
    int fd = ::open(native.constData(), O_RDONLY | O_CLOEXEC | O_NOATIME);
    if (fd < 0 && errno == EPERM)
        fd = ::open(native.constData(), O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return false;
    if (!file.open(fd, QIODevice::ReadOnly, QFileDevice::AutoCloseHandle)) {
        ::close(fd);
        return false;
    }
    return true;
}

QString privilege(bool read, bool write)
{
    if (read && write)
        return QStringLiteral("Read & Write");
    if (read)
        return QStringLiteral("Read only");
    if (write)
        return QStringLiteral("Write only (Drop Box)");
    return QStringLiteral("No Access");
}

QString items(qint64 count)
{
    return count == 1 ? QStringLiteral("1 item") : QStringLiteral("%1 items").arg(QLocale().toString(count));
}

}

// A folder's count, made on a worker thread and read by the timer.
struct ItemInfo::Count {
    std::atomic<qint64> bytes{0}, disk{0}, items{0};
    std::atomic<bool> cancel{false}, done{false};
};

ItemInfo::ItemInfo(QObject *parent)
    : QObject(parent)
{
    m_settle.setSingleShot(true);
    m_settle.setInterval(100);
    connect(&m_settle, &QTimer::timeout, this, &ItemInfo::follow);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_settle, qOverload<>(&QTimer::start));
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, &m_settle, qOverload<>(&QTimer::start));
    connect(Tags::instance(), &Tags::changed, this, [this](const QList<QUrl> &urls) {
        if (urls.contains(m_url)) {
            m_tags = Tags::read(localPath(m_url));
            Q_EMIT changed();
        }
    });
    m_progress.setInterval(150);
    connect(&m_progress, &QTimer::timeout, this, [this] {
        if (!m_count)
            return;
        m_bytes = m_count->bytes;
        m_disk = m_count->disk;
        m_items = m_count->items;
        if (m_count->done)
            m_progress.stop();
        Q_EMIT sizeChanged();
    });
}

ItemInfo::~ItemInfo()
{
    stopCounting();
}

void ItemInfo::setUrl(const QUrl &url)
{
    if (url == m_url)
        return;
    m_url = url;
    read(true);
    watch();
    Q_EMIT urlChanged();
}

void ItemInfo::refresh()
{
    read(true);
}

void ItemInfo::read(bool recount)
{
    if (recount) {
        stopCounting();
        m_bytes = m_disk = m_items = -1;
    }
    m_exists = false;
    m_isDir = false;
    m_dev = m_ino = 0;
    m_where.clear();
    m_created = m_modified = m_modifiedSeconds = m_opened = QStringLiteral("--");
    m_appName.clear();
    m_appIcon.clear();
    m_comment.clear();
    m_tags.clear();
    m_access.clear();
    m_permissions.clear();
    m_preview = QStringLiteral("generic");
    m_text.clear();
    m_pictureSize = QSize();

    const QString path = localPath(m_url);
    m_fileUrl = path.isEmpty() ? QUrl() : QUrl::fromLocalFile(path);
    const QByteArray native = QFile::encodeName(path);
    m_name = m_url.path() == QLatin1String("/") && m_url.isLocalFile() ? QSysInfo::machineHostName() : m_url.fileName();
    struct statx sx;
    if (path.isEmpty() || statx(AT_FDCWD, native.constData(), 0, STATX_BASIC_STATS | STATX_BTIME, &sx) != 0) {
        m_kind = Format::kind(m_name, false);
        m_badge = Format::badge(m_name, false);
        Q_EMIT changed();
        Q_EMIT sizeChanged();
        return;
    }
    m_exists = true;
    m_dev = makedev(sx.stx_dev_major, sx.stx_dev_minor);
    m_ino = sx.stx_ino;
    m_mtime = sx.stx_mtime.tv_sec * 1000000000LL + sx.stx_mtime.tv_nsec;
    m_isDir = S_ISDIR(sx.stx_mode);
    m_kind = Format::kind(m_name, m_isDir);
    m_badge = Format::badge(m_name, m_isDir);
    if (sx.stx_mask & STATX_BTIME)
        m_created = Format::longDate(sx.stx_btime.tv_sec);
    m_modified = Format::longDate(sx.stx_mtime.tv_sec);
    m_modifiedSeconds = Format::secondsDate(sx.stx_mtime.tv_sec);
    m_opened = Format::longDate(sx.stx_atime.tv_sec);

    // From the computer down to the folder it is in: the path bar's names.
    if (m_url.scheme() == QLatin1String("trash")) {
        m_where = QStringLiteral("Trash");
    } else if (path != QLatin1String("/")) {
        QStringList parts{QSysInfo::machineHostName()};
        parts += QFileInfo(path).absolutePath().split(QLatin1Char('/'), Qt::SkipEmptyParts);
        m_where = parts.join(QStringLiteral(" ▸ "));
    }

    if (m_isDir) {
        if (recount)
            countFolder();
    } else {
        m_bytes = qint64(sx.stx_size);
        m_disk = qint64(sx.stx_blocks) * 512;
        QFile file;
        const bool readable = openQuietly(file, native);
        static const QMimeDatabase mimes;
        const QMimeType mime = readable ? mimes.mimeTypeForFileNameAndData(path, &file)
                                        : mimes.mimeTypeForFile(path, QMimeDatabase::MatchExtension);
        static const QList<QByteArray> pictures = QImageReader::supportedMimeTypes();
        if (readable && pictures.contains(mime.name().toLatin1())) {
            file.seek(0);
            QImageReader reader(&file);
            reader.setAutoTransform(true);
            m_pictureSize = reader.size();
            if (reader.transformation() & QImageIOHandler::TransformationRotate90)
                m_pictureSize.transpose();
            if (m_pictureSize.isValid())
                m_preview = QStringLiteral("image");
        } else if (readable && mime.inherits(QStringLiteral("text/plain"))) {
            m_preview = QStringLiteral("text");
            file.seek(0);
            m_text = QString::fromUtf8(file.read(128 * 1024));
        }
        if (const KService::Ptr app = KApplicationTrader::preferredService(mime.name())) {
            m_appName = app->name();
            m_appIcon = app->icon();
        }
    }

    char value[4096];
    const ssize_t got = getxattr(native.constData(), commentKey, value, sizeof value);
    if (got > 0)
        m_comment = QString::fromUtf8(value, got);
    m_tags = Tags::read(path);

    const passwd *owner = getpwuid(sx.stx_uid);
    const group *grp = getgrgid(sx.stx_gid);
    const uint mode = sx.stx_mode;
    QString ownerName = owner ? QString::fromLocal8Bit(owner->pw_name) : QString::number(sx.stx_uid);
    if (sx.stx_uid == getuid())
        ownerName += QStringLiteral(" (Me)");
    m_permissions = {
        QVariantMap{{QStringLiteral("name"), ownerName}, {QStringLiteral("privilege"), privilege(mode & S_IRUSR, mode & S_IWUSR)}},
        QVariantMap{{QStringLiteral("name"), grp ? QString::fromLocal8Bit(grp->gr_name) : QString::number(sx.stx_gid)},
                    {QStringLiteral("privilege"), privilege(mode & S_IRGRP, mode & S_IWGRP)}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("everyone")}, {QStringLiteral("privilege"), privilege(mode & S_IROTH, mode & S_IWOTH)}},
    };
    const bool canRead = ::access(native.constData(), R_OK) == 0;
    const bool canWrite = ::access(native.constData(), W_OK) == 0;
    m_access = canRead && canWrite ? QStringLiteral("You can read and write")
        : canRead                  ? QStringLiteral("You can only read")
        : canWrite                 ? QStringLiteral("You can only write")
                                   : QStringLiteral("You have no access");
    Q_EMIT changed();
    Q_EMIT sizeChanged();
}

void ItemInfo::watch()
{
    if (const QStringList old = m_watcher.files() + m_watcher.directories(); !old.isEmpty())
        m_watcher.removePaths(old);
    const QString path = localPath(m_url);
    if (path.isEmpty() || !m_exists)
        return;
    QStringList paths{path};
    if (path != QLatin1String("/"))
        paths << QFileInfo(path).absolutePath();
    m_watcher.addPaths(paths);
}

// Something changed where the item is: read it again, or find it under its
// new name in the same folder (a rename, an undo); if it has gone, say so.
void ItemInfo::follow()
{
    const QString path = localPath(m_url);
    if (path.isEmpty())
        return;
    struct stat st;
    if (stat(QFile::encodeName(path).constData(), &st) == 0 && st.st_dev == m_dev && st.st_ino == m_ino) {
        // A folder is counted again only when its own items changed, not
        // when the folder around it did.
        const qint64 mtime = st.st_mtim.tv_sec * 1000000000LL + st.st_mtim.tv_nsec;
        read(!m_isDir || mtime != m_mtime);
        watch();
        return;
    }
    const QString dir = QFileInfo(path).absolutePath();
    if (DIR *d = opendir(QFile::encodeName(dir).constData())) {
        const int fd = dirfd(d);
        while (const dirent *e = readdir(d)) {
            if (e->d_ino != m_ino)
                continue;
            if (fstatat(fd, e->d_name, &st, 0) == 0 && st.st_dev == m_dev && st.st_ino == m_ino) {
                const QString name = QFile::decodeName(e->d_name);
                closedir(d);
                QUrl next = m_url.adjusted(QUrl::RemoveFilename);
                next.setPath(next.path() + name);
                setUrl(next);
                return;
            }
        }
        closedir(d);
    }
    if (m_exists) {
        m_exists = false;
        Q_EMIT changed();
    }
}

void ItemInfo::countFolder()
{
    const QByteArray root = QFile::encodeName(localPath(m_url));
    const dev_t dev = dev_t(m_dev);
    auto count = std::make_shared<Count>();
    m_count = count;
    QThreadPool::globalInstance()->start([count, root, dev] {
        std::vector<std::string> folders{root.toStdString()};
        while (!folders.empty() && !count->cancel) {
            const std::string folder = std::move(folders.back());
            folders.pop_back();
            // Counting isn't opening: the folders keep their access times.
            int fd = ::open(folder.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOATIME);
            if (fd < 0 && errno == EPERM)
                fd = ::open(folder.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
            if (fd < 0)
                continue;
            DIR *d = fdopendir(fd);
            if (!d) {
                ::close(fd);
                continue;
            }
            while (const dirent *e = readdir(d)) {
                if (count->cancel)
                    break;
                if (e->d_name[0] == '.' && (e->d_name[1] == 0 || (e->d_name[1] == '.' && e->d_name[2] == 0)))
                    continue;
                struct stat st;
                if (fstatat(fd, e->d_name, &st, AT_SYMLINK_NOFOLLOW) != 0)
                    continue;
                count->items += 1;
                count->disk += qint64(st.st_blocks) * 512;
                if (S_ISDIR(st.st_mode)) {
                    if (st.st_dev == dev) // other disks mounted inside aren't counted
                        folders.push_back(folder + '/' + e->d_name);
                } else {
                    count->bytes += st.st_size;
                }
            }
            closedir(d);
        }
        count->done = true;
    });
    m_progress.start();
}

void ItemInfo::stopCounting()
{
    if (m_count)
        m_count->cancel = true;
    m_count.reset();
    m_progress.stop();
}

QString ItemInfo::size() const
{
    return m_bytes < 0 ? QStringLiteral("--") : Format::size(m_bytes);
}

QString ItemInfo::sizeDetail() const
{
    if (m_bytes < 0)
        return QStringLiteral("--");
    QString text = Format::bytes(m_bytes);
    if (m_disk >= 0)
        text += QStringLiteral(" (%1 on disk)").arg(Format::size(m_disk));
    if (m_isDir)
        text += QStringLiteral(" for ") + items(m_items);
    return text;
}

QString ItemInfo::sizeSummary() const
{
    if (m_bytes < 0)
        return QString();
    return m_isDir ? Format::size(m_bytes) + QStringLiteral(", ") + items(m_items) : Format::size(m_bytes);
}

void ItemInfo::setComment(const QString &comment)
{
    if (comment == m_comment || !m_exists)
        return;
    const QByteArray native = QFile::encodeName(localPath(m_url));
    const QByteArray value = comment.toUtf8();
    const int result = value.isEmpty() ? removexattr(native.constData(), commentKey)
                                       : setxattr(native.constData(), commentKey, value.constData(), value.size(), 0);
    if (result != 0 && !(value.isEmpty() && errno == ENODATA)) {
        qWarning("Files: couldn't keep the comment on %s: %s", native.constData(), strerror(errno));
        return;
    }
    m_comment = comment;
    Q_EMIT changed();
}

QString ItemInfo::thumb() const
{
    return m_fileUrl.isEmpty() ? QString() : Thumbnailer::source(m_fileUrl, m_name, m_isDir, m_mtime / 1000000000);
}
