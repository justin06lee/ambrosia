#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class KJob;

// The copies and moves that are taking a while, as Finder's progress window
// lists them: what each is doing, how far along it is, and how much is
// done and about how long is left. One shows once it has run for a second.
class FileJobs : public QAbstractListModel
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // The window's title: "Copy", or "Move" when its first row is one.
    Q_PROPERTY(QString title READ title NOTIFY countChanged)

public:
    // fraction is under 0 until the job knows how much there is.
    enum Role { TitleRole = Qt::UserRole + 1, DetailRole, FractionRole };

    explicit FileJobs(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return int(m_shown.size()); }
    QString title() const;

    // Follows a job until it ends. kind is "Copy" or "Move".
    void add(KJob *job, const QString &kind, const QString &title);
    // The row's stop button: what was copied so far stays.
    Q_INVOKABLE void stop(int row);

Q_SIGNALS:
    void countChanged();
    // The first row is there: the window should be too.
    void wanted();

private:
    struct Run {
        QPointer<KJob> job;
        QString kind, title;
        qint64 started = 0;         // on m_clock, in ms
        qint64 bytesAt = 0, at = 0; // the last reading, for the rate
        double rate = 0;            // bytes a second, smoothed
    };
    void tick();
    void remove(KJob *job);
    QString detail(const Run &run) const;

    QList<Run> m_waiting, m_shown;
    QTimer m_tick;
    QElapsedTimer m_clock;
};

// Finder's file operations, through KIO: New Folder, rename, Duplicate, Copy
// and Paste, moves and copies by drag and drop, Move to Trash and Put Back.
// Each is recorded with KIO's undo manager, so Edit > Undo and Redo take it
// back and do it again (Put Back excepted: KIO can't record it). Each call
// returns an id that finished() repeats with the items it made or moved, so
// the window that asked can select them; -1 means nothing was started.
class FileOps : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoChanged)
    Q_PROPERTY(QString undoText READ undoText NOTIFY undoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY undoChanged)
    Q_PROPERTY(QString redoText READ redoText NOTIFY undoChanged)
    // How many items Paste would bring (0: the clipboard holds no files).
    Q_PROPERTY(int clipboardCount READ clipboardCount NOTIFY clipboardChanged)
    // Whether the Trash has nothing in it (KIO's own note of it, trashrc).
    Q_PROPERTY(bool trashEmpty READ trashEmpty NOTIFY trashChanged)
    // The copies and moves under way, for the progress window.
    Q_PROPERTY(FileJobs *jobs READ jobs CONSTANT)

public:
    explicit FileOps(QObject *parent = nullptr);

    bool canUndo() const;
    QString undoText() const;
    bool canRedo() const;
    QString redoText() const;
    int clipboardCount() const;
    bool trashEmpty() const { return m_trashEmpty; }
    FileJobs *jobs() const { return m_jobs; }

    // "untitled folder" (then "untitled folder 2" ...) in dir.
    Q_INVOKABLE int newFolder(const QUrl &dir);
    Q_INVOKABLE int rename(const QUrl &url, const QString &name);
    // Copies beside the originals: "notes copy.md", "notes copy 2.md".
    Q_INVOKABLE int duplicate(const QList<QUrl> &urls);
    // A link to each beside it: "notes.md alias", then "notes.md alias 2"
    // (Finder's Make Alias).
    Q_INVOKABLE int makeAlias(const QList<QUrl> &urls);
    // A zip beside them, written in the background: "notes.md.zip" for one
    // item, "Archive.zip" for several, then "Archive 2.zip" (Finder's
    // Compress). Local items only; not one of Undo's.
    Q_INVOKABLE int compress(const QList<QUrl> &urls);
    // Expands archives beside themselves, as a Mac's Archive Utility does
    // (expand.h): each in the progress window if it takes long, where it
    // can be stopped. Local ones only; not one of Undo's. The id is the
    // last one's.
    Q_INVOKABLE int expand(const QList<QUrl> &urls);
    Q_INVOKABLE int copy(const QList<QUrl> &urls, const QUrl &dir);
    Q_INVOKABLE int move(const QList<QUrl> &urls, const QUrl &dir);
    Q_INVOKABLE int trash(const QList<QUrl> &urls);
    // The app menu's Empty Trash…: asks first, as Finder does, then erases
    // what is in the Trash. Not one of Undo's.
    Q_INVOKABLE void emptyTrash();
    // Erases what has been in the home Trash longer than Files' Settings
    // allows (nothing while that is off). App runs it now and then.
    static void sweepTrash();
    Q_INVOKABLE int putBack(const QList<QUrl> &urls);
    Q_INVOKABLE void copyToClipboard(const QList<QUrl> &urls);
    // The clipboard's files into dir: copied, or moved (Move Item Here, or
    // files another app cut).
    Q_INVOKABLE int paste(const QUrl &dir, bool move);
    // Whether a drop of urls on dir moves them when no key says otherwise:
    // Finder moves within a disk and copies across disks.
    Q_INVOKABLE bool dropMoves(const QList<QUrl> &urls, const QUrl &dir) const;
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

Q_SIGNALS:
    void undoChanged();
    void clipboardChanged();
    void trashChanged();
    void finished(int id, const QList<QUrl> &urls, bool ok);

private:
    // Runs a job that KIO's undo manager has recorded (or that it can't), and
    // says finished() with these results once it's done.
    int start(KJob *job, const QList<QUrl> &results, const QString &label);
    void alert(const QString &text, const QString &detail = QString());
    void expandOne(int id, const QUrl &url, const QString &password);

    QHash<quint64, QString> m_labels; // what Edit > Undo calls each command, by KIO's serial number
    // What Edit > Redo calls each undone command, last undone last, beside
    // KIO's own words for it. KIO keeps no serial numbers for redo.
    struct RedoLabel {
        QString kio;
        QString label;
    };
    QList<RedoLabel> m_redoLabels;
    QString m_redone; // the label of the command being redone, until its job finishes
    int m_next = 0;
    FileJobs *m_jobs;
    bool m_trashEmpty = true;
    void readTrash();

    // Tags aren't KIO's to undo: their edits are kept here, each with the
    // KIO command that was last when it was made, so Undo takes back
    // whichever came last. Redo keeps both kinds in the order undone.
    struct TagStep {
        QList<QUrl> urls;
        QList<QStringList> before, after;
        quint64 kioBelow = 0; // KIO's command under it (0: none)
    };
    QList<TagStep> m_tagUndo;
    struct RedoStep {
        bool tags = false;
        TagStep step;
    };
    QList<RedoStep> m_redo;
    quint64 kioTop() const;
    bool tagsNext() const;
    QString tagLabel() const { return QStringLiteral("Tags"); }
};
