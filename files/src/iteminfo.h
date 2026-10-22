#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QSize>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "tags.h"

#include <atomic>
#include <memory>

// One item as Quick Look and Get Info show it: its kind, sizes, place,
// dates, comment, the app that opens it and who may use it. It follows the
// item through renames (its own, an undo, another window's) by its inode,
// and counts a folder's contents on a worker thread.
class ItemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(bool exists READ exists NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(bool isDir READ isDir NOTIFY changed)
    Q_PROPERTY(QString kind READ kind NOTIFY changed)
    Q_PROPERTY(QString badge READ badge NOTIFY changed)
    // How it previews: "image", "text" or "generic" (its icon).
    Q_PROPERTY(QString preview READ preview NOTIFY changed)
    // The file itself, for pictures (a Trash item's too).
    Q_PROPERTY(QUrl fileUrl READ fileUrl NOTIFY changed)
    // A picture's size in pixels, as it shows (turned as its camera says).
    Q_PROPERTY(QSize pictureSize READ pictureSize NOTIFY changed)
    // What Finder's preview lists beside its dates (a picture's Dimensions
    // and Resolution, a PDF's pages …): [{label, value, more}], the rows
    // with more shown only after Show More.
    Q_PROPERTY(QVariantList details READ details NOTIFY changed)
    // A text file's start, up to 128 KB of it.
    Q_PROPERTY(QString text READ text NOTIFY changed)
    // "tenet ▸ var ▸ tmp": the folder it is in, from the computer down.
    Q_PROPERTY(QString where READ where NOTIFY changed)
    Q_PROPERTY(QString created READ created NOTIFY changed)
    Q_PROPERTY(QString modified READ modified NOTIFY changed)
    Q_PROPERTY(QString modifiedSeconds READ modifiedSeconds NOTIFY changed)
    Q_PROPERTY(QString opened READ opened NOTIFY changed)
    // "422 bytes", "524 KB" (Get Info's header, Quick Look).
    Q_PROPERTY(QString size READ size NOTIFY sizeChanged)
    // "422 bytes (4 KB on disk)", "524,288 bytes (524 KB on disk) for 2 items".
    Q_PROPERTY(QString sizeDetail READ sizeDetail NOTIFY sizeChanged)
    // Quick Look's: "262 KB", "524 KB, 1 item".
    Q_PROPERTY(QString sizeSummary READ sizeSummary NOTIFY sizeChanged)
    Q_PROPERTY(QString appName READ appName NOTIFY changed)
    Q_PROPERTY(QString appIcon READ appIcon NOTIFY changed)
    // Get Info's Comments, kept where Dolphin keeps them (user.xdg.comment).
    Q_PROPERTY(QString comment READ comment WRITE setComment NOTIFY changed)
    // Its tags' names, in the order they were given.
    Q_PROPERTY(QStringList tags READ tags NOTIFY changed)
    // A folder's first colored tag's color, which its icon takes.
    Q_PROPERTY(QString tint READ tint NOTIFY changed)
    // Its thumbnail's image source, or "".
    Q_PROPERTY(QString thumb READ thumb NOTIFY changed)
    // "You can read and write"; then [{name, privilege}] for the owner, the
    // group and everyone.
    Q_PROPERTY(QString access READ access NOTIFY changed)
    Q_PROPERTY(QVariantList permissions READ permissions NOTIFY changed)

public:
    explicit ItemInfo(QObject *parent = nullptr);
    ~ItemInfo() override;

    QUrl url() const { return m_url; }
    void setUrl(const QUrl &url);
    bool exists() const { return m_exists; }
    QString name() const { return m_name; }
    bool isDir() const { return m_isDir; }
    QString kind() const { return m_kind; }
    QString badge() const { return m_badge; }
    QString preview() const { return m_preview; }
    QUrl fileUrl() const { return m_fileUrl; }
    QSize pictureSize() const { return m_pictureSize; }
    QVariantList details() const { return m_details; }
    QString text() const { return m_text; }
    QString where() const { return m_where; }
    QString created() const { return m_created; }
    QString modified() const { return m_modified; }
    QString modifiedSeconds() const { return m_modifiedSeconds; }
    QString opened() const { return m_opened; }
    QString size() const;
    QString sizeDetail() const;
    QString sizeSummary() const;
    QString appName() const { return m_appName; }
    QString appIcon() const { return m_appIcon; }
    QString comment() const { return m_comment; }
    QStringList tags() const { return m_tags; }
    QString tint() const { return m_isDir ? Tags::instance()->colorsOf(m_tags).value(0) : QString(); }
    QString thumb() const;
    void setComment(const QString &comment);
    QString access() const { return m_access; }
    QVariantList permissions() const { return m_permissions; }

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void urlChanged();
    void changed();
    void sizeChanged();

private:
    struct Count;
    void read(bool recount);
    void watch();
    void follow();
    void countFolder();
    void stopCounting();

    QUrl m_url;
    bool m_exists = false;
    QString m_name, m_kind, m_badge, m_preview, m_where, m_text;
    QUrl m_fileUrl;
    QSize m_pictureSize;
    QString m_created, m_modified, m_modifiedSeconds, m_opened;
    QString m_appName, m_appIcon, m_comment, m_access;
    QVariantList m_permissions, m_details;
    QStringList m_tags;
    bool m_isDir = false;
    qint64 m_bytes = -1; // its size; a folder's contents', once counted
    qint64 m_disk = -1;  // the blocks they take on disk
    qint64 m_items = -1; // a folder's items, inside its folders too
    quint64 m_dev = 0, m_ino = 0;
    qint64 m_mtime = 0;
    QFileSystemWatcher m_watcher;
    QTimer m_settle; // changes on disk come in bursts
    std::shared_ptr<Count> m_count;
    QTimer m_progress;
};
