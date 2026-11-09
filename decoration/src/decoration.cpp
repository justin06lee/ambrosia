#include "decoration.h"
#include "button.h"
#include "shadow.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/ScaleHelpers>

#include <QFontMetricsF>
#include <QHoverEvent>
#include <QPainter>
#include <QPainterPath>

namespace Ambrosia {

using namespace KDecoration3;

// The frame has no borders, as on a Mac; KWin still lets an edge be grabbed
// this far outside it to resize.
constexpr qreal resizeReach = 6;
// The lights sit centered in the titlebar, as far from the left as from the top.
constexpr qreal inset = (Tokens::titlebar - Tokens::diameter) / 2;

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

bool Decoration::init()
{
    auto *w = window();
    m_lights = new DecorationButtonGroup(DecorationButtonGroup::Position::Left, this, &Button::create);
    m_lights->setSpacing(Tokens::gap);

    connect(w, &DecoratedWindow::activeChanged, this, [this] {
        updateShadow();
        update();
    });
    connect(w, &DecoratedWindow::captionChanged, this, [this] { update(titleBar()); });
    connect(w, &DecoratedWindow::widthChanged, this, &Decoration::updateLayout);
    connect(w, &DecoratedWindow::maximizedChanged, this, &Decoration::updateLayout);
    connect(w, &DecoratedWindow::nextScaleChanged, this, &Decoration::updateLayout);
    connect(w, &DecoratedWindow::paletteChanged, this, &Decoration::updateScheme);
    connect(settings().get(), &DecorationSettings::fontChanged, this, [this] { update(); });

    updateScheme();
    return true;
}

// Light or dark from the window's color scheme, which the shell's appearance
// switch sets: the Ambrosia schemes' window color is the token's.
void Decoration::updateScheme()
{
    m_dark = window()->palette().color(QPalette::Window).lightnessF() < 0.5;
    updateLayout();
}

void Decoration::updateLayout()
{
    auto *w = window();
    const bool maximized = w->isMaximized();
    const BorderRadius radius = maximized ? BorderRadius() : BorderRadius(Tokens::radius);

    setBorders(QMarginsF(0, Tokens::titlebar, 0, 0));
    setResizeOnlyBorders(maximized ? QMarginsF() : QMarginsF(resizeReach, resizeReach, resizeReach, resizeReach));
    setTitleBar(QRectF(0, 0, w->width(), Tokens::titlebar));
    setOpaque(maximized);
    setBorderRadius(radius);
    // The hairline edge: one device pixel at any scale.
    setBorderOutline(maximized ? BorderOutline() : BorderOutline(pixelSize(w->nextScale()), QColor::fromRgba(tokens().edge), radius));
    m_lights->setPos(QPointF(inset, inset));
    updateShadow();
    update();
}

void Decoration::updateShadow()
{
    setShadow(windowShadow(m_dark, window()->isActive()));
}

void Decoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    auto *w = window();
    const auto &t = tokens();
    const QRectF bar = titleBar();
    const qreal r = w->isMaximized() ? 0 : Tokens::radius;

    // The titlebar, rounded at the top as the window is, and its rim: a pixel
    // of light along the top edge that follows the corners down.
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setClipRect(bar);
    QPainterPath body;
    body.addRoundedRect(QRectF(0, 0, bar.width(), bar.height() + r + 1), r, r);
    painter->fillPath(body, QColor::fromRgba(t.window));
    painter->fillPath(body.subtracted(body.translated(0, 1)), QColor::fromRgba(t.rim));
    painter->restore();

    // The title, centered on the window and clear of the lights.
    const qreal side = m_lights->geometry().right() + Tokens::gap;
    const QRectF text = bar.adjusted(side, 0, -side, 0);
    if (text.width() > 0) {
        const QFont font = settings()->font();
        painter->save();
        painter->setFont(font);
        painter->setPen(QColor::fromRgba(w->isActive() ? t.title : t.titleInactive));
        painter->drawText(text, Qt::AlignCenter | Qt::TextSingleLine,
                          QFontMetricsF(font).elidedText(w->caption(), Qt::ElideRight, text.width()));
        painter->restore();
    }

    m_lights->paint(painter, repaintArea);
}

void Decoration::hoverMoveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverMoveEvent(event);
    setLightsHovered(m_lights->geometry().contains(event->position()));
}

void Decoration::hoverLeaveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverLeaveEvent(event);
    setLightsHovered(false);
}

void Decoration::setLightsHovered(bool hovered)
{
    if (hovered == m_lightsHovered)
        return;
    m_lightsHovered = hovered;
    update(m_lights->geometry());
}

} // namespace Ambrosia
