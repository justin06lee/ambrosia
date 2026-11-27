// KWin's shadow for a frameless window with rounded corners, as Settings
// and Files make it (settings/src/app.cpp): two soft layers like macOS's, a
// wide one and a close one, split into the eight tiles KWindowShadow wants,
// with the window's own shape cut out so it doesn't show through the
// transparent corners.

#include "shadow.h"

#include <KWindowShadow>

#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QQuickWindow>

#include <algorithm>
#include <cmath>
#include <vector>

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
