#include "app.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickImageProvider>

// image://icon/NAME, an icon of the system's theme, or a file's.
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
    // Inter Variable has a real Bold: never let Qt fake one over it (the
    // Ambrosia session sets this too, but not every session does).
    qputenv("QT_NO_SYNTHESIZED_BOLD", "1");
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("ambrosia-settings"));
    QApplication::setApplicationDisplayName(QStringLiteral("System Settings"));
    QApplication::setApplicationVersion(QStringLiteral(SETTINGS_VERSION));
    // The Wayland app id: the Dock and the menu bar know Settings by it.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.settings"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.settings")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's System Settings"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption pane(QStringLiteral("pane"), QStringLiteral("The pane to show: general, about, network, sound… (sound?input: a place in it)"), QStringLiteral("pane"));
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once its pane is shown, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw the window as the active one (for grabs, where no window has the keyboard)."));
    parser.addOptions({pane, appearance, grab, active});
    parser.process(app);

    App::Options options;
    options.pane = parser.value(pane);
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);

    // One window, as System Settings: a second launch hands its pane (and
    // its activation token) to the first and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.settings"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.settings"), QStringLiteral("/org/ambrosia/settings"),
                                                           QStringLiteral("org.ambrosia.Settings"), QStringLiteral("Show"));
        call << options.pane << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App settings(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/settings"), &settings, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new ThemeIcons);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("Settings"), QStringLiteral("SettingsWindow"));
    return app.exec();
}
