// Draws a QML file into a picture, with no window on screen:
//
//   qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]
//           [--shell dir] [--icons dir] [--wallpapers dir]
//   qmlshot --svg picture.svg out.png width height
//   qmlshot --crop picture.png out.png x y width height
//
// The window is never shown; Qt Quick draws one frame of it into a texture
// with the real renderer, so shadows and shapes come out as on screen. The
// file sees `shotDark` (true with --dark) to set the Theme's mode by, and
// `shotPointer`, to move and click the pointer with (stubs.h).
// --font loads a font the machine hasn't installed (Inter, on a Mac).
//
// The shell's own files load too: what they import of Quickshell and Plasma
// is stood in for (stubs.h, stubs/), told by --shell where the shell is, by
// --icons where the generated icon theme is and by --wallpapers where the
// desktop pictures are. --svg draws one of those from its SVG; --crop cuts
// a part out of a picture, to look at it closely.

#include "stubs.h"

#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickView>
#include <QSvgRenderer>
#include <QTimer>
#include <QtQuick/private/qquickwindow_p.h>

int main(int argc, char **argv)
{
    // No Dock icon and no stolen focus while it runs on a Mac.
    qputenv("QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM", "1");
    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 3) {
        qWarning("usage: qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]"
                 " [--shell dir] [--icons dir] [--wallpapers dir]\n"
                 "       qmlshot --svg picture.svg out.png width height\n"
                 "       qmlshot --crop picture.png out.png x y width height");
        return 2;
    }
    if (args.at(1) == QLatin1String("--svg")) {
        if (args.size() < 6) {
            return 2;
        }
        QSvgRenderer picture(args.at(2));
        QImage image(args.at(4).toInt(), args.at(5).toInt(), QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        picture.render(&painter);
        painter.end();
        return picture.isValid() && image.save(args.at(3)) ? 0 : 1;
    }
    if (args.at(1) == QLatin1String("--crop")) {
        if (args.size() < 8) {
            return 2;
        }
        const QImage part = QImage(args.at(2)).copy(args.at(4).toInt(), args.at(5).toInt(), args.at(6).toInt(), args.at(7).toInt());
        return !part.isNull() && part.save(args.at(3)) ? 0 : 1;
    }
    int wait = 300;
    QString shellDir = QDir::current().filePath(QStringLiteral("shell"));
    QString iconsDir = QDir::current().filePath(QStringLiteral("dist/icons/Ambrosia"));
    QString wallpapersDir;
    for (qsizetype i = 3; i + 1 < args.size(); ++i) {
        if (args.at(i) == QLatin1String("--shell")) {
            shellDir = QDir::current().absoluteFilePath(args.at(++i));
        } else if (args.at(i) == QLatin1String("--icons")) {
            iconsDir = QDir::current().absoluteFilePath(args.at(++i));
        } else if (args.at(i) == QLatin1String("--wallpapers")) {
            wallpapersDir = QDir::current().absoluteFilePath(args.at(++i));
        }
    }
    registerStubs(shellDir, iconsDir, wallpapersDir);
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
    view.rootContext()->setContextProperty(QStringLiteral("shotPointer"), new ShotPointer(&view));
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(args.at(1)));
    if (view.status() != QQuickView::Ready) {
        for (const QQmlError &error : view.errors()) {
            qWarning("%s", qPrintable(error.toString()));
        }
        return 1;
    }
    // A sheet that needs longer to settle says so (its shotWait).
    if (!args.contains(QLatin1String("--wait")) && view.rootObject()->property("shotWait").isValid()) {
        wait = view.rootObject()->property("shotWait").toInt();
    }
    int result = 0;
    // Nothing lays a hidden window out between frames, so it is asked to
    // now and then: rows and columns settle, and what follows them (a menu
    // under its title) finds them where they will be. (Drawing a frame
    // each time would do it too, but a hidden window's scene is thrown away
    // after every frame, and Shapes don't all come back.)
    QTimer pump;
    QObject::connect(&pump, &QTimer::timeout, &view, [&] { QQuickWindowPrivate::get(&view)->polishItems(); });
    pump.start(50);
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
