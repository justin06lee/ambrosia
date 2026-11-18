// Stand-ins for what the shell's QML asks of Quickshell and Plasma, so the
// shell's own files load and draw where neither runs (see stubs/README.md).
// Nothing here talks to a compositor, the session bus or a real app: windows
// are items on a sheet, the task model lists what a sheet says is running,
// and commands are never started.
#pragma once

#include <QAbstractListModel>
#include <QJSValue>
#include <QQuickItem>
#include <QVariant>
#include <QtQml>

class QQuickWindow;

// A sheet's hand on the pointer and the keys (`shotPointer`): moves, clicks
// and typing reach the hidden window as a real mouse's and keyboard's would,
// so hovering, pressing and typing do what they do on screen. Places are in
// the sheet's own coordinates.
class ShotPointer : public QObject
{
    Q_OBJECT

public:
    explicit ShotPointer(QQuickWindow *window);
    Q_INVOKABLE void move(qreal x, qreal y);
    Q_INVOKABLE void press(qreal x, qreal y, int button = Qt::LeftButton);
    Q_INVOKABLE void release(qreal x, qreal y, int button = Qt::LeftButton);
    Q_INVOKABLE void click(qreal x, qreal y, int button = Qt::LeftButton);
    // Letters, digits and spaces, to whatever has the keyboard.
    Q_INVOKABLE void type(const QString &text);
    Q_INVOKABLE void key(int key);

private:
    void send(QEvent::Type type, qreal x, qreal y, Qt::MouseButton button, Qt::MouseButtons held);
    QQuickWindow *m_window;
};

// Registers every type below under its Quickshell or Plasma name.
void registerStubs(const QString &shellDir, const QString &iconsDir, const QString &wallpapersDir);

// The apps the sheet's desktop has: what DesktopEntries and the task model know.
struct ShotApp {
    QString id;
    QString name;
    QString icon;
};
const QList<ShotApp> &shotApps();

// ShellScreen: the sheet's item stands for the screen (shotHost), and what
// windows blur is whatever the sheet names as lying under them (shotBackdrop).
class ShotScreen : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name MEMBER m_name CONSTANT)
    Q_PROPERTY(QString model MEMBER m_name CONSTANT)
    Q_PROPERTY(int x READ zero CONSTANT)
    Q_PROPERTY(int y READ zero CONSTANT)
    Q_PROPERTY(int width READ width NOTIFY sizeChanged)
    Q_PROPERTY(int height READ height NOTIFY sizeChanged)
    Q_PROPERTY(qreal devicePixelRatio READ devicePixelRatio CONSTANT)
    Q_PROPERTY(QQuickItem *shotHost READ shotHost WRITE setShotHost NOTIFY shotHostChanged)
    Q_PROPERTY(QQuickItem *shotBackdrop MEMBER m_backdrop NOTIFY shotBackdropChanged)

public:
    using QObject::QObject;
    int zero() const { return 0; }
    int width() const { return m_host ? int(m_host->width()) : 0; }
    int height() const { return m_host ? int(m_host->height()) : 0; }
    qreal devicePixelRatio() const { return 2; }
    QQuickItem *shotHost() const { return m_host; }
    void setShotHost(QQuickItem *host);

Q_SIGNALS:
    void sizeChanged();
    void shotHostChanged();
    void shotBackdropChanged();

private:
    QString m_name = QStringLiteral("shot-1");
    QPointer<QQuickItem> m_host;
    QPointer<QQuickItem> m_backdrop;
};

// The Quickshell singleton. shotRun, shotFiles and shotMenus are a sheet's
// way in: what a command would have printed, what a file would have held,
// and the menus an app would have published.
class ShotShell : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString shellDir MEMBER m_shellDir CONSTANT)
    Q_PROPERTY(QVariantList screens READ screens CONSTANT)
    Q_PROPERTY(QString clipboardText MEMBER m_clipboard NOTIFY clipboardTextChanged)
    Q_PROPERTY(QJSValue shotRun READ shotRun WRITE setShotRun NOTIFY shotRunChanged)
    Q_PROPERTY(QVariantMap shotFiles MEMBER m_files NOTIFY shotFilesChanged)
    Q_PROPERTY(QVariantMap shotMenus MEMBER m_menus NOTIFY shotMenusChanged)

public:
    ShotShell(const QString &shellDir, const QString &iconsDir, const QString &wallpapersDir);
    QVariantList screens() const { return {QVariant::fromValue<QObject *>(m_screen)}; }
    QJSValue shotRun() const { return m_run; }
    void setShotRun(const QJSValue &run)
    {
        m_run = run;
        Q_EMIT shotRunChanged();
    }

    // HOME and USER are a made-up person's, so no picture names this Mac's.
    Q_INVOKABLE QVariant env(const QString &name) const;
    // An icon of the generated theme, or nothing: no other theme is here.
    Q_INVOKABLE QString iconPath(const QString &name, const QVariant &fallback = {}) const;
    Q_INVOKABLE void execDetached(const QVariant &) const {}
    Q_INVOKABLE QString statePath(const QString &name) const { return QStringLiteral("/shot/state/") + name; }
    Q_INVOKABLE QString dataPath(const QString &name) const { return QStringLiteral("/shot/data/") + name; }
    Q_INVOKABLE QString cachePath(const QString &name) const { return QStringLiteral("/shot/cache/") + name; }

Q_SIGNALS:
    void clipboardTextChanged();
    void shotRunChanged();
    void shotFilesChanged();
    void shotMenusChanged();

private:
    QString m_shellDir;
    QString m_iconsDir;
    QString m_wallpapersDir;
    QString m_clipboard;
    QJSValue m_run;
    QVariantMap m_files;
    QVariantMap m_menus;
    ShotScreen *m_screen;
};

// DesktopEntries: the table of shotApps().
class ShotEntries : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap applications READ applications CONSTANT)

public:
    using QObject::QObject;
    QVariantMap applications() const;
    Q_INVOKABLE QVariant byId(const QString &id) const;
    Q_INVOKABLE QVariant heuristicLookup(const QString &name) const;
};

// A list of objects as a model that also answers to `values`, as
// Quickshell's own object models do (a menu's rows).
class ShotObjectModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QVariantList values READ values WRITE setValues NOTIFY valuesChanged)

public:
    using QAbstractListModel::QAbstractListModel;
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : int(m_values.size()); }
    QVariant data(const QModelIndex &index, int role) const override
    {
        return role == Qt::UserRole && index.row() < m_values.size() ? m_values.at(index.row()) : QVariant();
    }
    QHash<int, QByteArray> roleNames() const override { return {{Qt::UserRole, "modelData"}}; }
    QVariantList values() const { return m_values; }
    void setValues(const QVariantList &values)
    {
        beginResetModel();
        m_values = values;
        endResetModel();
        Q_EMIT valuesChanged();
    }

Q_SIGNALS:
    void valuesChanged();

private:
    QVariantList m_values;
};

// QsWindow.window: the stand-in window an item is drawn in (the nearest
// item above it that says whose content it is).
class ShotWindowAttached : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *window READ window NOTIFY windowChanged)
    Q_PROPERTY(QQuickItem *contentItem READ contentItem NOTIFY windowChanged)

public:
    explicit ShotWindowAttached(QObject *parent);
    QObject *window() const;
    QQuickItem *contentItem() const;
    static ShotWindowAttached *qmlAttachedProperties(QObject *object) { return new ShotWindowAttached(object); }

Q_SIGNALS:
    void windowChanged();
};
QML_DECLARE_TYPEINFO(ShotWindowAttached, QML_HAS_ATTACHED_PROPERTIES)

// WlrLayershell.layer and friends: kept, and read by the stand-in windows to
// stack themselves.
class ShotLayerAttached : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int layer MEMBER m_layer NOTIFY changed)
    Q_PROPERTY(QString namespace MEMBER m_namespace NOTIFY changed)
    Q_PROPERTY(int keyboardFocus MEMBER m_keyboardFocus NOTIFY changed)

public:
    using QObject::QObject;
    static ShotLayerAttached *qmlAttachedProperties(QObject *object) { return new ShotLayerAttached(object); }

Q_SIGNALS:
    void changed();

private:
    int m_layer = 2;
    QString m_namespace;
    int m_keyboardFocus = 0;
};
QML_DECLARE_TYPEINFO(ShotLayerAttached, QML_HAS_ATTACHED_PROPERTIES)

// BackgroundEffect.blurRegion: kept, and drawn by the stand-in windows as a
// blur of the screen's backdrop.
class ShotBlurAttached : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *blurRegion MEMBER m_region NOTIFY blurRegionChanged)

public:
    using QObject::QObject;
    static ShotBlurAttached *qmlAttachedProperties(QObject *object) { return new ShotBlurAttached(object); }

Q_SIGNALS:
    void blurRegionChanged();

private:
    QPointer<QObject> m_region;
};
QML_DECLARE_TYPEINFO(ShotBlurAttached, QML_HAS_ATTACHED_PROPERTIES)

// Plasma's task model, as far as the shell reads it: the pinned apps in
// order, then the others a sheet says are running. One row an app; no groups.
class ShotAbstractTasksModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum AdditionalRoles {
        AppId = Qt::UserRole + 1,
        AppName,
        IsWindow,
        IsLauncher,
        IsStartup,
        IsDemandingAttention,
        IsMinimized,
        ChildCount,
        LastActivated,
        ApplicationMenuServiceName,
        ApplicationMenuObjectPath,
    };
    Q_ENUM(AdditionalRoles)
    using QAbstractListModel::QAbstractListModel;
};

class ShotTasksModel : public ShotAbstractTasksModel
{
    Q_OBJECT
    Q_PROPERTY(int groupMode MEMBER m_ignoredInt)
    Q_PROPERTY(int sortMode MEMBER m_ignoredInt)
    Q_PROPERTY(bool groupInline MEMBER m_ignored)
    Q_PROPERTY(bool separateLaunchers MEMBER m_ignored)
    Q_PROPERTY(bool launchInPlace MEMBER m_ignored)
    Q_PROPERTY(bool filterByVirtualDesktop MEMBER m_ignored)
    Q_PROPERTY(bool filterByScreen MEMBER m_ignored)
    Q_PROPERTY(bool filterByActivity MEMBER m_ignored)
    Q_PROPERTY(QStringList launcherList READ launcherList WRITE setLauncherList NOTIFY launcherListChanged)
    Q_PROPERTY(QModelIndex activeTask READ activeTask NOTIFY activeTaskChanged)
    // A sheet's say: the ids of the apps with windows, which of them is in
    // front, which wants attention and which is still starting.
    Q_PROPERTY(QStringList shotRunning MEMBER m_running WRITE setRunning NOTIFY shotChanged)
    Q_PROPERTY(QString shotActive MEMBER m_active WRITE setActive NOTIFY shotChanged)
    Q_PROPERTY(QStringList shotAttention MEMBER m_attention WRITE setAttention NOTIFY shotChanged)
    Q_PROPERTY(QStringList shotStarting MEMBER m_starting WRITE setStarting NOTIFY shotChanged)

public:
    enum GroupMode { GroupDisabled, GroupApplications };
    Q_ENUM(GroupMode)
    enum SortMode { SortDisabled, SortManual, SortAlpha, SortVirtualDesktop, SortActivity, SortLastActivated };
    Q_ENUM(SortMode)

    using ShotAbstractTasksModel::ShotAbstractTasksModel;

    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : int(m_rows.size()); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QStringList launcherList() const { return m_launchers; }
    void setLauncherList(const QStringList &list);
    QModelIndex activeTask() const;
    void setRunning(const QStringList &ids);
    void setActive(const QString &id);
    void setAttention(const QStringList &ids);
    void setStarting(const QStringList &ids);

    Q_INVOKABLE QModelIndex makeModelIndex(int row, int child = -1) const { Q_UNUSED(child) return index(row, 0); }
    Q_INVOKABLE void requestActivate(const QModelIndex &) {}
    Q_INVOKABLE void requestNewInstance(const QModelIndex &) {}
    Q_INVOKABLE void requestClose(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleMaximized(const QModelIndex &) {}
    Q_INVOKABLE void requestToggleFullScreen(const QModelIndex &) {}
    Q_INVOKABLE void requestPublishDelegateGeometry(const QModelIndex &, const QRect &, QObject * = nullptr) {}

Q_SIGNALS:
    void launcherListChanged();
    void activeTaskChanged();
    void shotChanged();

private:
    struct Row {
        QString id;
        bool running;
    };
    void rebuild();

    QList<Row> m_rows;
    QStringList m_launchers;
    QStringList m_running;
    QStringList m_attention;
    QStringList m_starting;
    QString m_active;
    bool m_ignored = false;
    int m_ignoredInt = 0;
};
