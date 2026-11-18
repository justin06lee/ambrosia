// Draws a QML file into a picture, with no window on screen:
//
//   qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]
//
// The window is never shown; Qt Quick draws one frame of it into a texture
// with the real renderer, so shadows and shapes come out as on screen. The
// file sees `shotDark` (true with --dark) to set the Theme's mode by.
// --font loads a font the machine hasn't installed (Inter, on a Mac).

#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickView>
#include <QTimer>

int main(int argc, char **argv)
{
    // No Dock icon and no stolen focus while it runs on a Mac.
    qputenv("QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM", "1");
    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 3) {
        qWarning("usage: qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]");
        return 2;
    }
    int wait = 300;
    QQuickView view;
    for (qsizetype i = 3; i < args.size(); ++i) {
        if (args.at(i) == QLatin1String("--import") && i + 1 < args.size()) {
            view.engine()->addImportPath(args.at(++i));
        } else if (args.at(i) == QLatin1String("--font") && i + 1 < args.size()) {
            if (QFontDatabase::addApplicationFont(args.at(++i)) < 0) {
                qWarning("couldn't load the font %s", qPrintable(args.at(i)));
            }
        } else if (args.at(i) == QLatin1String("--wait") && i + 1 < args.size()) {
            wait = args.at(++i).toInt();
        }
    }
    view.rootContext()->setContextProperty(QStringLiteral("shotDark"), args.contains(QLatin1String("--dark")));
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(args.at(1)));
    if (view.status() != QQuickView::Ready) {
        for (const QQmlError &error : view.errors()) {
            qWarning("%s", qPrintable(error.toString()));
        }
        return 1;
    }
    int result = 0;
    // A moment for pictures to load and bindings to settle.
    QTimer::singleShot(wait, &app, [&] {
        if (!view.grabWindow().save(args.at(2))) {
            qWarning("couldn't write %s", qPrintable(args.at(2)));
            result = 1;
        }
        app.quit();
    });
    app.exec();
    return result;
}
