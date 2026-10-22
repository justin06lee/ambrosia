#include "app.h"
#include "fileops.h"

#include <KIO/OpenUrlJob>
#include <KWindowShadow>

#include <QDir>
#include <QGuiApplication>
#include <QPainter>
#include <QPainterPath>
#include <QPalette>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QStyleHints>
#include <QTimer>

#include <cmath>
#include <cstdio>

App *App::s_instance = nullptr;

App::App(QQmlEngine *engine, const Options &options)
    : m_engine(engine)
    , m_options(options)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
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

void App::openWindow(const QUrl &url)
{
    QQmlComponent component(m_engine, QStringLiteral("Files"), QStringLiteral("FinderWindow"));
    QVariantMap initial{{QStringLiteral("startUrl"), url}};
    if (m_first) {
        if (!m_options.view.isEmpty())
            initial.insert(QStringLiteral("view"), m_options.view);
        if (m_options.size.isValid()) {
            initial.insert(QStringLiteral("width"), m_options.size.width());
            initial.insert(QStringLiteral("height"), m_options.size.height());
        }
    }
    QObject *object = component.createWithInitialProperties(initial);
    if (!object) {
        qWarning().noquote() << component.errorString();
        return;
    }
    auto *window = qobject_cast<QQuickWindow *>(object);
    connect(window, &QQuickWindow::closing, window, &QObject::deleteLater);
    window->setProperty("first", m_first);
    m_first = false;
}

void App::openFile(const QUrl &url)
{
    auto *job = new KIO::OpenUrlJob(url);
    job->start();
}

void App::Trash(const QStringList &urls)
{
    QList<QUrl> list;
    for (const QString &url : urls)
        list << QUrl(url);
    if (auto *ops = m_engine->singletonInstance<FileOps *>("Files", "FileOps"))
        ops->trash(list);
}

int App::modifiers() const
{
    return int(QGuiApplication::queryKeyboardModifiers());
}

void App::Open(const QStringList &urls)
{
    if (urls.isEmpty())
        openWindow(QUrl::fromLocalFile(QDir::homePath()));
    for (const QString &url : urls)
        openWindow(QUrl(url));
}

namespace {

// KWin's shadow for a window with rounded corners: two soft layers like
// macOS's (a wide one and a close one), split into the eight tiles
// KWindowShadow wants. The window's own shape is cut out, so the shadow
// doesn't show through its transparent corners.
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

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Files: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window, double loadMs, double firstMs)
{
    if (!window->property("first").toBool())
        return;
    if (m_options.bench) {
        std::printf("first_ms=%.2f load_ms=%.2f\n", firstMs, loadMs);
        std::fflush(stdout);
    }
    if (!m_options.grab.isEmpty()) {
        // Two frames later everything (fonts, images) has been drawn.
        QTimer::singleShot(300, window, [this, window] {
            window->grabWindow().save(m_options.grab);
            QGuiApplication::quit();
        });
    } else if (m_options.bench) {
        QGuiApplication::quit();
    }
}
