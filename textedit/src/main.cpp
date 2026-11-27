#include "../../kit/firstshortcut.h"
#include "app.h"

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
    // A point is a pixel of the window, as on a Mac: 12-point text is 12
    // high here too, not 16 (the interface gives its sizes in pixels and
    // doesn't change).
    qputenv("QT_FONT_DPI", "72");
    QApplication app(argc, argv);
    takeFirstShortcutId(&app);
    QApplication::setApplicationName(QStringLiteral("ambrosia-textedit"));
    QApplication::setApplicationDisplayName(QStringLiteral("TextEdit"));
    QApplication::setApplicationVersion(QStringLiteral(TEXTEDIT_VERSION));
    // The Wayland app id: the Dock and the menu bar know it by this.
    QApplication::setDesktopFileName(QStringLiteral("org.ambrosia.textedit"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.ambrosia.textedit")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Ambrosia's TextEdit: plain and rich text"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("files"), QStringLiteral("Documents to open, each in a window."), QStringLiteral("[files...]"));
    const QCommandLineOption appearance(QStringLiteral("appearance"), QStringLiteral("Force light or dark."), QStringLiteral("mode"));
    const QCommandLineOption grab(QStringLiteral("grab"), QStringLiteral("Save the first window to a PNG once it is shown, then quit."), QStringLiteral("file"));
    const QCommandLineOption active(QStringLiteral("active"), QStringLiteral("Draw windows as the active one (for grabs)."));
    const QCommandLineOption plain(QStringLiteral("plain"), QStringLiteral("A new document is plain text."));
    const QCommandLineOption find(QStringLiteral("find"), QStringLiteral("Open with the Find bar looking for this (for grabs)."), QStringLiteral("text"));
    parser.addOptions({appearance, grab, active, plain, find});
    parser.process(app);

    App::Options options;
    options.files = App::urls(parser.positionalArguments());
    options.appearance = parser.value(appearance);
    options.grab = parser.value(grab);
    options.active = parser.isSet(active);
    options.plain = parser.isSet(plain);
    options.find = parser.value(find);

    // One TextEdit, as on a Mac: a second launch hands its files (and its
    // activation token) to the first and leaves.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (options.grab.isEmpty() && bus.isConnected() && !bus.registerService(QStringLiteral("org.ambrosia.textedit"))) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.ambrosia.textedit"), QStringLiteral("/org/ambrosia/textedit"),
                                                           QStringLiteral("org.ambrosia.TextEdit"), QStringLiteral("Open"));
        call << options.files << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        bus.call(call);
        return 0;
    }

    App textedit(options);
    if (options.grab.isEmpty())
        bus.registerObject(QStringLiteral("/org/ambrosia/textedit"), &textedit, QDBusConnection::ExportScriptableSlots);
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new Icons);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("TextEditor"), QStringLiteral("Main"));
    return app.exec();
}
