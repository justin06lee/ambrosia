// Ambrosia's Qt widget style. See style.cpp.
#pragma once

#include <QProxyStyle>

namespace Ambrosia
{

class Pulse;

class Style : public QProxyStyle
{
    Q_OBJECT

public:
    // `base` names the style it stands on; empty takes Breeze where it is
    // installed and Fusion elsewhere.
    explicit Style(const QString &base = QString());

    void drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget = nullptr) const override;
    void drawControl(ControlElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget = nullptr) const override;
    void drawComplexControl(ComplexControl control, const QStyleOptionComplex *option, QPainter *painter, const QWidget *widget = nullptr) const override;
    QRect subElementRect(SubElement element, const QStyleOption *option, const QWidget *widget = nullptr) const override;
    QRect subControlRect(ComplexControl control, const QStyleOptionComplex *option, SubControl subControl, const QWidget *widget = nullptr) const override;
    QSize sizeFromContents(ContentsType type, const QStyleOption *option, const QSize &size, const QWidget *widget = nullptr) const override;
    int pixelMetric(PixelMetric metric, const QStyleOption *option = nullptr, const QWidget *widget = nullptr) const override;
    int styleHint(StyleHint hint, const QStyleOption *option = nullptr, const QWidget *widget = nullptr, QStyleHintReturn *returnData = nullptr) const override;
    void polish(QWidget *widget) override;
    using QProxyStyle::polish;

private:
    Pulse *m_pulse;
};

} // namespace Ambrosia
