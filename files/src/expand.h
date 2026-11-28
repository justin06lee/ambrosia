#pragma once

#include <KJob>

#include <QString>
#include <QStringList>
#include <QTimer>

#include <atomic>
#include <memory>

// Expands one archive beside itself, as a Mac's Archive Utility does: what
// the archive holds lands next to it, by itself when it is one item, in a
// folder named for the archive when it is several; a name already taken
// gets a number ("notes 2"). The archive stays. libarchive reads it (zip,
// tar and its compressed kinds, 7z, rar, cpio, and a lone file that was
// gzipped, xz'd and the like), on a thread of its own; the job reports the
// archive's bytes read so far, and can be stopped. A zip closed with a
// password is expanded with the one given; without it, or with a wrong
// one, the job fails `locked` and whoever started it asks.
class ExpandJob : public KJob
{
    Q_OBJECT

public:
    explicit ExpandJob(const QString &archive, const QString &password = QString(), QObject *parent = nullptr);

    void start() override;
    // What it made: the item, or the folder of them. Empty until it is done.
    QString made() const { return m_made; }
    // It failed for want of the right password, which can be asked for.
    bool locked() const { return m_locked; }

    struct State {
        std::atomic<bool> stop{false};
        std::atomic<qint64> read{0};
    };
    struct Result {
        bool ok = false;
        QString made;
        QString error;
        bool locked = false;
    };
    // The work itself, off the main thread (and for tests).
    static Result expand(const QString &archive, const QString &password, const std::shared_ptr<State> &state);

protected:
    bool doKill() override;

private:
    QString m_archive;
    QString m_password;
    QString m_made;
    bool m_locked = false;
    std::shared_ptr<State> m_state;
    QTimer m_tick;
};

// Makes one zip of some items, as Finder's Compress does: folders with all
// that is in them (hidden files too, and empty folders), links as links.
// It is written under a hidden name beside where it will be and given its
// own when whole, so a zip half made is never seen as one. On a thread of
// its own; the job reports the bytes of the files put in so far, and can
// be stopped, which leaves nothing behind.
class CompressJob : public KJob
{
    Q_OBJECT

public:
    CompressJob(const QStringList &paths, const QString &to, QObject *parent = nullptr);

    void start() override;

    struct State {
        std::atomic<bool> stop{false};
        std::atomic<qint64> done{0};
    };
    // The work itself, off the main thread (and for tests).
    static bool compress(const QStringList &paths, const QString &to, const std::shared_ptr<State> &state);
    // The bytes of every file among them.
    static qint64 sizeOf(const QStringList &paths);

protected:
    bool doKill() override;

private:
    QStringList m_paths;
    QString m_to;
    std::shared_ptr<State> m_state;
    QTimer m_tick;
};
