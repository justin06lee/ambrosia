// --bench-search: times the index and searches (plan targets 7, 8 and 14),
// with no window. Environment:
//   FILES_INDEX_ROOT     the folder to index (the home by default)
//   FILES_INDEX_NOSAVE=1 don't write the snapshot
//   FILES_BENCH_CONTENT  a folder to time content search (rg) in
//   FILES_BENCH_TOUCH    a writable folder in the index, to time how soon
//                        a new, renamed and deleted file shows in searches
#include "foldermodel.h"
#include "index.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QThread>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>
#include <cstdio>
#include <functional>

#include <unistd.h>

namespace {

double rssMb()
{
    QFile status(QStringLiteral("/proc/self/status"));
    if (!status.open(QIODevice::ReadOnly))
        return 0;
    for (const QByteArray &line : status.readAll().split('\n'))
        if (line.startsWith("VmRSS:"))
            return line.mid(6).trimmed().split(' ').value(0).toDouble() / 1024;
    return 0;
}

bool waitFor(const std::function<bool()> &done, int timeoutMs)
{
    QElapsedTimer clock;
    clock.start();
    while (!done()) {
        if (clock.elapsed() > timeoutMs)
            return false;
        QCoreApplication::processEvents(QEventLoop::AllEvents, 2);
        QThread::usleep(200);
    }
    return true;
}

double ms(const QElapsedTimer &clock)
{
    return clock.nsecsElapsed() / 1e6;
}

bool finds(const QString &name)
{
    Index::Query q;
    q.words = {name};
    for (const std::string &p : Index::instance()->find(q).paths)
        if (QFile::decodeName(p.c_str()).endsWith(QLatin1Char('/') + name))
            return true;
    return false;
}

}

int benchSearch(const QStringList &queries)
{
    Index *index = Index::instance();
    const double rss0 = rssMb();
    QElapsedTimer clock;
    clock.start();
    index->start(qEnvironmentVariableIntValue("FILES_INDEX_NOSAVE") == 0);
    if (!waitFor([&] { return index->ready(); }, 30 * 60 * 1000)) {
        std::printf("index: not ready after 30 min\n");
        return 1;
    }
    const double readyMs = ms(clock);
    // A snapshot's check runs on after it's ready: wait for it too.
    waitFor([&] { return index->stats().checkMs > 0 || !index->stats().fromSnapshot; }, 30 * 60 * 1000);
    const Index::Stats s = index->stats();
    std::printf("index: %s, root %s\n", s.fromSnapshot ? "from the snapshot" : "walked", qPrintable(index->root()));
    std::printf("index: %zu items, %zu folders, %zu watches, %zu gone; %.1f MB of arrays; RSS +%.1f MB\n", s.entries, s.dirs, s.watches, s.gone,
                s.bytes / 1048576.0, rssMb() - rss0);
    if (s.fromSnapshot)
        std::printf("index: snapshot loaded in %.1f ms (ready after %.1f ms), checked in %.1f ms\n", s.loadMs, readyMs, s.checkMs);
    else
        std::printf("index: walked in %.1f ms\n", s.walkMs);

    for (const QString &query : queries) {
        // Typing it: each prefix a keystroke.
        for (int n = 1; n <= query.size(); ++n) {
            Index::Query q;
            q.words = query.left(n).split(QLatin1Char(' '), Qt::SkipEmptyParts);
            if (q.words.isEmpty())
                continue;
            std::vector<double> times;
            size_t total = 0;
            for (int run = 0; run < 15; ++run) {
                const Index::Result r = index->find(q);
                times.push_back(r.ms);
                total = r.total;
            }
            std::sort(times.begin(), times.end());
            std::printf("find  %-24s median %6.2f ms  max %6.2f ms  %zu matches\n", qPrintable(QLatin1Char('"') + query.left(n) + QLatin1Char('"')),
                        times[times.size() / 2], times.back(), total);
        }
        // The same keystrokes through a model, as a window sees them: from
        // the URL changing to the rows (names only, so rg stays out of it).
        FolderModel model;
        bool loaded = false;
        QObject::connect(&model, &FolderModel::loaded, [&] { loaded = true; });
        for (int n = 1; n <= query.size(); ++n) {
            if (query.left(n).trimmed().isEmpty())
                continue;
            QUrl url(QStringLiteral("search:"));
            url.setQuery(QStringLiteral("mode=name&q=") + QString::fromLatin1(QUrl::toPercentEncoding(query.left(n))));
            loaded = false;
            QElapsedTimer key;
            key.start();
            model.setUrl(url);
            waitFor([&] { return loaded; }, 60000);
            std::printf("keystroke %-20s %6.2f ms to rows (index %5.2f ms)  %d rows\n", qPrintable(QLatin1Char('"') + query.left(n) + QLatin1Char('"')),
                        ms(key), model.searchMs(), model.count());
        }
        // Contents: rg as the window runs it, to its first file.
        const QString where = qEnvironmentVariable("FILES_BENCH_CONTENT");
        if (!where.isEmpty() && query.size() >= 2) {
            QProcess rg;
            rg.setProgram(QStringLiteral("rg"));
            rg.setArguments({QStringLiteral("--files-with-matches"), QStringLiteral("--null"), QStringLiteral("--fixed-strings"),
                             QStringLiteral("--ignore-case"), QStringLiteral("--no-messages"), QStringLiteral("--max-filesize"),
                             QStringLiteral("20M"), QStringLiteral("--threads"), QStringLiteral("4"), QStringLiteral("--"), query, where});
            QElapsedTimer run;
            run.start();
            rg.start();
            double first = -1;
            QByteArray out;
            waitFor(
                [&] {
                    out += rg.readAllStandardOutput();
                    if (first < 0 && out.contains('\0'))
                        first = ms(run);
                    return rg.state() == QProcess::NotRunning;
                },
                10000);
            if (rg.state() != QProcess::NotRunning) {
                rg.kill();
                rg.waitForFinished();
            }
            out += rg.readAllStandardOutput();
            std::printf("contents %-21s first file %7.1f ms, all %7.1f ms, %lld files (in %s)\n", qPrintable(QLatin1Char('"') + query + QLatin1Char('"')),
                        first, ms(run), qlonglong(out.count('\0')), qPrintable(where));
        }
    }

    // A change: how soon searches see it.
    const QString touch = qEnvironmentVariable("FILES_BENCH_TOUCH");
    if (!touch.isEmpty()) {
        const QString name = QStringLiteral("files-bench-%1.txt").arg(getpid());
        const QString renamed = QStringLiteral("files-bench-%1-renamed.txt").arg(getpid());
        QElapsedTimer change;
        QFile file(touch + QLatin1Char('/') + name);
        change.start();
        file.open(QIODevice::WriteOnly);
        file.close();
        const bool added = waitFor([&] { return finds(name); }, 5000);
        std::printf("change: new file found after %.1f ms%s\n", ms(change), added ? "" : " (not found in 5 s)");
        change.restart();
        QFile::rename(touch + QLatin1Char('/') + name, touch + QLatin1Char('/') + renamed);
        const bool moved = waitFor([&] { return finds(renamed) && !finds(name); }, 5000);
        std::printf("change: rename found after %.1f ms%s\n", ms(change), moved ? "" : " (not seen in 5 s)");
        change.restart();
        QFile::remove(touch + QLatin1Char('/') + renamed);
        const bool gone = waitFor([&] { return !finds(renamed); }, 5000);
        std::printf("change: deletion seen after %.1f ms%s\n", ms(change), gone ? "" : " (not seen in 5 s)");
        // ... and in a window showing a search for it (the index settles a
        // burst for 100 ms, the window rereads 150 ms after).
        FolderModel model;
        bool loaded = false;
        QObject::connect(&model, &FolderModel::loaded, [&] { loaded = true; });
        model.setUrl(QUrl(QStringLiteral("search:?mode=name&q=files-bench-window")));
        waitFor([&] { return loaded; }, 5000);
        const QString shown = touch + QStringLiteral("/files-bench-window-%1.txt").arg(getpid());
        change.restart();
        QFile window(shown);
        window.open(QIODevice::WriteOnly);
        window.close();
        const bool seen = waitFor([&] { return model.count() == 1; }, 5000);
        std::printf("change: new file in a search window after %.1f ms%s\n", ms(change), seen ? "" : " (not shown in 5 s)");
        change.restart();
        QFile::remove(shown);
        const bool out = waitFor([&] { return model.count() == 0; }, 5000);
        std::printf("change: deletion in a search window after %.1f ms%s\n", ms(change), out ? "" : " (not shown in 5 s)");
    }
    index->stop(); // the snapshot is written before this returns
    std::fflush(stdout);
    return 0;
}
