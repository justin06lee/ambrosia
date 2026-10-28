#pragma once

#include <tokens.h>

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButtonGroup>

#include <QVariantList>

namespace Ambrosia {

// The frame KWin puts on every window that doesn't draw its own: a 32-tall
// titlebar in the window's color with a centered title, the traffic lights on
// the left, rounded corners (KWin clips the app to them too), a hairline edge
// and the window shadow. Light or dark follows the window's color scheme.
class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT

public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = {});

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    const Tokens::Mode &tokens() const { return m_dark ? Tokens::dark : Tokens::light; }
    bool isDark() const { return m_dark; }
    // Over any of the three lights (or the gaps between them): macOS shows
    // all three glyphs at once.
    bool lightsHovered() const { return m_lightsHovered; }

protected:
    void hoverMoveEvent(QHoverEvent *event) override;
    void hoverLeaveEvent(QHoverEvent *event) override;

private:
    void updateScheme();
    void updateLayout();
    void updateShadow();
    void setLightsHovered(bool hovered);

    KDecoration3::DecorationButtonGroup *m_lights = nullptr;
    bool m_dark = false;
    bool m_lightsHovered = false;
};

} // namespace Ambrosia
