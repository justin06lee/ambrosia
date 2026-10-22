// --bench-thumbs DIR: times thumbnails (plan targets 9 and 10) on
// files/bench/thumbfix.sh's fixtures, with no window. It writes to the
// thumbnail cache, so it runs only with XDG_CACHE_HOME set (a scratch
// folder, never the user's cache).
//   #10: the first thumbnail of a 24 MP JPEG, with an EXIF thumbnail
//        (DIR/jpeg-exif) and without (DIR/jpeg-plain), the file cold (out
//        of the page cache) and warm, for a 64-pt icon at 2x (128 px)
//   #9:  a screenful, 40 cached thumbnails (DIR/many) through the provider
//   kinds: each of DIR/Kinds (videos, fonts, office documents, songs) made
//        directly, its file warm, by the way it was made; then all through
//        the provider, framed as icons, into the cache and again from it
#include "thumbnailer.h"

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QMap>
#include <QSemaphore>
#include <QStandardPaths>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include <fcntl.h>
#include <unistd.h>

namespace {

void evict(const QString &path)
{
    const int fd = ::open(QFile::encodeName(path).constData(), O_RDONLY | O_CLOEXEC | O_NOATIME);
    if (fd < 0)
        return;
    posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
    ::close(fd);
}

double median(std::vector<double> v)
{
    if (v.empty())
        return 0;
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

double pressure()
{
    QFile file(QStringLiteral("/proc/pressure/io"));
    if (!file.open(QIODevice::ReadOnly))
        return 0;
    return file.readLine().split(' ').value(1).mid(6).toDouble();
}

QStringList files(const QString &dir)
{
    QStringList out;
    for (const QString &name : QDir(dir).entryList(QDir::Files, QDir::Name))
        out << dir + QLatin1Char('/') + name;
    return out;
}

// Asks the provider for each path at box pixels, all at once, and waits
// for every one: the time to the last.
double round(Thumbnailer &provider, const QStringList &paths, int box, const QString &suffix = {})
{
    QSemaphore done;
    std::vector<QQuickImageResponse *> responses;
    QElapsedTimer clock;
    clock.start();
    for (const QString &path : paths) {
        const QString id = QStringLiteral("1/") + QString::fromLatin1(QUrl::toPercentEncoding(path)) + suffix;
        QQuickImageResponse *response = provider.requestImageResponse(id, QSize(box, box));
        QObject::connect(response, &QQuickImageResponse::finished, response, [&done] { done.release(); }, Qt::DirectConnection);
        responses.push_back(response);
    }
    done.acquire(int(paths.size()));
    const double ms = clock.nsecsElapsed() / 1e6;
    for (QQuickImageResponse *response : responses)
        delete response;
    return ms;
}

}

int benchThumbs(const QString &dir)
{
    const QString cache = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    if (qEnvironmentVariableIsEmpty("XDG_CACHE_HOME") || cache == QDir::homePath() + QStringLiteral("/.cache")) {
        std::fprintf(stderr, "bench-thumbs: set XDG_CACHE_HOME to a scratch folder (it writes thumbnails there)\n");
        return 2;
    }
    QDir(cache + QStringLiteral("/thumbnails")).removeRecursively();
    std::printf("cache %s, I/O pressure %.1f%%\n", qPrintable(cache), pressure());

    // #10, made directly, as the pool's threads make them.
    for (const char *group : {"jpeg-exif", "jpeg-plain"}) {
        std::vector<double> cold, warm;
        QString how;
        for (const QString &path : files(dir + QLatin1Char('/') + QLatin1String(group))) {
            evict(path);
            QElapsedTimer clock;
            clock.start();
            const QImage image = Thumbnailer::make(path, 128, &how);
            cold.push_back(clock.nsecsElapsed() / 1e6);
            clock.restart();
            Thumbnailer::make(path, 128);
            warm.push_back(clock.nsecsElapsed() / 1e6);
            if (image.isNull())
                std::printf("  failed: %s\n", qPrintable(path));
        }
        std::printf("#10 %-10s %zu files (%s): cold median %.1f ms (max %.1f), warm median %.1f ms\n", group, cold.size(),
                    qPrintable(how), median(cold), cold.empty() ? 0 : *std::max_element(cold.begin(), cold.end()), median(warm));
    }

    // #10 through the provider (queue, threads, cache write), one at a time.
    Thumbnailer provider;
    for (const char *group : {"jpeg-exif", "jpeg-plain"}) {
        std::vector<double> times;
        for (const QString &path : files(dir + QLatin1Char('/') + QLatin1String(group)))
            times.push_back(round(provider, {path}, 128));
        std::printf("#10 %-10s via the provider, warm file, uncached: median %.1f ms\n", group, median(times));
    }

    // #9: 40 made into the cache, then asked for again, cached.
    QStringList screen = files(dir + QStringLiteral("/many")).mid(0, 40);
    if (screen.size() == 40) {
        QElapsedTimer clock;
        clock.start();
        const double made = round(provider, screen, 128);
        std::printf("    40 made into the cache (12 MP, warm files): %.0f ms, I/O pressure %.1f%%\n", made, pressure());
        std::vector<double> warm, cold;
        for (int i = 0; i < 5; ++i)
            warm.push_back(round(provider, screen, 128));
        // The cache's files out of the page cache too, as after a reboot.
        for (int i = 0; i < 3; ++i) {
            for (const QString &name : QDir(cache + QStringLiteral("/thumbnails/normal")).entryList(QDir::Files))
                evict(cache + QStringLiteral("/thumbnails/normal/") + name);
            cold.push_back(round(provider, screen, 128));
        }
        std::printf("#9  40 cached: median %.1f ms (cache in memory), %.1f ms (cache on disk, cold)\n", median(warm), median(cold));
    }
    // The kinds of step 2, made directly (the median of 3, the file warm).
    const QStringList kinds = files(dir + QStringLiteral("/Kinds"));
    if (!kinds.isEmpty()) {
        QMap<QString, std::vector<double>> byHow;
        for (const QString &path : kinds) {
            std::vector<double> runs;
            QString how;
            QImage image;
            for (int i = 0; i < 3; ++i) {
                QElapsedTimer clock;
                clock.start();
                image = Thumbnailer::make(path, 128, &how);
                runs.push_back(clock.nsecsElapsed() / 1e6);
            }
            const double ms = median(runs);
            std::printf("    %-28s %-7s %6.1f ms  %s\n", qPrintable(QFileInfo(path).fileName()), qPrintable(how), ms,
                        image.isNull() ? "none (its icon)" : qPrintable(QStringLiteral("%1x%2").arg(image.width()).arg(image.height())));
            if (!image.isNull())
                byHow[how].push_back(ms);
        }
        for (auto it = byHow.cbegin(); it != byHow.cend(); ++it)
            std::printf("kinds %-7s %zu made: median %.1f ms, max %.1f ms\n", qPrintable(it.key()), it->size(), median(*it),
                        *std::max_element(it->begin(), it->end()));
        const double made = round(provider, kinds, 128, QStringLiteral("/tile"));
        std::vector<double> cached;
        for (int i = 0; i < 5; ++i)
            cached.push_back(round(provider, kinds, 128, QStringLiteral("/tile")));
        std::printf("kinds via the provider, framed: %lld into the cache in %.0f ms; then cached, %.2f ms each (median of 5 rounds)\n",
                    qint64(kinds.size()), made, median(cached) / kinds.size());
    }
    std::printf("I/O pressure at the end %.1f%%\n", pressure());
    return 0;
}
