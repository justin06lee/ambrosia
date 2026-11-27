#pragma once

#include <KJob>

#include <QString>
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
