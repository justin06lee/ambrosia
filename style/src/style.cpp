// Ambrosia's Qt widget style: every Qt Widgets app's controls as macOS 26
// draws its own. Push buttons, checkboxes and radio buttons, text fields,
// pop-up buttons and steppers, sliders, progress bars, scroll bars, menus
// and tooltips are painted here; everything else is the style underneath
// (Breeze on an Ambrosia system), so an app never meets a control this
// doesn't know. Sizes and the colors a palette has no role for come from the
// tokens; the accent, the text and the window come from the app's palette,
// so the color scheme and the accent the user chose still decide.

#include "style.h"

#include "tokens.h"

#include <QAbstractItemView>
#include <QComboBox>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QStyleFactory>
#include <QStyleOption>
#include <QtMath>

namespace Ambrosia
{

namespace
{

namespace T = Tokens;

QStyle *styleUnderneath(const QString &name)
{
    if (!name.isEmpty()) {
        return QStyleFactory::create(name);
    }
    QStyle *breeze = QStyleFactory::create(QStringLiteral("breeze"));
    return breeze ? breeze : QStyleFactory::create(QStringLiteral("fusion"));
}

bool isDark(const QPalette &palette)
{
    return palette.color(QPalette::Window).lightness() < 128;
}

// The tokens' colors for the mode the palette is in.
const T::Mode &mode(const QPalette &palette)
{
    return isDark(palette) ? T::dark : T::light;
}

QColor color(unsigned argb)
{
    return QColor::fromRgba(argb);
}

bool enabled(const QStyleOption *option)
{
    return option->state & QStyle::State_Enabled;
}

// A focus ring is only drawn for focus that came by the keyboard, as on a Mac.
bool ringed(const QStyleOption *option)
{
    return (option->state & QStyle::State_HasFocus) && (option->state & QStyle::State_KeyboardFocusChange);
}

QColor accent(const QStyleOption *option)
{
    return option->palette.color(QPalette::Active, QPalette::Highlight);
}

QColor accentText(const QStyleOption *option)
{
    return option->palette.color(QPalette::Active, QPalette::HighlightedText);
}

// Saves the painter and sets it up for smooth shapes, dimmed when the
// control is disabled.
class Paint
{
public:
    Paint(QPainter *painter, const QStyleOption *option)
        : m_painter(painter)
    {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setPen(Qt::NoPen);
        if (!enabled(option)) {
            painter->setOpacity(painter->opacity() * T::disabled);
        }
    }
    ~Paint()
    {
        m_painter->restore();
    }

private:
    QPainter *m_painter;
};

void fill(QPainter *painter, const QRectF &rect, qreal radius, const QColor &color)
{
    painter->setPen(Qt::NoPen);
    painter->setBrush(color);
    painter->drawRoundedRect(rect, radius, radius);
}

// The ring, inside the control's own rectangle: Qt clips a widget's painting
// to it, where a Mac draws the ring outside.
void ring(QPainter *painter, const QRectF &rect, qreal radius, const QStyleOption *option)
{
    QColor c = accent(option);
    c.setAlphaF(0.6);
    const qreal half = T::focusRing / 2;
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(c, T::focusRing));
    painter->drawRoundedRect(rect.adjusted(half, half, -half, -half), qMax(0.0, radius - half), qMax(0.0, radius - half));
    painter->setPen(Qt::NoPen);
}

// A chevron in the middle of `rect`, pointing the way `arrow` says.
void chevron(QPainter *painter, const QRectF &rect, Qt::ArrowType arrow, const QColor &color, qreal size = 4, qreal width = 1.5)
{
    const QPointF c = rect.center();
    const qreal h = size / 2;
    QPainterPath path;
    switch (arrow) {
    case Qt::UpArrow:
        path.moveTo(c.x() - size, c.y() + h);
        path.lineTo(c.x(), c.y() - h);
        path.lineTo(c.x() + size, c.y() + h);
        break;
    case Qt::DownArrow:
        path.moveTo(c.x() - size, c.y() - h);
        path.lineTo(c.x(), c.y() + h);
        path.lineTo(c.x() + size, c.y() - h);
        break;
    case Qt::LeftArrow:
        path.moveTo(c.x() + h, c.y() - size);
        path.lineTo(c.x() - h, c.y());
        path.lineTo(c.x() + h, c.y() + size);
        break;
    default:
        path.moveTo(c.x() - h, c.y() - size);
        path.lineTo(c.x() + h, c.y());
        path.lineTo(c.x() - h, c.y() + size);
        break;
    }
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(color, width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    painter->drawPath(path);
    painter->setPen(Qt::NoPen);
}

// A pop-up button's pair of arrows, one over the other.
void arrows(QPainter *painter, const QRectF &rect, const QColor &color)
{
    const QPointF c = rect.center();
    chevron(painter, QRectF(c.x() - 4, c.y() - 6.5, 8, 5), Qt::UpArrow, color, 3, 1.5);
    chevron(painter, QRectF(c.x() - 4, c.y() + 1.5, 8, 5), Qt::DownArrow, color, 3, 1.5);
}

// A button's face: the accent for a window's default button, the control
// color for the rest.
void face(QPainter *painter, const QRectF &rect, const QStyleOption *option, bool isDefault)
{
    const T::Mode &m = mode(option->palette);
    const bool down = option->state & (QStyle::State_Sunken | QStyle::State_On);
    QColor c;
    if (isDefault) {
        c = accent(option);
        if (down) {
            // Pressed, the accent deepens on a light window and lifts on a dark one.
            c = c.darker(isDark(option->palette) ? 85 : 108);
        }
    } else {
        c = color(down ? m.facePressed : m.face);
    }
    fill(painter, rect, T::pushRadius, c);
}

// A text field's box: its ground, a hairline, and the ring when it has focus.
void field(QPainter *painter, const QRectF &rect, const QStyleOption *option)
{
    const T::Mode &m = mode(option->palette);
    fill(painter, rect, T::fieldRadius, color(m.field));
    if (option->state & QStyle::State_HasFocus) {
        ring(painter, rect, T::fieldRadius, option);
    } else {
        painter->setBrush(Qt::NoBrush);
        painter->setPen(QPen(color(m.fieldBorder), 1));
        painter->drawRoundedRect(rect.adjusted(0.5, 0.5, -0.5, -0.5), T::fieldRadius - 0.5, T::fieldRadius - 0.5);
        painter->setPen(Qt::NoPen);
    }
}

// The box of a checkbox or a radio button, centered in `rect`.
QRectF box(const QRect &rect)
{
    return QRectF(rect.center().x() + 0.5 - T::checkSize / 2, rect.center().y() + 0.5 - T::checkSize / 2, T::checkSize, T::checkSize);
}

bool isDefaultButton(const QStyleOptionButton *button)
{
    return (button->features & QStyleOptionButton::DefaultButton) && (button->state & QStyle::State_Active) && enabled(button);
}

} // namespace

Style::Style(const QString &base)
    : QProxyStyle(styleUnderneath(base))
{
    setObjectName(QStringLiteral("ambrosia"));
}

void Style::polish(QWidget *widget)
{
    QProxyStyle::polish(widget);
    // Round corners need a window that isn't filled first.
    if (qobject_cast<QMenu *>(widget) || widget->inherits("QTipLabel")) {
        widget->setAttribute(Qt::WA_TranslucentBackground);
    }
    if (widget->inherits("QScrollBar") || widget->inherits("QAbstractSlider")) {
        widget->setAttribute(Qt::WA_Hover);
    }
}

int Style::pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const
{
    switch (metric) {
    case PM_IndicatorWidth:
    case PM_IndicatorHeight:
    case PM_ExclusiveIndicatorWidth:
    case PM_ExclusiveIndicatorHeight:
        return T::checkSize;
    case PM_CheckBoxLabelSpacing:
    case PM_RadioButtonLabelSpacing:
        return T::checkGap;
    case PM_ButtonDefaultIndicator:
    case PM_ButtonShiftHorizontal:
    case PM_ButtonShiftVertical:
        return 0;
    case PM_SliderThickness:
    case PM_SliderControlThickness:
        return T::sliderKnobHeight + 6;
    case PM_SliderLength:
        return T::sliderKnobWidth;
    case PM_ScrollBarExtent:
        return T::scrollbarHover + 2 * T::scrollbarInset;
    case PM_ScrollBarSliderMin:
        return 28;
    case PM_ScrollView_ScrollBarSpacing:
        return 0;
    case PM_MenuPanelWidth:
        return 0;
    case PM_MenuHMargin:
    case PM_MenuVMargin:
        return T::menuMargin;
    case PM_SubMenuOverlap:
        return -2;
    case PM_ToolTipLabelFrameWidth:
        return T::tooltipPadding;
    default:
        return QProxyStyle::pixelMetric(metric, option, widget);
    }
}

int Style::styleHint(StyleHint hint, const QStyleOption *option, const QWidget *widget, QStyleHintReturn *returnData) const
{
    switch (hint) {
    // Cancel on the left, the answer on the right, and no pictures on them.
    case SH_DialogButtonLayout:
        return 1; // QDialogButtonBox::MacLayout
    case SH_DialogButtonBox_ButtonsHaveIcons:
        return false;
    // No underlined letters: a Mac's menus and buttons don't have them.
    case SH_UnderlineShortcut:
        return false;
    case SH_ScrollBar_MiddleClickAbsolutePosition:
        return true;
    case SH_Menu_Scrollable:
        return true;
    case SH_Menu_SloppySubMenus:
        return true;
    case SH_ComboBox_ListMouseTracking:
        return true;
    default:
        return QProxyStyle::styleHint(hint, option, widget, returnData);
    }
}

QSize Style::sizeFromContents(ContentsType type, const QStyleOption *option, const QSize &size, const QWidget *widget) const
{
    switch (type) {
    case CT_PushButton: {
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        int width = size.width() + 2 * T::pushPadding;
        if (button && (button->features & QStyleOptionButton::HasMenu)) {
            width += T::arrowsWidth - T::pushPadding / 2;
        }
        if (button && (button->features & (QStyleOptionButton::DefaultButton | QStyleOptionButton::AutoDefaultButton)) && !button->text.isEmpty()) {
            width = qMax<int>(width, T::pushMinimumDefault);
        }
        return QSize(width, qMax<int>(size.height() + 4, T::pushHeight));
    }
    case CT_LineEdit:
        return QSize(size.width() + 2 * T::fieldPadding, qMax<int>(size.height() + 4, T::fieldHeight));
    case CT_ComboBox: {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        const int padding = combo && combo->editable ? T::fieldPadding : T::menuRowPadding;
        return QSize(size.width() + padding + T::arrowsWidth + 8, qMax<int>(size.height() + 4, T::fieldHeight));
    }
    case CT_SpinBox:
        return QSize(size.width() + T::fieldPadding + T::arrowsWidth, qMax<int>(size.height() + 4, T::fieldHeight));
    case CT_ProgressBar: {
        const auto *bar = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (bar && !bar->textVisible) {
            return bar->state & State_Horizontal ? QSize(size.width(), T::sliderTrack) : QSize(T::sliderTrack, size.height());
        }
        return QProxyStyle::sizeFromContents(type, option, size, widget);
    }
    case CT_MenuItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) {
            break;
        }
        if (item->menuItemType == QStyleOptionMenuItem::Separator) {
            return QSize(10, item->text.isEmpty() ? T::menuRule : T::menuRow);
        }
        int width = size.width() + 2 * T::menuRowPadding;
        if (item->maxIconWidth > 0 || item->menuHasCheckableItems) {
            width += T::menuIcon + T::menuGap;
        }
        if (item->reservedShortcutWidth > 0) {
            width += T::menuShortcutGap;
        }
        // Room for a submenu's arrow on every row, so the shortcuts line up.
        width += T::menuIcon;
        return QSize(width, qMax<int>(size.height() + 4, T::menuRow));
    }
    default:
        break;
    }
    return QProxyStyle::sizeFromContents(type, option, size, widget);
}

QRect Style::subElementRect(SubElement element, const QStyleOption *option, const QWidget *widget) const
{
    switch (element) {
    case SE_LineEditContents: {
        // Text keeps clear of the box's edge; inside a combo or a stepper
        // that control has made the room already.
        const QWidget *parent = widget ? widget->parentWidget() : nullptr;
        if (parent && (qobject_cast<const QComboBox *>(parent) || parent->inherits("QAbstractSpinBox"))) {
            return option->rect;
        }
        return option->rect.adjusted(T::fieldPadding, 0, -T::fieldPadding, 0);
    }
    default:
        return QProxyStyle::subElementRect(element, option, widget);
    }
}

void Style::drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const
{
    const T::Mode &m = mode(option->palette);
    switch (element) {
    case PE_PanelButtonCommand: {
        Paint paint(painter, option);
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        const bool flat = button && (button->features & QStyleOptionButton::Flat) && !(option->state & (State_Sunken | State_On));
        if (!flat) {
            face(painter, option->rect, option, button && isDefaultButton(button));
        }
        if (ringed(option)) {
            ring(painter, option->rect, T::pushRadius, option);
        }
        return;
    }
    case PE_FrameDefaultButton:
    case PE_FrameFocusRect:
        // The ring is the control's own to draw; a Mac has no dotted box.
        return;
    case PE_PanelButtonTool: {
        // A toolbar's button has no face until the pointer is on it.
        Paint paint(painter, option);
        if (option->state & (State_Sunken | State_On)) {
            fill(painter, option->rect, T::toolRadius, color(m.facePressed));
        } else if ((option->state & State_MouseOver) && enabled(option)) {
            fill(painter, option->rect, T::toolRadius, color(m.face));
        }
        return;
    }
    case PE_IndicatorCheckBox: {
        Paint paint(painter, option);
        const QRectF r = box(option->rect);
        const bool on = option->state & (State_On | State_NoChange);
        QColor ground = on ? accent(option) : color(m.track);
        if (on && (option->state & State_Sunken)) {
            ground = ground.darker(108);
        }
        fill(painter, r, T::checkRadius, ground);
        if (on) {
            QPainterPath mark;
            if (option->state & State_NoChange) {
                mark.moveTo(r.left() + 4.5, r.center().y());
                mark.lineTo(r.right() - 4.5, r.center().y());
            } else {
                mark.moveTo(r.left() + 4.2, r.top() + 8.4);
                mark.lineTo(r.left() + 7, r.top() + 11.1);
                mark.lineTo(r.left() + 11.8, r.top() + 5.1);
            }
            painter->setBrush(Qt::NoBrush);
            painter->setPen(QPen(accentText(option), 1.8, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            painter->drawPath(mark);
        }
        return;
    }
    case PE_IndicatorRadioButton: {
        Paint paint(painter, option);
        const QRectF r = box(option->rect);
        const bool on = option->state & State_On;
        painter->setBrush(on ? accent(option) : color(m.track));
        painter->drawEllipse(r);
        if (on) {
            painter->setBrush(accentText(option));
            painter->drawEllipse(r.center(), 3, 3);
        }
        return;
    }
    case PE_PanelLineEdit: {
        // A field inside a combo or a stepper sits in that control's box.
        const QWidget *parent = widget ? widget->parentWidget() : nullptr;
        if (parent && (qobject_cast<const QComboBox *>(parent) || parent->inherits("QAbstractSpinBox"))) {
            return;
        }
        const auto *frame = qstyleoption_cast<const QStyleOptionFrame *>(option);
        if (frame && frame->lineWidth <= 0) {
            return;
        }
        Paint paint(painter, option);
        field(painter, option->rect, option);
        return;
    }
    case PE_FrameLineEdit:
        return;
    case PE_Frame: {
        // A list's or a text view's edge: one hairline, no bevel.
        const auto *frame = qstyleoption_cast<const QStyleOptionFrame *>(option);
        if (frame && frame->lineWidth <= 0) {
            return;
        }
        painter->save();
        painter->setPen(QPen(color(m.fieldBorder), 1));
        painter->setBrush(Qt::NoBrush);
        painter->drawRect(QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5));
        painter->restore();
        return;
    }
    case PE_PanelScrollAreaCorner:
        // Where two scroll bars meet there is nothing.
        return;
    case PE_PanelMenu: {
        Paint paint(painter, option);
        const QRectF r = QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5);
        painter->setBrush(color(m.menu));
        painter->setPen(QPen(color(m.menuRim), 1));
        painter->drawRoundedRect(r, T::menuRadius, T::menuRadius);
        return;
    }
    case PE_FrameMenu:
        return;
    case PE_PanelTipLabel: {
        Paint paint(painter, option);
        const QRectF r = QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5);
        painter->setBrush(color(m.menu));
        painter->setPen(QPen(color(m.menuRim), 1));
        painter->drawRoundedRect(r, T::tooltipRadius, T::tooltipRadius);
        return;
    }
    case PE_IndicatorArrowUp:
    case PE_IndicatorArrowDown:
    case PE_IndicatorArrowLeft:
    case PE_IndicatorArrowRight: {
        Paint paint(painter, option);
        const Qt::ArrowType arrow = element == PE_IndicatorArrowUp ? Qt::UpArrow
            : element == PE_IndicatorArrowDown ? Qt::DownArrow
            : element == PE_IndicatorArrowLeft ? Qt::LeftArrow
                                               : Qt::RightArrow;
        chevron(painter, option->rect, arrow, option->palette.color(QPalette::WindowText), 3.5);
        return;
    }
    default:
        break;
    }
    QProxyStyle::drawPrimitive(element, option, painter, widget);
}

void Style::drawControl(ControlElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const
{
    const T::Mode &m = mode(option->palette);
    switch (element) {
    case CE_PushButtonBevel: {
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        drawPrimitive(PE_PanelButtonCommand, option, painter, widget);
        if (button && (button->features & QStyleOptionButton::HasMenu)) {
            Paint paint(painter, option);
            const QRectF r(option->rect.right() - T::arrowsWidth, option->rect.top(), T::arrowsWidth, option->rect.height());
            chevron(painter, r, Qt::DownArrow, isDefaultButton(button) ? accentText(option) : option->palette.color(QPalette::ButtonText), 3.5);
        }
        return;
    }
    case CE_PushButtonLabel: {
        // The default button's title is in the accent's own text color.
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        if (button && isDefaultButton(button)) {
            QStyleOptionButton copy(*button);
            copy.palette.setColor(QPalette::ButtonText, accentText(option));
            QProxyStyle::drawControl(element, &copy, painter, widget);
            return;
        }
        break;
    }
    case CE_ProgressBarGroove: {
        Paint paint(painter, option);
        const QRectF r = option->rect;
        const bool flatwise = option->state & State_Horizontal;
        const QRectF track = flatwise ? QRectF(r.left(), r.center().y() - T::sliderTrack / 2 + 0.5, r.width(), T::sliderTrack)
                                      : QRectF(r.center().x() - T::sliderTrack / 2 + 0.5, r.top(), T::sliderTrack, r.height());
        fill(painter, track, T::sliderTrack / 2, color(m.track));
        return;
    }
    case CE_ProgressBarContents: {
        const auto *bar = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (!bar) {
            break;
        }
        Paint paint(painter, option);
        const QRectF r = option->rect;
        const bool flatwise = option->state & State_Horizontal;
        const qreal length = flatwise ? r.width() : r.height();
        const bool busy = bar->minimum == bar->maximum;
        // With no end in sight, a third of the track is lit.
        qreal share = busy ? 1.0 / 3 : qBound(0.0, qreal(bar->progress - bar->minimum) / qMax(1, bar->maximum - bar->minimum), 1.0);
        qreal lit = share <= 0 ? 0 : qMax<qreal>(T::sliderTrack, length * share);
        qreal from = busy ? (length - lit) / 2 : 0;
        const bool backwards = bar->invertedAppearance != (flatwise && bar->direction == Qt::RightToLeft);
        if (backwards) {
            from = length - lit - from;
        }
        if (lit <= 0) {
            return;
        }
        const QRectF chunk = flatwise ? QRectF(r.left() + from, r.center().y() - T::sliderTrack / 2 + 0.5, lit, T::sliderTrack)
                                      : QRectF(r.center().x() - T::sliderTrack / 2 + 0.5, r.bottom() + 1 - from - lit, T::sliderTrack, lit);
        fill(painter, chunk, T::sliderTrack / 2, accent(option));
        return;
    }
    case CE_MenuEmptyArea:
        return;
    case CE_MenuItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) {
            break;
        }
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        const QRectF r = item->rect;
        const bool usable = enabled(item);
        const bool lit = (item->state & State_Selected) && usable;

        if (item->menuItemType == QStyleOptionMenuItem::Separator) {
            if (item->text.isEmpty()) {
                painter->setPen(QPen(color(m.menuRule), 1));
                const qreal y = qFloor(r.center().y()) + 0.5;
                painter->drawLine(QPointF(r.left() + T::menuRowPadding, y), QPointF(r.right() - T::menuRowPadding, y));
            } else {
                // A titled rule is a heading for the rows under it.
                QFont heading = item->font;
                heading.setBold(true);
                heading.setPointSizeF(heading.pointSizeF() * 0.85);
                painter->setFont(heading);
                painter->setPen(color(m.textSecondary));
                painter->drawText(r.adjusted(T::menuRowPadding, 0, -T::menuRowPadding, 0), Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine, item->text);
            }
            painter->restore();
            return;
        }

        if (lit) {
            fill(painter, r, T::menuRowRadius, accent(item));
        }
        const QColor ink = lit ? accentText(item) : usable ? item->palette.color(QPalette::Active, QPalette::Text) : color(m.textTertiary);
        QColor faint = lit ? accentText(item) : usable ? color(m.textSecondary) : color(m.textTertiary);
        if (lit) {
            faint.setAlphaF(0.85);
        }

        qreal x = r.left() + T::menuRowPadding;
        if (item->maxIconWidth > 0 || item->menuHasCheckableItems) {
            const QRectF slot(x, r.center().y() + 0.5 - T::menuIcon / 2, T::menuIcon, T::menuIcon);
            if (item->checked && item->checkType != QStyleOptionMenuItem::NotCheckable) {
                if (item->checkType == QStyleOptionMenuItem::Exclusive) {
                    painter->setPen(Qt::NoPen);
                    painter->setBrush(ink);
                    painter->drawEllipse(slot.center(), 2.5, 2.5);
                } else {
                    QPainterPath mark;
                    mark.moveTo(slot.left() + 3.5, slot.top() + 8.5);
                    mark.lineTo(slot.left() + 6.5, slot.top() + 11.5);
                    mark.lineTo(slot.left() + 12.5, slot.top() + 4.5);
                    painter->setBrush(Qt::NoBrush);
                    painter->setPen(QPen(ink, 1.6, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
                    painter->drawPath(mark);
                }
            } else if (!item->icon.isNull()) {
                const QIcon::Mode iconMode = !usable ? QIcon::Disabled : lit ? QIcon::Selected : QIcon::Normal;
                item->icon.paint(painter, slot.toRect(), Qt::AlignCenter, iconMode);
            }
            x += T::menuIcon + T::menuGap;
        }

        const qreal right = r.right() + 1 - T::menuRowPadding;
        const qsizetype tab = item->text.indexOf(QLatin1Char('\t'));
        const QString title = tab < 0 ? item->text : item->text.left(tab);
        QFont font = item->font;
        if (item->menuItemType == QStyleOptionMenuItem::DefaultItem) {
            font.setBold(true);
        }
        painter->setFont(font);
        painter->setPen(ink);
        painter->drawText(QRectF(x, r.top(), right - x, r.height()), Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine | Qt::TextHideMnemonic, title);
        if (tab >= 0) {
            painter->setPen(faint);
            painter->drawText(QRectF(x, r.top(), right - x, r.height()), Qt::AlignVCenter | Qt::AlignRight | Qt::TextSingleLine, item->text.mid(tab + 1));
        }
        if (item->menuItemType == QStyleOptionMenuItem::SubMenu) {
            chevron(painter, QRectF(right - 8, r.top(), 8, r.height()), item->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow, faint, 3.5);
        }
        painter->restore();
        return;
    }
    default:
        break;
    }
    QProxyStyle::drawControl(element, option, painter, widget);
}

QRect Style::subControlRect(ComplexControl control, const QStyleOptionComplex *option, SubControl subControl, const QWidget *widget) const
{
    const QRect r = option->rect;
    switch (control) {
    case CC_ComboBox: {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        const int arrow = T::arrowsWidth;
        const int padding = combo && combo->editable ? T::fieldPadding : T::menuRowPadding;
        switch (subControl) {
        case SC_ComboBoxFrame:
            return r;
        case SC_ComboBoxArrow:
            return visualRect(option->direction, r, QRect(r.right() + 1 - arrow, r.top(), arrow, r.height()));
        case SC_ComboBoxEditField:
            return visualRect(option->direction, r, r.adjusted(padding, 0, -arrow - 2, 0));
        default:
            break;
        }
        break;
    }
    case CC_SpinBox: {
        const int arrow = T::arrowsWidth - 4;
        const QRect stepper(r.right() + 1 - arrow, r.top(), arrow, r.height());
        switch (subControl) {
        case SC_SpinBoxFrame:
            return r;
        case SC_SpinBoxUp:
            return visualRect(option->direction, r, QRect(stepper.left(), stepper.top(), arrow, stepper.height() / 2));
        case SC_SpinBoxDown:
            return visualRect(option->direction, r, QRect(stepper.left(), stepper.top() + stepper.height() / 2, arrow, stepper.height() - stepper.height() / 2));
        case SC_SpinBoxEditField:
            return visualRect(option->direction, r, r.adjusted(T::fieldPadding, 0, -arrow - 4, 0));
        default:
            break;
        }
        break;
    }
    case CC_Slider: {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) {
            break;
        }
        const bool flatwise = slider->orientation == Qt::Horizontal;
        const int knob = T::sliderKnobWidth;
        const int across = T::sliderKnobHeight;
        switch (subControl) {
        case SC_SliderGroove:
            return flatwise ? QRect(r.left(), r.center().y() - int(T::sliderTrack) / 2 + 1, r.width(), T::sliderTrack)
                            : QRect(r.center().x() - int(T::sliderTrack) / 2 + 1, r.top(), T::sliderTrack, r.height());
        case SC_SliderHandle: {
            const int travel = (flatwise ? r.width() : r.height()) - knob;
            const int at = sliderPositionFromValue(slider->minimum, slider->maximum, slider->sliderPosition, travel, slider->upsideDown);
            return flatwise ? QRect(r.left() + at, r.center().y() - across / 2 + 1, knob, across)
                            : QRect(r.center().x() - across / 2 + 1, r.top() + at, across, knob);
        }
        default:
            break;
        }
        break;
    }
    case CC_ScrollBar: {
        const auto *bar = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!bar) {
            break;
        }
        const bool flatwise = bar->orientation == Qt::Horizontal;
        const int length = flatwise ? r.width() : r.height();
        const int range = bar->maximum - bar->minimum;
        int thumb = length;
        if (range > 0) {
            thumb = qMax<int>(pixelMetric(PM_ScrollBarSliderMin, option, widget), qint64(length) * bar->pageStep / (range + bar->pageStep));
            thumb = qMin(thumb, length);
        }
        const int at = range > 0 ? sliderPositionFromValue(bar->minimum, bar->maximum, bar->sliderPosition, length - thumb, bar->upsideDown) : 0;
        const auto along = [&](int from, int size) {
            const QRect part = flatwise ? QRect(r.left() + from, r.top(), size, r.height()) : QRect(r.left(), r.top() + from, r.width(), size);
            return visualRect(option->direction, r, part);
        };
        switch (subControl) {
        case SC_ScrollBarGroove:
            return r;
        case SC_ScrollBarSlider:
            return along(at, thumb);
        case SC_ScrollBarSubPage:
            return along(0, at);
        case SC_ScrollBarAddPage:
            return along(at + thumb, length - at - thumb);
        // No arrows at the ends.
        case SC_ScrollBarAddLine:
        case SC_ScrollBarSubLine:
        case SC_ScrollBarFirst:
        case SC_ScrollBarLast:
            return QRect();
        default:
            break;
        }
        break;
    }
    default:
        break;
    }
    return QProxyStyle::subControlRect(control, option, subControl, widget);
}

void Style::drawComplexControl(ComplexControl control, const QStyleOptionComplex *option, QPainter *painter, const QWidget *widget) const
{
    const T::Mode &m = mode(option->palette);
    switch (control) {
    case CC_ComboBox: {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        if (!combo) {
            break;
        }
        Paint paint(painter, option);
        const QRectF arrow = subControlRect(CC_ComboBox, option, SC_ComboBoxArrow, widget);
        if (combo->editable) {
            // A box to type in, with one arrow for the list.
            field(painter, option->rect, option);
            chevron(painter, arrow, Qt::DownArrow, option->palette.color(QPalette::Text), 3.5);
        } else {
            // A pop-up button: the choice on a button's face, and the pair
            // of arrows that says there are others.
            QStyleOptionComboBox pressed(*combo);
            pressed.state.setFlag(State_On, false);
            face(painter, option->rect, &pressed, false);
            if (ringed(option)) {
                ring(painter, option->rect, T::pushRadius, option);
            }
            arrows(painter, arrow, option->palette.color(QPalette::ButtonText));
        }
        return;
    }
    case CC_SpinBox: {
        const auto *spin = qstyleoption_cast<const QStyleOptionSpinBox *>(option);
        if (!spin) {
            break;
        }
        Paint paint(painter, option);
        if (spin->frame) {
            field(painter, option->rect, option);
        }
        if (spin->buttonSymbols != QAbstractSpinBox::NoButtons) {
            const QRectF up = subControlRect(CC_SpinBox, option, SC_SpinBoxUp, widget);
            const QRectF down = subControlRect(CC_SpinBox, option, SC_SpinBoxDown, widget);
            // The stepper: a small face at the field's end, an arrow each way.
            const QRectF stepper = up.united(down).adjusted(0, 3, -3, -3);
            fill(painter, stepper, 4, color(m.face));
            const auto arrowColor = [&](QAbstractSpinBox::StepEnabledFlag way, SubControl part) {
                QColor c = option->palette.color(QPalette::Text);
                if (!(spin->stepEnabled & way)) {
                    c.setAlphaF(0.3);
                } else if ((spin->activeSubControls & part) && (option->state & State_Sunken)) {
                    c = accent(option);
                }
                return c;
            };
            chevron(painter, QRectF(stepper.left(), stepper.top() + 1, stepper.width(), stepper.height() / 2 - 1), Qt::UpArrow, arrowColor(QAbstractSpinBox::StepUpEnabled, SC_SpinBoxUp), 2.5, 1.4);
            chevron(painter, QRectF(stepper.left(), stepper.center().y(), stepper.width(), stepper.height() / 2 - 1), Qt::DownArrow, arrowColor(QAbstractSpinBox::StepDownEnabled, SC_SpinBoxDown), 2.5, 1.4);
        }
        return;
    }
    case CC_Slider: {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) {
            break;
        }
        Paint paint(painter, option);
        const bool flatwise = slider->orientation == Qt::Horizontal;
        const QRectF groove = subControlRect(CC_Slider, option, SC_SliderGroove, widget);
        const QRectF knob = subControlRect(CC_Slider, option, SC_SliderHandle, widget);
        if (slider->subControls & SC_SliderGroove) {
            fill(painter, groove, T::sliderTrack / 2, color(m.track));
            // Lit from the low end up to the knob.
            QRectF lit = groove;
            const bool fromFar = slider->upsideDown != (flatwise && slider->direction == Qt::RightToLeft);
            if (flatwise) {
                fromFar ? lit.setLeft(knob.center().x()) : lit.setRight(knob.center().x());
            } else {
                // A standing slider grows from the bottom unless it is turned over.
                slider->upsideDown ? lit.setTop(knob.center().y()) : lit.setBottom(knob.center().y());
            }
            fill(painter, lit, T::sliderTrack / 2, accent(option));
        }
        if ((slider->subControls & SC_SliderTickmarks) && slider->tickPosition != QSlider::NoTicks && slider->tickInterval > 0) {
            // Dots under the track, one a step.
            painter->setBrush(color(m.textTertiary));
            const int travel = (flatwise ? option->rect.width() : option->rect.height()) - T::sliderKnobWidth;
            for (int v = slider->minimum; v <= slider->maximum; v += slider->tickInterval) {
                const qreal at = sliderPositionFromValue(slider->minimum, slider->maximum, v, travel, slider->upsideDown) + T::sliderKnobWidth / 2;
                const QPointF dot = flatwise ? QPointF(option->rect.left() + at, groove.bottom() + 5) : QPointF(groove.right() + 5, option->rect.top() + at);
                painter->drawEllipse(dot, 1, 1);
            }
        }
        if (slider->subControls & SC_SliderHandle) {
            // The knob: a white capsule with a little shade under it.
            const qreal round = qMin(knob.width(), knob.height()) / 2;
            painter->setBrush(QColor(0, 0, 0, 22));
            painter->drawRoundedRect(knob.adjusted(-1, 0, 1, 2), round + 1, round + 1);
            painter->setBrush(QColor(0, 0, 0, 30));
            painter->drawRoundedRect(knob.adjusted(-0.5, 0, 0.5, 1), round + 0.5, round + 0.5);
            fill(painter, knob, round, color(m.knob));
            if (ringed(option)) {
                ring(painter, knob, round, option);
            }
        }
        return;
    }
    case CC_ScrollBar: {
        const auto *bar = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!bar || bar->maximum <= bar->minimum) {
            // Nothing to scroll: nothing drawn.
            return;
        }
        Paint paint(painter, option);
        const bool flatwise = bar->orientation == Qt::Horizontal;
        const bool held = (bar->activeSubControls & SC_ScrollBarSlider) && (option->state & State_Sunken);
        const bool over = option->state & State_MouseOver;
        // Thin at rest, wider with the pointer on it, against the far edge.
        const qreal thick = held || over ? T::scrollbarHover : T::scrollbarThin;
        QRectF thumb = subControlRect(CC_ScrollBar, option, SC_ScrollBarSlider, widget);
        if (flatwise) {
            thumb = QRectF(thumb.left() + T::scrollbarInset, thumb.bottom() + 1 - T::scrollbarInset - thick, thumb.width() - 2 * T::scrollbarInset, thick);
        } else {
            const qreal x = option->direction == Qt::RightToLeft ? thumb.left() + T::scrollbarInset : thumb.right() + 1 - T::scrollbarInset - thick;
            thumb = QRectF(x, thumb.top() + T::scrollbarInset, thick, thumb.height() - 2 * T::scrollbarInset);
        }
        fill(painter, thumb, thick / 2, color(held || over ? m.scrollerHover : m.scroller));
        return;
    }
    default:
        break;
    }
    QProxyStyle::drawComplexControl(control, option, painter, widget);
}

} // namespace Ambrosia
