#pragma once

#include <KDecoration3/DecorationButton>

namespace Ambrosia {

class Decoration;

// One traffic light: close, minimize or zoom (KWin's maximize). Gray while
// its window is inactive or the action isn't allowed; colored, with its glyph,
// while the pointer is over the three.
class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT

public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);

    // For DecorationButtonGroup: only the three lights, whatever else the
    // button layout names.
    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintArea) override;
};

} // namespace Ambrosia
