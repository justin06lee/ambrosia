#include "../../kit/firstshortcut.h"
#include "app.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QIcon>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    // Inter Variable has a real Bold: never let Qt fake one over it.
    qputenv("QT_NO_SYNTHESIZED_BOLD", "1");
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-calculator"));
    QApplication::setApplicationDisplayName(QStringLiteral("Calculator"));
    QApplication::setApplicationVersion(QStringLiteral(CALCULATOR_VERSION));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.calculator"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("accessories-calculator")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's Calculator"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the window to a PNG once it is shown, then quit."), QStringLiteral("file"));
    const QCommandLineOption keys(QStringLiteral("keys"), QStringLiteral("Keys to press as it opens, as on the buttons: 2+3×4="), QStringLiteral("keys"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw the window as the active one (for grabs)."));
    parser.addOptions({grab, keys, active});
    parser.process(app);

    App::Options options;
    options.grab = parser.value(grab);
    options.keys = parser.value(keys);
    options.active = parser.isSet(active);

    App calculator(options);
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("Calculator"), QStringLiteral("CalculatorWindow"));
    return app.exec();
}
