#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Where the notes are kept: a directory (~/.local/share/ambrosia/notes, or
// --store) holding one directory for each folder, "Notes" always among
// them, and ".deleted" for what waits to be removed for good; in each, a
// note is a Markdown file named for when it was made. This only reads and
// writes: what a file says and where a note belongs is notes.mjs's. It
// watches the directories and says `changed` a moment after anything in
// them was made, renamed or removed (by Notes or by another program: the
// window compares what `stamps` says with what it lists).
class Store : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString root READ root CONSTANT)

public:
    explicit Store(const QString &root);
    static Store *create(QQmlEngine *, QJSEngine *);

    QString root() const { return m_root; }

    // The folders' names (".deleted" among them when it is there).
    Q_INVOKABLE QStringList folders() const;
    // Every note: { folder, id, text, stamp } (when its file last changed,
    // in milliseconds).
    Q_INVOKABLE QVariantList read() const;
    // Every note without its text: { folder, id, stamp }.
    Q_INVOKABLE QVariantList stamps() const;
    // When a note's file last changed; 0 when it isn't there.
    Q_INVOKABLE double stampOf(const QString &folder, const QString &id) const;
    // One of them: { text, stamp }, or nothing when it isn't there.
    Q_INVOKABLE QVariantMap one(const QString &folder, const QString &id) const;
    Q_INVOKABLE bool write(const QString &folder, const QString &id, const QString &text);
    Q_INVOKABLE bool move(const QString &id, const QString &from, const QString &to);
    Q_INVOKABLE bool remove(const QString &folder, const QString &id);
    Q_INVOKABLE bool createFolder(const QString &name);
    Q_INVOKABLE bool renameFolder(const QString &from, const QString &to);
    // Only one with no notes left in it.
    Q_INVOKABLE bool removeFolder(const QString &name);

Q_SIGNALS:
    void changed();

private:
    void watch();
    QString dir(const QString &folder) const;
    QString file(const QString &folder, const QString &id) const;

    static Store *s_instance;
    QString m_root;
    QFileSystemWatcher m_watcher;
    QTimer m_settled;
};
