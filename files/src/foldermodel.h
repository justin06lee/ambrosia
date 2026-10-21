#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <memory>
#include <string>
#include <vector>

class QFileSystemWatcher;
class QTimer;
class KJob;

// One folder's contents, sorted as Finder sorts them. Local folders are read
// on worker threads straight from the kernel: getdents64 for the names (a
// small first buffer, then 1 MiB ones), then statx for every entry, in
// parallel for big folders. Everything else (trash:/, recentlyused:/, smb://)
// is listed through KIO. Nothing touches the filesystem on the GUI thread.
class FolderModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(QString name READ name NOTIFY urlChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY loaded)
    Q_PROPERTY(QString sortColumn READ sortColumn WRITE setSortColumn NOTIFY sortChanged)
    Q_PROPERTY(bool ascending READ ascending WRITE setAscending NOTIFY sortChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    // Milliseconds from asking for the folder to having it, sorted.
    Q_PROPERTY(double loadMs READ loadMs NOTIFY loaded)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        UrlRole,
        IsDirRole,
        SizeRole,
        DateRole,
        SizeTextRole,
        DateTextRole,
        KindRole,
        IconRole,
        BadgeRole,
    };
    Q_ENUM(Role)

    struct Entry {
        quint32 name = 0; // offsets into Listing::strings, NUL-terminated
        quint32 display = 0;
        quint8 flags = 0;
        qint64 size = -1;
        qint64 mtime = 0;
    };
    enum Flag : quint8 { Dir = 1, Symlink = 2, Hidden = 4 };

    struct Listing {
        std::string strings;
        std::vector<Entry> entries;
        std::vector<QUrl> urls; // KIO listings only, parallel to entries
        QString error;
    };

    explicit FolderModel(QObject *parent = nullptr);
    ~FolderModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QUrl url() const { return m_url; }
    void setUrl(const QUrl &url);
    QString name() const;
    int count() const { return rowCount(); }
    bool loading() const { return m_loading; }
    QString error() const { return m_listing ? m_listing->error : QString(); }
    QString sortColumn() const { return m_sortColumn; }
    void setSortColumn(const QString &column);
    bool ascending() const { return m_ascending; }
    void setAscending(bool ascending);
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool show);
    double loadMs() const { return m_loadMs; }

    Q_INVOKABLE QUrl urlAt(int row) const;
    Q_INVOKABLE QString nameAt(int row) const;
    Q_INVOKABLE bool isDirAt(int row) const;
    Q_INVOKABLE int indexOf(const QString &name) const;
    // Type-select: the first row, from `from` on and wrapping, whose name
    // starts with prefix, ignoring case; -1 if none.
    Q_INVOKABLE int match(const QString &prefix, int from = 0) const;
    Q_INVOKABLE void reload();

Q_SIGNALS:
    void urlChanged();
    void countChanged();
    void loadingChanged();
    void sortChanged();
    void showHiddenChanged();
    void loaded();

private:
    void load();
    void listRemote();
    void resort();
    void apply(std::shared_ptr<Listing> listing, quint64 generation);
    const char *str(quint32 offset) const { return m_listing->strings.data() + offset; }

    QUrl m_url;
    std::shared_ptr<const Listing> m_listing;
    QString m_sortColumn = QStringLiteral("name");
    bool m_ascending = true;
    bool m_showHidden = false;
    bool m_loading = false;
    double m_loadMs = 0;
    quint64 m_generation = 0;
    QElapsedTimer m_clock;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_reload = nullptr;
    KJob *m_job = nullptr;
    mutable QHash<QString, QString> m_kinds; // extension -> kind, GUI thread
};
