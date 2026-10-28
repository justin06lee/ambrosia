#include "shadow.h"

#include <QImage>
#include <QPainter>

#include <cmath>
#include <vector>

namespace Ambrosia {

using namespace KDecoration3;

namespace {

// How far the shadow's corner pieces reach into the window, so the shadow
// fades round the corners instead of meeting the edges in a seam; and the
// length of the edge pieces KWin stretches along the sides.
constexpr int reach = 56;
constexpr int span = 4;

using Plane = std::vector<float>;

// Antialiased coverage of a rounded rect, 0 to 1 a pixel.
Plane cover(int w, int h, const QRectF &rect, qreal radius)
{
    QImage img(w, h, QImage::Format_Alpha8);
    img.fill(0);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);
    p.drawRoundedRect(rect, radius, radius);
    p.end();
    Plane out(size_t(w) * h);
    for (int y = 0; y < h; ++y) {
        const uchar *line = img.constScanLine(y);
        for (int x = 0; x < w; ++x)
            out[size_t(y) * w + x] = line[x] / 255.f;
    }
    return out;
}

// Gaussian blur, σ half the CSS blur radius, as box-shadow does.
void blur(Plane &v, int w, int h, qreal radius)
{
    const double sigma = radius / 2;
    if (sigma <= 0)
        return;
    const int k = int(std::ceil(sigma * 3));
    std::vector<float> kernel(2 * k + 1);
    double sum = 0;
    for (int i = -k; i <= k; ++i)
        sum += kernel[i + k] = float(std::exp(-(i * i) / (2 * sigma * sigma)));
    for (auto &x : kernel)
        x = float(x / sum);
    Plane tmp(v.size());
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            float a = 0;
            for (int i = std::max(-k, -x); i <= std::min(k, w - 1 - x); ++i)
                a += v[size_t(y) * w + x + i] * kernel[i + k];
            tmp[size_t(y) * w + x] = a;
        }
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            float a = 0;
            for (int i = std::max(-k, -y); i <= std::min(k, h - 1 - y); ++i)
                a += tmp[size_t(y + i) * w + x] * kernel[i + k];
            v[size_t(y) * w + x] = a;
        }
}

std::shared_ptr<DecorationShadow> make(const Tokens::Shadow &s)
{
    // Room for each layer on every side: its blur and spread past its offset.
    qreal left = 0, top = 0, right = 0, bottom = 0;
    for (int i = 0; i < s.count; ++i) {
        const auto &l = s.layers[i];
        left = std::max(left, l.blur + l.spread - l.x);
        right = std::max(right, l.blur + l.spread + l.x);
        top = std::max(top, l.blur + l.spread - l.y);
        bottom = std::max(bottom, l.blur + l.spread + l.y);
    }
    const QMargins pad(int(std::ceil(left)), int(std::ceil(top)), int(std::ceil(right)), int(std::ceil(bottom)));
    // A reference window just big enough for every piece.
    const int w = pad.left() + reach + span + reach + pad.right();
    const int h = pad.top() + reach + span + reach + pad.bottom();
    const QRectF win(pad.left(), pad.top(), reach + span + reach, reach + span + reach);
    const Plane body = cover(w, h, win, Tokens::radius);

    // The layers bottom to top (the last listed lowest), one ink, straight alpha.
    const QColor ink = QColor::fromRgba(s.ink);
    Plane alpha(size_t(w) * h, 0.f);
    for (int i = s.count - 1; i >= 0; --i) {
        const auto &l = s.layers[i];
        Plane mask = cover(w, h, win.translated(l.x, l.y).adjusted(-l.spread, -l.spread, l.spread, l.spread), Tokens::radius + l.spread);
        blur(mask, w, h, l.blur);
        for (size_t p = 0; p < alpha.size(); ++p) {
            const float a = float(ink.alphaF() * l.opacity) * mask[p];
            alpha[p] = a + alpha[p] * (1 - a);
        }
    }

    QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < h; ++y) {
        auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const size_t p = size_t(y) * w + x;
            // Nothing under the window, which may be translucent.
            const float a = alpha[p] * (1 - body[p]);
            line[x] = qPremultiply(qRgba(ink.red(), ink.green(), ink.blue(), qRound(a * 255)));
        }
    }

    auto shadow = std::make_shared<DecorationShadow>();
    shadow->setPadding(QMarginsF(pad));
    shadow->setInnerShadowRect(QRectF(pad.left() + reach, pad.top() + reach, span, span));
    shadow->setShadow(img);
    return shadow;
}

} // namespace

std::shared_ptr<DecorationShadow> windowShadow(bool dark, bool active)
{
    static std::shared_ptr<DecorationShadow> made[2][2];
    auto &shadow = made[dark][active];
    if (!shadow) {
        const auto &m = dark ? Tokens::dark : Tokens::light;
        shadow = make(active ? m.shadow : m.shadowInactive);
    }
    return shadow;
}

} // namespace Ambrosia
