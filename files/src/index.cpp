#include "index.h"

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QSaveFile>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <malloc.h>
#include <mutex>
#include <shared_mutex>
#include <thread>
#include <unordered_map>

#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/inotify.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/xattr.h>
#include <unistd.h>

#if defined(__x86_64__)
#include <immintrin.h>
#endif

namespace {

constexpr quint32 None = 0xffffffffu;
enum : quint8 { IsDir = 1, IsGone = 2, IsMount = 4 };
constexpr uint32_t WatchMask = IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO | IN_ATTRIB | IN_ONLYDIR | IN_DONT_FOLLOW | IN_EXCL_UNLINK;
const char TagsAttr[] = "user.xdg.tags";

struct Dirent64 {
    quint64 ino;
    qint64 off;
    unsigned short reclen;
    unsigned char type;
    char name[];
};

bool hidden(const char *name)
{
    return name[0] == '.';
}

// Names fold as queries do; plain ASCII (most names) without QString.
void foldInto(const char *s, size_t n, std::string &out)
{
    size_t i = 0;
    while (i < n && !(quint8(s[i]) & 0x80))
        ++i;
    if (i < n) {
        out += Index::fold(QString::fromUtf8(s, qsizetype(n)));
        return;
    }
    for (size_t j = 0; j < n; ++j)
        out.push_back(s[j] >= 'A' && s[j] <= 'Z' ? char(s[j] + 32) : s[j]);
}

qint64 stampOf(const struct stat &st)
{
    const qint64 m = qint64(st.st_mtim.tv_sec) * 1000000000 + st.st_mtim.tv_nsec;
    const qint64 c = qint64(st.st_ctim.tv_sec) * 1000000000 + st.st_ctim.tv_nsec;
    return std::max(m, c);
}

// An item's tags attribute, read through its folder: getxattrat (Linux
// 6.13) or else the folder's /proc/self/fd link.
std::string tagsAt(int dirfd, const char *name)
{
    char buf[1024];
    long n = -1;
#ifdef SYS_getxattrat
    struct {
        quint64 value;
        quint32 size;
        quint32 flags;
    } args{quint64(quintptr(buf)), sizeof buf, 0};
    static std::atomic<bool> missing{false};
    if (!missing.load(std::memory_order_relaxed)) {
        n = syscall(SYS_getxattrat, dirfd, name, AT_SYMLINK_NOFOLLOW, TagsAttr, &args, sizeof args);
        if (n >= 0 || errno != ENOSYS)
            return n > 0 ? std::string(buf, size_t(n)) : std::string();
        missing = true;
    }
#endif
    char path[64 + NAME_MAX];
    std::snprintf(path, sizeof path, "/proc/self/fd/%d/%s", dirfd, name);
    n = lgetxattr(path, TagsAttr, buf, sizeof buf);
    return n > 0 ? std::string(buf, size_t(n)) : std::string();
}

std::string tagsOfPath(const std::string &path)
{
    char buf[1024];
    const long n = lgetxattr(path.c_str(), TagsAttr, buf, sizeof buf);
    return n > 0 ? std::string(buf, size_t(n)) : std::string();
}

// FILES_INDEX_NOTAGS=1 leaves tags out of the walk, to time it without them.
const bool readTags = std::getenv("FILES_INDEX_NOTAGS") == nullptr;

// The calling thread yields to everything else: nice 10 and idle I/O.
void background()
{
    const auto tid = pid_t(syscall(SYS_gettid));
    setpriority(PRIO_PROCESS, id_t(tid), 10);
    syscall(SYS_ioprio_set, 1 /* IOPRIO_WHO_PROCESS */, tid, 3 << 13 /* IOPRIO_CLASS_IDLE */);
}

// The items: parallel arrays, one row each; row 0 is the root folder.
struct Tree {
    std::string folded = std::string(1, '\0'); // each name folded, NUL-terminated
    std::string originals;                     // the names folding changed
    std::vector<quint32> name{0};              // → folded, increasing with the row
    std::vector<quint32> orig{None};           // → originals, or None: the folded name is the name
    std::vector<quint32> parent{None};
    std::vector<quint8> flags{IsDir};
    std::vector<quint16> tags{0};              // → tagSets
    std::vector<std::string> tagSets{std::string()};
    std::unordered_map<std::string, quint16> tagIds;
    struct Folder {
        quint32 first = 0, count = 0; // its children as read: rows [first, first + count)
        int wd = -1;
        qint64 stamp = 0;             // max(mtime, ctime) when read
    };
    std::unordered_map<quint32, Folder> folders;
    std::unordered_multimap<quint32, quint32> added; // children that came after the read
    // inotify's watch numbers (small, and increasing) → the folder's row:
    // a plain array, about a tenth of a hash map's memory.
    struct Watches {
        std::vector<quint32> rows; // None where there's no watch
        size_t count = 0;
        quint32 find(int wd) const { return wd >= 0 && size_t(wd) < rows.size() ? rows[size_t(wd)] : None; }
        void set(int wd, quint32 row)
        {
            if (wd < 0)
                return;
            if (size_t(wd) >= rows.size())
                rows.resize(std::max(size_t(wd) + 1, rows.size() + rows.size() / 2), None);
            if (rows[size_t(wd)] == None)
                ++count;
            rows[size_t(wd)] = row;
        }
        void erase(int wd)
        {
            if (find(wd) != None) {
                rows[size_t(wd)] = None;
                --count;
            }
        }
        size_t size() const { return count; }
    } wds;
    size_t gone = 0;
    std::string root, prefix; // prefix: root, or "" for "/"
    dev_t dev = 0;
    int inotify = -1;

    size_t size() const { return name.size(); }
    const char *nameOf(quint32 e) const { return orig[e] != None ? originals.data() + orig[e] : folded.data() + name[e]; }

    void setRoot(const std::string &path)
    {
        root = path;
        prefix = path == "/" ? std::string() : path;
        struct stat st;
        if (::stat(path.c_str(), &st) == 0)
            dev = st.st_dev;
    }
    quint16 intern(const std::string &value)
    {
        if (value.empty())
            return 0;
        const auto it = tagIds.find(value);
        if (it != tagIds.end())
            return it->second;
        if (tagSets.size() >= 0xffff)
            return 0;
        const auto id = quint16(tagSets.size());
        tagSets.push_back(value);
        tagIds.emplace(value, id);
        return id;
    }
    quint32 append(quint32 dir, const char *n, size_t len, quint8 f, quint16 tag)
    {
        const auto e = quint32(name.size());
        const size_t at = folded.size();
        name.push_back(quint32(at));
        foldInto(n, len, folded);
        if (folded.size() - at == len && std::memcmp(folded.data() + at, n, len) == 0) {
            orig.push_back(None);
        } else {
            orig.push_back(quint32(originals.size()));
            originals.append(n, len);
            originals.push_back('\0');
        }
        folded.push_back('\0');
        parent.push_back(dir);
        flags.push_back(f);
        tags.push_back(tag);
        return e;
    }
    template<typename F>
    void eachChild(quint32 dir, F f) const
    {
        const auto it = folders.find(dir);
        if (it != folders.end())
            for (quint32 i = it->second.first; i < it->second.first + it->second.count; ++i)
                if (!(flags[i] & IsGone) && parent[i] == dir)
                    f(i);
        auto [a, b] = added.equal_range(dir);
        for (; a != b; ++a)
            if (!(flags[a->second] & IsGone) && parent[a->second] == dir)
                f(a->second);
    }
    quint32 child(quint32 dir, const char *n) const
    {
        quint32 found = None;
        eachChild(dir, [&](quint32 i) {
            if (found == None && std::strcmp(nameOf(i), n) == 0)
                found = i;
        });
        return found;
    }
    std::string path(quint32 e) const
    {
        thread_local std::vector<quint32> chain;
        chain.clear();
        for (quint32 i = e; i != 0 && i != None; i = parent[i])
            chain.push_back(i);
        std::string p = chain.empty() ? root : prefix;
        for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
            p.push_back('/');
            p += nameOf(*it);
        }
        return p;
    }
    int depth(quint32 e) const
    {
        int d = 0;
        for (quint32 i = e; i != 0 && i != None; i = parent[i])
            ++d;
        return d;
    }
    // The row of a path under the root, or None.
    quint32 lookup(const std::string &path) const
    {
        if (path == root)
            return 0;
        if (path.compare(0, prefix.size(), prefix) != 0 || path.size() <= prefix.size() || path[prefix.size()] != '/')
            return None;
        quint32 e = 0;
        size_t at = prefix.size() + 1;
        while (at < path.size()) {
            size_t slash = path.find('/', at);
            if (slash == std::string::npos)
                slash = path.size();
            if (slash > at) {
                e = child(e, path.substr(at, slash - at).c_str());
                if (e == None)
                    return None;
            }
            at = slash + 1;
        }
        return e;
    }
    // Drops gone items' rows in place, keeping the rest in order: names
    // stay increasing with the row, and each folder's rows stay together.
    void compact()
    {
        if (gone == 0)
            return;
        const size_t n = size();
        std::vector<quint32> before(n + 1); // the live rows before each row: its new number
        quint32 live = 0;
        for (size_t i = 0; i < n; ++i) {
            before[i] = live;
            if (!(flags[i] & IsGone))
                ++live;
        }
        before[n] = live;
        const auto alive = [&](quint32 i) { return i < n && before[i + 1] != before[i]; };
        size_t nameAt = 0, origAt = 0;
        for (size_t i = 0; i < n; ++i) {
            if (!alive(quint32(i)))
                continue;
            const quint32 j = before[i];
            const size_t len = std::strlen(folded.data() + name[i]) + 1;
            std::memmove(folded.data() + nameAt, folded.data() + name[i], len);
            name[j] = quint32(nameAt);
            nameAt += len;
            if (orig[i] != None) {
                const size_t olen = std::strlen(originals.data() + orig[i]) + 1;
                std::memmove(originals.data() + origAt, originals.data() + orig[i], olen);
                orig[j] = quint32(origAt);
                origAt += olen;
            } else {
                orig[j] = None;
            }
            parent[j] = alive(parent[i]) ? before[parent[i]] : None;
            flags[j] = flags[i];
            tags[j] = tags[i];
        }
        folded.resize(nameAt);
        originals.resize(origAt);
        name.resize(live);
        orig.resize(live);
        parent.resize(live);
        flags.resize(live);
        tags.resize(live);
        std::unordered_map<quint32, Folder> moved;
        moved.reserve(folders.size());
        for (const auto &[e, f] : folders)
            if (alive(e))
                moved.emplace(before[e], Folder{before[f.first], before[f.first + f.count] - before[f.first], f.wd, f.stamp});
        folders = std::move(moved);
        std::unordered_multimap<quint32, quint32> later;
        for (const auto &[dir, e] : added)
            if (alive(dir) && alive(e))
                later.emplace(before[dir], before[e]);
        added = std::move(later);
        for (quint32 &row : wds.rows) {
            if (row == None)
                continue;
            if (alive(row)) {
                row = before[row];
            } else {
                row = None;
                --wds.count;
            }
        }
        gone = 0;
    }
    void shrink()
    {
        folded.shrink_to_fit();
        originals.shrink_to_fit();
        name.shrink_to_fit();
        orig.shrink_to_fit();
        parent.shrink_to_fit();
        flags.shrink_to_fit();
        tags.shrink_to_fit();
    }
    size_t bytes() const
    {
        return folded.capacity() + originals.capacity() + (name.capacity() + orig.capacity() + parent.capacity()) * 4
            + flags.capacity() + tags.capacity() * 2 + folders.size() * 48 + wds.rows.capacity() * 4 + added.size() * 32;
    }
};

// An exclusive hold on a tree's lock, when it has one (a tree only the
// walk sees doesn't).
struct WriteLock {
    std::shared_mutex *m;
    explicit WriteLock(std::shared_mutex *m) : m(m) { if (m) m->lock(); }
    ~WriteLock() { if (m) m->unlock(); }
};

// Reads folders into a tree breadth-first on a few threads: each reads a
// folder (adding its inotify watch first, so nothing is missed), then
// appends all its children at once, so a folder's children are one range
// of rows.
struct Walk {
    Tree &tree;
    std::shared_mutex *lock;
    int inotify;
    const std::atomic<bool> &stop;
    size_t limit = SIZE_MAX; // stop queueing folders past this many rows
    std::function<void()> progress;

    std::shared_mutex own; // the tree's lock when it has none (only the walk sees it)
    std::mutex m;
    std::condition_variable cv;
    std::deque<std::pair<quint32, std::string>> jobs;
    size_t busy = 0;
    QElapsedTimer since;

    void run(std::vector<std::pair<quint32, std::string>> starts, int threads)
    {
        jobs.assign(std::make_move_iterator(starts.begin()), std::make_move_iterator(starts.end()));
        since.start();
        std::vector<std::thread> pool;
        for (int i = 1; i < threads; ++i)
            pool.emplace_back([this] {
                background();
                work();
            });
        work();
        for (auto &t : pool)
            t.join();
    }
    void work()
    {
        std::unique_lock lk(m);
        for (;;) {
            cv.wait(lk, [&] { return !jobs.empty() || busy == 0; });
            if (jobs.empty() || stop.load(std::memory_order_relaxed)) {
                jobs.clear();
                cv.notify_all();
                if (busy == 0)
                    return;
                continue;
            }
            auto job = std::move(jobs.front());
            jobs.pop_front();
            ++busy;
            lk.unlock();
            std::vector<std::pair<quint32, std::string>> subdirs;
            read(job.first, job.second, subdirs);
            lk.lock();
            for (auto &s : subdirs)
                jobs.push_back(std::move(s));
            --busy;
            if (progress && since.elapsed() > 500) {
                since.restart();
                progress();
            }
            cv.notify_all();
        }
    }
    void read(quint32 entry, const std::string &path, std::vector<std::pair<quint32, std::string>> &subdirs)
    {
        const int fd = ::open(path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
        if (fd < 0)
            return;
        struct stat st;
        if (fstat(fd, &st) != 0 || st.st_dev != tree.dev) {
            ::close(fd);
            WriteLock w(lock ? lock : &own);
            tree.flags[entry] |= IsMount; // another filesystem: not walked
            return;
        }
        const int wd = inotify >= 0 ? inotify_add_watch(inotify, path.c_str(), WatchMask) : -1;
        struct Item {
            quint32 at, len;
            bool dir;
            std::string tags;
        };
        std::string names;
        std::vector<Item> items;
        alignas(8) char buffer[32 * 1024];
        for (;;) {
            const long n = syscall(SYS_getdents64, fd, buffer, sizeof buffer);
            if (n <= 0) {
                if (n < 0 && errno == EINTR)
                    continue;
                break;
            }
            for (long offset = 0; offset < n;) {
                const auto *d = reinterpret_cast<const Dirent64 *>(buffer + offset);
                offset += d->reclen;
                if (hidden(d->name))
                    continue;
                bool dir = d->type == DT_DIR;
                if (d->type == DT_UNKNOWN) {
                    struct stat s;
                    dir = fstatat(fd, d->name, &s, AT_SYMLINK_NOFOLLOW) == 0 && S_ISDIR(s.st_mode);
                }
                const size_t len = std::strlen(d->name);
                items.push_back({quint32(names.size()), quint32(len), dir, readTags ? tagsAt(fd, d->name) : std::string()});
                names.append(d->name, len + 1);
            }
        }
        ::close(fd);
        WriteLock w(lock ? lock : &own);
        auto &folder = tree.folders[entry];
        folder.first = quint32(tree.size());
        folder.count = quint32(items.size());
        folder.wd = wd;
        folder.stamp = stampOf(st);
        tree.wds.set(wd, entry);
        const bool more = tree.size() < limit;
        for (const Item &item : items) {
            const quint32 e = tree.append(entry, names.data() + item.at, item.len, item.dir ? IsDir : 0, tree.intern(item.tags));
            if (item.dir && more)
                subdirs.emplace_back(e, (path == "/" ? std::string() : path) + '/' + (names.data() + item.at));
        }
    }
};

// The next place needle is in [s, s + n): the first and last bytes of the
// needle compared 32 (or 16) places at a time, the middle checked only
// where both match (W. Muła's SIMD substring search). memmem otherwise.
#if defined(__x86_64__)
__attribute__((target("avx2"))) const char *findAvx2(const char *s, size_t n, const char *needle, size_t k)
{
    const __m256i first = _mm256_set1_epi8(needle[0]), last = _mm256_set1_epi8(needle[k - 1]);
    size_t i = 0;
    for (; i + k - 1 + 32 <= n; i += 32) {
        const __m256i a = _mm256_loadu_si256(reinterpret_cast<const __m256i *>(s + i));
        const __m256i b = _mm256_loadu_si256(reinterpret_cast<const __m256i *>(s + i + k - 1));
        auto mask = quint32(_mm256_movemask_epi8(_mm256_and_si256(_mm256_cmpeq_epi8(a, first), _mm256_cmpeq_epi8(b, last))));
        for (; mask; mask &= mask - 1) {
            const size_t at = i + size_t(__builtin_ctz(mask));
            if (std::memcmp(s + at + 1, needle + 1, k - 2) == 0)
                return s + at;
        }
    }
    return static_cast<const char *>(memmem(s + i, n - i, needle, k));
}

const char *findSse2(const char *s, size_t n, const char *needle, size_t k)
{
    const __m128i first = _mm_set1_epi8(needle[0]), last = _mm_set1_epi8(needle[k - 1]);
    size_t i = 0;
    for (; i + k - 1 + 16 <= n; i += 16) {
        const __m128i a = _mm_loadu_si128(reinterpret_cast<const __m128i *>(s + i));
        const __m128i b = _mm_loadu_si128(reinterpret_cast<const __m128i *>(s + i + k - 1));
        auto mask = quint32(_mm_movemask_epi8(_mm_and_si128(_mm_cmpeq_epi8(a, first), _mm_cmpeq_epi8(b, last))));
        for (; mask; mask &= mask - 1) {
            const size_t at = i + size_t(__builtin_ctz(mask));
            if (std::memcmp(s + at + 1, needle + 1, k - 2) == 0)
                return s + at;
        }
    }
    return static_cast<const char *>(memmem(s + i, n - i, needle, k));
}
#endif

const char *find(const char *s, size_t n, const std::string &needle)
{
    const size_t k = needle.size();
    if (k == 1)
        return static_cast<const char *>(std::memchr(s, needle[0], n));
#if defined(__x86_64__)
    static const bool avx2 = __builtin_cpu_supports("avx2");
    return avx2 ? findAvx2(s, n, needle.data(), k) : findSse2(s, n, needle.data(), k);
#else
    return static_cast<const char *>(memmem(s, n, needle.data(), k));
#endif
}

// Finds a word in names: the hit's row by galloping from the last one,
// since hits come in row order.
quint32 rowOf(const Tree &t, size_t offset, quint32 from)
{
    const auto n = quint32(t.name.size());
    quint32 lo = from, step = 1;
    while (lo + step < n && t.name[lo + step] <= offset) {
        lo += step;
        step *= 2;
    }
    const auto end = t.name.begin() + std::min<size_t>(n, size_t(lo) + step + 1);
    return quint32(std::upper_bound(t.name.begin() + lo, end, quint32(offset)) - t.name.begin()) - 1;
}

bool boundary(char c)
{
    return c == ' ' || c == '-' || c == '_' || c == '.' || c == '(' || c == '[';
}

// The best `limit` matches, in row order: those where the word starts the
// name or a word in it first, then the rest. Rows are in breadth-first order
// (shallower items first), so the scan stops once it has enough of the best.
Index::Result search(const Tree &t, const Index::Query &q, quint32 scope)
{
    QElapsedTimer clock;
    clock.start();
    Index::Result result;
    const auto limit = size_t(std::max(q.limit, 1));
    std::vector<quint32> best, rest;
    size_t pos = 1; // past the root's empty name
    auto inScope = [&](quint32 e) {
        if (scope == 0)
            return true;
        for (quint32 i = t.parent[e]; i != None; i = t.parent[i])
            if (i == scope)
                return true;
        return false;
    };
    if (!q.tag.isEmpty()) {
        std::vector<bool> want(t.tagSets.size());
        for (size_t i = 1; i < t.tagSets.size(); ++i)
            for (const QString &name : QString::fromUtf8(t.tagSets[i]).split(QLatin1Char(',')))
                if (name.trimmed().compare(q.tag, Qt::CaseInsensitive) == 0)
                    want[i] = true;
        for (quint32 e = 1; e < t.size() && best.size() < limit; ++e)
            if (t.tags[e] && want[t.tags[e]] && !(t.flags[e] & IsGone) && inScope(e)) {
                best.push_back(e);
                ++result.total;
            }
    } else {
        std::vector<std::string> words;
        for (const QString &w : q.words)
            if (const std::string f = Index::fold(w); !f.empty())
                words.push_back(f);
        if (words.empty())
            return result;
        std::sort(words.begin(), words.end(), [](const auto &a, const auto &b) { return a.size() > b.size(); });
        const std::string &first = words.front();
        const char *base = t.folded.data();
        const size_t size = t.folded.size();
        quint32 row = 0;
        while (pos < size) {
            const char *hit = find(base + pos, size - pos, first);
            if (!hit)
                break;
            row = rowOf(t, size_t(hit - base), row);
            pos = row + 1 < t.name.size() ? t.name[row + 1] : size;
            if (t.flags[row] & IsGone)
                continue;
            const char *name = base + t.name[row];
            bool all = true;
            for (size_t w = 1; w < words.size() && all; ++w)
                all = std::strstr(name, words[w].c_str()) != nullptr;
            if (!all || !inScope(row))
                continue;
            ++result.total;
            if (hit == name || boundary(hit[-1])) {
                best.push_back(row);
                if (best.size() >= limit)
                    break;
            } else if (rest.size() < limit) {
                rest.push_back(row);
            }
        }
    }
    result.capped = best.size() + rest.size() > limit || (best.size() >= limit && pos < t.folded.size());
    if (best.size() < limit)
        best.insert(best.end(), rest.begin(), rest.begin() + std::ptrdiff_t(std::min(rest.size(), limit - best.size())));
    result.paths.reserve(best.size());
    result.dirs.reserve(best.size());
    for (const quint32 row : best) {
        result.paths.push_back(t.path(row));
        result.dirs.push_back(t.flags[row] & IsDir);
    }
    result.ms = clock.nsecsElapsed() / 1e6;
    return result;
}

}

struct Index::Core {
    Index *q;
    mutable std::shared_mutex lock;
    Tree tree;
    std::atomic<bool> ready{false};
    std::atomic<bool> stop{false};
    std::atomic<bool> started{false};
    bool save = true;
    bool dirty = false;
    Stats stats;
    std::string root;

    QThread thread;
    QObject *home = nullptr; // on the thread: its timers and the notifier
    QSocketNotifier *notifier = nullptr;
    QTimer *settle = nullptr, *saveLater = nullptr, *rescanLater = nullptr;

    // A folder the index doesn't cover, walked for queries in it.
    mutable std::mutex scratchLock;
    mutable std::unique_ptr<Tree> scratch;
    mutable QElapsedTimer scratchAge;

    QString snapshotPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/ambrosia/files/index");
    }
    int threads() const { return int(std::clamp(std::thread::hardware_concurrency() / 2, 1u, 4u)); }

    void begin();
    void walkAll(Tree &t, std::shared_mutex *lk);
    bool load();
    void check();
    void reread(quint32 e, const std::string &path, qint64 stamp, std::vector<std::pair<quint32, std::string>> &toWalk);
    void listen();
    void events();
    void remove(quint32 e);
    void move(quint32 source, quint32 dir, const std::string &name);
    void touched();
    void rescan();
    void write();
};

void Index::Core::begin()
{
    background();
    settle = new QTimer(home);
    settle->setSingleShot(true);
    settle->setInterval(100);
    QObject::connect(settle, &QTimer::timeout, home, [this] { Q_EMIT q->changed(); });
    saveLater = new QTimer(home);
    saveLater->setSingleShot(true);
    saveLater->setInterval(60000);
    QObject::connect(saveLater, &QTimer::timeout, home, [this] { write(); });
    rescanLater = new QTimer(home);
    rescanLater->setSingleShot(true);
    rescanLater->setInterval(5000);
    QObject::connect(rescanLater, &QTimer::timeout, home, [this] { rescan(); });

    QElapsedTimer clock;
    clock.start();
    tree.setRoot(root);
    if (load()) {
        {
            WriteLock w(&lock);
            stats.loadMs = clock.nsecsElapsed() / 1e6;
            stats.fromSnapshot = true;
        }
        ready = true;
        Q_EMIT q->readyChanged();
        Q_EMIT q->changed();
        clock.restart();
        check();
        if (stop)
            return;
        WriteLock w(&lock);
        stats.checkMs = clock.nsecsElapsed() / 1e6;
    } else {
        tree.inotify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
        walkAll(tree, &lock);
        if (stop)
            return; // half a walk isn't saved
        {
            WriteLock w(&lock);
            tree.shrink();
            stats.walkMs = clock.nsecsElapsed() / 1e6;
        }
        ready = true;
        Q_EMIT q->readyChanged();
        Q_EMIT q->changed();
        write();
    }
    if (dirty)
        write();
    // What loading or walking freed (the snapshot's bytes, grown arrays)
    // goes back to the system rather than staying in the heap.
    malloc_trim(0);
    listen();
}

void Index::Core::walkAll(Tree &t, std::shared_mutex *lk)
{
    Walk walk{t, lk, t.inotify, stop};
    walk.progress = [this] { Q_EMIT q->changed(); };
    walk.run({{0, t.root}}, threads());
}

void Index::Core::listen()
{
    delete notifier;
    notifier = nullptr;
    if (tree.inotify < 0)
        return;
    notifier = new QSocketNotifier(tree.inotify, QSocketNotifier::Read, home);
    QObject::connect(notifier, &QSocketNotifier::activated, home, [this] { events(); });
}

void Index::Core::touched()
{
    dirty = true;
    if (!settle->isActive())
        settle->start();
    if (!saveLater->isActive())
        saveLater->start();
    // Rows of gone items pile up: past a quarter, read it all again.
    if (tree.gone > 50000 && tree.gone * 4 > tree.size() && !rescanLater->isActive())
        rescanLater->start();
}

void Index::Core::events()
{
    struct Event {
        int wd;
        uint32_t mask, cookie;
        std::string name;
    };
    std::vector<Event> list;
    alignas(inotify_event) char buffer[64 * 1024];
    for (;;) {
        const ssize_t n = ::read(tree.inotify, buffer, sizeof buffer);
        if (n <= 0)
            break;
        for (char *p = buffer; p < buffer + n;) {
            const auto *ev = reinterpret_cast<const inotify_event *>(p);
            list.push_back({ev->wd, ev->mask, ev->cookie, ev->len ? std::string(ev->name) : std::string()});
            p += sizeof(inotify_event) + ev->len;
        }
    }
    if (list.empty())
        return;
    bool any = false, overflow = false;
    std::unordered_map<uint32_t, quint32> moving; // cookie → the row moved away
    std::vector<std::pair<quint32, std::string>> toWalk;
    {
        WriteLock w(&lock);
        for (const Event &ev : list) {
            if (ev.mask & IN_Q_OVERFLOW) {
                overflow = true;
                continue;
            }
            const quint32 dir = tree.wds.find(ev.wd);
            if (dir == None)
                continue;
            if (ev.mask & IN_IGNORED) {
                const auto f = tree.folders.find(dir);
                if (f != tree.folders.end() && f->second.wd == ev.wd)
                    f->second.wd = -1;
                tree.wds.erase(ev.wd);
                continue;
            }
            // The folder's own changes come with a name in its parent's.
            if (ev.name.empty() || hidden(ev.name.c_str()))
                continue;
            const quint32 e = tree.child(dir, ev.name.c_str());
            if (ev.mask & IN_MOVED_FROM) {
                if (e != None)
                    moving[ev.cookie] = e;
            } else if (ev.mask & IN_DELETE) {
                if (e != None) {
                    remove(e);
                    any = true;
                }
            } else if (ev.mask & IN_ATTRIB) {
                if (e != None) {
                    const quint16 tag = tree.intern(tagsOfPath(tree.path(e)));
                    if (tag != tree.tags[e]) {
                        tree.tags[e] = tag;
                        any = true;
                    }
                }
            } else if (ev.mask & (IN_CREATE | IN_MOVED_TO)) {
                const bool isDir = ev.mask & IN_ISDIR;
                const auto from = ev.mask & IN_MOVED_TO ? moving.find(ev.cookie) : moving.end();
                if (from != moving.end()) {
                    const quint32 source = from->second;
                    moving.erase(from);
                    if (e != source) {
                        if (e != None)
                            remove(e); // replaced
                        move(source, dir, ev.name);
                        any = true;
                    }
                    continue;
                }
                if (e != None) {
                    if (!(ev.mask & IN_MOVED_TO) && bool(tree.flags[e] & IsDir) == isDir)
                        continue; // already read
                    remove(e);
                }
                const std::string path = tree.path(dir) + '/' + ev.name;
                const quint32 n = tree.append(dir, ev.name.data(), ev.name.size(), isDir ? IsDir : 0, tree.intern(tagsOfPath(path)));
                tree.added.emplace(dir, n);
                if (isDir)
                    toWalk.emplace_back(n, path);
                any = true;
            }
        }
        // Moved out of the home, or to a hidden name.
        for (const auto &[cookie, e] : moving) {
            remove(e);
            any = true;
        }
    }
    if (!toWalk.empty()) {
        Walk walk{tree, &lock, tree.inotify, stop};
        walk.run(std::move(toWalk), 2);
        any = true;
    }
    if (overflow && !rescanLater->isActive())
        rescanLater->start();
    if (any)
        touched();
}

void Index::Core::remove(quint32 e)
{
    std::vector<quint32> stack{e};
    while (!stack.empty()) {
        const quint32 i = stack.back();
        stack.pop_back();
        if (i == 0 || (tree.flags[i] & IsGone))
            continue;
        tree.flags[i] |= IsGone;
        ++tree.gone;
        if (!(tree.flags[i] & IsDir))
            continue;
        tree.eachChild(i, [&](quint32 c) { stack.push_back(c); });
        const auto f = tree.folders.find(i);
        if (f != tree.folders.end()) {
            if (f->second.wd >= 0) {
                inotify_rm_watch(tree.inotify, f->second.wd);
                tree.wds.erase(f->second.wd);
            }
            tree.folders.erase(f);
        }
        tree.added.erase(i);
    }
}

// A rename or a move within the home: a new row under the new name (rows'
// names stay in order), which takes over a folder's children and watch.
void Index::Core::move(quint32 source, quint32 dir, const std::string &name)
{
    const quint32 n = tree.append(dir, name.data(), name.size(), tree.flags[source] & (IsDir | IsMount), tree.tags[source]);
    tree.added.emplace(dir, n);
    tree.flags[source] |= IsGone;
    ++tree.gone;
    if (!(tree.flags[source] & IsDir))
        return;
    std::vector<quint32> kids;
    tree.eachChild(source, [&](quint32 c) { kids.push_back(c); });
    for (const quint32 c : kids)
        tree.parent[c] = n;
    std::vector<quint32> later;
    auto [a, b] = tree.added.equal_range(source);
    for (; a != b; ++a)
        later.push_back(a->second);
    tree.added.erase(source);
    for (const quint32 c : later)
        tree.added.emplace(n, c);
    const auto f = tree.folders.find(source);
    if (f != tree.folders.end()) {
        const Tree::Folder folder = f->second;
        tree.folders.erase(f);
        tree.folders[n] = folder;
        if (folder.wd >= 0)
            tree.wds.set(folder.wd, n);
    }
}

// inotify lost events: the whole home again, into a new tree that replaces
// this one when it's read.
void Index::Core::rescan()
{
    Tree fresh;
    fresh.setRoot(root);
    fresh.inotify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    Walk walk{fresh, nullptr, fresh.inotify, stop};
    walk.run({{0, fresh.root}}, threads());
    if (stop) {
        ::close(fresh.inotify);
        return;
    }
    delete notifier;
    notifier = nullptr;
    fresh.shrink();
    {
        WriteLock w(&lock);
        std::swap(tree, fresh);
    }
    if (fresh.inotify >= 0)
        ::close(fresh.inotify);
    listen();
    touched();
}

void Index::Core::reread(quint32 e, const std::string &path, qint64 stamp, std::vector<std::pair<quint32, std::string>> &toWalk)
{
    const int fd = ::open(path.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0)
        return;
    struct Item {
        std::string name;
        bool dir;
        std::string tags;
    };
    std::vector<Item> items;
    alignas(8) char buffer[32 * 1024];
    for (;;) {
        const long n = syscall(SYS_getdents64, fd, buffer, sizeof buffer);
        if (n <= 0)
            break;
        for (long offset = 0; offset < n;) {
            const auto *d = reinterpret_cast<const Dirent64 *>(buffer + offset);
            offset += d->reclen;
            if (hidden(d->name))
                continue;
            bool dir = d->type == DT_DIR;
            if (d->type == DT_UNKNOWN) {
                struct stat s;
                dir = fstatat(fd, d->name, &s, AT_SYMLINK_NOFOLLOW) == 0 && S_ISDIR(s.st_mode);
            }
            items.push_back({d->name, dir, readTags ? tagsAt(fd, d->name) : std::string()});
        }
    }
    ::close(fd);
    WriteLock w(&lock);
    std::unordered_map<std::string, quint32> now;
    tree.eachChild(e, [&](quint32 c) { now.emplace(tree.nameOf(c), c); });
    for (const Item &item : items) {
        const auto it = now.find(item.name);
        if (it != now.end()) {
            const quint32 c = it->second;
            now.erase(it);
            if (bool(tree.flags[c] & IsDir) == item.dir) {
                tree.tags[c] = tree.intern(item.tags);
                continue;
            }
            remove(c);
        }
        const quint32 n = tree.append(e, item.name.data(), item.name.size(), item.dir ? IsDir : 0, tree.intern(item.tags));
        tree.added.emplace(e, n);
        if (item.dir)
            toWalk.emplace_back(n, path + '/' + item.name);
    }
    for (const auto &[name, c] : now)
        remove(c);
    tree.folders[e].stamp = stamp;
    dirty = true;
}

// After a snapshot: watch every folder again, and read again the ones
// whose mtime or ctime moved since it was saved (updatedb's rule).
void Index::Core::check()
{
    tree.inotify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    std::vector<quint32> dirs;
    dirs.reserve(tree.folders.size());
    for (const auto &[e, folder] : tree.folders)
        dirs.push_back(e);
    std::sort(dirs.begin(), dirs.end());
    std::vector<std::pair<quint32, std::string>> toWalk;
    bool any = false;
    for (const quint32 e : dirs) {
        if (stop)
            return;
        if (tree.flags[e] & IsGone)
            continue;
        const std::string path = tree.path(e);
        const int wd = inotify_add_watch(tree.inotify, path.c_str(), WatchMask);
        struct stat st;
        if (wd < 0 || ::stat(path.c_str(), &st) != 0 || st.st_dev != tree.dev) {
            WriteLock w(&lock);
            remove(e);
            any = true;
            continue;
        }
        {
            WriteLock w(&lock);
            auto &folder = tree.folders[e];
            folder.wd = wd;
            tree.wds.set(wd, e);
        }
        if (const auto f = tree.folders.find(e); f != tree.folders.end() && stampOf(st) != f->second.stamp) {
            reread(e, path, stampOf(st), toWalk);
            any = true;
        }
    }
    if (!toWalk.empty()) {
        Walk walk{tree, &lock, tree.inotify, stop};
        walk.run(std::move(toWalk), threads());
    }
    if (any)
        touched();
}

namespace {

const char Magic[8] = {'A', 'M', 'B', 'I', 'D', 'X', '0', '1'};

struct Writer {
    QSaveFile &f;
    void raw(const void *p, size_t n) { f.write(static_cast<const char *>(p), qint64(n)); }
    void u64(quint64 v) { raw(&v, 8); }
    void str(const std::string &s) { u64(s.size()); raw(s.data(), s.size()); }
    template<typename T>
    void vec(const std::vector<T> &v) { u64(v.size()); raw(v.data(), v.size() * sizeof(T)); }
};

struct Reader {
    const char *p, *end;
    bool ok = true;
    bool raw(void *out, size_t n)
    {
        if (!ok || size_t(end - p) < n)
            return ok = false;
        std::memcpy(out, p, n);
        p += n;
        return true;
    }
    quint64 u64()
    {
        quint64 v = 0;
        raw(&v, 8);
        return v;
    }
    std::string str()
    {
        const quint64 n = u64();
        if (!ok || quint64(end - p) < n) {
            ok = false;
            return {};
        }
        std::string s(p, size_t(n));
        p += n;
        return s;
    }
    template<typename T>
    void vec(std::vector<T> &v)
    {
        const quint64 n = u64();
        if (!ok || quint64(end - p) / sizeof(T) < n) {
            ok = false;
            return;
        }
        v.resize(size_t(n));
        raw(v.data(), size_t(n) * sizeof(T));
    }
};

}

void Index::Core::write()
{
    if (!save)
        return;
    // Gone items' rows go first, from memory and from the snapshot.
    if (tree.gone > 0) {
        WriteLock w(&lock);
        tree.compact();
        tree.shrink();
    }
    saveLater->stop();
    const QString path = snapshotPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    Writer out{file};
    out.raw(Magic, sizeof Magic);
    out.str(tree.root);
    out.u64(quint64(tree.dev));
    out.str(tree.folded);
    out.str(tree.originals);
    out.vec(tree.name);
    out.vec(tree.orig);
    out.vec(tree.parent);
    out.vec(tree.flags);
    out.vec(tree.tags);
    out.u64(tree.tagSets.size());
    for (const std::string &s : tree.tagSets)
        out.str(s);
    out.u64(tree.folders.size());
    for (const auto &[e, f] : tree.folders) {
        const quint32 v[3] = {e, f.first, f.count};
        out.raw(v, sizeof v);
        out.raw(&f.stamp, 8);
    }
    out.u64(tree.added.size());
    for (const auto &[dir, e] : tree.added) {
        const quint32 v[2] = {dir, e};
        out.raw(v, sizeof v);
    }
    out.u64(tree.gone);
    if (file.commit())
        dirty = false;
}

bool Index::Core::load()
{
    QFile file(snapshotPath());
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QByteArray data = file.readAll();
    Reader in{data.constData(), data.constData() + data.size()};
    char magic[8];
    if (!in.raw(magic, 8) || std::memcmp(magic, Magic, 8) != 0)
        return false;
    Tree t;
    t.setRoot(root);
    if (in.str() != t.root || in.u64() != quint64(t.dev))
        return false;
    t.folded = in.str();
    t.originals = in.str();
    in.vec(t.name);
    in.vec(t.orig);
    in.vec(t.parent);
    in.vec(t.flags);
    in.vec(t.tags);
    t.tagSets.resize(size_t(std::min<quint64>(in.u64(), 0xffff)));
    for (std::string &s : t.tagSets)
        s = in.str();
    const size_t rows = t.name.size();
    if (!in.ok || rows == 0 || t.orig.size() != rows || t.parent.size() != rows || t.flags.size() != rows || t.tags.size() != rows
        || t.tagSets.empty())
        return false;
    for (size_t i = 1; i < t.tagSets.size(); ++i)
        t.tagIds.emplace(t.tagSets[i], quint16(i));
    for (quint64 n = in.u64(); in.ok && n > 0; --n) {
        quint32 v[3];
        qint64 stamp = 0;
        in.raw(v, sizeof v);
        in.raw(&stamp, 8);
        if (v[0] >= rows || quint64(v[1]) + v[2] > rows)
            return false;
        t.folders[v[0]] = {v[1], v[2], -1, stamp};
    }
    for (quint64 n = in.u64(); in.ok && n > 0; --n) {
        quint32 v[2];
        in.raw(v, sizeof v);
        if (v[0] >= rows || v[1] >= rows)
            return false;
        t.added.emplace(v[0], v[1]);
    }
    t.gone = size_t(in.u64());
    if (!in.ok)
        return false;
    for (size_t i = 0; i < rows; ++i)
        if ((t.parent[i] != None && t.parent[i] >= rows) || t.name[i] >= t.folded.size() || (t.orig[i] != None && t.orig[i] >= t.originals.size())
            || t.tags[i] >= t.tagSets.size())
            return false;
    t.compact();
    t.shrink();
    WriteLock w(&lock);
    tree = std::move(t);
    return true;
}

Index *Index::instance()
{
    static Index *index = new Index; // lives as long as the process
    return index;
}

Index::Index()
    : d(std::make_unique<Core>())
{
    d->q = this;
    const QByteArray root = qgetenv("FILES_INDEX_ROOT");
    d->root = QFile::encodeName(root.isEmpty() ? QDir::homePath() : QDir::cleanPath(QString::fromLocal8Bit(root))).toStdString();
    d->home = new QObject;
    d->home->moveToThread(&d->thread);
    d->thread.setObjectName(QStringLiteral("files-index"));
    connect(qApp, &QCoreApplication::aboutToQuit, this, &Index::stop);
}

Index::~Index() = default;

void Index::stop()
{
    if (!d->started || !d->thread.isRunning())
        return;
    d->stop = true;
    QMetaObject::invokeMethod(
        d->home, [this] {
            if (d->dirty && d->ready)
                d->write();
        },
        Qt::BlockingQueuedConnection);
    d->thread.quit();
    d->thread.wait(3000);
}

void Index::start(bool save)
{
    if (d->started.exchange(true))
        return;
    d->save = save;
    d->thread.start();
    QMetaObject::invokeMethod(d->home, [this] { d->begin(); }, Qt::QueuedConnection);
}

bool Index::ready() const
{
    return d->ready;
}

QString Index::root() const
{
    return QFile::decodeName(QByteArray::fromStdString(d->root));
}

bool Index::covers(const QString &path) const
{
    const std::string p = QFile::encodeName(QDir::cleanPath(path)).toStdString();
    const std::string &root = d->root;
    if (p == root)
        return true;
    const std::string prefix = root == "/" ? std::string() : root;
    if (p.compare(0, prefix.size(), prefix) != 0 || p.size() <= prefix.size() || p[prefix.size()] != '/')
        return false;
    return p.find("/.", prefix.size()) == std::string::npos;
}

Index::Result Index::find(const Query &query) const
{
    const std::string scope = query.scope.isEmpty() ? std::string() : QFile::encodeName(QDir::cleanPath(query.scope)).toStdString();
    if (!scope.empty() && !covers(query.scope)) {
        // Somewhere not indexed (another drive, a hidden folder): walked
        // once, kept for queries in it while they keep coming.
        std::lock_guard g(d->scratchLock);
        if (!d->scratch || d->scratch->root != scope || d->scratchAge.elapsed() > 30000) {
            auto t = std::make_unique<Tree>();
            t->setRoot(scope);
            Walk walk{*t, nullptr, -1, d->stop};
            walk.limit = 1000000;
            walk.run({{0, scope}}, d->threads());
            d->scratch = std::move(t);
        }
        d->scratchAge.start();
        Result r = search(*d->scratch, query, 0);
        r.ready = true;
        return r;
    }
    if (!d->started)
        const_cast<Index *>(this)->start();
    std::shared_lock r(d->lock);
    const quint32 at = scope.empty() ? 0 : d->tree.lookup(scope);
    if (at == None)
        return {};
    Result result = search(d->tree, query, at);
    result.ready = d->ready;
    return result;
}

std::string Index::fold(const QString &text)
{
    const QString decomposed = text.normalized(QString::NormalizationForm_KD);
    QString out;
    out.reserve(decomposed.size());
    for (const QChar c : decomposed)
        if (c.category() != QChar::Mark_NonSpacing)
            out.append(c);
    return out.toCaseFolded().toStdString();
}

Index::Stats Index::stats() const
{
    std::shared_lock r(d->lock);
    Stats s = d->stats;
    s.entries = d->tree.size() - d->tree.gone;
    s.dirs = d->tree.folders.size();
    s.gone = d->tree.gone;
    s.bytes = d->tree.bytes();
    s.watches = d->tree.wds.size();
    return s;
}
