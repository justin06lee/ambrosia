#include "button.h"
#include "decoration.h"

#include <KDecoration3/DecoratedWindow>

#include <QPainter>
#include <QPainterPath>

namespace Ambrosia {

using namespace KDecoration3;

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
    // Half a pixel of shade just inside the edge, as Files draws it.
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(QColor(0, 0, 0, deco->isDark() ? 64 : 31), 0.5));
    painter->drawEllipse(r.adjusted(0.25, 0.25, -0.25, -0.25));

    if (hovered) {
        // Files' glyphs, drawn on a 14-unit box.
        QPainterPath glyph;
        switch (type()) {
        case DecorationButtonType::Close:
            glyph.moveTo(4, 4), glyph.lineTo(10, 10);
            glyph.moveTo(10, 4), glyph.lineTo(4, 10);
            break;
        case DecorationButtonType::Minimize:
            glyph.moveTo(3.5, 7), glyph.lineTo(10.5, 7);
            break;
        default:
            glyph.moveTo(4.5, 3.5), glyph.lineTo(10.5, 3.5), glyph.lineTo(10.5, 9.5);
            glyph.moveTo(9.5, 10.5), glyph.lineTo(3.5, 10.5), glyph.lineTo(3.5, 4.5);
            break;
        }
        painter->translate(r.topLeft());
        painter->scale(r.width() / 14, r.height() / 14);
        painter->setPen(QPen(QColor(0, 0, 0, 140), 1.3, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
        painter->drawPath(glyph);
    }
    painter->restore();
}

} // namespace Ambrosia
