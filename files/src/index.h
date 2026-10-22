#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

#include <functional>
#include <memory>
#include <string>
#include <vector>

// The index behind search: every visible name under the home, held in
// memory by the resident process and kept fresh by inotify, as the plan's
// research chose (a scan of every name takes a few milliseconds, so no
// trigram index). Names live in one arena of case- and accent-folded
// strings, each item a row of parallel arrays (its name, its folder, its
// flags, its tags), so a query is one memmem pass over the arena.
//
// Hidden items (and everything in hidden folders) aren't indexed, as
// Spotlight doesn't show them, and the walk stays on the home's filesystem.
// The first walk is parallel; after that the index is saved to
// ~/.cache/ambrosia/files/index and loaded at the next start, then checked
// folder by folder as updatedb does (a folder is read again only if its
// mtime or ctime moved).
//
// Queries run on any thread under a shared lock; the index's own thread
// walks, applies inotify's events and saves, taking the lock only to write.
class Index : public QObject
{
    Q_OBJECT

public:
    struct Query {
        QStringList words; // every one must be in the name (folded)
        QString scope;     // a folder's path: only items under it; empty for the home
        QString tag;       // items with this tag, instead of words
        int limit = 10000; // the most paths returned (the best matches)
    };
    struct Result {
        std::vector<std::string> paths;
        std::vector<bool> dirs; // which of them are folders
        size_t total = 0;  // matches seen (a lower bound when capped)
        bool capped = false; // there were more than the limit
        double ms = 0;     // the scan
        bool ready = false; // the index was complete when asked
    };

    static Index *instance();
    // Starts it: loads the snapshot or walks the home (FILES_INDEX_ROOT
    // overrides the home, for tests). save: whether to write the snapshot.
    void start(bool save = true);
    // Stops its walks and saves what changed since the last snapshot (on
    // the way out).
    void stop();
    bool ready() const;
    // The folder it covers: the home, unless FILES_INDEX_ROOT says.
    QString root() const;
    // Whether path is a folder the index covers.
    bool covers(const QString &path) const;
    // Runs a query on the calling thread.
    Result find(const Query &query) const;
    // The folding queries and names share: lower case, no accents.
    static std::string fold(const QString &text);

    // For benchmarks: how many items and folders, and the bytes they take.
    struct Stats {
        size_t entries = 0, dirs = 0, gone = 0, bytes = 0, watches = 0;
        double walkMs = 0, loadMs = 0, checkMs = 0;
        bool fromSnapshot = false;
    };
    Stats stats() const;

Q_SIGNALS:
    // Items came, went, were renamed or retagged (a burst of changes once
    // it settles; emitted on the index's thread).
    void changed();
    void readyChanged();

private:
    Index();
    ~Index() override;
    struct Core;
    std::unique_ptr<Core> d;
};
