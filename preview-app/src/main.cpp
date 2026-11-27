#include "../../kit/firstshortcut.h"
#include "app.h"
#include "pages.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QIcon>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    // Inter Variable has a real Bold: never let Qt fake one over it.
    qputenv("QT_NO_SYNTHESIZED_BOLD", "1");
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-preview"));
    QApplication::setApplicationDisplayName(QStringLiteral("Preview"));
    QApplication::setApplicationVersion(QStringLiteral(PREVIEW_VERSION));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.preview"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.preview")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Preview: pictures and PDFs"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("files"), QStringLiteral("Pictures (together in one window) and PDFs (a window each) to open."), QStringLiteral("[files...]"));
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the first window to a PNG once it is shown, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption find(QStringLiteral("find"), QStringLiteral("Search a PDF for this as it opens (for grabs)."), QStringLiteral("text"));
    const QCommandLineOption zoom(QStringLiteral("zoom"), QStringLiteral("Open at this zoom, 1 being actual size (for grabs)."), QStringLiteral("factor"));
    const QCommandLineOption sidebar(QStringLiteral("sidebar"), QStringLiteral("Open with the sidebar as none, thumbnails or outline (for grabs)."), QStringLiteral("mode"));
    parser.addOptions({appearance, grab, active, find, zoom, sidebar});
    parser.process(app);

    App::Options options;
    options.files = App::urls(parser.positionalArguments());
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.find = parser.value(find);
    options.zoom = parser.value(zoom).toDouble();
    options.sidebar = parser.value(sidebar);

    // One Preview, as on a Mac: a second launch hands its files (and its
    // activation token) to the first and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.preview"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.preview"), QStringLiteral("/org/ambrosia/preview"),
                                                           QStringLiteral("org.ambrosia.Preview"), QStringLiteral("Open"));
        call << options.files << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App preview(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/preview"), &preview, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("page"), new Pages);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("Preview"), QStringLiteral("Main"));
    return app.exec();
}
