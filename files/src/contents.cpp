#include "contents.h"

#include <QElapsedTimer>
#include <QFile>

#include <algorithm>
#include <cerrno>
#include <cstring>

#include <dirent.h>
#include <fcntl.h>
#include <sys/resource.h>
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

constexpr off_t MaxSize = 8 << 20;
constexpr size_t Chunk = 256 << 10;

inline char lower(char c)
{
    return c >= 'A' && c <= 'Z' ? char(c + 32) : c;
}

// Opens without touching the access time where the item is the user's own
// (O_NOATIME needs ownership), and as usual otherwise.
int openQuiet(int dirfd, const char *name, int flags)
{
    int fd = openat(dirfd, name, flags | O_NOATIME | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0 && errno == EPERM)
        fd = openat(dirfd, name, flags | O_CLOEXEC | O_NOFOLLOW);
    return fd;
}

struct Searcher {
    std::string needle;
    const std::atomic<bool> &stop;
    int limitMs;
    size_t maxHits;
    const std::function<void(std::vector<std::string> &&)> &found;
    QElapsedTimer clock, sinceFlush;
    size_t hits = 0;
    std::vector<std::string> batch;
    std::vector<char> buffer;

    bool over() const
    {
        return stop.load(std::memory_order_relaxed) || hits >= maxHits || (limitMs > 0 && clock.elapsed() > limitMs);
    }

    void flush()
    {
        if (!batch.empty())
            found(std::exchange(batch, {}));
        sinceFlush.restart();
    }

    bool has(int dirfd, const char *name)
    {
        const int fd = openQuiet(dirfd, name, O_RDONLY | O_NONBLOCK);
        if (fd < 0)
            return false;
        struct stat st;
        if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size == 0 || st.st_size > MaxSize) {
            ::close(fd);
            return false;
        }
        const size_t k = needle.size();
        size_t keep = 0;
        bool first = true, hit = false;
        for (;;) {
            const ssize_t n = ::read(fd, buffer.data() + keep, Chunk);
            if (n <= 0)
                break;
            // A NUL near the start: a binary file, which rg skips too.
            if (first && memchr(buffer.data() + keep, 0, std::min<size_t>(size_t(n), 8192)))
                break;
            first = false;
            const size_t len = keep + size_t(n);
            std::transform(buffer.begin() + keep, buffer.begin() + len, buffer.begin() + keep, lower);
            if (memmem(buffer.data(), len, needle.data(), k)) {
                hit = true;
                break;
            }
            keep = std::min(len, k - 1);
            memmove(buffer.data(), buffer.data() + len - keep, keep);
            if (over())
                break;
        }
        ::close(fd);
        return hit;
    }

    void walk(const std::string &path)
    {
        if (over())
            return;
        const int fd = openQuiet(AT_FDCWD, path.c_str(), O_RDONLY | O_DIRECTORY);
        if (fd < 0)
            return;
        std::vector<std::string> dirs;
        alignas(8) char names[32 * 1024];
        for (;;) {
            const long n = syscall(SYS_getdents64, fd, names, sizeof names);
            if (n <= 0)
                break;
            for (long offset = 0; offset < n && !over();) {
                const auto *d = reinterpret_cast<const Dirent64 *>(names + offset);
                offset += d->reclen;
                // Hidden items, and the folders rg's ignore files usually leave out.
                if (d->name[0] == '.' || !strcmp(d->name, "node_modules") || !strcmp(d->name, "__pycache__"))
                    continue;
                unsigned char type = d->type;
                if (type == DT_UNKNOWN) {
                    struct stat st;
                    if (fstatat(fd, d->name, &st, AT_SYMLINK_NOFOLLOW) != 0)
                        continue;
                    type = S_ISDIR(st.st_mode) ? DT_DIR : S_ISREG(st.st_mode) ? DT_REG : DT_LNK;
                }
                if (type == DT_DIR) {
                    dirs.push_back(path + '/' + d->name);
                } else if (type == DT_REG && has(fd, d->name)) {
                    batch.push_back(path + '/' + d->name);
                    ++hits;
                }
            }
            if (over())
                break;
        }
        ::close(fd);
        if (sinceFlush.elapsed() > 100 || batch.size() >= 64)
            flush();
        std::sort(dirs.begin(), dirs.end());
        for (const std::string &dir : dirs)
            walk(dir);
    }
};

}

void Contents::search(const QString &text, const QStringList &dirs, const std::atomic<bool> &stop, int limitMs, size_t maxHits,
                      const std::function<void(std::vector<std::string> &&)> &found)
{
    std::string needle = text.toUtf8().toStdString();
    std::transform(needle.begin(), needle.end(), needle.begin(), lower);
    if (needle.empty())
        return;
    // Gentle on the disk and the processor: this thread only.
    setpriority(PRIO_PROCESS, gettid(), 15);
    syscall(SYS_ioprio_set, 1 /* IOPRIO_WHO_PROCESS */, 0, 3 << 13 /* IOPRIO_CLASS_IDLE */);
    Searcher s{needle, stop, limitMs, maxHits, found, {}, {}, 0, {}, std::vector<char>(Chunk + needle.size())};
    s.clock.start();
    s.sinceFlush.start();
    for (const QString &dir : dirs)
        s.walk(QFile::encodeName(dir).toStdString());
    s.flush();
}
