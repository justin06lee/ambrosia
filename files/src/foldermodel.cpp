#include "foldermodel.h"

#include "format.h"
#include "sortkey.h"

#include <KIO/ListJob>
#include <KIO/UDSEntry>

#include <QCollator>
#include <QCoreApplication>
#include <QFile>
#include <QFileSystemWatcher>
#include <QPointer>
#include <QThreadPool>
#include <QTimer>

#include <QElapsedTimer>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <numeric>
#include <functional>
#include <thread>

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

namespace {

struct Dirent64 {
    quint64 ino;
    qint64 off;
    unsigned short reclen;
    unsigned char type;
    char name[];
};

using Listing = FolderModel::Listing;

// FILES_TRACE=1 prints how long each stage of a listing takes.
const bool trace = std::getenv("FILES_TRACE") != nullptr;
void stage(QElapsedTimer &clock, const char *what)
{
    if (trace)
        std::fprintf(stderr, "files: %-8s %7.2f ms\n", what, clock.nsecsElapsed() / 1e6);
    clock.restart();
}
using Entry = FolderModel::Entry;

quint32 addString(Listing &l, const char *s, size_t len)
{
    const auto offset = quint32(l.strings.size());
    l.strings.append(s, len);
    l.strings.push_back('\0');
    return offset;
}

QString errorText(int error)
{
    switch (error) {
    case EACCES:
    case EPERM:
        return QStringLiteral("You don't have permission to see its contents.");
    case ENOENT:
        return QStringLiteral("The folder can't be found.");
    case ENOTDIR:
        return QStringLiteral("It isn't a folder.");
    default:
        return QString::fromLocal8Bit(strerror(error));
    }
}

// Fills in type, size and modification time for entries [begin, end).
void statRange(int dirfd, Listing &l, size_t begin, size_t end)
{
    struct statx sx;
    const unsigned mask = STATX_TYPE | STATX_MODE | STATX_SIZE | STATX_MTIME;
    for (size_t i = begin; i < end; ++i) {
        Entry &e = l.entries[i];
        const char *name = l.strings.data() + e.name;
        if (statx(dirfd, name, AT_SYMLINK_NOFOLLOW | AT_STATX_DONT_SYNC, mask, &sx) != 0)
            continue;
        if (S_ISLNK(sx.stx_mode)) {
            // A link shows as what it points to, as Finder shows aliases.
            e.flags |= FolderModel::Symlink;
            if (statx(dirfd, name, AT_STATX_DONT_SYNC, mask, &sx) != 0)
                continue;
        }
        if (S_ISDIR(sx.stx_mode))
            e.flags |= FolderModel::Dir;
        else
            e.flags &= ~FolderModel::Dir;
        e.size = S_ISDIR(sx.stx_mode) ? -1 : qint64(sx.stx_size);
        e.mtime = sx.stx_mtime.tv_sec;
    }
}

enum class Column { Name, Date, Size, Kind };

Column columnOf(const QString &name)
{
    if (name == QLatin1String("date"))
        return Column::Date;
    if (name == QLatin1String("size"))
        return Column::Size;
    if (name == QLatin1String("kind"))
        return Column::Kind;
    return Column::Name;
}

// Reads a folder's names with getdents64 into l and returns the folder, open
// for statAll, or -1 (with l.error set).
int readNames(const QString &path, bool showHidden, Listing &l)
{
    const int fd = ::open(QFile::encodeName(path).constData(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) {
        l.error = errorText(errno);
        return -1;
    }
    // The first read is small so a huge folder's first names come at once;
    // after that 1 MiB reads keep the number of calls down.
    std::vector<char> buffer(32 * 1024);
    for (;;) {
        const long n = syscall(SYS_getdents64, fd, buffer.data(), buffer.size());
        if (n < 0) {
            if (errno == EINTR)
                continue;
            l.error = errorText(errno);
            break;
        }
        if (n == 0)
            break;
        for (long offset = 0; offset < n;) {
            const auto *d = reinterpret_cast<const Dirent64 *>(buffer.data() + offset);
            offset += d->reclen;
            const size_t len = strlen(d->name);
            if (d->name[0] == '.' && (len == 1 || (len == 2 && d->name[1] == '.')))
                continue;
            const bool hidden = d->name[0] == '.';
            if (hidden && !showHidden)
                continue;
            Entry e;
            e.name = e.display = addString(l, d->name, len);
            e.flags = (d->type == DT_DIR ? FolderModel::Dir : 0) | (hidden ? FolderModel::Hidden : 0);
            l.entries.push_back(e);
        }
        if (buffer.size() < (1u << 20))
            buffer.resize(1u << 20);
    }
    return fd;
}

// statx costs about half a microsecond an entry: big folders split it
// across threads.
void statAll(int fd, Listing &l)
{
    const size_t count = l.entries.size();
    const size_t threads = count < 4096 ? 1 : std::clamp<size_t>(std::thread::hardware_concurrency() / 2, 1, 8);
    if (threads == 1) {
        statRange(fd, l, 0, count);
        return;
    }
    std::vector<std::thread> pool;
    const size_t chunk = (count + threads - 1) / threads;
    for (size_t t = 0; t < threads; ++t) {
        const size_t begin = t * chunk, end = std::min(count, begin + chunk);
        if (begin < end)
            pool.emplace_back(statRange, fd, std::ref(l), begin, end);
    }
    for (auto &thread : pool)
        thread.join();
}

// Name-order keys for a listing: byte keys when every name is ASCII (with
// each key's first 8 bytes as an integer, so most comparisons never touch
// the strings), ICU keys otherwise.
struct Keys {
    bool ascii = true;
    std::string bytes;
    std::vector<quint32> at;
    std::vector<quint64> prefix;
    std::vector<QCollatorSortKey> icu;

    int compare(const Listing &l, quint32 a, quint32 b) const
    {
        if (ascii) {
            if (prefix[a] != prefix[b])
                return prefix[a] < prefix[b] ? -1 : 1;
            return std::string_view(bytes.data() + at[a], at[a + 1] - at[a])
                .compare(std::string_view(bytes.data() + at[b], at[b + 1] - at[b]));
        }
        const int c = icu[a].compare(icu[b]);
        return c != 0 ? c : std::strcmp(l.strings.data() + l.entries[a].display, l.strings.data() + l.entries[b].display);
    }
};

Keys makeKeys(const Listing &l)
{
    Keys k;
    const size_t n = l.entries.size();
    k.at.resize(n + 1);
    k.bytes.reserve(n * 24);
    for (size_t i = 0; i < n && k.ascii; ++i) {
        k.at[i] = quint32(k.bytes.size());
        k.ascii = SortKey::append(l.strings.data() + l.entries[i].display, k.bytes);
    }
    if (k.ascii) {
        k.at[n] = quint32(k.bytes.size());
        k.prefix.resize(n);
        for (size_t i = 0; i < n; ++i) {
            quint64 p = 0;
            const size_t len = k.at[i + 1] - k.at[i];
            for (size_t j = 0; j < 8; ++j)
                p = p << 8 | (j < len ? quint8(k.bytes[k.at[i] + j]) : 0);
            k.prefix[i] = p;
        }
        return k;
    }
    k.bytes.clear();
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    k.icu.reserve(n);
    for (size_t i = 0; i < n; ++i)
        k.icu.push_back(collator.sortKey(QString::fromUtf8(l.strings.data() + l.entries[i].display)));
    return k;
}

// The listing's order by a column, or only its first `limit` rows. Big
// folders sort in parallel: chunks on threads, then merged pairwise.
std::vector<quint32> sortedOrder(const Listing &l, const Keys &keys, Column column, bool ascending, size_t limit = SIZE_MAX)
{
    const size_t n = l.entries.size();
    std::vector<QString> kinds;
    if (column == Column::Kind) {
        QHash<QString, QString> cache;
        kinds.reserve(n);
        for (size_t i = 0; i < n; ++i) {
            const QString name = QString::fromUtf8(l.strings.data() + l.entries[i].display);
            const bool dir = l.entries[i].flags & FolderModel::Dir;
            const QString ext = dir ? QString() : name.section(QLatin1Char('.'), -1).toLower();
            auto it = cache.find(ext);
            if (it == cache.end())
                it = cache.insert(ext, Format::kind(name, dir));
            kinds.push_back(*it);
        }
    }
    auto less = [&](quint32 a, quint32 b) {
        const Entry &x = l.entries[a], &y = l.entries[b];
        int c = 0;
        switch (column) {
        case Column::Date:
            c = x.mtime < y.mtime ? -1 : x.mtime > y.mtime ? 1 : 0;
            break;
        case Column::Size:
            c = x.size < y.size ? -1 : x.size > y.size ? 1 : 0;
            break;
        case Column::Kind:
            c = kinds[a].compare(kinds[b], Qt::CaseInsensitive);
            break;
        case Column::Name:
            break;
        }
        if (c == 0)
            c = keys.compare(l, a, b);
        return ascending ? c < 0 : c > 0;
    };
    std::vector<quint32> order(n);
    std::iota(order.begin(), order.end(), 0);
    if (limit < n) {
        std::partial_sort(order.begin(), order.begin() + limit, order.end(), less);
        order.resize(limit);
        return order;
    }
    const size_t threads = n < 50000 ? 1 : std::clamp<size_t>(std::thread::hardware_concurrency() / 2, 2, 8);
    if (threads == 1) {
        std::sort(order.begin(), order.end(), less);
        return order;
    }
    std::vector<size_t> bounds;
    for (size_t t = 0; t <= threads; ++t)
        bounds.push_back(n * t / threads);
    std::vector<std::thread> pool;
    for (size_t t = 0; t < threads; ++t)
        pool.emplace_back([&, t] { std::sort(order.begin() + bounds[t], order.begin() + bounds[t + 1], less); });
    for (auto &thread : pool)
        thread.join();
    while (bounds.size() > 2) {
        std::vector<size_t> merged;
        pool.clear();
        for (size_t i = 0; i + 2 < bounds.size(); i += 2) {
            const size_t a = bounds[i], m = bounds[i + 1], b = bounds[i + 2];
            pool.emplace_back([&, a, m, b] { std::inplace_merge(order.begin() + a, order.begin() + m, order.begin() + b, less); });
            merged.push_back(a);
        }
        if ((bounds.size() - 1) % 2 == 1)
            merged.push_back(bounds[bounds.size() - 2]);
        merged.push_back(n);
        for (auto &thread : pool)
            thread.join();
        bounds.swap(merged);
    }
    return order;
}

void permute(Listing &l, const std::vector<quint32> &order)
{
    std::vector<Entry> sorted;
    sorted.reserve(order.size());
    for (quint32 i : order)
        sorted.push_back(l.entries[i]);
    l.entries.swap(sorted);
    if (!l.urls.empty()) {
        std::vector<QUrl> urls;
        urls.reserve(order.size());
        for (quint32 i : order)
            urls.push_back(l.urls[i]);
        l.urls.swap(urls);
    }
}

void sortListing(Listing &l, const QString &column, bool ascending)
{
    QElapsedTimer clock;
    clock.start();
    const Keys keys = makeKeys(l);
    stage(clock, "keys");
    const auto order = sortedOrder(l, keys, columnOf(column), ascending);
    stage(clock, "sort");
    permute(l, order);
}

// A local folder, sorted. A big one sorted by name shows its first
// screenful (`first`) before every entry is stat'ed and sorted.
std::shared_ptr<Listing> listLocal(const QString &path, bool showHidden, const QString &column, bool ascending,
                                   const std::function<void(std::shared_ptr<Listing>)> &first)
{
    QElapsedTimer clock;
    clock.start();
    auto l = std::make_shared<Listing>();
    const int fd = readNames(path, showHidden, *l);
    stage(clock, "names");
    if (fd < 0)
        return l;
    const Keys keys = makeKeys(*l);
    stage(clock, "keys");
    const Column by = columnOf(column);
    if (l->entries.size() > 20000 && by == Column::Name) {
        auto top = std::make_shared<Listing>();
        for (quint32 i : sortedOrder(*l, keys, by, ascending, 256)) {
            Entry e = l->entries[i];
            e.name = e.display = addString(*top, l->strings.data() + e.name, strlen(l->strings.data() + e.name));
            top->entries.push_back(e);
        }
        statAll(fd, *top);
        first(top);
        stage(clock, "first");
    }
    statAll(fd, *l);
    ::close(fd);
    stage(clock, "stat");
    const auto order = sortedOrder(*l, keys, by, ascending);
    stage(clock, "sort");
    permute(*l, order);
    return l;
}

}

FolderModel::FolderModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_listing(std::make_shared<Listing>())
    , m_watcher(new QFileSystemWatcher(this))
    , m_reload(new QTimer(this))
{
    // Changes come in bursts (a copy writes many files): reread once they
    // settle.
    m_reload->setSingleShot(true);
    m_reload->setInterval(150);
    connect(m_reload, &QTimer::timeout, this, &FolderModel::load);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, m_reload, qOverload<>(&QTimer::start));
}

FolderModel::~FolderModel()
{
    ++m_generation;
    if (m_job)
        m_job->kill();
}

void FolderModel::setUrl(const QUrl &url)
{
    const QUrl clean = url.adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments);
    if (clean == m_url)
        return;
    m_url = clean;
    Q_EMIT urlChanged();
    if (!m_watcher->directories().isEmpty())
        m_watcher->removePaths(m_watcher->directories());
    if (m_url.isLocalFile())
        m_watcher->addPath(m_url.toLocalFile());
    load();
}

QString FolderModel::name() const
{
    if (m_url.isLocalFile() && m_url.path() == QLatin1String("/"))
        return QSysInfo::machineHostName();
    if (m_url.scheme() == QLatin1String("trash"))
        return QStringLiteral("Trash");
    if (m_url.scheme() == QLatin1String("recentlyused"))
        return QStringLiteral("Recents");
    const QString file = m_url.fileName();
    return file.isEmpty() ? m_url.toDisplayString() : file;
}

void FolderModel::reload()
{
    load();
}

void FolderModel::load()
{
    const quint64 generation = ++m_generation;
    m_clock.start();
    m_firstMs = 0;
    if (!m_loading) {
        m_loading = true;
        Q_EMIT loadingChanged();
    }
    if (!m_url.isLocalFile()) {
        listRemote();
        return;
    }
    QPointer<FolderModel> self(this);
    const QString path = m_url.toLocalFile();
    const QString column = m_sortColumn;
    const bool ascending = m_ascending, hidden = m_showHidden;
    QThreadPool::globalInstance()->start([self, generation, path, column, ascending, hidden] {
        auto deliver = [self, generation](std::shared_ptr<Listing> listing, bool partial) {
            QMetaObject::invokeMethod(
                qApp, [self, listing, generation, partial] {
                    if (self)
                        self->apply(listing, generation, partial);
                },
                Qt::QueuedConnection);
        };
        auto listing = listLocal(path, hidden, column, ascending, [&](std::shared_ptr<Listing> top) { deliver(top, true); });
        deliver(listing, false);
    });
}

void FolderModel::listRemote()
{
    if (m_job)
        m_job->kill();
    auto listing = std::make_shared<Listing>();
    auto *job = KIO::listDir(m_url, KIO::HideProgressInfo);
    m_job = job;
    const QUrl base = m_url;
    const bool showHidden = m_showHidden;
    connect(job, &KIO::ListJob::entries, this, [listing, base, showHidden](KIO::Job *, const KIO::UDSEntryList &list) {
        for (const KIO::UDSEntry &u : list) {
            const QString name = u.stringValue(KIO::UDSEntry::UDS_NAME);
            if (name.isEmpty() || name == QLatin1String(".") || name == QLatin1String(".."))
                continue;
            QString display = u.stringValue(KIO::UDSEntry::UDS_DISPLAY_NAME);
            if (display.isEmpty())
                display = name;
            const bool hidden = display.startsWith(QLatin1Char('.'));
            if (hidden && !showHidden)
                continue;
            const QByteArray n = name.toUtf8(), d = display.toUtf8();
            Entry e;
            e.name = addString(*listing, n.constData(), n.size());
            e.display = addString(*listing, d.constData(), d.size());
            e.flags = (u.isDir() ? FolderModel::Dir : 0) | (hidden ? FolderModel::Hidden : 0);
            e.size = u.isDir() ? -1 : u.numberValue(KIO::UDSEntry::UDS_SIZE, -1);
            e.mtime = u.numberValue(KIO::UDSEntry::UDS_MODIFICATION_TIME, 0);
            const QString target = u.stringValue(KIO::UDSEntry::UDS_URL);
            QUrl url = target.isEmpty() ? base : QUrl(target);
            if (target.isEmpty())
                url.setPath(base.path() + (base.path().endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + name);
            listing->entries.push_back(e);
            listing->urls.push_back(url);
        }
    });
    const quint64 generation = m_generation;
    connect(job, &KJob::result, this, [this, job, listing, generation] {
        if (m_job == job)
            m_job = nullptr;
        if (job->error() && job->error() != KJob::KilledJobError)
            listing->error = job->errorString();
        QPointer<FolderModel> self(this);
        const QString column = m_sortColumn;
        const bool ascending = m_ascending;
        QThreadPool::globalInstance()->start([self, listing, generation, column, ascending] {
            sortListing(*listing, column, ascending);
            QMetaObject::invokeMethod(
                qApp, [self, listing, generation] {
                    if (self)
                        self->apply(listing, generation, false);
                },
                Qt::QueuedConnection);
        });
    });
}

void FolderModel::resort()
{
    const quint64 generation = ++m_generation;
    m_clock.start();
    QPointer<FolderModel> self(this);
    auto copy = std::make_shared<Listing>(*m_listing);
    const QString column = m_sortColumn;
    const bool ascending = m_ascending;
    QThreadPool::globalInstance()->start([self, copy, generation, column, ascending] {
        sortListing(*copy, column, ascending);
        QMetaObject::invokeMethod(
            qApp, [self, copy, generation] {
                if (self)
                    self->apply(copy, generation, false);
            },
            Qt::QueuedConnection);
    });
}

void FolderModel::apply(std::shared_ptr<Listing> listing, quint64 generation, bool partial)
{
    if (generation != m_generation)
        return; // a newer request superseded this one
    const int before = rowCount();
    beginResetModel();
    m_listing = std::move(listing);
    endResetModel();
    if (partial || m_firstMs == 0)
        m_firstMs = m_clock.nsecsElapsed() / 1e6;
    if (partial) {
        Q_EMIT countChanged();
        return;
    }
    m_loadMs = m_clock.nsecsElapsed() / 1e6;
    if (trace)
        std::fprintf(stderr, "files: applied  %7.2f ms after the request\n", m_loadMs);
    if (m_loading) {
        m_loading = false;
        Q_EMIT loadingChanged();
    }
    if (before != rowCount())
        Q_EMIT countChanged();
    Q_EMIT loaded();
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_listing->entries.size());
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {UrlRole, "url"},
        {IsDirRole, "isDir"},
        {SizeRole, "size"},
        {DateRole, "date"},
        {SizeTextRole, "sizeText"},
        {DateTextRole, "dateText"},
        {KindRole, "kind"},
        {IconRole, "icon"},
        {BadgeRole, "badge"},
    };
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const Entry &e = m_listing->entries[index.row()];
    const bool dir = e.flags & Dir;
    switch (role) {
    case NameRole:
    case Qt::DisplayRole:
        return QString::fromUtf8(str(e.display));
    case UrlRole:
        return urlAt(index.row());
    case IsDirRole:
        return dir;
    case SizeRole:
        return e.size;
    case DateRole:
        return e.mtime;
    case SizeTextRole:
        return dir ? QStringLiteral("--") : Format::size(e.size);
    case DateTextRole:
        return Format::date(e.mtime);
    case KindRole: {
        const QString name = QString::fromUtf8(str(e.display));
        const QString ext = dir ? QString() : name.section(QLatin1Char('.'), -1).toLower();
        auto it = m_kinds.find(ext);
        if (it == m_kinds.end())
            it = m_kinds.insert(ext, Format::kind(name, dir));
        return *it;
    }
    case IconRole:
        return Format::icon(QString(), dir);
    case BadgeRole:
        return Format::badge(QString::fromUtf8(str(e.display)), dir);
    }
    return {};
}

QUrl FolderModel::urlAt(int row) const
{
    if (row < 0 || row >= rowCount())
        return {};
    if (!m_listing->urls.empty())
        return m_listing->urls[row];
    QUrl url = m_url;
    const QString path = url.path();
    url.setPath(path + (path.endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + QString::fromUtf8(str(m_listing->entries[row].name)));
    return url;
}

QString FolderModel::nameAt(int row) const
{
    return row >= 0 && row < rowCount() ? QString::fromUtf8(str(m_listing->entries[row].display)) : QString();
}

bool FolderModel::isDirAt(int row) const
{
    return row >= 0 && row < rowCount() && (m_listing->entries[row].flags & Dir);
}

int FolderModel::indexOf(const QString &name) const
{
    const QByteArray n = name.toUtf8();
    for (int i = 0; i < rowCount(); ++i)
        if (n == str(m_listing->entries[i].display))
            return i;
    return -1;
}

int FolderModel::match(const QString &prefix, int from) const
{
    const int n = rowCount();
    if (prefix.isEmpty() || n == 0)
        return -1;
    for (int k = 0; k < n; ++k) {
        const int i = (from + k) % n;
        if (QString::fromUtf8(str(m_listing->entries[i].display)).startsWith(prefix, Qt::CaseInsensitive))
            return i;
    }
    return -1;
}

void FolderModel::setSortColumn(const QString &column)
{
    if (column == m_sortColumn)
        return;
    m_sortColumn = column;
    Q_EMIT sortChanged();
    resort();
}

void FolderModel::setAscending(bool ascending)
{
    if (ascending == m_ascending)
        return;
    m_ascending = ascending;
    Q_EMIT sortChanged();
    resort();
}

void FolderModel::setShowHidden(bool show)
{
    if (show == m_showHidden)
        return;
    m_showHidden = show;
    Q_EMIT showHiddenChanged();
    load();
}
