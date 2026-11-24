#include "portal.h"
#include "app.h"

#include <KWindowSystem>

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>

namespace {

// A filter as the portal writes it: (sa(us)), a name and its conditions,
// each a glob (0) or a MIME type (1).
struct Condition {
    uint type = 0;
    QString pattern;
};
struct Filter {
    QString name;
    QList<Condition> conditions;
};

QDBusArgument &operator<<(QDBusArgument &arg, const Condition &c)
{
    arg.beginStructure();
    arg << c.type << c.pattern;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, Condition &c)
{
    arg.beginStructure();
    arg >> c.type >> c.pattern;
    arg.endStructure();
    return arg;
}
QDBusArgument &operator<<(QDBusArgument &arg, const Filter &f)
{
    arg.beginStructure();
    arg << f.name << f.conditions;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, Filter &f)
{
    arg.beginStructure();
    arg >> f.name >> f.conditions;
    arg.endStructure();
    return arg;
}

QSettings settings()
{
    return QSettings(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/ambrosia/files.conf"),
                     QSettings::IniFormat);
}

// A path the portal sends as bytes with a NUL at the end.
QString pathOf(const QVariant &bytes)
{
    QByteArray path = bytes.toByteArray();
    while (path.endsWith('\0'))
        path.chop(1);
    return QString::fromLocal8Bit(path);
}

// "_Open" is GTK's way of marking the O as the button's key.
QString plain(QString label)
{
    static const QRegularExpression mnemonic(QStringLiteral("_(?!_)"));
    return label.replace(mnemonic, QString()).replace(QStringLiteral("__"), QStringLiteral("_"));
}

QList<Filter> filtersOf(const QVariantMap &options)
{
    return qdbus_cast<QList<Filter>>(options.value(QStringLiteral("filters")));
}

}

Q_DECLARE_METATYPE(Condition)
Q_DECLARE_METATYPE(Filter)

Portal::Portal(App *app)
    : QObject(app)
    , m_app(app)
{
    qDBusRegisterMetaType<Condition>();
    qDBusRegisterMetaType<QList<Condition>>();
    qDBusRegisterMetaType<Filter>();
    qDBusRegisterMetaType<QList<Filter>>();
}

QVariantMap Portal::panelFor(const QString &kind, const QString &title, const QVariantMap &options)
{
    const bool save = kind.startsWith(QLatin1String("save"));
    QVariantMap panel;
    panel.insert(QStringLiteral("kind"), kind);
    panel.insert(QStringLiteral("title"), title);
    const QString accept = plain(options.value(QStringLiteral("accept_label")).toString());
    panel.insert(QStringLiteral("accept"), !accept.isEmpty() ? accept : save ? QStringLiteral("Save") : QStringLiteral("Open"));
    panel.insert(QStringLiteral("multiple"), kind != QLatin1String("save") && options.value(QStringLiteral("multiple")).toBool());
    QString name = options.value(QStringLiteral("current_name")).toString();
    if (name.isEmpty() && options.contains(QStringLiteral("current_file")))
        name = QFileInfo(pathOf(options.value(QStringLiteral("current_file")))).fileName();
    panel.insert(QStringLiteral("name"), kind == QLatin1String("save") ? name : QString());

    QVariantList filters;
    int chosen = -1;
    const QList<Filter> all = filtersOf(options);
    const Filter current = qdbus_cast<Filter>(options.value(QStringLiteral("current_filter")));
    for (const Filter &f : all) {
        QStringList globs, mimes;
        for (const Condition &c : f.conditions)
            (c.type == 0 ? globs : mimes) << c.pattern;
        if (!current.name.isEmpty() && f.name == current.name)
            chosen = int(filters.size());
        filters << QVariantMap{{QStringLiteral("text"), f.name}, {QStringLiteral("value"), int(filters.size())},
                               {QStringLiteral("globs"), globs}, {QStringLiteral("mimes"), mimes}};
    }
    if (chosen < 0 && !filters.isEmpty())
        chosen = 0;
    panel.insert(QStringLiteral("filters"), filters);
    panel.insert(QStringLiteral("filter"), chosen);
    return panel;
}

QUrl Portal::folderFor(const QVariantMap &options)
{
    QString folder = pathOf(options.value(QStringLiteral("current_folder")));
    if (folder.isEmpty() && options.contains(QStringLiteral("current_file")))
        folder = QFileInfo(pathOf(options.value(QStringLiteral("current_file")))).path();
    if (folder.isEmpty() || !QFileInfo(folder).isDir())
        folder = settings().value(QStringLiteral("panel/folder")).toString();
    if (folder.isEmpty() || !QFileInfo(folder).isDir())
        folder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (folder.isEmpty() || !QFileInfo(folder).isDir())
        folder = QDir::homePath();
    return QUrl::fromLocalFile(folder);
}

QVariantMap Portal::samplePanel(const QString &kind)
{
    QVariantMap panel = panelFor(kind, kind == QLatin1String("save") ? QStringLiteral("Save") : QStringLiteral("Open"), {});
    if (kind == QLatin1String("save"))
        panel.insert(QStringLiteral("name"), QStringLiteral("Untitled.txt"));
    if (kind == QLatin1String("open")) {
        panel.insert(QStringLiteral("filters"),
                     QVariantList{QVariantMap{{QStringLiteral("text"), QStringLiteral("Images")}, {QStringLiteral("value"), 0},
                                              {QStringLiteral("globs"), QStringList{}}, {QStringLiteral("mimes"), QStringList{QStringLiteral("image/*")}}},
                                  QVariantMap{{QStringLiteral("text"), QStringLiteral("All Files")}, {QStringLiteral("value"), 1},
                                              {QStringLiteral("globs"), QStringList{QStringLiteral("*")}}, {QStringLiteral("mimes"), QStringList{}}}});
        panel.insert(QStringLiteral("filter"), 0);
    }
    return panel;
}

void Portal::OpenFile(const QDBusObjectPath &handle, const QString &, const QString &parent_window, const QString &title, const QVariantMap &options)
{
    ask(options.value(QStringLiteral("directory")).toBool() ? QStringLiteral("folder") : QStringLiteral("open"), handle, parent_window, title, options);
}

void Portal::SaveFile(const QDBusObjectPath &handle, const QString &, const QString &parent_window, const QString &title, const QVariantMap &options)
{
    ask(QStringLiteral("save"), handle, parent_window, title, options);
}

void Portal::SaveFiles(const QDBusObjectPath &handle, const QString &, const QString &parent_window, const QString &title, const QVariantMap &options)
{
    ask(QStringLiteral("saveFiles"), handle, parent_window, title, options);
}

void Portal::ask(const QString &kind, const QDBusObjectPath &handle, const QString &parent, const QString &title, const QVariantMap &options)
{
    setDelayedReply(true);
    const QDBusMessage call = message();
    QQuickWindow *window = m_app->openPanel(folderFor(options), panelFor(kind, title, options));
    if (!window) {
        QDBusConnection::sessionBus().send(call.createReply({uint(2), QVariantMap()}));
        return;
    }
    // Over the window that asked, as a sheet is on a Mac: KWin keeps it
    // above that window and places it on it.
    if (parent.startsWith(QLatin1String("wayland:")))
        KWindowSystem::setMainWindow(window, parent.mid(8));
    else if (parent.startsWith(QLatin1String("x11:")))
        KWindowSystem::setMainWindow(window, WId(parent.mid(4).toULongLong(nullptr, 16)));
    new PanelRequest(window, call, handle.path(), options, this);
    window->show();
    window->requestActivate();
}

PanelRequest::PanelRequest(QQuickWindow *window, const QDBusMessage &call, const QString &path, const QVariantMap &options, QObject *parent)
    : QObject(parent)
    , m_window(window)
    , m_call(call)
    , m_path(path)
    , m_options(options)
{
    QDBusConnection::sessionBus().registerObject(m_path, this, QDBusConnection::ExportScriptableSlots);
    connect(window, SIGNAL(panelAccepted(QVariant, int)), this, SLOT(accepted(QVariant, int)));
    // Closed with no choice made (Cancel, Escape, the app itself): cancelled.
    connect(window, &QObject::destroyed, this, [this] {
        answer(1, {});
        deleteLater();
    });
}

PanelRequest::~PanelRequest()
{
    QDBusConnection::sessionBus().unregisterObject(m_path);
}

void PanelRequest::Close()
{
    answer(1, {});
    if (m_window)
        m_window->close();
}

void PanelRequest::accepted(const QVariant &urls, int filter)
{
    QStringList uris;
    for (const QVariant &url : urls.toList())
        uris << url.toUrl().toString(QUrl::FullyEncoded);
    if (uris.isEmpty())
        return;
    const QUrl first(uris.first());
    QString folder = first.toLocalFile();
    // SaveFiles chooses a folder: the answer is each file's place in it.
    if (m_options.contains(QStringLiteral("files"))) {
        const QList<QByteArray> names = qdbus_cast<QList<QByteArray>>(m_options.value(QStringLiteral("files")));
        uris.clear();
        for (const QByteArray &name : names)
            uris << QUrl::fromLocalFile(folder + QLatin1Char('/') + pathOf(name)).toString(QUrl::FullyEncoded);
    } else if (!QFileInfo(folder).isDir()) {
        folder = QFileInfo(folder).path();
    }
    if (first.isLocalFile())
        settings().setValue(QStringLiteral("panel/folder"), folder);

    QVariantMap results{{QStringLiteral("uris"), uris}};
    const QList<Filter> filters = filtersOf(m_options);
    if (filter >= 0 && filter < filters.size())
        results.insert(QStringLiteral("current_filter"), QVariant::fromValue(filters.at(filter)));
    answer(0, results);
    if (m_window)
        m_window->close();
}

void PanelRequest::answer(uint response, const QVariantMap &results)
{
    if (m_done)
        return;
    m_done = true;
    QDBusConnection::sessionBus().send(m_call.createReply({response, results}));
}
