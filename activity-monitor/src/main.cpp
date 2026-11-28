#include "../../kit/firstshortcut.h"
#include "../../kit/scrolling.h"
#include "app.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickImageProvider>

// image://icon/NAME, an icon of the system's theme: an app's, beside its
// process's name.
class ThemeIcons : public QQuickImageProvider
{
public:
    ThemeIcons()
        : QQuickImageProvider(QQuickImageProvider::Pixmap)
    {
    }
    QPixmap requestPixmap(const QString &name, QSize *size, const QSize &requested) override
    {
        const QSize wanted = requested.isValid() ? requested : QSize(64, 64);
        const QIcon icon = name.startsWith(QLatin1Char('/')) ? QIcon(name) : QIcon::fromTheme(name, QIcon::fromTheme(QStringLiteral("application-x-executable")));
        const QPixmap pixmap = icon.pixmap(wanted);
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};

int main(int argc, char *argv[])
{
    // Inter Variable has a real Bold: never let Qt fake one over it.
    qputenv("QT_NO_SYNTHESIZED_BOLD", "1");
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    kitScrolling(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-activity-monitor"));
    QApplication::setApplicationDisplayName(QStringLiteral("Activity Monitor"));
    QApplication::setApplicationVersion(QStringLiteral(MONITOR_VERSION));
    QApplication::setOrganizationName(QStringLiteral("ambrosia"));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.activitymonitor"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.activitymonitor")));
    // Its inspectors may all be closed and it goes on; closing its own
    // window ends it (MonitorWindow says so).
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Activity Monitor: what the computer is doing"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once it has read twice, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption tab(QStringLiteral("tab"), QStringLiteral("Open on cpu, memory, energy, disk or network (for grabs)."), QStringLiteral("name"));
    const QCommandLineOption inspect(QStringLiteral("inspect"), QStringLiteral("Open a process's inspector too, and grab that (for grabs)."), QStringLiteral("pid"));
    parser.addOptions({appearance, grab, active, tab, inspect});
    parser.process(app);

    App::Options options;
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.tab = parser.value(tab);
    options.inspect = parser.isSet(inspect) ? parser.value(inspect).toInt() : -1;

    // One Activity Monitor: a second launch brings the first one's window
    // forward (with its activation token) and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.activitymonitor"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.activitymonitor"), QStringLiteral("/org/ambrosia/activitymonitor"),
                                                           QStringLiteral("org.ambrosia.ActivityMonitor"), QStringLiteral("Show"));
        call << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App monitor(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/activitymonitor"), &monitor, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new ThemeIcons);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("ActivityMonitor"), QStringLiteral("Main"));
    return app.exec();
}
