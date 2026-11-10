#include "app.h"
#include "fileops.h"
#include "index.h"
#include "thumbnailer.h"

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

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <tuple>
#include <vector>

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

void App::openInfo(const QUrl &url)
{
    m_infos.removeAll(nullptr);
    for (const QPointer<QQuickWindow> &window : std::as_const(m_infos)) {
        if (window->property("url").toUrl() == url) {
            window->raise();
            window->requestActivate();
            return;
        }
    }
    QQmlComponent component(m_engine, QStringLiteral("Files"), QStringLiteral("InfoWindow"));
    QObject *object = component.createWithInitialProperties({{QStringLiteral("startUrl"), url}});
    if (!object) {
        qWarning().noquote() << component.errorString();
        return;
    }
    auto *window = qobject_cast<QQuickWindow *>(object);
    connect(window, &QQuickWindow::closing, window, &QObject::deleteLater);
    m_infos << window;
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

QStringList App::Find(const QString &query, int limit)
{
    Index::Query q;
    q.words = query.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    q.limit = 2000; // the shallowest matches; the best of them are picked here
    if (q.words.isEmpty() || limit < 1)
        return {};
    const Index::Result found = Index::instance()->find(q);
    // Best first: the name is the query (with or without its extension),
    // then starts with it, then has it at a word's start, then anywhere;
    // nearer the home before deeper, shorter names before longer.
    const std::string whole = Index::fold(query.simplified());
    struct Hit {
        int rank, depth;
        size_t length, at;
    };
    std::vector<Hit> hits;
    hits.reserve(found.paths.size());
    for (size_t i = 0; i < found.paths.size(); ++i) {
        const std::string &path = found.paths[i];
        const size_t slash = path.rfind('/');
        const std::string name = Index::fold(QString::fromUtf8(path.c_str() + (slash == std::string::npos ? 0 : slash + 1)));
        const size_t dot = name.rfind('.');
        const size_t in = name.find(whole);
        int rank = 1;
        if (name == whole || (dot != std::string::npos && dot > 0 && name.compare(0, dot, whole) == 0))
            rank = 4;
        else if (in == 0)
            rank = 3;
        else if (in != std::string::npos && !std::isalnum(static_cast<unsigned char>(name[in - 1])) && static_cast<unsigned char>(name[in - 1]) < 0x80)
            rank = 2;
        hits.push_back({rank, int(std::count(path.begin(), path.end(), '/')), name.size(), i});
    }
    const auto better = [&](const Hit &a, const Hit &b) {
        return std::tie(b.rank, a.depth, a.length, found.paths[a.at]) < std::tie(a.rank, b.depth, b.length, found.paths[b.at]);
    };
    const size_t count = std::min(hits.size(), size_t(limit));
    std::partial_sort(hits.begin(), hits.begin() + std::ptrdiff_t(count), hits.end(), better);
    QStringList items;
    for (size_t i = 0; i < count; ++i) {
        const QString path = QString::fromStdString(found.paths[hits[i].at]);
        const bool dir = found.dirs[hits[i].at];
        items << (dir ? path + QLatin1Char('/') : path) << (dir ? QString() : Thumbnailer::cached(path));
    }
    return items;
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
