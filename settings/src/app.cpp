#include "app.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJSEngine>
#include <QPainter>
#include <QPainterPath>
#include <QPalette>
#include <QProcess>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTimer>

#include <cmath>

App *App::s_instance = nullptr;

namespace {

QString readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
}

// A battery that powers the computer (not a mouse's or a headset's).
bool findBattery()
{
    const QDir dir(QStringLiteral("/sys/class/power_supply"));
    for (const QString &name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const QString base = dir.filePath(name);
        if (readFile(base + QStringLiteral("/type")) == QLatin1String("Battery")
            && readFile(base + QStringLiteral("/scope")) != QLatin1String("Device"))
            return true;
    }
    return false;
}

// Pointing devices from the kernel's input list: a touchpad names itself
// so; anything else with a mouse handler is a mouse.
void findPointers(bool *mouse, bool *trackpad)
{
    const QString all = readFile(QStringLiteral("/proc/bus/input/devices"));
    for (const QString &device : all.split(QStringLiteral("\n\n"))) {
        QString name, handlers;
        for (const QString &line : device.split(QLatin1Char('\n'))) {
            if (line.startsWith(QLatin1String("N: Name=")))
                name = line.mid(8);
            else if (line.startsWith(QLatin1String("H: Handlers=")))
                handlers = line.mid(12);
        }
        if (!handlers.split(QLatin1Char(' ')).filter(QStringLiteral("mouse")).isEmpty()) {
            if (name.contains(QLatin1String("touchpad"), Qt::CaseInsensitive) || name.contains(QLatin1String("trackpad"), Qt::CaseInsensitive))
                *trackpad = true;
            else
                *mouse = true;
        }
    }
}

// KWin's shadow for a window with rounded corners, as Files makes it
// (files/src/app.cpp): two soft layers like macOS's, a wide one and a close
// one, split into the eight tiles KWindowShadow wants, with the window's own
// shape cut out so it doesn't show through the transparent corners.
KWindowShadow *makeShadow(QQuickWindow *window, int radius, qreal dpr)
{
    struct Layer {
        qreal y, blur, opacity;
    };
    const Layer layers[] = {{22, 50, 0.32}, {1, 3, 0.18}};
    const int pad = 72; // room for the widest layer, in points
    const int core = 2 * radius + 1;
    const int side = 2 * pad + core;
    QImage image(QSize(side, side) * dpr, QImage::Format_ARGB32_Premultiplied);
    image.setDevicePixelRatio(dpr);
    image.fill(Qt::transparent);
    const QRectF body(pad, pad, core, core);
    for (const Layer &layer : layers) {
        // A box blur three times over approximates a Gaussian.
        QImage mask(image.size(), QImage::Format_Alpha8);
        mask.fill(0);
        {
            QPainter p(&mask);
            p.setRenderHint(QPainter::Antialiasing);
            p.scale(dpr, dpr);
            QPainterPath path;
            path.addRoundedRect(body.translated(0, layer.y), radius, radius);
            p.fillPath(path, QColor(0, 0, 0, int(255 * layer.opacity)));
        }
        const int r = std::max(1, int(std::lround(layer.blur * dpr / 3.0)));
        const int w = mask.width(), h = mask.height();
        std::vector<int> line(std::max(w, h));
        for (int pass = 0; pass < 3; ++pass) {
            for (int y = 0; y < h; ++y) {
                uchar *row = mask.scanLine(y);
                for (int x = 0; x < w; ++x)
                    line[x] = row[x];
                int sum = 0;
                for (int x = -r; x <= r; ++x)
                    sum += line[std::clamp(x, 0, w - 1)];
                for (int x = 0; x < w; ++x) {
                    row[x] = uchar(sum / (2 * r + 1));
                    sum += line[std::min(x + r + 1, w - 1)] - line[std::max(x - r, 0)];
                }
            }
            for (int x = 0; x < w; ++x) {
                for (int y = 0; y < h; ++y)
                    line[y] = mask.scanLine(y)[x];
                int sum = 0;
                for (int y = -r; y <= r; ++y)
                    sum += line[std::clamp(y, 0, h - 1)];
                for (int y = 0; y < h; ++y) {
                    mask.scanLine(y)[x] = uchar(sum / (2 * r + 1));
                    sum += line[std::min(y + r + 1, h - 1)] - line[std::max(y - r, 0)];
                }
            }
        }
        QPainter p(&image);
        QImage tinted(image.size(), QImage::Format_ARGB32_Premultiplied);
        tinted.fill(Qt::black);
        {
            QPainter t(&tinted);
            t.setCompositionMode(QPainter::CompositionMode_DestinationIn);
            t.drawImage(0, 0, mask);
        }
        p.drawImage(QPointF(0, 0), tinted);
    }
    {
        QPainter p(&image);
        p.setRenderHint(QPainter::Antialiasing);
        p.setCompositionMode(QPainter::CompositionMode_Clear);
        QPainterPath path;
        path.addRoundedRect(body, radius, radius);
        p.fillPath(path, Qt::black);
    }
    auto tile = [&](qreal x, qreal y, qreal w, qreal h) {
        auto t = KWindowShadowTile::Ptr::create();
        QImage part = image.copy(QRectF(x * dpr, y * dpr, w * dpr, h * dpr).toRect());
        part.setDevicePixelRatio(dpr);
        t->setImage(part);
        return t;
    };
    const qreal edge = pad + radius;
    auto *shadow = new KWindowShadow(window);
    shadow->setTopLeftTile(tile(0, 0, edge, edge));
    shadow->setTopTile(tile(edge, 0, 1, edge));
    shadow->setTopRightTile(tile(edge + 1, 0, edge, edge));
    shadow->setRightTile(tile(edge + 1, edge, edge, 1));
    shadow->setBottomRightTile(tile(edge + 1, edge + 1, edge, edge));
    shadow->setBottomTile(tile(edge, edge + 1, 1, edge));
    shadow->setBottomLeftTile(tile(0, edge + 1, edge, edge));
    shadow->setLeftTile(tile(0, edge, edge, 1));
    shadow->setPadding(QMargins(pad, pad, pad, pad));
    shadow->setWindow(window);
    return shadow;
}

}

App::App(const Options &options)
    : m_options(options)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
    m_battery = findBattery();
    findPointers(&m_mouse, &m_trackpad);
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, &App::appearanceChanged);
    connect(qGuiApp, &QGuiApplication::paletteChanged, this, &App::appearanceChanged);
}

App *App::create(QQmlEngine *, QJSEngine *)
{
    return s_instance;
}

bool App::dark() const
{
    if (!m_options.appearance.isEmpty())
        return m_options.appearance == QLatin1String("dark");
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

QColor App::accent() const
{
    if (!m_options.appearance.isEmpty())
        return {};
    return QGuiApplication::palette().color(QPalette::Active, QPalette::Highlight);
}

bool App::hasModule(const QString &name) const
{
    for (const QString &dir : QCoreApplication::libraryPaths()) {
        for (const char *kind : {"systemsettings", "systemsettings_qwidgets"}) {
            if (QFile::exists(QStringLiteral("%1/plasma/kcms/%2/%3.so").arg(dir, QLatin1String(kind), name)))
                return true;
        }
    }
    return false;
}

void App::openModule(const QString &name)
{
    run(QStringLiteral("kcmshell6"), {name});
}

bool App::has(const QString &program) const
{
    return !QStandardPaths::findExecutable(program).isEmpty();
}

void App::run(const QString &program, const QStringList &arguments)
{
    if (!QProcess::startDetached(program, arguments))
        qWarning().noquote() << "Settings: couldn't start" << program;
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Settings: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    // A second later everything has been drawn (fonts, images) and the
    // services a pane reads (KScreen's configuration) have answered.
    QTimer::singleShot(1000, window, [this, window] {
        window->grabWindow().save(m_options.grab);
        QGuiApplication::quit();
    });
}

void App::activate(QQuickWindow *window)
{
    if (window->visibility() == QWindow::Minimized)
        window->showNormal();
    KWindowSystem::activateWindow(window);
}

void App::zoom(QQuickWindow *window)
{
    // xdg-shell maximizes both ways and KWin then ignores the window's fixed
    // width, so Settings asks KWin itself, through a script, to maximize it
    // vertically only (or restore it when it already fills the height).
    static const QString kwin = QStringLiteral("org.kde.KWin");
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QString path = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + QStringLiteral("/ambrosia-settings-zoom.js");
    QFile script(path);
    if (!bus.interface()->isServiceRegistered(kwin) || !script.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        window->visibility() == QWindow::Maximized ? window->showNormal() : window->showMaximized();
        return;
    }
    script.write(QStringLiteral("for (const w of workspace.windowList()) {\n"
                                "    if (w.pid !== %1) continue;\n"
                                "    const area = workspace.clientArea(KWin.MaximizeArea, w), frame = w.frameGeometry;\n"
                                "    w.setMaximize(Math.round(frame.y) !== Math.round(area.y) || Math.round(frame.height) !== Math.round(area.height), false);\n"
                                "}\n")
                     .arg(QCoreApplication::applicationPid())
                     .toUtf8());
    script.close();
    // The last run's script stays loaded until this one replaces it: KWin
    // reads the file after run() returns.
    static const QString name = QStringLiteral("ambrosia-settings-zoom");
    QDBusInterface scripting(kwin, QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"), bus);
    scripting.call(QStringLiteral("unloadScript"), name);
    const QDBusReply<int> id = scripting.call(QStringLiteral("loadScript"), path, name);
    if (!id.isValid() || id.value() < 0) {
        qWarning("Settings: KWin didn't load the zoom script");
        return;
    }
    QDBusInterface(kwin, QStringLiteral("/Scripting/Script%1").arg(id.value()), QStringLiteral("org.kde.kwin.Script"), bus)
        .call(QStringLiteral("run"));
}

void App::Show(const QString &pane, const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    Q_EMIT showRequested(pane);
}
