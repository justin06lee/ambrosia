#include "button.h"
#include "decoration.h"

#include <KDecoration3/DecoratedWindow>

#include <QPainter>
#include <QPainterPath>
#include <QPolygonF>

namespace Ambrosia {

using namespace KDecoration3;

// A run of polygons from the tokens: each one's point count, then its x, y
// pairs; 0 ends the run.
static QPainterPath polygons(const double *run)
{
    QPainterPath path;
    for (int count; (count = int(*run++));) {
        QPolygonF polygon;
        for (int i = 0; i < count; ++i, run += 2)
            polygon << QPointF(run[0], run[1]);
        path.addPolygon(polygon);
        path.closeSubpath();
    }
    return path;
}

Button::Button(DecorationButtonType type, Decoration *decoration, QObject *parent)
    : DecorationButton(type, decoration, parent)
{
    setGeometry(QRectF(0, 0, Tokens::diameter, Tokens::diameter));
    // Gray and back as the window loses and gains focus.
    connect(decoration->window(), &DecoratedWindow::activeChanged, this, [this] { update(); });
}

DecorationButton *Button::create(DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    switch (type) {
    case DecorationButtonType::Close:
    case DecorationButtonType::Minimize:
    case DecorationButtonType::Maximize:
        return new Button(type, static_cast<Decoration *>(decoration), parent);
    default:
        return nullptr;
    }
}

void Button::paint(QPainter *painter, const QRectF &)
{
    if (!isVisible())
        return;
    auto *deco = static_cast<Decoration *>(decoration());
    const auto &t = deco->tokens();
    const QRectF r = geometry();
    const bool hovered = isEnabled() && deco->lightsHovered();
    const bool lit = isEnabled() && (deco->window()->isActive() || deco->lightsHovered());

    unsigned color = t.inactive;
    if (lit)
        color = type() == DecorationButtonType::Close ? t.close : type() == DecorationButtonType::Minimize ? t.minimize : t.zoom;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    painter->setBrush(QColor::fromRgba(color));
    painter->drawEllipse(r);
    if (lit && isPressed()) {
        painter->setBrush(QColor(0, 0, 0, 46));
        painter->drawEllipse(r);
    }
    // Half a pixel just inside the edge, as Files draws it: a deeper shade of
    // a lit light, black on an inactive one.
    const unsigned rim = type() == DecorationButtonType::Close ? t.closeRim : type() == DecorationButtonType::Minimize ? t.minimizeRim : t.zoomRim;
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(lit ? QColor::fromRgba(rim) : QColor(0, 0, 0, deco->isDark() ? 64 : 31), 0.5));
    painter->drawEllipse(r.adjusted(0.25, 0.25, -0.25, -0.25));

    if (hovered) {
        // The tokens' glyph, filled on the light's own box.
        const double *glyph = type() == DecorationButtonType::Close ? Tokens::closeGlyph
            : type() == DecorationButtonType::Minimize               ? Tokens::minimizeGlyph
                                                                     : Tokens::zoomGlyph;
        painter->translate(r.topLeft());
        painter->scale(r.width() / Tokens::diameter, r.height() / Tokens::diameter);
        painter->fillPath(polygons(glyph), QColor::fromRgbF(0, 0, 0, Tokens::glyphOpacity));
    }
    painter->restore();
}

} // namespace Ambrosia
