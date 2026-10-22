#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QSet>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

class QFileSystemWatcher;
class QProcess;
class QTimer;
class KJob;

// One folder's contents, sorted as Finder sorts them. Local folders are read
// on worker threads straight from the kernel: getdents64 for the names (a
// small first buffer, then 1 MiB ones), then statx for every entry, in
// parallel for big folders. Everything else (trash:/, recentlyused:/, smb://)
// is listed through KIO. Nothing touches the filesystem on the GUI thread.
//
// Folders opened in place by their disclosure triangles hang under their
// rows as a tree of nodes; while any is open the model's rows are an
// outline (m_rows) of the folder and the open nodes, each row with its
// depth. Opening and closing one inserts and removes just its rows.
//
// A folder that changes (inotify for local folders, KDirNotify for the rest)
// is reread and lined up with what it showed: rows that went are taken
// out, new ones put in, and the rest stay put, so a view keeps its place and
// a window its selection while files are copied, renamed and trashed.
//
// A search is a place too: search:?q=TEXT[&in=FOLDER][&mode=name|content]
// [&kind=KIND], or search:?tag=NAME for a sidebar tag. Names come from the
// index at once; contents stream in from rg, run in a folder's scope (the
// whole home only when asked, mode=content: rg reads every file); both are
// read again when the index sees a change.
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
    // ... and to having its first rows (sooner than loadMs in big folders).
    Q_PROPERTY(double firstMs READ firstMs NOTIFY loaded)
    // How much of a date the list's column has room for: 0 "Yesterday at
    // 3:30 PM", 1 "Yesterday, 3:30 PM", 2 "Yesterday" (or "3:30 PM" today).
    Q_PROPERTY(int dateLevel READ dateLevel WRITE setDateLevel NOTIFY dateLevelChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY urlChanged)
    // rg is still looking through contents.
    Q_PROPERTY(bool searchingContents READ searchingContents NOTIFY searchingContentsChanged)
    // How long the index took for the last search's names.
    Q_PROPERTY(double searchMs READ searchMs NOTIFY loaded)

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
        KindShortRole,
        DepthRole,
        ExpandedRole,
        TagsRole, // the colors of its tags, read when asked for
    };
    Q_ENUM(Role)

    struct Entry {
        quint32 name = 0; // offsets into Listing::strings, NUL-terminated
        quint32 display = 0;
        quint8 flags = 0;
        qint64 size = -1;
        qint64 mtime = 0;
    };
    enum Flag : quint8 { Dir = 1, Symlink = 2, Hidden = 4, Missing = 8 };

    struct Listing {
        std::string strings;
        std::vector<Entry> entries;
        std::vector<QUrl> urls; // KIO listings only, parallel to entries
        bool paths = false;     // search results: each entry's name is its whole path
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
    double firstMs() const { return m_firstMs; }
    int dateLevel() const { return m_dateLevel; }
    void setDateLevel(int level);
    bool searching() const { return m_url.scheme() == QLatin1String("search"); }
    bool searchingContents() const { return m_rg != nullptr; }
    double searchMs() const { return m_searchMs; }

    Q_INVOKABLE QUrl urlAt(int row) const;
    Q_INVOKABLE QString nameAt(int row) const;
    Q_INVOKABLE bool isDirAt(int row) const;
    Q_INVOKABLE int indexOf(const QString &name) const;
    // The rows showing these items, in the same order (-1 for one that isn't).
    Q_INVOKABLE QList<int> rowsOf(const QList<QUrl> &urls) const;
    // Type-select: the first row, from `from` on and wrapping, whose name
    // starts with prefix, ignoring case; -1 if none.
    Q_INVOKABLE int match(const QString &prefix, int from = 0) const;
    // A row's roles by name (name, kind, sizeText, dateText, …), for the
    // Columns view's preview of one file.
    Q_INVOKABLE QVariantMap infoAt(int row) const;
    // A row's dates as Finder's preview writes them: created, modified and
    // last opened (only modified for an item not on this computer).
    Q_INVOKABLE QVariantMap timesAt(int row) const;
    Q_INVOKABLE void reload();
    // The outline: whether a folder's row is open, opening or closing it
    // (with all, every folder under it too, as Option-click does), and the
    // row of the folder a row sits in (-1 at the top level).
    Q_INVOKABLE bool isExpanded(int row) const;
    Q_INVOKABLE void setExpanded(int row, bool expanded, bool all = false);
    Q_INVOKABLE int parentRow(int row) const;

Q_SIGNALS:
    void urlChanged();
    void countChanged();
    void loadingChanged();
    void sortChanged();
    void showHiddenChanged();
    void loaded();
    void dateLevelChanged();
    void searchingContentsChanged();

private:
    struct Node {
        Node *parent = nullptr; // null for a folder in the top level
        std::string name;
        QUrl url;
        std::shared_ptr<const Listing> listing; // null until read, and while closed
        bool open = false;
        bool openAll = false; // opens every folder inside as it's read
        quint64 id = 0;
        quint64 generation = 0;
        std::unordered_map<std::string, std::unique_ptr<Node>> children;
    };
    struct Row {
        const Node *node; // null for the top level
        quint32 index;
        quint32 depth;
    };
    using Children = std::unordered_map<std::string, std::unique_ptr<Node>>;

    Row rowAt(int row) const { return m_outline ? m_rows[row] : Row{nullptr, quint32(row), 0}; }
    const Listing &listingOf(const Node *node) const { return node ? *node->listing : *m_listing; }
    const Entry &entryOf(const Row &r) const { return listingOf(r.node).entries[r.index]; }
    const char *nameOf(const Row &r) const;
    QString displayOf(const Row &r) const;
    Children &childrenOf(const Node *node) { return node ? const_cast<Node *>(node)->children : m_children; }
    const Children &childrenOf(const Node *node) const { return node ? node->children : m_children; }
    void appendRows(const Node *node, quint32 depth, std::vector<Row> &rows) const;
    void rebuildRows();
    int rowOfNode(const Node *node) const;
    int subtreeEnd(int row) const;
    void loadNode(Node *node);
    void nodeLoaded(quint64 id, quint64 generation, std::shared_ptr<Listing> listing, const QString &column, bool ascending);
    void showNode(Node *node);
    void hideNode(Node *node);
    void openAllIn(Node *node);
    void closeListings(Node *node);
    void forget(Node *node);
    void watch(const QString &path, bool on);
    void changed(const QString &path);
    void notified(const QStringList &urls, bool parents);
    void replace(Node *node, std::shared_ptr<const Listing> next, const std::vector<qint32> &from);
    void dropGone(Node *node);

    // reread: the folder changed; line the new listing up with the old.
    void load(bool reread = false);
    void listRemote(bool reread);
    void listSearch(bool reread);
    void statResults(quint64 generation);
    void searchContents(const QString &text, const QString &dir);
    void startContents();
    void stopContents();
    void resort();
    void apply(std::shared_ptr<Listing> listing, quint64 generation, bool partial);
    void reapply(std::shared_ptr<Listing> listing, quint64 generation, const std::shared_ptr<const Listing> &before, const std::vector<qint32> &from);
    // Offers the listing to other models opening the same folder.
    void share();
    const char *str(quint32 offset) const { return m_listing->strings.data() + offset; }

    QUrl m_url;
    std::shared_ptr<const Listing> m_listing;
    QString m_sortColumn = QStringLiteral("name");
    bool m_ascending = true;
    bool m_showHidden = false;
    bool m_loading = false;
    double m_loadMs = 0;
    double m_firstMs = 0;
    quint64 m_generation = 0;
    QElapsedTimer m_clock;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_reload = nullptr;
    bool m_rootChanged = false;
    QSet<QString> m_changedPaths; // open folders written to since the last reread
    int m_dateLevel = 0;
    Children m_children; // the top level's folders that have been opened
    QHash<quint64, Node *> m_nodes;
    quint64 m_nextNode = 0;
    std::vector<Row> m_rows;
    bool m_outline = false;
    KJob *m_job = nullptr;
    mutable QHash<QString, QString> m_kinds; // extension -> kind, GUI thread
    // Content search: rg's run, and the files it found so far.
    QProcess *m_rg = nullptr;
    QTimer *m_rgLater = nullptr; // rg starts once typing pauses
    QString m_rgFor, m_rgText, m_rgDir;
    QByteArray m_rgRest;
    std::vector<std::string> m_contentHits;
    std::unordered_set<std::string> m_contentSeen;
    double m_searchMs = 0;
};
