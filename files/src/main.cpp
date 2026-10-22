#include "app.h"
#include "index.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QPainter>
#include <QQuickImageProvider>
#include <QRegularExpression>
#include <QSvgRenderer>
#include <QSettings>
#include <QStandardPaths>

int benchSearch(const QStringList &queries); // searchbench.cpp

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

// A tagged folder in its tag's color, as macOS 26 draws it
// (image://folder/COLOR): the art's blues move to the tag's hue, its middle
// blue becoming the tag's color and the rest keeping their steps of light
// around it; the paper stays white.
class FolderProvider : public QQuickImageProvider
{
public:
    FolderProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override
    {
        static const QHash<QString, QColor> tags = {
            {QStringLiteral("red"), QColor(0xe6524c)},    {QStringLiteral("orange"), QColor(0xec9647)},
            {QStringLiteral("yellow"), QColor(0xf0c43c)}, {QStringLiteral("green"), QColor(0x66c966)},
            {QStringLiteral("blue"), QColor(0x4089f2)},   {QStringLiteral("purple"), QColor(0xc043dc)},
            {QStringLiteral("gray"), QColor(0x98989d)},
        };
        QFile file(QStringLiteral(":/qt/qml/Files/art/folder.svg"));
        file.open(QIODevice::ReadOnly);
        QString svg = QString::fromUtf8(file.readAll());
        if (const QColor tag = tags.value(id); tag.isValid()) {
            const QColor middle(0x63c4f0); // the front's middle blue
            static const QRegularExpression hex(QStringLiteral("#[0-9a-fA-F]{6}"));
            QString out;
            qsizetype last = 0;
            for (auto it = hex.globalMatch(svg); it.hasNext();) {
                const auto m = it.next();
                QColor c(m.captured());
                if (c.hslSaturationF() > 0.3) { // a blue, not the paper
                    const float light = std::clamp(tag.lightnessF() + 0.8f * (c.lightnessF() - middle.lightnessF()), 0.0f, 1.0f);
                    const float saturation = std::clamp(tag.hslSaturationF() * c.hslSaturationF() / middle.hslSaturationF(), 0.0f, 1.0f);
                    c = QColor::fromHslF(std::max(0.0f, tag.hslHueF()), saturation, light);
                }
                out += svg.mid(last, m.capturedStart() - last) + c.name();
                last = m.capturedEnd();
            }
            svg = out + svg.mid(last);
        }
        QSvgRenderer renderer(svg.toUtf8());
        QImage image(requested.isValid() ? requested : QSize(64, 64), QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        renderer.render(&painter);
        painter.end();
        if (size)
            *size = image.size();
        return image;
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
    const QCommandLineOption benchSearchOption(QStringLiteral("bench-search"),
                                               QStringLiteral("Time the index and these searches (comma-separated), with no window, then quit."),
                                               QStringLiteral("queries"));
    parser.addOptions({newWindow, background, appearance, view, size, grab, bench, expand, select, active, sidebar, benchSearchOption});
    parser.addPositionalArgument(QStringLiteral("urls"), QStringLiteral("Folders to open."), QStringLiteral("[urls...]"));
    parser.process(app);

    if (parser.isSet(benchSearchOption))
        return benchSearch(parser.value(benchSearchOption).split(QLatin1Char(','), Qt::SkipEmptyParts));
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
    engine.addImageProvider(QStringLiteral("folder"), new FolderProvider);
    App files(&engine, options);
    if (!oneShot)
        bus.registerObject(QStringLiteral("/org/ambrosia/files"), &files, QDBusConnection::ExportScriptableSlots);
    if (!quiet)
        files.Open(urls);
    // The index behind search, warm from the start (a one-shot run starts
    // it only if it searches).
    if (!oneShot)
        Index::instance()->start();
    return app.exec();
}
