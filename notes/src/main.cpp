#include "../../kit/firstshortcut.h"
#include "../../kit/scrolling.h"
#include "app.h"
#include "store.h"

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
    // A QApplication: the Save panel and the pop-up menus are the
    // platform's.
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    kitScrolling(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-notes"));
    QApplication::setApplicationDisplayName(QStringLiteral("Notes"));
    QApplication::setApplicationVersion(QStringLiteral(NOTES_VERSION));
    QApplication::setOrganizationName(QStringLiteral("ambrosia"));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.notes"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.notes")));
    // The Settings window may outlive the main one for a moment: Main.qml
    // ends the app when the main window goes.
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Notes: notes in folders, kept as Markdown files"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once it has drawn, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption store(QStringLiteral("store"), QStringLiteral("Keep the notes in this directory, not the usual one."), QStringLiteral("directory"));
    const QCommandLineOption show(QStringLiteral("show"), QStringLiteral("Show something over the window: format (for grabs)."), QStringLiteral("what"));
    parser.addOptions({appearance, grab, active, store, show});
    parser.process(app);

    App::Options options;
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.show = parser.value(show);
    const QString root = parser.isSet(store) ? QDir(parser.value(store)).absolutePath() : QString();

    // One Notes over the usual notes: a second launch brings the first
    // forward (with its activation token) and leaves. One started on a
    // directory of its own, or for a grab, stands apart.
    QDBusConnection bus = QDBusConnection::sessionBus();
    const bool usual = options.grab.isEmpty() && root.isEmpty();
    if (usual && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.notes"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.notes"), QStringLiteral("/org/ambrosia/notes"),
                                                           QStringLiteral("org.ambrosia.Notes"), QStringLiteral("Show"));
        call << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App notes(options);
    Store kept(root);
    if (usual)
        bus.registerObject(QStringLiteral("/org/ambrosia/notes"), &notes, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("Notes"), QStringLiteral("Main"));
    return app.exec();
}
