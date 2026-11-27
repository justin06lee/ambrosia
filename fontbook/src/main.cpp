#include "../../kit/firstshortcut.h"
#include "app.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    // Inter Variable has a real Bold: never let Qt fake one over it.
    qputenv("QT_NO_SYNTHESIZED_BOLD", "1");
    // A QApplication: the Open panel and the pop-up menus are the
    // platform's.
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-fontbook"));
    QApplication::setApplicationDisplayName(QStringLiteral("Font Book"));
    QApplication::setApplicationVersion(QStringLiteral(FONTBOOK_VERSION));
    QApplication::setOrganizationName(QStringLiteral("ambrosia"));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.fontbook"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.fontbook")));
    // A font file's preview may be all that is open, or nothing for a
    // moment between two windows: Main.qml ends it when the last one goes.
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Font Book: the computer's fonts, and adding your own"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once it has drawn, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption view(QStringLiteral("view"), QStringLiteral("Open on grid, samples or list (for grabs)."), QStringLiteral("name"));
    const QCommandLineOption family(QStringLiteral("family"), QStringLiteral("Open a typeface's page (for grabs)."), QStringLiteral("name"));
    const QCommandLineOption info(QStringLiteral("info"), QStringLiteral("Show the info pane (for grabs)."));
    parser.addOptions({appearance, grab, active, view, family, info});
    parser.addPositionalArgument(QStringLiteral("files"), QStringLiteral("Font files to look at and install."), QStringLiteral("[files...]"));
    parser.process(app);

    App::Options options;
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.view = parser.value(view);
    options.family = parser.value(family);
    options.info = parser.isSet(info);
    QStringList asked;
    for (const QString &argument : parser.positionalArguments()) {
        const QUrl url = QUrl::fromUserInput(argument, QDir::currentPath(), QUrl::AssumeLocalFile);
        options.files << url;
        asked << url.toString();
    }

    // One Font Book: a second launch hands its files to the first (with
    // its activation token) and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.fontbook"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.fontbook"), QStringLiteral("/org/ambrosia/fontbook"),
                                                           QStringLiteral("org.ambrosia.FontBook"), QStringLiteral("Open"));
        call << asked << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App fontBook(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/fontbook"), &fontBook, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("FontBook"), QStringLiteral("Main"));
    return app.exec();
}
