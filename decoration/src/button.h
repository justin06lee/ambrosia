#pragma once

#include <KDecoration3/DecorationButton>

#include <QPoint>

class QTimer;

namespace Ambrosia {

class Decoration;

// One traffic light: close, minimize or zoom (KWin's maximize). Gray while
// its window is inactive or the action isn't allowed; colored, with its glyph,
// while the pointer is over the three. The pointer resting on the zoom light
// brings up where the window can go, as a Mac's green light does: the shell
// draws that menu (`ambrosia window-menu`).
class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT

public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);

    // For DecorationButtonGroup: only the three lights, whatever else the
    // button layout names.
    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintArea) override;

private:
    void offerPlaces();

    QTimer *m_linger = nullptr;
    // Where the pointer was on the screen when the menu was last offered:
    // it has to move before the menu is offered again.
    QPoint m_offeredAt{-1, -1};
};

} // namespace Ambrosia
