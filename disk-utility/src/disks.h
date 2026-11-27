#pragma once

#include <QDBusMessage>
#include <QElapsedTimer>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QQmlEngine;
class QJSEngine;

// The computer's disks, read from UDisks2 on the system bus and handed to
// QML as plain maps (qml/disks.mjs makes the sidebar, the pages and the
// rules of them); and what Disk Utility does to them, each through
// UDisks2's own method, so each asks for a password by polkit exactly when
// UDisks2's rules say so. Nothing here runs as root.
class Disks : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Every block device: { path, device, drive, size, usage, type,
    // version, label, uuid, readOnly, hintIgnore, backing, filesystem,
    // mounts, total, free, available, mountedReadOnly, partitioned, table,
    // partition, number, partName, partType, partTable, offset, container,
    // loop, backingFile, encrypted, cleartext, swapActive }.
    Q_PROPERTY(QVariantList blocks READ blocks NOTIFY changed)
    // Every drive: { path, model, vendor, serial, revision, size, bus,
    // removable, mediaRemovable, ejectable, canPowerOff, optical, rotation,
    // mediaAvailable, smart: verified | failing | unsupported }.
    Q_PROPERTY(QVariantList drives READ drives NOTIFY changed)
    // The file systems UDisks2 can make here, and those it can check (the
    // tools for them are installed).
    Q_PROPERTY(QStringList formats READ formats NOTIFY toolsChanged)
    Q_PROPERTY(QStringList checkable READ checkable NOTIFY toolsChanged)
    // The disks have been read once.
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    // UDisks2 answered: without it there is nothing to show.
    Q_PROPERTY(bool available READ available NOTIFY changed)
    // The system's own name and version (os-release), said of the volume
    // it runs from.
    Q_PROPERTY(QString system READ system CONSTANT)

public:
    explicit Disks(QObject *parent = nullptr);
    static Disks *create(QQmlEngine *, QJSEngine *);
    static Disks *instance();

    QVariantList blocks() const { return m_blocks; }
    QVariantList drives() const { return m_drives; }
    QStringList formats() const { return m_formats; }
    QStringList checkable() const { return m_checkable; }
    bool ready() const { return m_ready; }
    bool available() const { return m_available; }
    QString system() const;

    // Read the disks again (the room on each changes without a word from
    // UDisks2).
    Q_INVOKABLE void refresh();
    // Mount these file systems (block paths).
    Q_INVOKABLE void mount(const QStringList &filesystems);
    // Unmount these file systems, then lock these encrypted blocks.
    Q_INVOKABLE void unmount(const QStringList &filesystems, const QStringList &lock);
    // Open an encrypted block with its password and mount what is inside.
    Q_INVOKABLE void unlock(const QString &block, const QString &passphrase);
    // Unmount and lock as above, then let the disk go: `how` is "loop" (a
    // disk image: its loop device, `disk`, is taken down), "off" (the
    // drive is powered off) or "eject" (its medium comes out).
    Q_INVOKABLE void eject(const QStringList &filesystems, const QStringList &lock, const QString &disk, const QString &drive, const QString &how);
    // Check a file system and repair it if it needs it; `mounted` ones are
    // unmounted for it and mounted again after.
    Q_INVOKABLE void firstAid(const QString &filesystem, bool mounted);
    // Erase a block: a new file system of `format` named `name` on it, or,
    // with a `scheme` (gpt or dos), a new partition map with one such
    // volume over the whole of it. What is mounted on it is unmounted first.
    Q_INVOKABLE void erase(const QString &block, const QStringList &filesystems, const QStringList &lock, const QString &format, const QString &name, const QString &scheme);
    // Open a disk image file: a loop device over it, its volumes mounted.
    Q_INVOKABLE void attach(const QUrl &file);

Q_SIGNALS:
    void changed();
    void toolsChanged();
    // Mounting, unmounting, ejecting or attaching didn't work: `what` is
    // the verb, `code` busy, denied or other (a password prompt dismissed
    // says nothing), `detail` UDisks2's own words.
    void failed(const QString &what, const QString &code, const QString &detail);
    void unlockDone(const QString &block, bool ok, const QString &code, const QString &detail);
    void firstAidLine(const QString &line);
    void firstAidDone(bool ok, const QString &code, const QString &detail);
    void eraseDone(bool ok, const QString &code, const QString &detail);
    void attached(const QString &block);

private:
    struct Step {
        QString path;
        QString interface;
        QString method;
        QVariantList arguments;
    };
    using Done = std::function<void(bool ok, const QString &code, const QString &detail, const QDBusMessage &last)>;

    void load();
    void parsed(const QDBusMessage &reply);
    void readTools();
    void call(const Step &step, std::function<void(const QDBusMessage &)> then);
    void run(QList<Step> steps, Done done);
    void mountNew();
    static QList<Step> letGo(const QStringList &filesystems, const QStringList &lock);
    static QString codeOf(const QDBusMessage &reply);

    static Disks *s_instance;
    QVariantList m_blocks;
    QVariantList m_drives;
    QStringList m_formats;
    QStringList m_checkable;
    QTimer m_later;
    bool m_ready = false;
    bool m_available = false;
    bool m_loading = false;
    bool m_again = false;
    // A disk image just attached: its volumes are mounted as they appear,
    // for a few seconds.
    QString m_fresh;
    QElapsedTimer m_freshSince;
    QSet<QString> m_freshAsked;
};
