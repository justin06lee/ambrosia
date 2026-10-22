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
#include <utility>

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

// Lists a folder through KIO; `done` gets it, unsorted, on the GUI thread.
KJob *listWithKio(QObject *context, const QUrl &base, bool showHidden, const std::function<void(std::shared_ptr<Listing>)> &done)
{
    auto listing = std::make_shared<Listing>();
    auto *job = KIO::listDir(base, KIO::HideProgressInfo);
    QObject::connect(job, &KIO::ListJob::entries, context, [listing, base, showHidden](KIO::Job *, const KIO::UDSEntryList &list) {
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
    QObject::connect(job, &KJob::result, context, [job, listing, done] {
        if (job->error() && job->error() != KJob::KilledJobError)
            listing->error = job->errorString();
        done(listing);
    });
    return job;
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
    connect(m_reload, &QTimer::timeout, this, [this] {
        if (std::exchange(m_rootChanged, false))
            load();
    });
    connect(m_reload, &QTimer::timeout, this, [this] {
        const auto paths = std::exchange(m_changedPaths, {});
        for (const QString &path : paths)
            for (Node *node : std::as_const(m_nodes))
                if (node->open && node->listing && node->url.isLocalFile() && node->url.toLocalFile() == path)
                    loadNode(node);
    });
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &FolderModel::changed);
}

void FolderModel::changed(const QString &path)
{
    if (m_url.isLocalFile() && path == m_url.toLocalFile())
        m_rootChanged = true;
    else
        m_changedPaths.insert(path);
    m_reload->start();
}

void FolderModel::watch(const QString &path, bool on)
{
    if (on)
        m_watcher->addPath(path);
    else
        m_watcher->removePath(path);
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
    // Another folder: nothing in it is open yet.
    if (m_outline || !m_children.empty()) {
        beginResetModel();
        m_children.clear();
        m_nodes.clear();
        m_rows.clear();
        m_outline = false;
        endResetModel();
        Q_EMIT countChanged();
    }
    m_changedPaths.clear();
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
    const quint64 generation = m_generation;
    m_job = listWithKio(this, m_url, m_showHidden, [this, generation](std::shared_ptr<Listing> listing) {
        if (generation == m_generation)
            m_job = nullptr;
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
    std::vector<std::pair<quint64, std::shared_ptr<Listing>>> open;
    for (Node *node : std::as_const(m_nodes))
        if (node->listing)
            open.emplace_back(node->id, std::make_shared<Listing>(*node->listing));
    const QString column = m_sortColumn;
    const bool ascending = m_ascending;
    QThreadPool::globalInstance()->start([self, copy, open, generation, column, ascending] {
        sortListing(*copy, column, ascending);
        for (const auto &[id, listing] : open)
            sortListing(*listing, column, ascending);
        QMetaObject::invokeMethod(
            qApp, [self, copy, open, generation] {
                if (!self || generation != self->m_generation)
                    return;
                for (const auto &[id, listing] : open)
                    if (Node *node = self->m_nodes.value(id); node && node->listing)
                        node->listing = listing;
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
    rebuildRows();
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
    if (parent.isValid())
        return 0;
    return int(m_outline ? m_rows.size() : m_listing->entries.size());
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
        {KindShortRole, "kindShort"},
        {DepthRole, "depth"},
        {ExpandedRole, "expanded"},
    };
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const Row r = rowAt(index.row());
    const Entry &e = entryOf(r);
    const bool dir = e.flags & Dir;
    switch (role) {
    case NameRole:
    case Qt::DisplayRole:
        return displayOf(r);
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
        return Format::date(e.mtime, m_dateLevel);
    case KindRole:
    case KindShortRole: {
        const QString name = displayOf(r);
        const QString ext = dir ? QString() : name.section(QLatin1Char('.'), -1).toLower();
        auto it = m_kinds.find(ext);
        if (it == m_kinds.end())
            it = m_kinds.insert(ext, Format::kind(name, dir));
        return role == KindRole ? *it : Format::shortKind(*it);
    }
    case IconRole:
        return Format::icon(QString(), dir);
    case BadgeRole:
        return Format::badge(displayOf(r), dir);
    case DepthRole:
        return int(r.depth);
    case ExpandedRole:
        return isExpanded(index.row());
    }
    return {};
}

const char *FolderModel::nameOf(const Row &r) const
{
    const Listing &l = listingOf(r.node);
    return l.strings.data() + l.entries[r.index].name;
}

QString FolderModel::displayOf(const Row &r) const
{
    const Listing &l = listingOf(r.node);
    return QString::fromUtf8(l.strings.data() + l.entries[r.index].display);
}

QUrl FolderModel::urlAt(int row) const
{
    if (row < 0 || row >= rowCount())
        return {};
    const Row r = rowAt(row);
    const Listing &l = listingOf(r.node);
    if (!l.urls.empty())
        return l.urls[r.index];
    QUrl url = r.node ? r.node->url : m_url;
    const QString path = url.path();
    url.setPath(path + (path.endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + QString::fromUtf8(nameOf(r)));
    return url;
}

QString FolderModel::nameAt(int row) const
{
    return row >= 0 && row < rowCount() ? displayOf(rowAt(row)) : QString();
}

bool FolderModel::isDirAt(int row) const
{
    return row >= 0 && row < rowCount() && (entryOf(rowAt(row)).flags & Dir);
}

int FolderModel::indexOf(const QString &name) const
{
    for (int i = 0; i < rowCount(); ++i)
        if (rowAt(i).depth == 0 && displayOf(rowAt(i)) == name)
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
        if (displayOf(rowAt(i)).startsWith(prefix, Qt::CaseInsensitive))
            return i;
    }
    return -1;
}

void FolderModel::setDateLevel(int level)
{
    if (level == m_dateLevel)
        return;
    m_dateLevel = level;
    Q_EMIT dateLevelChanged();
    if (rowCount() > 0)
        Q_EMIT dataChanged(index(0), index(rowCount() - 1), {DateTextRole});
}

// The outline

void FolderModel::appendRows(const Node *node, quint32 depth, std::vector<Row> &rows) const
{
    const Listing &l = listingOf(node);
    const Children &children = childrenOf(node);
    for (quint32 i = 0; i < l.entries.size(); ++i) {
        rows.push_back({node, i, depth});
        if (children.empty() || !(l.entries[i].flags & Dir))
            continue;
        const auto it = children.find(l.strings.data() + l.entries[i].name);
        if (it != children.end() && it->second->open && it->second->listing)
            appendRows(it->second.get(), depth + 1, rows);
    }
}

// The rows again, after the folder itself was reread or resorted.
void FolderModel::rebuildRows()
{
    m_rows.clear();
    m_outline = false;
    bool open = false;
    for (const auto &[name, node] : m_children)
        open = open || (node->open && node->listing);
    if (!open)
        return;
    appendRows(nullptr, 0, m_rows);
    m_outline = m_rows.size() != m_listing->entries.size();
    if (!m_outline)
        m_rows.clear();
}

// The row of the folder a node lists, or -1 when it isn't showing.
int FolderModel::rowOfNode(const Node *node) const
{
    const int n = rowCount();
    for (int i = 0; i < n; ++i) {
        const Row r = rowAt(i);
        if (r.node == node->parent && (entryOf(r).flags & Dir) && node->name == nameOf(r))
            return i;
    }
    return -1;
}

// One past the last row inside the folder at `row`.
int FolderModel::subtreeEnd(int row) const
{
    const quint32 depth = rowAt(row).depth;
    int end = row + 1;
    while (end < rowCount() && rowAt(end).depth > depth)
        ++end;
    return end;
}

bool FolderModel::isExpanded(int row) const
{
    if (row < 0 || row >= rowCount())
        return false;
    const Row r = rowAt(row);
    if (!(entryOf(r).flags & Dir))
        return false;
    const Children &children = childrenOf(r.node);
    const auto it = children.find(nameOf(r));
    return it != children.end() && it->second->open;
}

int FolderModel::parentRow(int row) const
{
    if (row < 0 || row >= rowCount() || rowAt(row).depth == 0)
        return -1;
    const quint32 depth = rowAt(row).depth;
    for (int i = row - 1; i >= 0; --i)
        if (rowAt(i).depth < depth)
            return i;
    return -1;
}

void FolderModel::setExpanded(int row, bool expanded, bool all)
{
    if (!isDirAt(row))
        return;
    const Row r = rowAt(row);
    Children &children = childrenOf(r.node);
    const std::string name = nameOf(r);
    auto it = children.find(name);
    if (expanded) {
        if (it == children.end()) {
            auto node = std::make_unique<Node>();
            node->parent = const_cast<Node *>(r.node);
            node->name = name;
            node->url = urlAt(row);
            node->id = ++m_nextNode;
            m_nodes.insert(node->id, node.get());
            it = children.emplace(name, std::move(node)).first;
        }
        Node *node = it->second.get();
        if (all)
            node->openAll = true;
        if (node->open) {
            if (all && node->listing)
                openAllIn(node);
            return;
        }
        node->open = true;
        Q_EMIT dataChanged(index(row), index(row), {ExpandedRole});
        loadNode(node);
        return;
    }
    if (it == children.end() || !it->second->open)
        return;
    Node *node = it->second.get();
    hideNode(node);
    if (all) {
        // Option-click forgets what was open inside, as Finder does.
        forget(node);
        children.erase(it);
    } else {
        node->open = false;
        closeListings(node);
    }
    Q_EMIT dataChanged(index(row), index(row), {ExpandedRole});
}

void FolderModel::loadNode(Node *node)
{
    const quint64 id = node->id, generation = ++node->generation;
    const QString column = m_sortColumn;
    const bool ascending = m_ascending;
    if (!node->url.isLocalFile()) {
        listWithKio(this, node->url, m_showHidden, [this, id, generation, column, ascending](std::shared_ptr<Listing> listing) {
            sortListing(*listing, column, ascending);
            nodeLoaded(id, generation, listing, column, ascending);
        });
        return;
    }
    QPointer<FolderModel> self(this);
    const QString path = node->url.toLocalFile();
    const bool hidden = m_showHidden;
    QThreadPool::globalInstance()->start([self, id, generation, path, column, ascending, hidden] {
        auto listing = listLocal(path, hidden, column, ascending, [](std::shared_ptr<Listing>) {});
        QMetaObject::invokeMethod(
            qApp, [self, id, generation, listing, column, ascending] {
                if (self)
                    self->nodeLoaded(id, generation, listing, column, ascending);
            },
            Qt::QueuedConnection);
    });
}

void FolderModel::nodeLoaded(quint64 id, quint64 generation, std::shared_ptr<Listing> listing, const QString &column, bool ascending)
{
    Node *node = m_nodes.value(id);
    if (!node || node->generation != generation || !node->open)
        return;
    if (column != m_sortColumn || ascending != m_ascending)
        sortListing(*listing, m_sortColumn, m_ascending); // the order changed while it was read
    hideNode(node); // a reread replaces the rows it showed
    if (!node->listing && node->url.isLocalFile())
        watch(node->url.toLocalFile(), true);
    node->listing = std::move(listing);
    showNode(node);
    if (node->openAll)
        openAllIn(node);
    for (auto &[name, child] : node->children)
        if (child->open && !child->listing)
            loadNode(child.get());
}

// Inserts a node's rows (and those of the open folders in it) under its row.
void FolderModel::showNode(Node *node)
{
    const int at = rowOfNode(node);
    if (at < 0)
        return;
    std::vector<Row> rows;
    appendRows(node, rowAt(at).depth + 1, rows);
    if (rows.empty())
        return;
    if (!m_outline) {
        // Nothing else is open: the same rows as before, as an outline.
        m_rows.reserve(m_listing->entries.size() + rows.size());
        for (quint32 i = 0; i < m_listing->entries.size(); ++i)
            m_rows.push_back({nullptr, i, 0});
        m_outline = true;
    }
    beginInsertRows({}, at + 1, at + int(rows.size()));
    m_rows.insert(m_rows.begin() + at + 1, rows.begin(), rows.end());
    endInsertRows();
    Q_EMIT countChanged();
}

// Takes a node's rows out from under its row.
void FolderModel::hideNode(Node *node)
{
    if (!node->listing)
        return;
    const int at = rowOfNode(node);
    if (at < 0)
        return;
    const int end = subtreeEnd(at);
    if (end == at + 1)
        return;
    beginRemoveRows({}, at + 1, end - 1);
    m_rows.erase(m_rows.begin() + at + 1, m_rows.begin() + end);
    endRemoveRows();
    if (m_rows.size() == m_listing->entries.size()) {
        m_rows.clear();
        m_outline = false;
    }
    Q_EMIT countChanged();
}

// Opens every folder in an open node, and every folder in those as they come.
void FolderModel::openAllIn(Node *node)
{
    const Listing &l = *node->listing;
    for (quint32 i = 0; i < l.entries.size(); ++i) {
        if (!(l.entries[i].flags & Dir))
            continue;
        const std::string name = l.strings.data() + l.entries[i].name;
        auto it = node->children.find(name);
        if (it == node->children.end()) {
            auto child = std::make_unique<Node>();
            child->parent = node;
            child->name = name;
            if (!l.urls.empty()) {
                child->url = l.urls[i];
            } else {
                child->url = node->url;
                child->url.setPath(node->url.path() + QLatin1Char('/') + QString::fromUtf8(name.c_str()));
            }
            child->id = ++m_nextNode;
            m_nodes.insert(child->id, child.get());
            it = node->children.emplace(name, std::move(child)).first;
        }
        Node *child = it->second.get();
        child->openAll = true;
        if (!child->open) {
            child->open = true;
            loadNode(child);
        } else if (child->listing) {
            openAllIn(child);
        }
    }
    if (rowCount() > 0)
        Q_EMIT dataChanged(index(0), index(rowCount() - 1), {ExpandedRole});
}

// A closed folder keeps which folders in it were open, not their contents.
void FolderModel::closeListings(Node *node)
{
    if (node->listing && node->url.isLocalFile())
        watch(node->url.toLocalFile(), false);
    node->listing.reset();
    node->openAll = false;
    ++node->generation;
    for (auto &[name, child] : node->children)
        closeListings(child.get());
}

void FolderModel::forget(Node *node)
{
    closeListings(node);
    m_nodes.remove(node->id);
    for (auto &[name, child] : node->children)
        forget(child.get());
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
