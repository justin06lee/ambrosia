#include "app.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickImageProvider>
#include <QSettings>
#include <QStandardPaths>

// Theme icons for QML, as image://icon/NAME (the app that opens a file).
class IconProvider : public QQuickImageProvider
{
public:
    IconProvider()
        : QQuickImageProvider(QQuickImageProvider::Pixmap)
    {
    }
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override
    {
        const QIcon icon = id.startsWith(QLatin1Char('/')) ? QIcon(id) : QIcon::fromTheme(id);
        const QPixmap pixmap = icon.pixmap(requested.isValid() ? requested : QSize(32, 32));
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("ambrosia-files"));
    QApplication::setApplicationDisplayName(QStringLiteral("Files"));
    QApplication::setApplicationVersion(QStringLiteral(FILES_VERSION));
    // The Wayland app id: the Dock and the menu bar know Files by it.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.files"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.files")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Files"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption newWindow(QStringLiteral("new-window"), QStringLiteral("Open a new window on the home folder."));
    const QCommandLineOption background(QStringLiteral("background"), QStringLiteral("Start with no window, as at login, and keep running."));
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption view(QStringLiteral("view"), QStringLiteral("The first window's view: icon, list, column, gallery."), QStringLiteral("view"));
    const QCommandLineOption size(QStringLiteral("size"), QStringLiteral("The first window's size, WxH in points."), QStringLiteral("size"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the first window to a PNG once its folder is shown, then quit."), QStringLiteral("file"));
    const QCommandLineOption bench(QStringLiteral("bench"), QStringLiteral("Print how long the first folder took to load, then quit."));
    const QCommandLineOption expand(QStringLiteral("expand"), QStringLiteral("Folders in the first one to open in place, comma-separated paths (for grabs)."), QStringLiteral("paths"));
    const QCommandLineOption select(QStringLiteral("select"), QStringLiteral("The item to select in the first folder (for grabs)."), QStringLiteral("name"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw the first window as the active one (for grabs, where no window has the keyboard)."));
    const QCommandLineOption sidebar(QStringLiteral("sidebar"), QStringLiteral("The sidebar: floating (the default) or flush."), QStringLiteral("style"));
    parser.addOptions({newWindow, background, appearance, view, size, grab, bench, expand, select, active, sidebar});
    parser.addPositionalArgument(QStringLiteral("urls"), QStringLiteral("Folders to open."), QStringLiteral("[urls...]"));
    parser.process(app);

    QStringList urls;
    for (const QString &arg : parser.positionalArguments())
        urls << QUrl::fromUserInput(arg, QDir::currentPath(), QUrl::AssumeLocalFile).toString();

    App::Options options;
    options.appearance = parser.value(appearance);
    options.view = parser.value(view);
    options.grab = parser.value(grab);
    options.bench = parser.isSet(bench);
    options.expand = parser.value(expand).split(QLatin1Char(','), Qt::SkipEmptyParts);
    options.select = parser.value(select);
    options.active = parser.isSet(active);
    // The sidebar, from the command line or ~/.config/ambrosia/files.conf.
    const QSettings settings(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/ambrosia/files.conf"),
                             QSettings::IniFormat);
    options.sidebar = parser.isSet(sidebar) ? parser.value(sidebar) : settings.value(QStringLiteral("sidebar"), QStringLiteral("floating")).toString();
    if (const QStringList wh = parser.value(size).split(QLatin1Char('x')); wh.size() == 2)
        options.size = QSize(wh[0].toInt(), wh[1].toInt());
    const bool oneShot = options.bench || !options.grab.isEmpty();
    const bool quiet = parser.isSet(background) && urls.isEmpty();

    // One process serves every window: a second launch hands its folders to
    // the first and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!oneShot && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.files"))) {
        if (quiet)
            return 0; // already running
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.files"), QStringLiteral("/org/ambrosia/files"),
                                                           QStringLiteral("org.ambrosia.Files"), QStringLiteral("Open"));
        call << urls;
        bus.call(call);
        return 0;
    }

    // Files keeps running with no window open, as Finder does: started at
    // login (ambrosia-files.service), it is there for the Dock's Trash,
    // whose drops it trashes undoably, and for the next window.
    if (!oneShot)
        app.setQuitOnLastWindowClosed(false);

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    App files(&engine, options);
    if (!oneShot)
        bus.registerObject(QStringLiteral("/org/ambrosia/files"), &files, QDBusConnection::ExportScriptableSlots);
    if (!quiet)
        files.Open(urls);
    return app.exec();
}
