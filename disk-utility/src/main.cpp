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
    QApplication::setApplicationName(QStringLiteral("ambrosia-disk-utility"));
    QApplication::setApplicationDisplayName(QStringLiteral("Disk Utility"));
    QApplication::setApplicationVersion(QStringLiteral(DISKUTILITY_VERSION));
    QApplication::setOrganizationName(QStringLiteral("ambrosia"));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.diskutility"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.diskutility")));
    // The Info windows may outlive the main one for a moment: Main.qml
    // ends the app when the main window goes.
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Disk Utility: the computer's disks and volumes, and what can be done to them"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once it has drawn, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption show(QStringLiteral("show"), QStringLiteral("Choose a device by its name, as sda1 (for grabs)."), QStringLiteral("device"));
    const QCommandLineOption all(QStringLiteral("all"), QStringLiteral("List every device, not only volumes (for grabs)."));
    const QCommandLineOption sheet(QStringLiteral("sheet"), QStringLiteral("Show a sheet: erase, firstaid or info (for grabs)."), QStringLiteral("name"));
    parser.addOptions({appearance, grab, active, show, all, sheet});
    parser.addPositionalArgument(QStringLiteral("files"), QStringLiteral("Disk images to open."), QStringLiteral("[files...]"));
    parser.process(app);

    App::Options options;
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.show = parser.value(show);
    options.all = parser.isSet(all);
    options.sheet = parser.value(sheet);
    QStringList asked;
    for (const QString &argument : parser.positionalArguments()) {
        const QUrl url = QUrl::fromUserInput(argument, QDir::currentPath(), QUrl::AssumeLocalFile);
        options.files << url;
        asked << url.toString();
    }

    // One Disk Utility: a second launch hands its files to the first (with
    // its activation token) and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.diskutility"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.diskutility"), QStringLiteral("/org/ambrosia/diskutility"),
                                                           QStringLiteral("org.ambrosia.DiskUtility"), QStringLiteral("Open"));
        call << asked << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App diskUtility(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/diskutility"), &diskUtility, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("DiskUtility"), QStringLiteral("Main"));
    return app.exec();
}
