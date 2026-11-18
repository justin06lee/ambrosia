#include "stubs.h"

#include <QDir>
#include <QFile>
#include <QMouseEvent>
#include <QQuickWindow>
#include <QTimer>

ShotPointer::ShotPointer(QQuickWindow *window)
    : QObject(window)
    , m_window(window)
{
}

void ShotPointer::send(QEvent::Type type, qreal x, qreal y, Qt::MouseButton button, Qt::MouseButtons held)
{
    const QPointF at(x, y);
    QMouseEvent event(type, at, at, at, button, held, Qt::NoModifier);
    QCoreApplication::sendEvent(m_window, &event);
}

void ShotPointer::move(qreal x, qreal y)
{
    send(QEvent::MouseMove, x, y, Qt::NoButton, Qt::NoButton);
}

void ShotPointer::press(qreal x, qreal y, int button)
{
    send(QEvent::MouseButtonPress, x, y, Qt::MouseButton(button), Qt::MouseButton(button));
}

void ShotPointer::release(qreal x, qreal y, int button)
{
    send(QEvent::MouseButtonRelease, x, y, Qt::MouseButton(button), Qt::NoButton);
}

void ShotPointer::click(qreal x, qreal y, int button)
{
    move(x, y);
    press(x, y, button);
    release(x, y, button);
}

void ShotPointer::type(const QString &text)
{
    for (const QChar letter : text) {
        const int key = letter.isLetterOrNumber() ? letter.toUpper().unicode() : letter == QLatin1Char(' ') ? Qt::Key_Space : 0;
        QKeyEvent press(QEvent::KeyPress, key, Qt::NoModifier, QString(letter));
        QCoreApplication::sendEvent(m_window, &press);
        QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier, QString(letter));
        QCoreApplication::sendEvent(m_window, &release);
    }
}

void ShotPointer::key(int key)
{
    QKeyEvent press(QEvent::KeyPress, key, Qt::NoModifier);
    QCoreApplication::sendEvent(m_window, &press);
    QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier);
    QCoreApplication::sendEvent(m_window, &release);
}

const QList<ShotApp> &shotApps()
{
    static const QList<ShotApp> apps = {
        {QStringLiteral("org.ambrosia.files"), QStringLiteral("Files"), QStringLiteral("org.ambrosia.files")},
        {QStringLiteral("org.kde.konsole"), QStringLiteral("Konsole"), QStringLiteral("utilities-terminal")},
        {QStringLiteral("org.kde.kate"), QStringLiteral("Kate"), QStringLiteral("kate")},
        {QStringLiteral("org.kde.gwenview"), QStringLiteral("Gwenview"), QStringLiteral("gwenview")},
        {QStringLiteral("org.kde.okular"), QStringLiteral("Okular"), QStringLiteral("okular")},
        {QStringLiteral("org.kde.kcalc"), QStringLiteral("KCalc"), QStringLiteral("accessories-calculator")},
        {QStringLiteral("org.kde.ark"), QStringLiteral("Ark"), QStringLiteral("ark")},
        {QStringLiteral("org.kde.spectacle"), QStringLiteral("Spectacle"), QStringLiteral("spectacle")},
        {QStringLiteral("org.kde.discover"), QStringLiteral("Discover"), QStringLiteral("plasmadiscover")},
        {QStringLiteral("org.kde.kinfocenter"), QStringLiteral("Info Center"), QStringLiteral("hwinfo")},
        {QStringLiteral("org.ambrosia.settings"), QStringLiteral("System Settings"), QStringLiteral("org.ambrosia.settings")},
    };
    return apps;
}

static const ShotApp *appById(const QString &id)
{
    for (const ShotApp &app : shotApps()) {
        if (app.id == id) {
            return &app;
        }
    }
    return nullptr;
}

static QVariant entryOf(const ShotApp &app)
{
    return QVariantMap{
        {QStringLiteral("id"), app.id},
        {QStringLiteral("name"), app.name},
        {QStringLiteral("icon"), app.icon},
        {QStringLiteral("genericName"), QString()},
        {QStringLiteral("comment"), QString()},
        {QStringLiteral("keywords"), QStringList()},
        {QStringLiteral("categories"), QStringList()},
        {QStringLiteral("noDisplay"), false},
        {QStringLiteral("runInTerminal"), false},
    };
}

static QString bare(QString id)
{
    if (id.startsWith(QLatin1String("applications:"))) {
        id.remove(0, 13);
    }
    if (id.endsWith(QLatin1String(".desktop"))) {
        id.chop(8);
    }
    return id;
}

void ShotScreen::setShotHost(QQuickItem *host)
{
    if (host == m_host) {
        return;
    }
    if (m_host) {
        m_host->disconnect(this);
    }
    m_host = host;
    if (host) {
        connect(host, &QQuickItem::widthChanged, this, &ShotScreen::sizeChanged);
        connect(host, &QQuickItem::heightChanged, this, &ShotScreen::sizeChanged);
    }
    Q_EMIT shotHostChanged();
    Q_EMIT sizeChanged();
}

ShotShell::ShotShell(const QString &shellDir, const QString &iconsDir, const QString &wallpapersDir)
    : m_shellDir(shellDir)
    , m_iconsDir(iconsDir)
    , m_wallpapersDir(wallpapersDir)
    , m_screen(new ShotScreen(this))
{
}

QVariant ShotShell::env(const QString &name) const
{
    if (name == QLatin1String("HOME")) {
        return QStringLiteral("/home/ada");
    }
    if (name == QLatin1String("USER")) {
        return QStringLiteral("ada");
    }
    if (name == QLatin1String("AMBROSIA_WALLPAPERS") && !m_wallpapersDir.isEmpty()) {
        return m_wallpapersDir;
    }
    if (name.startsWith(QLatin1String("XDG_"))) {
        return {};
    }
    const QByteArray value = qgetenv(name.toUtf8().constData());
    return value.isNull() ? QVariant() : QString::fromUtf8(value);
}

QString ShotShell::iconPath(const QString &name, const QVariant &fallback) const
{
    QStringList names{name};
    if (fallback.typeId() == QMetaType::QString) {
        names << fallback.toString();
    }
    for (const QString &each : std::as_const(names)) {
        if (each.isEmpty()) {
            continue;
        }
        const QStringList kinds = QDir(m_iconsDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &kind : kinds) {
            const QString path = QStringLiteral("%1/%2/scalable/%3.svg").arg(m_iconsDir, kind, each);
            if (QFile::exists(path)) {
                return QStringLiteral("file://") + path;
            }
        }
        // An app of someone else's, as a sheet stands in for it.
        const QString art = QDir::current().absoluteFilePath(QStringLiteral("tools/qmlshot/sheets/art/%1.svg").arg(each));
        if (QFile::exists(art)) {
            return QStringLiteral("file://") + art;
        }
    }
    return {};
}

QVariantMap ShotEntries::applications() const
{
    QVariantList list;
    for (const ShotApp &app : shotApps()) {
        list << entryOf(app);
    }
    return {{QStringLiteral("values"), list}};
}

QVariant ShotEntries::byId(const QString &id) const
{
    const ShotApp *app = appById(bare(id));
    return app ? entryOf(*app) : QVariant();
}

QVariant ShotEntries::heuristicLookup(const QString &name) const
{
    for (const ShotApp &app : shotApps()) {
        if (app.id.compare(name, Qt::CaseInsensitive) == 0 || app.name.compare(name, Qt::CaseInsensitive) == 0
            || app.id.endsWith(QLatin1Char('.') + name, Qt::CaseInsensitive)) {
            return entryOf(app);
        }
    }
    return {};
}

ShotWindowAttached::ShotWindowAttached(QObject *parent)
    : QObject(parent)
{
    // The item may be asked before it has been put in its window.
    QTimer::singleShot(0, this, &ShotWindowAttached::windowChanged);
}

QObject *ShotWindowAttached::window() const
{
    for (auto *item = qobject_cast<QQuickItem *>(parent()); item; item = item->parentItem()) {
        if (QObject *window = item->property("shotWindow").value<QObject *>()) {
            return window;
        }
    }
    return nullptr;
}

QQuickItem *ShotWindowAttached::contentItem() const
{
    for (auto *item = qobject_cast<QQuickItem *>(parent()); item; item = item->parentItem()) {
        if (item->property("shotWindow").value<QObject *>()) {
            return item;
        }
    }
    return nullptr;
}

QHash<int, QByteArray> ShotTasksModel::roleNames() const
{
    return {
        {Qt::DisplayRole, "display"},
        {AppId, "AppId"},
        {AppName, "AppName"},
        {IsWindow, "IsWindow"},
        {IsLauncher, "IsLauncher"},
        {IsStartup, "IsStartup"},
        {IsDemandingAttention, "IsDemandingAttention"},
        {IsMinimized, "IsMinimized"},
        {ChildCount, "ChildCount"},
        {LastActivated, "LastActivated"},
        {ApplicationMenuServiceName, "ApplicationMenuServiceName"},
        {ApplicationMenuObjectPath, "ApplicationMenuObjectPath"},
    };
}

QVariant ShotTasksModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size()) {
        return {};
    }
    const Row &row = m_rows.at(index.row());
    const ShotApp *app = appById(row.id);
    switch (role) {
    case Qt::DisplayRole:
    case AppName:
        return app ? app->name : row.id;
    case AppId:
        // As Plasma gives them: a launcher's ends in .desktop, a window's doesn't.
        return row.running ? row.id : row.id + QStringLiteral(".desktop");
    case IsWindow:
        return row.running && !m_starting.contains(row.id);
    case IsLauncher:
        return !row.running;
    case IsStartup:
        return m_starting.contains(row.id);
    case IsDemandingAttention:
        return m_attention.contains(row.id);
    case IsMinimized:
        return false;
    case ChildCount:
    case LastActivated:
        return 0;
    case ApplicationMenuServiceName:
        // The app's id stands for its bus name; Quickshell.shotMenus holds its menus.
        return row.running ? row.id : QString();
    case ApplicationMenuObjectPath:
        return row.running ? QStringLiteral("/MenuBar") : QString();
    }
    return {};
}

QModelIndex ShotTasksModel::activeTask() const
{
    for (int row = 0; row < m_rows.size(); ++row) {
        if (m_rows.at(row).running && m_rows.at(row).id == m_active) {
            return index(row, 0);
        }
    }
    return {};
}

void ShotTasksModel::setLauncherList(const QStringList &list)
{
    if (list == m_launchers) {
        return;
    }
    m_launchers = list;
    rebuild();
    Q_EMIT launcherListChanged();
}

void ShotTasksModel::setRunning(const QStringList &ids)
{
    m_running = ids;
    rebuild();
}

void ShotTasksModel::setActive(const QString &id)
{
    m_active = id;
    rebuild();
}

void ShotTasksModel::setAttention(const QStringList &ids)
{
    m_attention = ids;
    rebuild();
}

void ShotTasksModel::setStarting(const QStringList &ids)
{
    m_starting = ids;
    rebuild();
}

void ShotTasksModel::rebuild()
{
    beginResetModel();
    m_rows.clear();
    QStringList listed;
    for (const QString &launcher : std::as_const(m_launchers)) {
        const QString id = bare(launcher);
        m_rows.append({id, m_running.contains(id) || m_starting.contains(id)});
        listed << id;
    }
    for (const QString &id : m_running + m_starting) {
        if (!listed.contains(id)) {
            m_rows.append({id, true});
            listed << id;
        }
    }
    endResetModel();
    Q_EMIT shotChanged();
    Q_EMIT activeTaskChanged();
}

void registerStubs(const QString &shellDir, const QString &iconsDir, const QString &wallpapersDir)
{
    const QString attached = QStringLiteral("only as an attached property");
    qmlRegisterSingletonInstance("Quickshell", 1, 0, "Quickshell", new ShotShell(shellDir, iconsDir, wallpapersDir));
    qmlRegisterSingletonInstance("Quickshell", 1, 0, "DesktopEntries", new ShotEntries);
    qmlRegisterUncreatableType<ShotScreen>("Quickshell", 1, 0, "ShellScreen", QStringLiteral("the sheet's screen is Quickshell.screens[0]"));
    qmlRegisterType<ShotObjectModel>("Quickshell", 1, 0, "ShotObjectModel");
    qmlRegisterUncreatableType<ShotWindowAttached>("Quickshell", 1, 0, "QsWindow", attached);
    qmlRegisterUncreatableType<ShotLayerAttached>("Quickshell.Wayland", 1, 0, "WlrLayershell", attached);
    qmlRegisterUncreatableType<ShotBlurAttached>("Quickshell.Wayland", 1, 0, "BackgroundEffect", attached);
    qmlRegisterUncreatableType<ShotAbstractTasksModel>("org.kde.taskmanager", 1, 0, "AbstractTasksModel", QStringLiteral("only for its roles"));
    qmlRegisterType<ShotTasksModel>("org.kde.taskmanager", 1, 0, "TasksModel");
}
