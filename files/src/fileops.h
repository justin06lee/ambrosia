#pragma once

#include <QHash>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class KJob;

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

public:
    explicit FileOps(QObject *parent = nullptr);

    bool canUndo() const;
    QString undoText() const;
    bool canRedo() const;
    QString redoText() const;
    int clipboardCount() const;

    // "untitled folder" (then "untitled folder 2" ...) in dir.
    Q_INVOKABLE int newFolder(const QUrl &dir);
    Q_INVOKABLE int rename(const QUrl &url, const QString &name);
    // Copies beside the originals: "notes copy.md", "notes copy 2.md".
    Q_INVOKABLE int duplicate(const QList<QUrl> &urls);
    Q_INVOKABLE int copy(const QList<QUrl> &urls, const QUrl &dir);
    Q_INVOKABLE int move(const QList<QUrl> &urls, const QUrl &dir);
    Q_INVOKABLE int trash(const QList<QUrl> &urls);
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
    void finished(int id, const QList<QUrl> &urls, bool ok);

private:
    // Runs a job that KIO's undo manager has recorded (or that it can't), and
    // says finished() with these results once it's done.
    int start(KJob *job, const QList<QUrl> &results, const QString &label);
    void alert(const QString &text, const QString &detail = QString());

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
};
