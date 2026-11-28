// Ambrosia's Qt widget style: every Qt Widgets app's controls as macOS 26
// draws its own. Push buttons, checkboxes and radio buttons, text fields,
// pop-up buttons and steppers, sliders, progress bars, scroll bars, menus
// and tooltips, tabs, boxes, the rows and headers of lists, trees and
// tables, toolbars and menu bars, a combo box's list, dials, tool boxes, a
// dock widget's title and the calendar are painted here; everything else is the
// style underneath (Breeze on an Ambrosia system), so an app never meets a
// control this doesn't know. Sizes and the colors a palette has no role for come from the
// tokens; the accent, the text and the window come from the app's palette,
// so the color scheme and the accent the user chose still decide.

#include "style.h"

#include "tokens.h"

#include "../../kit/scrolling.h"

#include <QAbstractItemView>
#include <QAction>
#include <QApplication>
#include <QBasicTimer>
#include <QCalendarWidget>
#include <QComboBox>
#include <QDate>
#include <QElapsedTimer>
#include <QEvent>
#include <QHash>
#include <QHeaderView>
#include <QItemDelegate>
#include <QKeySequence>
#include <QLayout>
#include <QListView>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QProgressBar>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleFactory>
#include <QStyleOption>
#include <QTabBar>
#include <QTextCharFormat>
#include <QTabWidget>
#include <QTreeView>
#include <QtMath>

#ifdef AMBROSIA_HAVE_KWINDOWSYSTEM
#include <KWindowEffects>
#endif

namespace Ambrosia
{

namespace T = Tokens;

// Keeps the progress bars with no end in sight moving: while one is on
// screen it is drawn again sixty times a second, and asks here where its
// lit piece has got to.
class Pulse : public QObject
{
public:
    using QObject::QObject;

    void watch(QProgressBar *bar)
    {
        if (!m_bars.contains(bar)) {
            m_bars.append(bar);
        }
    }

    // How far along its track the lit piece is: 0 to 1 and back, easing at
    // each end.
    qreal along()
    {
        if (!m_clock.isValid()) {
            m_clock.start();
        }
        if (!m_timer.isActive()) {
            m_timer.start(16, this);
        }
        const qreal t = (m_clock.elapsed() % period) / qreal(period);
        const qreal there = t < 0.5 ? 2 * t : 2 - 2 * t;
        return there * there * (3 - 2 * there);
    }

protected:
    void timerEvent(QTimerEvent *) override
    {
        bool any = false;
        m_bars.removeAll(nullptr);
        for (const QPointer<QProgressBar> &bar : std::as_const(m_bars)) {
            if (bar->isVisible() && bar->minimum() == bar->maximum()) {
                bar->update();
                any = true;
            }
        }
        if (!any) {
            m_timer.stop();
        }
    }

private:
    static constexpr int period = 2400;
    QList<QPointer<QProgressBar>> m_bars;
    QBasicTimer m_timer;
    QElapsedTimer m_clock;
};

// Has the compositor blur behind the lists that pop up from a combo box, so
// they can be the glass a menu is (Breeze, underneath, asks for its menus
// only). Where KWindowSystem isn't built in nothing is asked, and they are
// solid.
class Glass : public QObject
{
public:
    using QObject::QObject;

    static constexpr char marked[] = "_ambrosia_glass";

    void watch(QWidget *window)
    {
#ifdef AMBROSIA_HAVE_KWINDOWSYSTEM
        window->removeEventFilter(this);
        window->installEventFilter(this);
#else
        Q_UNUSED(window)
#endif
    }

protected:
    bool eventFilter(QObject *object, QEvent *event) override
    {
#ifdef AMBROSIA_HAVE_KWINDOWSYSTEM
        auto *window = qobject_cast<QWidget *>(object);
        if (window && (event->type() == QEvent::Show || event->type() == QEvent::Resize) && window->testAttribute(Qt::WA_WState_Created)) {
            window->winId();
            // The panel's own shape, a pixel in from the window's edge.
            QPainterPath shape;
            shape.addRoundedRect(QRectF(window->rect()).adjusted(0.5, 0.5, -0.5, -0.5), Tokens::menuRadius, Tokens::menuRadius);
            KWindowEffects::enableBlurBehind(window->windowHandle(), true, QRegion(shape.toFillPolygon().toPolygon()));
            window->setProperty(marked, true);
        }
#else
        Q_UNUSED(event)
#endif
        return QObject::eventFilter(object, event);
    }
};

namespace
{

QStyle *styleUnderneath(const QString &name)
{
    if (!name.isEmpty()) {
        return QStyleFactory::create(name);
    }
    QStyle *breeze = QStyleFactory::create(QStringLiteral("breeze"));
    return breeze ? breeze : QStyleFactory::create(QStringLiteral("fusion"));
}

// How solid a menu's panel is. Breeze, underneath, has KWin blur behind menus
// when it is told to draw its own see-through (breezerc's MenuOpacity; the
// session's says 72, the thick material's): then ours is glass of the same
// opacity. Anywhere else nothing would blur behind it, and it is solid.
qreal blurredMenuOpacity(const QStyle *underneath)
{
    if (!underneath || underneath->objectName().compare(QLatin1String("breeze"), Qt::CaseInsensitive) != 0) {
        return 1;
    }
    static const qreal opacity = [] {
        const QStringList files = QStandardPaths::locateAll(QStandardPaths::GenericConfigLocation, QStringLiteral("breezerc"));
        for (const QString &file : files) {
            const QVariant value = QSettings(file, QSettings::IniFormat).value(QStringLiteral("Style/MenuOpacity"));
            if (value.isValid()) {
                return qBound(0.0, value.toDouble() / 100, 1.0);
            }
        }
        return 1.0;
    }();
    return opacity;
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

// A rectangle round at only some of its corners.
QPainterPath rounded(const QRectF &r, qreal topLeft, qreal topRight, qreal bottomRight, qreal bottomLeft)
{
    QPainterPath path;
    path.moveTo(r.left() + topLeft, r.top());
    path.lineTo(r.right() - topRight, r.top());
    if (topRight > 0) {
        path.arcTo(r.right() - 2 * topRight, r.top(), 2 * topRight, 2 * topRight, 90, -90);
    }
    path.lineTo(r.right(), r.bottom() - bottomRight);
    if (bottomRight > 0) {
        path.arcTo(r.right() - 2 * bottomRight, r.bottom() - 2 * bottomRight, 2 * bottomRight, 2 * bottomRight, 0, -90);
    }
    path.lineTo(r.left() + bottomLeft, r.bottom());
    if (bottomLeft > 0) {
        path.arcTo(r.left(), r.bottom() - 2 * bottomLeft, 2 * bottomLeft, 2 * bottomLeft, 270, -90);
    }
    path.lineTo(r.left(), r.top() + topLeft);
    if (topLeft > 0) {
        path.arcTo(r.left(), r.top(), 2 * topLeft, 2 * topLeft, 180, -90);
    }
    path.closeSubpath();
    return path;
}

// A font for a table's header or a menu's heading: the same face, smaller.
QFont smaller(QFont font)
{
    if (font.pointSizeF() > 0) {
        font.setPointSizeF(font.pointSizeF() * T::caption);
    } else {
        font.setPixelSize(qRound(font.pixelSize() * T::caption));
    }
    return font;
}

// A menu row's shortcut as a Mac prints it: the modifiers as ⌃⌥⇧⌘ in that
// order, then the key, arrows and editing keys as their symbols. On the
// Mac-first keyboard (docs/keyboard.md) the Command key reaches an app as
// Ctrl, so its Ctrl reads ⌘ and its Meta ⌃, as in the shell's menus
// (shell/MenuView.qml). Text that isn't a shortcut is left as it is.
QString macShortcut(const QString &text)
{
    static QHash<QString, QString> known;
    const auto found = known.constFind(text);
    if (found != known.constEnd()) {
        return *found;
    }
    static const QHash<int, QString> glyphs = {
        {Qt::Key_Up, QStringLiteral("↑")},        {Qt::Key_Down, QStringLiteral("↓")},     {Qt::Key_Left, QStringLiteral("←")},
        {Qt::Key_Right, QStringLiteral("→")},     {Qt::Key_Return, QStringLiteral("↩")},   {Qt::Key_Enter, QStringLiteral("⌤")},
        {Qt::Key_Tab, QStringLiteral("⇥")},       {Qt::Key_Backtab, QStringLiteral("⇤")},  {Qt::Key_Backspace, QStringLiteral("⌫")},
        {Qt::Key_Delete, QStringLiteral("⌦")},    {Qt::Key_Escape, QStringLiteral("⎋")},   {Qt::Key_PageUp, QStringLiteral("⇞")},
        {Qt::Key_PageDown, QStringLiteral("⇟")},  {Qt::Key_Home, QStringLiteral("↖")},     {Qt::Key_End, QStringLiteral("↘")},
    };
    QStringList keys;
    const QKeySequence sequence = QKeySequence::fromString(text, QKeySequence::NativeText);
    for (int i = 0; i < sequence.count(); ++i) {
        const QKeyCombination each = sequence[i];
        if (each.key() == Qt::Key_unknown) {
            keys.clear();
            break;
        }
        QString one;
        if (each.keyboardModifiers() & Qt::MetaModifier) {
            one += QStringLiteral("⌃");
        }
        if (each.keyboardModifiers() & Qt::AltModifier) {
            one += QStringLiteral("⌥");
        }
        if (each.keyboardModifiers() & Qt::ShiftModifier) {
            one += QStringLiteral("⇧");
        }
        if (each.keyboardModifiers() & Qt::ControlModifier) {
            one += QStringLiteral("⌘");
        }
        const auto glyph = glyphs.constFind(each.key());
        keys << one + (glyph != glyphs.constEnd() ? *glyph : QKeySequence(each.key()).toString(QKeySequence::PortableText));
    }
    const QString mac = keys.isEmpty() ? text : keys.join(QLatin1Char(' '));
    if (known.size() > 1024) {
        known.clear();
    }
    known.insert(text, mac);
    return mac;
}

// How much narrower a menu's shortcuts are as a Mac prints them than as Qt
// measured them: QMenu adds the widest it measured to every row itself.
int shortcutsSaved(const QMenu *menu, const QFontMetrics &metrics)
{
    int measured = 0;
    int drawn = 0;
    const QList<QAction *> actions = menu->actions();
    for (const QAction *action : actions) {
        if (action->isSeparator() || !action->isVisible()) {
            continue;
        }
        const qsizetype tab = action->text().indexOf(QLatin1Char('\t'));
        QString shortcut;
        if (tab >= 0) {
            shortcut = action->text().mid(tab + 1);
        } else if (action->isShortcutVisibleInContextMenu() && !action->shortcut().isEmpty()) {
            shortcut = action->shortcut().toString(QKeySequence::NativeText);
        }
        if (!shortcut.isEmpty()) {
            measured = qMax(measured, metrics.horizontalAdvance(shortcut));
            drawn = qMax(drawn, metrics.horizontalAdvance(macShortcut(shortcut)));
        }
    }
    return measured - drawn;
}

// One color laid over another, for where Qt wants a color with no alpha.
QColor over(const QColor &top, const QColor &under)
{
    const qreal a = top.alphaF();
    return QColor::fromRgbF(top.redF() * a + under.redF() * (1 - a), top.greenF() * a + under.greenF() * (1 - a), top.blueF() * a + under.blueF() * (1 - a));
}

// A box round a group of controls: a faint fill and a hairline.
void panel(QPainter *painter, const QRectF &rect, const T::Mode &m)
{
    painter->setBrush(color(m.box));
    painter->setPen(QPen(color(m.separator), 1));
    painter->drawRoundedRect(rect.adjusted(0.5, 0.5, -0.5, -0.5), T::boxRadius, T::boxRadius);
    painter->setPen(Qt::NoPen);
}

// A hairline through the middle of `rect`, along it or across it.
void hairline(QPainter *painter, const QRectF &rect, bool flatwise, const QColor &color, qreal inset = 0)
{
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    if (flatwise) {
        painter->fillRect(QRectF(rect.left() + inset, qFloor(rect.center().y()), rect.width() - 2 * inset, 1), color);
    } else {
        painter->fillRect(QRectF(qFloor(rect.center().x()), rect.top() + inset, 1, rect.height() - 2 * inset), color);
    }
    painter->restore();
}

bool upright(QTabBar::Shape shape)
{
    return shape == QTabBar::RoundedWest || shape == QTabBar::RoundedEast || shape == QTabBar::TriangularWest || shape == QTabBar::TriangularEast;
}

// Which side of its pane a tab bar is on, whatever the shape of its tabs.
QTabBar::Shape side(QTabBar::Shape shape)
{
    switch (shape) {
    case QTabBar::RoundedSouth:
    case QTabBar::TriangularSouth:
        return QTabBar::RoundedSouth;
    case QTabBar::RoundedWest:
    case QTabBar::TriangularWest:
        return QTabBar::RoundedWest;
    case QTabBar::RoundedEast:
    case QTabBar::TriangularEast:
        return QTabBar::RoundedEast;
    default:
        return QTabBar::RoundedNorth;
    }
}

// A tab view's pane: the box its pages are in. The tabs sit half over its
// edge, as a Mac's do; a window's own tabs (document mode) have no box.
QRect tabPane(const QStyleOptionTabWidgetFrame *frame)
{
    const int overlap = frame->lineWidth <= 0 ? 0 : int(T::tabHeight) / 2;
    QRect r = frame->rect;
    switch (side(frame->shape)) {
    case QTabBar::RoundedSouth:
        r.setBottom(r.bottom() - qMax(frame->tabBarSize.height() - overlap, 0));
        break;
    case QTabBar::RoundedWest:
        r.setLeft(r.left() + qMax(frame->tabBarSize.width() - overlap, 0));
        break;
    case QTabBar::RoundedEast:
        r.setRight(r.right() - qMax(frame->tabBarSize.width() - overlap, 0));
        break;
    default:
        r.setTop(r.top() + qMax(frame->tabBarSize.height() - overlap, 0));
        break;
    }
    return r;
}

// A chosen row is in the accent color only where the keyboard is: in the
// window in front, in the list that has the focus. Anywhere else it is gray.
bool emphasized(const QStyleOption *option, const QWidget *widget)
{
    if (!widget) {
        return option->state & QStyle::State_Active;
    }
    // A list that popped up (a combo's, a completion's) leaves the focus
    // with what opened it.
    const Qt::WindowType type = widget->window()->windowType();
    if (type == Qt::Popup || type == Qt::ToolTip) {
        return true;
    }
    if (!widget->isActiveWindow()) {
        return false;
    }
    const QWidget *focus = QApplication::focusWidget();
    return widget->hasFocus() || (focus && widget->isAncestorOf(focus));
}

// Whether the rows over and under this one are chosen too: the highlight
// then runs on into theirs, square where they meet.
struct Joined {
    bool above = false;
    bool below = false;
};

Joined joined(const QWidget *widget, const QModelIndex &index)
{
    Joined j;
    const auto *view = qobject_cast<const QAbstractItemView *>(widget);
    if (!view || !index.isValid() || !view->selectionModel()) {
        return j;
    }
    QModelIndex up, down;
    if (const auto *tree = qobject_cast<const QTreeView *>(view)) {
        up = tree->indexAbove(index);
        down = tree->indexBelow(index);
    } else if (const auto *list = qobject_cast<const QListView *>(view);
               list && list->viewMode() == QListView::ListMode && list->flow() == QListView::TopToBottom && !list->isWrapping() && list->spacing() == 0) {
        up = index.siblingAtRow(index.row() - 1);
        down = index.siblingAtRow(index.row() + 1);
    }
    j.above = up.isValid() && view->selectionModel()->isSelected(up.siblingAtColumn(index.column()));
    j.below = down.isValid() && view->selectionModel()->isSelected(down.siblingAtColumn(index.column()));
    return j;
}

// A row's highlight: round at the ends of the row (`head` where it starts,
// `tail` where it ends), square where it meets a chosen neighbor.
void highlight(QPainter *painter, const QRectF &rect, bool head, bool tail, Joined j, bool rightToLeft, const QColor &color)
{
    if (rightToLeft) {
        std::swap(head, tail);
    }
    const qreal r = T::rowRadius;
    painter->setRenderHint(QPainter::Antialiasing);
    painter->fillPath(rounded(rect, head && !j.above ? r : 0, tail && !j.above ? r : 0, tail && !j.below ? r : 0, head && !j.below ? r : 0), color);
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

// How far into its pane a tab view's pages start: past the half of the tabs
// that hangs into it, and a little air.
constexpr int tabClear = int(T::tabHeight) / 2 + 4;

// A table header's title keeps this far from its section's ends, and the
// arrow that says which way it is sorted takes this much of the far one.
constexpr int headerPadding = 6;
constexpr int headerArrow = 12;

// The room a checkbox keeps round its box for the focus ring.
constexpr int ringRoom = 2;

// The combo box a popped-up list belongs to, when `container` is the window
// Qt puts that list in.
const QComboBox *comboOf(const QWidget *container)
{
    return container && container->inherits("QComboBoxPrivateContainer") ? qobject_cast<const QComboBox *>(container->parentWidget()) : nullptr;
}

// A menu's panel: glass where the compositor blurs behind it, solid where
// not. (Not through Paint: a menu hands its panel over with no state at
// all, which would dim it as a disabled control's.)
void menuPanel(QPainter *painter, const QRect &rect, const T::Mode &m, const QWidget *widget, qreal glass)
{
    painter->save();
    QColor ground = color(m.menu);
    if (widget && widget->isWindow() && widget->testAttribute(Qt::WA_TranslucentBackground)) {
        if (comboOf(widget)) {
            // Breeze has painted a frame of its own under a combo's list.
            painter->setCompositionMode(QPainter::CompositionMode_Source);
            painter->fillRect(rect, Qt::transparent);
            painter->setCompositionMode(QPainter::CompositionMode_SourceOver);
            if (widget->property(Glass::marked).toBool()) {
                ground.setAlphaF(glass);
            }
        } else {
            ground.setAlphaF(glass);
        }
    }
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setBrush(ground);
    painter->setPen(QPen(color(m.menuRim), 1));
    painter->drawRoundedRect(QRectF(rect).adjusted(0.5, 0.5, -0.5, -0.5), T::menuRadius, T::menuRadius);
    painter->restore();
}

// The rows of the list a combo box you can type in drops: a menu's rows, the
// one under the pointer on the accent color.
class ComboRows : public QItemDelegate
{
public:
    using QItemDelegate::QItemDelegate;

    void paint(QPainter *painter, const QStyleOptionViewItem &option, const QModelIndex &index) const override
    {
        const T::Mode &m = mode(option.palette);
        const bool usable = (option.state & QStyle::State_Enabled) && (index.flags() & Qt::ItemIsEnabled);
        const bool lit = (option.state & QStyle::State_Selected) && usable;
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        const QRectF r = option.rect;
        if (lit) {
            fill(painter, r, T::menuRowRadius, option.palette.color(QPalette::Active, QPalette::Highlight));
        }
        qreal x = r.left() + T::menuRowPadding;
        const QIcon icon = qvariant_cast<QIcon>(index.data(Qt::DecorationRole));
        if (!icon.isNull()) {
            const QRectF slot(x, r.center().y() + 0.5 - T::menuIcon / 2, T::menuIcon, T::menuIcon);
            icon.paint(painter, slot.toRect(), Qt::AlignCenter, !usable ? QIcon::Disabled : lit ? QIcon::Selected : QIcon::Normal);
            x += T::menuIcon + T::menuGap;
        }
        painter->setFont(option.font);
        painter->setPen(lit ? option.palette.color(QPalette::Active, QPalette::HighlightedText) : usable ? option.palette.color(QPalette::Active, QPalette::Text) : color(m.textTertiary));
        const qreal width = r.right() + 1 - T::menuRowPadding - x;
        painter->drawText(QRectF(x, r.top(), width, r.height()), Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine,
                          option.fontMetrics.elidedText(index.data(Qt::DisplayRole).toString(), Qt::ElideRight, int(width)));
        painter->restore();
    }

    QSize sizeHint(const QStyleOptionViewItem &option, const QModelIndex &index) const override
    {
        int width = option.fontMetrics.horizontalAdvance(index.data(Qt::DisplayRole).toString()) + 2 * T::menuRowPadding;
        if (!qvariant_cast<QIcon>(index.data(Qt::DecorationRole)).isNull()) {
            width += T::menuIcon + T::menuGap;
        }
        return QSize(width, qMax<int>(option.fontMetrics.height() + 4, T::menuRow));
    }
};

// The calendar a table of days belongs to, when `view` is that table.
const QCalendarWidget *calendarOf(const QWidget *view)
{
    if (!view || view->objectName() != QLatin1String("qt_calendar_calendarview")) {
        return nullptr;
    }
    return qobject_cast<const QCalendarWidget *>(view->parentWidget());
}

// A cell of the calendar's table that names a weekday or numbers a week.
bool calendarHeading(const QCalendarWidget *calendar, const QModelIndex &index)
{
    return (calendar->horizontalHeaderFormat() != QCalendarWidget::NoHorizontalHeader && index.row() == 0)
        || (calendar->verticalHeaderFormat() != QCalendarWidget::NoVerticalHeader && index.column() == 0);
}

// Whether a cell of the calendar's table is today's. The table shows six
// weeks: a day past the first week in the top one is last month's, and one
// from a month's start in the bottom two is next month's.
bool calendarToday(const QCalendarWidget *calendar, const QModelIndex &index)
{
    if (calendarHeading(calendar, index)) {
        return false;
    }
    const QDate today = QDate::currentDate();
    const QCalendar system = calendar->calendar();
    if (calendar->yearShown() != today.year(system) || calendar->monthShown() != today.month(system)) {
        return false;
    }
    const int day = index.data(Qt::DisplayRole).toInt();
    const int week = index.row() - (calendar->horizontalHeaderFormat() != QCalendarWidget::NoHorizontalHeader ? 1 : 0);
    if ((week == 0 && day > 7) || (week >= 4 && day < 15)) {
        return false;
    }
    return day == today.day(system);
}

// One of the buttons over the calendar's days: back, on, the month, the year.
bool calendarButton(const QWidget *widget)
{
    return widget && widget->parentWidget() && widget->parentWidget()->objectName() == QLatin1String("qt_calendar_navigationbar");
}

// The angle a dial's mark is at for a place along its range, as Qt turns
// the pointer into a value: a gap at the bottom unless the dial wraps round.
qreal dialAngle(const QStyleOptionSlider *dial, int position)
{
    const int along = dial->upsideDown ? position : dial->maximum - position;
    if (dial->maximum == dial->minimum) {
        return M_PI / 2;
    }
    const qreal share = qreal(along - dial->minimum) / (dial->maximum - dial->minimum);
    return dial->dialWrapping ? M_PI * 3 / 2 - share * 2 * M_PI : (M_PI * 8 - share * 10 * M_PI) / 6;
}

bool isDefaultButton(const QStyleOptionButton *button)
{
    return (button->features & QStyleOptionButton::DefaultButton) && (button->state & QStyle::State_Active) && enabled(button);
}

// A push button with a title and a picture: only the title is drawn.
bool titledWithIcon(const QStyleOptionButton *button)
{
    return !button->icon.isNull() && !button->text.isEmpty();
}

} // namespace

Style::Style(const QString &base)
    : QProxyStyle(styleUnderneath(base))
    , m_pulse(new Pulse(this))
    , m_glass(new Glass(this))
{
    setObjectName(QStringLiteral("ambrosia"));
}

// An app that draws with this style also scrolls as ours do under a
// trackpad: its Qt Quick lists glide and give at their ends, its widgets'
// scroll bars glide (kit/scrolling.h).
void Style::polish(QApplication *app)
{
    QProxyStyle::polish(app);
    kitScrolling(app);
}

void Style::polish(QWidget *widget)
{
    // The list of a combo you can type in gets rows of ours in place of
    // Qt's, before the style underneath sees it: Breeze would put its own
    // there, and those can't be told from an app's, which are left alone.
    if (auto *combo = qobject_cast<QComboBox *>(widget); combo && combo->isEditable() && combo->view() && combo->view()->itemDelegate()) {
        if (qstrcmp(combo->view()->itemDelegate()->metaObject()->className(), "QComboBoxDelegate") == 0) {
            combo->view()->setItemDelegate(new ComboRows(combo->view()));
        }
    }
    QProxyStyle::polish(widget);
    // Round corners need a window that isn't filled first.
    if (qobject_cast<QMenu *>(widget) || widget->inherits("QTipLabel")) {
        widget->setAttribute(Qt::WA_TranslucentBackground);
    }
    if (widget->inherits("QScrollBar") || widget->inherits("QAbstractSlider") || qobject_cast<QTabBar *>(widget) || widget->inherits("QDockWidgetTitleButton")
        || widget->inherits("QToolBoxButton")) {
        widget->setAttribute(Qt::WA_Hover);
    }
    if (auto *bar = qobject_cast<QProgressBar *>(widget)) {
        m_pulse->watch(bar);
    }
    // A combo's list is a menu: round, and the menu's color behind its rows
    // rather than a list's white.
    const QWidget *parent = widget->parentWidget();
    if (const QComboBox *combo = comboOf(widget)) {
        widget->setAttribute(Qt::WA_TranslucentBackground);
        m_glass->watch(widget);
        // Qt fills each row of a pop-up button's list from edge to edge
        // before it is drawn: kept a pixel in, the rows leave the panel's
        // rim alone. (The list of a combo to type in has the panel's margin
        // round it: SE_ShapedFrameContents.)
        if (widget->layout() && !combo->isEditable()) {
            widget->layout()->setContentsMargins(1, 0, 1, 0);
        }
    }
    if (auto *view = qobject_cast<QAbstractItemView *>(widget); view && comboOf(parent)) {
        view->viewport()->setAutoFillBackground(false);
    }
    // The calendar is one sheet: the bar over its days isn't a band of the
    // accent color, and the weekend isn't in red (where that is still Qt's
    // doing and not the app's).
    if (widget->objectName() == QLatin1String("qt_calendar_navigationbar")) {
        widget->setBackgroundRole(QPalette::Base);
    }
    if (auto *calendar = qobject_cast<QCalendarWidget *>(widget)) {
        for (const Qt::DayOfWeek day : {Qt::Saturday, Qt::Sunday}) {
            QTextCharFormat format = calendar->weekdayTextFormat(day);
            if (format.foreground() == QBrush(Qt::red)) {
                format.clearForeground();
                calendar->setWeekdayTextFormat(day, format);
            }
        }
    }
}

int Style::pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const
{
    switch (metric) {
    // A checkbox's own room is its box and the focus ring's two pixels all
    // round it, which Qt wouldn't let it draw outside.
    case PM_IndicatorWidth:
    case PM_IndicatorHeight:
    case PM_ExclusiveIndicatorWidth:
    case PM_ExclusiveIndicatorHeight:
        return T::checkSize + 2 * ringRoom;
    case PM_CheckBoxLabelSpacing:
    case PM_RadioButtonLabelSpacing:
        return T::checkGap - ringRoom;
    case PM_TabBarTabHSpace:
        return 2 * T::tabPadding;
    case PM_TabBarTabVSpace:
        return 6;
    case PM_TabBarTabShiftHorizontal:
    case PM_TabBarTabShiftVertical:
    case PM_TabBarTabOverlap:
    case PM_TabBarBaseHeight:
        return 0;
    case PM_TabBarBaseOverlap:
        // What a tab bar on its own asks is how thick the line under it is.
        if (qobject_cast<const QTabBar *>(widget)) {
            return 1;
        }
        if (const auto *tabs = qobject_cast<const QTabWidget *>(widget); tabs && tabs->documentMode()) {
            return 0;
        }
        return int(T::tabHeight) / 2;
    case PM_TabCloseIndicatorWidth:
    case PM_TabCloseIndicatorHeight:
        return T::tabClose;
    case PM_MenuBarPanelWidth:
        return 0;
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
    // A pop-up button's choices open as a menu over it, the current one
    // ticked; a combo that can be typed in drops a list.
    case SH_ComboBox_Popup: {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        return combo && !combo->editable;
    }
    case SH_ComboBox_PopupFrameStyle: {
        // The menu's panel is its edge.
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        if (combo && !combo->editable) {
            return 0; // QFrame::NoFrame
        }
        // A list dropped from a combo to type in: a frame, which is where
        // its panel is drawn (CE_ShapedFrame).
        return 0x0006 | 0x0010; // QFrame::StyledPanel | QFrame::Plain
    }
    case SH_DockWidget_ButtonsHaveFrame:
        return false;
    // A tab view's tabs sit in the middle of its top edge; a window's own
    // start at the left and close from the left.
    case SH_TabBar_Alignment: {
        const auto *tabs = qobject_cast<const QTabWidget *>(widget);
        if (!tabs && widget) {
            tabs = qobject_cast<const QTabWidget *>(widget->parentWidget());
        }
        return int(tabs && !tabs->documentMode() ? Qt::AlignCenter : Qt::AlignLeft);
    }
    case SH_TabBar_CloseButtonPosition:
        return QTabBar::LeftSide;
    case SH_TabBar_ElideMode:
        return Qt::ElideRight;
    // A chosen row is chosen from edge to edge.
    case SH_ItemView_ShowDecorationSelected:
        return true;
    case SH_Table_GridLineColor:
        if (option) {
            return int(over(color(mode(option->palette).separator), option->palette.color(QPalette::Base)).rgba());
        }
        break;
    // Dragging out a selection draws a tinted rectangle, not an outline.
    case SH_RubberBand_Mask:
        return false;
    default:
        break;
    }
    return QProxyStyle::styleHint(hint, option, widget, returnData);
}

QSize Style::sizeFromContents(ContentsType type, const QStyleOption *option, const QSize &size, const QWidget *widget) const
{
    switch (type) {
    case CT_PushButton: {
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        int width = size.width() + 2 * T::pushPadding;
        if (button && titledWithIcon(button)) {
            // The room QPushButton left for the picture that isn't drawn.
            width -= button->iconSize.width() + 4;
        }
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
    case CT_TabBarTab: {
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (!tab) {
            break;
        }
        const int across = tab->documentMode ? T::tabDocument : T::tabHeight;
        return upright(tab->shape) ? QSize(qMax(size.width(), across), size.height()) : QSize(size.width(), qMax(size.height(), across));
    }
    case CT_TabWidget: {
        // The pane's hairline, and the half of the tabs that hangs into it
        // (see SE_TabWidgetTabContents).
        const auto *frame = qstyleoption_cast<const QStyleOptionTabWidgetFrame *>(option);
        if (!frame || frame->lineWidth <= 0) {
            return size;
        }
        return upright(frame->shape) ? size + QSize(2 + tabClear, 2) : size + QSize(2, 2 + tabClear);
    }
    case CT_HeaderSection: {
        const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
        const QSize base = QProxyStyle::sizeFromContents(type, option, size, widget);
        if (header && header->orientation == Qt::Horizontal) {
            return QSize(base.width(), qMax<int>(base.height(), T::rowHeader));
        }
        return base;
    }
    case CT_ItemViewItem: {
        const QSize base = QProxyStyle::sizeFromContents(type, option, size, widget);
        return QSize(base.width(), qMax<int>(base.height(), T::rowHeight));
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
        int height = size.height() + 4;
        // A pop-up button's list asks with the size of the list, not of
        // the row's text, and has no margin of its own beside its rows.
        if (qobject_cast<const QComboBox *>(widget)) {
            width = item->fontMetrics.horizontalAdvance(item->text) + 2 * T::menuRowPadding + 2 * (T::menuMargin - 1);
            height = item->fontMetrics.height() + 4;
        }
        if (item->maxIconWidth > 0 || item->menuHasCheckableItems) {
            width += T::menuIcon + T::menuGap;
        }
        if (item->reservedShortcutWidth > 0) {
            width += T::menuShortcutGap;
        }
        if (const auto *menu = qobject_cast<const QMenu *>(widget)) {
            width = qMax(width - shortcutsSaved(menu, item->fontMetrics), 0);
        }
        // Room for a submenu's arrow on every row, so the shortcuts line up.
        if (!qobject_cast<const QComboBox *>(widget)) {
            width += T::menuIcon;
        }
        return QSize(width, qMax<int>(height, T::menuRow));
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
    case SE_TabWidgetTabPane:
        if (const auto *frame = qstyleoption_cast<const QStyleOptionTabWidgetFrame *>(option)) {
            return tabPane(frame);
        }
        break;
    case SE_TabWidgetTabContents: {
        const auto *frame = qstyleoption_cast<const QStyleOptionTabWidgetFrame *>(option);
        if (!frame) {
            break;
        }
        const QRect pane = tabPane(frame);
        if (frame->lineWidth <= 0) {
            return pane;
        }
        // Inside the pane's hairline, clear of the tabs if there are any.
        const bool tabs = (upright(frame->shape) ? frame->tabBarSize.width() : frame->tabBarSize.height()) > T::tabHeight / 2;
        const int clear = tabs ? tabClear : 0;
        switch (side(frame->shape)) {
        case QTabBar::RoundedSouth:
            return pane.adjusted(1, 1, -1, -1 - clear);
        case QTabBar::RoundedWest:
            return pane.adjusted(1 + clear, 1, -1, -1);
        case QTabBar::RoundedEast:
            return pane.adjusted(1, 1, -1 - clear, -1);
        default:
            return pane.adjusted(1, 1 + clear, -1, -1);
        }
    }
    case SE_TabWidgetTabBar: {
        const auto *frame = qstyleoption_cast<const QStyleOptionTabWidgetFrame *>(option);
        if (!frame) {
            break;
        }
        // In the middle of the pane's edge; a window's own tabs fill it.
        const QRect r = frame->rect;
        const bool document = frame->lineWidth <= 0;
        const QSize bar = frame->tabBarSize;
        if (upright(frame->shape)) {
            const int height = document ? r.height() : qMin(bar.height(), r.height());
            const int x = side(frame->shape) == QTabBar::RoundedWest ? r.left() : r.right() + 1 - bar.width();
            return QRect(x, r.top() + (r.height() - height) / 2, bar.width(), height);
        }
        const int before = frame->leftCornerWidgetSize.width();
        const int room = r.width() - before - frame->rightCornerWidgetSize.width();
        const int width = document ? room : qMin(bar.width(), room);
        const int y = side(frame->shape) == QTabBar::RoundedSouth ? r.bottom() + 1 - bar.height() : r.top();
        return visualRect(frame->direction, r, QRect(r.left() + before + (room - width) / 2, y, width, bar.height()));
    }
    case SE_TabBarTabText: {
        // A window's tab has its title in its middle, whatever room the
        // close button keeps at one end; a title too long for that sits as
        // near the middle as the button lets it.
        QRect r = QProxyStyle::subElementRect(element, option, widget);
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (tab && tab->documentMode && tab->icon.isNull() && !upright(tab->shape)) {
            const int before = r.left() - tab->rect.left();
            const int after = tab->rect.right() - r.right();
            const int width = qMax(tab->rect.width() - 2 * qMax(before, after), qMin(r.width(), tab->fontMetrics.horizontalAdvance(tab->text) + 2));
            if (before > after) {
                r.setWidth(width);
            } else {
                r.setLeft(r.right() + 1 - width);
            }
        }
        return r;
    }
    case SE_HeaderLabel: {
        const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
        if (!header) {
            break;
        }
        const int arrow = header->sortIndicator != QStyleOptionHeader::None ? headerArrow : 0;
        return visualRect(header->direction, header->rect, header->rect.adjusted(headerPadding, 0, -headerPadding - arrow, 0));
    }
    case SE_ShapedFrameContents:
        // The list a combo to type in drops keeps a menu's margin from its
        // panel's edge.
        if (const QComboBox *combo = comboOf(widget); combo && combo->isEditable()) {
            const int margin = T::menuMargin;
            return option->rect.adjusted(margin, margin, -margin, -margin);
        }
        break;
    case SE_HeaderArrow:
        return visualRect(option->direction, option->rect, QRect(option->rect.right() + 1 - headerPadding - headerArrow, option->rect.top(), headerArrow, option->rect.height()));
    default:
        break;
    }
    return QProxyStyle::subElementRect(element, option, widget);
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
    case PE_IndicatorCheckBox:
    case PE_IndicatorItemViewItemCheck: {
        Paint paint(painter, option);
        const QRectF r = box(option->rect);
        const bool on = option->state & (State_On | State_NoChange);
        QColor ground = on ? accent(option) : color(m.track);
        if (on && (option->state & State_Sunken)) {
            ground = ground.darker(108);
        }
        fill(painter, r, T::checkRadius, ground);
        if (element == PE_IndicatorCheckBox && ringed(option)) {
            ring(painter, r.adjusted(-ringRoom, -ringRoom, ringRoom, ringRoom), T::checkRadius + ringRoom, option);
        }
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
        if (ringed(option)) {
            ring(painter, r.adjusted(-ringRoom, -ringRoom, ringRoom, ringRoom), T::checkSize / 2 + ringRoom, option);
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
    case PE_FrameGroupBox: {
        Paint paint(painter, option);
        panel(painter, option->rect, m);
        return;
    }
    case PE_FrameTabWidget: {
        // A window's own tabs (document mode) have no box round the page.
        const auto *frame = qstyleoption_cast<const QStyleOptionTabWidgetFrame *>(option);
        if (frame && frame->lineWidth <= 0) {
            return;
        }
        Paint paint(painter, option);
        panel(painter, option->rect, m);
        return;
    }
    case PE_FrameTabBarBase: {
        // A line between a window's tabs and its page; a tab view's tabs
        // sit on their pane and need none.
        const auto *base = qstyleoption_cast<const QStyleOptionTabBarBase *>(option);
        if (base && base->documentMode) {
            painter->fillRect(base->rect, color(m.separator));
        }
        return;
    }
    case PE_IndicatorTabClose: {
        Paint paint(painter, option);
        // Only on the tab the pointer is over, as a Mac shows it.
        if (const auto *bar = widget ? qobject_cast<const QTabBar *>(widget->parentWidget()) : nullptr) {
            const int under = bar->underMouse() || widget->underMouse() ? bar->tabAt(bar->mapFromGlobal(QCursor::pos())) : -1;
            if (under < 0 || !bar->tabRect(under).contains(widget->geometry().center())) {
                return;
            }
        }
        const QPointF c = QRectF(option->rect).center();
        if (option->state & (State_Raised | State_Sunken)) {
            fill(painter, QRectF(c.x() - T::tabClose / 2, c.y() - T::tabClose / 2, T::tabClose, T::tabClose), 4, color(option->state & State_Sunken ? m.facePressed : m.face));
        }
        painter->setPen(QPen(color(m.textSecondary), 1.4, Qt::SolidLine, Qt::RoundCap));
        painter->drawLine(QPointF(c.x() - 3, c.y() - 3), QPointF(c.x() + 3, c.y() + 3));
        painter->drawLine(QPointF(c.x() + 3, c.y() - 3), QPointF(c.x() - 3, c.y() + 3));
        return;
    }
    case PE_IndicatorTabTearLeft:
    case PE_IndicatorTabTearRight:
        return;
    case PE_PanelItemViewRow: {
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (!item) {
            break;
        }
        painter->save();
        if (item->features & QStyleOptionViewItem::Alternate) {
            painter->fillRect(item->rect, item->palette.brush(enabled(item) ? QPalette::Active : QPalette::Disabled, QPalette::AlternateBase));
        }
        // A tree draws this under the arrows at the start of a row, where
        // the chosen row's highlight begins; everywhere else the highlight
        // is the item's own (PE_PanelItemViewItem).
        const auto *tree = qobject_cast<const QTreeView *>(widget);
        const QPoint middle = item->rect.center();
        if (tree && !item->rect.isEmpty() && tree->columnAt(middle.x()) == tree->header()->logicalIndex(0)) {
            const QModelIndex index = tree->indexAt(middle);
            const bool before = item->direction == Qt::RightToLeft ? item->rect.left() > tree->visualRect(index).right() : item->rect.right() < tree->visualRect(index).left();
            if (before && index.isValid() && tree->selectionModel() && tree->selectionModel()->isSelected(index)) {
                highlight(painter, item->rect, true, false, joined(tree, index), item->direction == Qt::RightToLeft, emphasized(item, widget) ? accent(item) : color(m.rowUnfocused));
            }
        }
        painter->restore();
        return;
    }
    case PE_PanelItemViewItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (!item) {
            break;
        }
        if (calendarOf(widget)) {
            // A day of the calendar: the chosen one on a disc.
            if (item->state & State_Selected) {
                Paint paint(painter, item);
                const QRectF r = item->rect;
                const qreal across = qMin<qreal>(qMin(r.width(), r.height()) - 2, T::rowHeight + 4);
                painter->setBrush(emphasized(item, widget) ? accent(item) : color(m.rowUnfocused));
                painter->drawEllipse(QRectF(r.center().x() + 0.5 - across / 2, r.center().y() + 0.5 - across / 2, across, across));
            }
            return;
        }
        painter->save();
        if (item->backgroundBrush.style() != Qt::NoBrush) {
            painter->setBrushOrigin(item->rect.topLeft());
            painter->fillRect(item->rect, item->backgroundBrush);
        }
        if (item->state & State_Selected) {
            // The same rule as the row's start (PE_PanelItemViewRow) and
            // CE_ItemViewItem: some views' own delegates (the file dialog's)
            // come straight here.
            const QColor fill = !enabled(item) ? item->palette.color(QPalette::Disabled, QPalette::Highlight)
                : emphasized(item, widget) ? item->palette.color(QPalette::Active, QPalette::Highlight) : color(m.rowUnfocused);
            const QStyleOptionViewItem::ViewItemPosition at = item->viewItemPosition;
            bool head = at == QStyleOptionViewItem::Beginning || at == QStyleOptionViewItem::OnlyOne;
            const bool tail = at == QStyleOptionViewItem::End || at == QStyleOptionViewItem::OnlyOne;
            const bool rightToLeft = item->direction == Qt::RightToLeft;
            if (const auto *tree = qobject_cast<const QTreeView *>(widget); tree && head && item->index.isValid()) {
                // Past a tree's arrows the highlight has begun already.
                const int column = tree->columnViewportPosition(item->index.column());
                head = rightToLeft ? item->rect.right() >= column + tree->columnWidth(item->index.column()) - 1 : item->rect.left() <= column;
            }
            highlight(painter, item->rect, head, tail, joined(widget, item->index), rightToLeft, fill);
        }
        painter->restore();
        return;
    }
    case PE_IndicatorBranch: {
        // No lines down a tree: an arrow where a row can open, and that is all.
        if (!(option->state & State_Children)) {
            return;
        }
        Paint paint(painter, option);
        const bool lit = (option->state & State_Selected) && emphasized(option, widget);
        const Qt::ArrowType arrow = option->state & State_Open ? Qt::DownArrow : option->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow;
        chevron(painter, option->rect, arrow, lit ? accentText(option) : color(m.textSecondary), 3.5);
        return;
    }
    case PE_IndicatorHeaderArrow: {
        // Up for the smallest first, as a Mac has it; Qt calls that one down.
        const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
        if (!header || header->sortIndicator == QStyleOptionHeader::None) {
            return;
        }
        Paint paint(painter, option);
        chevron(painter, option->rect, header->sortIndicator == QStyleOptionHeader::SortDown ? Qt::UpArrow : Qt::DownArrow, color(m.textSecondary), 3, 1.4);
        return;
    }
    case PE_PanelToolBar:
    case PE_PanelMenuBar:
    case PE_PanelStatusBar:
    case PE_FrameStatusBarItem:
    case PE_IndicatorToolBarHandle:
        // Bars are the window itself: no bevel, no edge, no grip.
        return;
    case PE_IndicatorToolBarSeparator:
        // Across a toolbar that runs along, and the other way about.
        hairline(painter, option->rect, !(option->state & State_Horizontal), color(m.separator), 5);
        return;
    case PE_IndicatorDockWidgetResizeHandle:
        hairline(painter, option->rect, option->rect.width() > option->rect.height(), color(m.separator));
        return;
    case PE_PanelMenu:
        menuPanel(painter, option->rect, m, widget, blurredMenuOpacity(baseStyle()));
        return;
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
        // The default button's title is in the accent's own text color, and
        // a button with a title has no picture beside it (KDE's apps give
        // theirs one whatever SH_DialogButtonBox_ButtonsHaveIcons says).
        // A button with a menu has its arrow already (CE_PushButtonBevel):
        // the title is set in the room beside it, and the style underneath
        // isn't told of the menu, or Breeze draws an arrow of its own.
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        const bool hasMenu = button && (button->features & QStyleOptionButton::HasMenu);
        if (button && (isDefaultButton(button) || titledWithIcon(button) || hasMenu)) {
            QStyleOptionButton copy(*button);
            if (isDefaultButton(button)) {
                copy.palette.setColor(QPalette::ButtonText, accentText(option));
            }
            if (titledWithIcon(button)) {
                copy.icon = QIcon();
            }
            if (hasMenu) {
                copy.features.setFlag(QStyleOptionButton::HasMenu, false);
                copy.rect = visualRect(button->direction, button->rect, button->rect.adjusted(0, 0, -int(T::arrowsWidth - T::pushPadding / 2), 0));
            }
            QProxyStyle::drawControl(element, &copy, painter, widget);
            return;
        }
        break;
    }
    case CE_ProgressBar: {
        // Put together here, piece by piece: Breeze draws its own track and
        // its own lit part without asking for ours.
        const auto *bar = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (!bar) {
            break;
        }
        QStyleOptionProgressBar part(*bar);
        part.rect = subElementRect(SE_ProgressBarGroove, bar, widget);
        drawControl(CE_ProgressBarGroove, &part, painter, widget);
        part.rect = subElementRect(SE_ProgressBarContents, bar, widget);
        drawControl(CE_ProgressBarContents, &part, painter, widget);
        if (bar->textVisible && bar->minimum != bar->maximum) {
            part.rect = subElementRect(SE_ProgressBarLabel, bar, widget);
            drawControl(CE_ProgressBarLabel, &part, painter, widget);
        }
        return;
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
        // It runs up and down the track while a widget is there to redraw;
        // drawn once, with none, it rests in the middle.
        const bool moving = busy && qobject_cast<const QProgressBar *>(widget);
        qreal from = moving ? (length - lit) * m_pulse->along() : busy ? (length - lit) / 2 : 0;
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
    case CE_MenuBarEmptyArea:
    case CE_ToolBar:
    case CE_SizeGrip:
        return;
    case CE_MenuBarItem: {
        // A title; a soft face behind it while its menu is open.
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) {
            break;
        }
        Paint paint(painter, option);
        if ((item->state & State_Selected) && enabled(item)) {
            fill(painter, QRectF(item->rect).adjusted(1, 2, -1, -2), T::menuRowRadius, color(item->state & State_Sunken ? m.facePressed : m.face));
        }
        if (item->text.isEmpty() && !item->icon.isNull()) {
            item->icon.paint(painter, item->rect, Qt::AlignCenter, enabled(item) ? QIcon::Normal : QIcon::Disabled);
            return;
        }
        painter->setFont(item->font);
        painter->setPen(item->palette.color(QPalette::Active, QPalette::WindowText));
        painter->drawText(item->rect, Qt::AlignCenter | Qt::TextSingleLine | Qt::TextHideMnemonic, item->text);
        return;
    }
    case CE_Splitter:
        hairline(painter, option->rect, option->rect.width() > option->rect.height(), color(m.separator));
        return;
    case CE_RubberBand: {
        // The rectangle dragged out over icons: a gray wash and its edge.
        Paint paint(painter, option);
        QColor wash = color(m.textSecondary);
        wash.setAlphaF(0.18);
        QColor edge = color(m.textSecondary);
        edge.setAlphaF(0.55);
        painter->setBrush(wash);
        painter->setPen(QPen(edge, 1));
        painter->drawRect(QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5));
        return;
    }
    case CE_TabBarTabShape: {
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (!tab) {
            break;
        }
        Paint paint(painter, option);
        const bool standing = upright(tab->shape);
        const bool chosen = tab->state & State_Selected;
        const bool first = tab->position == QStyleOptionTab::Beginning || tab->position == QStyleOptionTab::OnlyOneTab;
        const bool last = tab->position == QStyleOptionTab::End || tab->position == QStyleOptionTab::OnlyOneTab;
        const QRectF r = tab->rect;
        // A rule between two tabs when neither is the chosen one.
        const auto rule = [&](const QRectF &in) {
            if (chosen || last || tab->selectedPosition == QStyleOptionTab::NextIsSelected) {
                return;
            }
            const bool atLeft = !standing && tab->direction == Qt::RightToLeft;
            const QRectF edge = standing ? QRectF(in.left(), in.bottom() - 1, in.width(), 1) : QRectF(atLeft ? in.left() : in.right() - 1, in.top(), 1, in.height());
            hairline(painter, edge, standing, color(m.fieldBorder), standing ? in.width() / 4 : in.height() / 4);
        };
        if (tab->documentMode) {
            // A window's own tabs: titles in a row, the one in front on a face.
            const QRectF pill = r.adjusted(2, 3, -2, -3);
            if (chosen) {
                fill(painter, pill, T::tabRadius, color(m.facePressed));
            } else if ((tab->state & State_MouseOver) && enabled(tab)) {
                fill(painter, pill, T::tabRadius, color(m.face));
            }
            rule(r);
            if (ringed(tab)) {
                ring(painter, pill, T::tabRadius, tab);
            }
            return;
        }
        // A segmented control: each tab draws its own piece of the track,
        // and the chosen one a segment in the accent color over it (gray in
        // a window behind).
        bool head = first;
        bool tail = last;
        if (!standing && tab->direction == Qt::RightToLeft) {
            std::swap(head, tail);
        }
        const qreal a = head ? T::tabRadius : 0;
        const qreal b = tail ? T::tabRadius : 0;
        painter->fillPath(standing ? rounded(r, a, a, b, b) : rounded(r, a, b, b, a), color(m.face));
        if (chosen) {
            if (tab->state & State_Active) {
                fill(painter, r, T::tabRadius, accent(tab));
            } else {
                fill(painter, r, T::tabRadius, color(m.facePressed));
                fill(painter, r, T::tabRadius, color(m.face));
            }
        }
        rule(r);
        if (ringed(tab)) {
            ring(painter, r, T::tabRadius, tab);
        }
        return;
    }
    case CE_TabBarTabLabel: {
        // The chosen segment's title is in the accent's own text color.
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (tab && !tab->documentMode && (tab->state & State_Selected) && (tab->state & State_Active) && enabled(tab)) {
            QStyleOptionTab copy(*tab);
            copy.palette.setColor(QPalette::WindowText, accentText(tab));
            copy.palette.setColor(QPalette::ButtonText, accentText(tab));
            QProxyStyle::drawControl(element, &copy, painter, widget);
            return;
        }
        break;
    }
    case CE_HeaderSection: {
        // A table's header is part of the table: its ground, a hairline
        // under it, and a short rule between one title and the next.
        const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
        if (!header) {
            break;
        }
        const QRectF r = header->rect;
        painter->save();
        painter->fillRect(r, header->palette.color(QPalette::Base));
        if (header->state & State_Sunken) {
            painter->fillRect(r, color(m.face));
        }
        const QColor line = color(m.separator);
        if (header->orientation == Qt::Horizontal) {
            painter->fillRect(QRectF(r.left(), r.bottom() - 1, r.width(), 1), line);
            if (header->position != QStyleOptionHeader::End && header->position != QStyleOptionHeader::OnlyOneSection) {
                const qreal x = header->direction == Qt::RightToLeft ? r.left() : r.right() - 1;
                painter->fillRect(QRectF(x, r.top() + 6, 1, r.height() - 13), line);
            }
        } else {
            const qreal x = header->direction == Qt::RightToLeft ? r.left() : r.right() - 1;
            painter->fillRect(QRectF(x, r.top(), 1, r.height()), line);
        }
        painter->restore();
        return;
    }
    case CE_HeaderEmptyArea: {
        const QRectF r = option->rect;
        painter->fillRect(r, option->palette.color(QPalette::Base));
        if (option->state & State_Horizontal) {
            painter->fillRect(QRectF(r.left(), r.bottom() - 1, r.width(), 1), color(m.separator));
        } else {
            painter->fillRect(QRectF(option->direction == Qt::RightToLeft ? r.left() : r.right() - 1, r.top(), 1, r.height()), color(m.separator));
        }
        return;
    }
    case CE_HeaderLabel: {
        // Small and quiet; the column the table is sorted by, bold.
        const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
        if (!header) {
            break;
        }
        const bool sorted = header->sortIndicator != QStyleOptionHeader::None;
        QStyleOptionHeader copy(*header);
        copy.state.setFlag(State_On, false);
        copy.palette.setColor(QPalette::ButtonText, sorted ? header->palette.color(QPalette::Active, QPalette::Text) : color(m.textSecondary));
        painter->save();
        QFont font = smaller(painter->font());
        font.setBold(sorted);
        painter->setFont(font);
        copy.fontMetrics = QFontMetrics(font);
        QProxyStyle::drawControl(element, &copy, painter, widget);
        painter->restore();
        return;
    }
    case CE_ItemViewItem: {
        // Where the keyboard isn't, a chosen row is gray and its text stays
        // the color it was.
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (const QCalendarWidget *calendar = item ? calendarOf(widget) : nullptr) {
            // The calendar's days on its own sheet: the weekdays' names small
            // and quiet over them, today in the accent color, the chosen day
            // on its disc (PE_PanelItemViewItem).
            QStyleOptionViewItem copy(*item);
            copy.backgroundBrush = Qt::NoBrush;
            const auto ink = [&copy](QPalette::ColorRole role, const QColor &c) {
                for (const auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
                    copy.palette.setColor(group, role, c);
                }
            };
            if (calendarHeading(calendar, item->index)) {
                copy.state.setFlag(State_Selected, false);
                copy.font = smaller(item->font);
                copy.fontMetrics = QFontMetrics(copy.font);
                ink(QPalette::Text, color(m.textSecondary));
            } else if (!(item->state & State_Selected)) {
                if (calendarToday(calendar, item->index)) {
                    copy.font.setBold(true);
                    ink(QPalette::Text, accent(item));
                }
            } else if (!emphasized(item, widget)) {
                ink(QPalette::HighlightedText, item->palette.color(QPalette::Active, QPalette::Text));
            }
            QProxyStyle::drawControl(element, &copy, painter, widget);
            return;
        }
        if (item && (item->state & State_Selected) && !emphasized(item, widget)) {
            QStyleOptionViewItem copy(*item);
            for (const auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
                copy.palette.setColor(group, QPalette::Highlight, color(m.rowUnfocused));
                copy.palette.setColor(group, QPalette::HighlightedText, item->palette.color(group == QPalette::Disabled ? group : QPalette::Active, QPalette::Text));
            }
            QProxyStyle::drawControl(element, &copy, painter, widget);
            return;
        }
        break;
    }
    case CE_ShapedFrame:
        // The window round the list a combo to type in drops is a menu's panel.
        if (const QComboBox *combo = comboOf(widget); combo && combo->isEditable()) {
            menuPanel(painter, option->rect, m, widget, blurredMenuOpacity(baseStyle()));
            return;
        }
        break;
    case CE_ToolBoxTab: {
        // A tool box's tab is a heading that opens what is under it: an
        // arrow, down while it is open, and its title in bold.
        const auto *tab = qstyleoption_cast<const QStyleOptionToolBox *>(option);
        if (!tab) {
            break;
        }
        Paint paint(painter, option);
        const QRectF r = tab->rect;
        const bool rightToLeft = tab->direction == Qt::RightToLeft;
        if (tab->position != QStyleOptionToolBox::Beginning && tab->position != QStyleOptionToolBox::OnlyOneTab) {
            painter->fillRect(QRectF(r.left(), r.top(), r.width(), 1), color(m.separator));
        }
        const Qt::ArrowType arrow = tab->state & State_Selected ? Qt::DownArrow : rightToLeft ? Qt::LeftArrow : Qt::RightArrow;
        chevron(painter, QRectF(rightToLeft ? r.right() + 1 - 20 : r.left() + 4, r.top(), 16, r.height()), arrow, color(m.textSecondary), 3.5);
        QRectF title = r.adjusted(rightToLeft ? 6 : 24, 0, rightToLeft ? -24 : -6, 0);
        if (!tab->icon.isNull()) {
            const QRectF slot(rightToLeft ? title.right() - T::menuIcon : title.left(), r.center().y() + 0.5 - T::menuIcon / 2, T::menuIcon, T::menuIcon);
            tab->icon.paint(painter, slot.toRect(), Qt::AlignCenter, enabled(tab) ? QIcon::Normal : QIcon::Disabled);
            title.adjust(rightToLeft ? 0 : T::menuIcon + T::menuGap, 0, rightToLeft ? -(T::menuIcon + T::menuGap) : 0, 0);
        }
        QFont bold = painter->font();
        bold.setBold(true);
        painter->setFont(bold);
        painter->setPen(tab->palette.color(QPalette::Active, QPalette::WindowText));
        painter->drawText(title, int(Qt::AlignVCenter | visualAlignment(tab->direction, Qt::AlignLeft)) | Qt::TextSingleLine | Qt::TextHideMnemonic,
                          QFontMetrics(bold).elidedText(tab->text, Qt::ElideRight, int(title.width()), Qt::TextHideMnemonic));
        return;
    }
    case CE_DockWidgetTitle: {
        // A panel's name over it: small, bold and quiet, as the heading of
        // a Mac's inspector is.
        const auto *dock = qstyleoption_cast<const QStyleOptionDockWidget *>(option);
        if (!dock || dock->verticalTitleBar) {
            break;
        }
        Paint paint(painter, option);
        // (In from the edge as far as a list's rows start under it.)
        const QRect bar = subElementRect(SE_DockWidgetTitleBarText, option, widget);
        const QRect title = visualRect(dock->direction, bar, bar.adjusted(qMax(0, int(T::fieldPadding) - (bar.left() - option->rect.left())), 0, 0, 0));
        QFont font = smaller(painter->font());
        font.setBold(true);
        painter->setFont(font);
        painter->setPen(color(m.textSecondary));
        painter->drawText(title, int(Qt::AlignVCenter | visualAlignment(dock->direction, Qt::AlignLeft)) | Qt::TextSingleLine | Qt::TextHideMnemonic,
                          QFontMetrics(font).elidedText(dock->title, Qt::ElideRight, title.width(), Qt::TextHideMnemonic));
        return;
    }
    case CE_MenuItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) {
            break;
        }
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        // A pop-up button's list draws its rows edge to edge; a menu has
        // made them a margin already.
        const int margin = qobject_cast<const QComboBox *>(widget) ? T::menuMargin - 1 : 0;
        const QRectF r = QRectF(item->rect).adjusted(margin, 0, -margin, 0);
        const bool usable = enabled(item);
        const bool lit = (item->state & State_Selected) && usable;

        if (item->menuItemType == QStyleOptionMenuItem::Separator) {
            if (item->text.isEmpty()) {
                painter->setPen(QPen(color(m.menuRule), 1));
                const qreal y = qFloor(r.center().y()) + 0.5;
                painter->drawLine(QPointF(r.left() + T::menuRowPadding, y), QPointF(r.right() - T::menuRowPadding, y));
            } else {
                // A titled rule is a heading for the rows under it.
                QFont heading = smaller(item->font);
                heading.setBold(true);
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
            painter->drawText(QRectF(x, r.top(), right - x, r.height()), Qt::AlignVCenter | Qt::AlignRight | Qt::TextSingleLine, macShortcut(item->text.mid(tab + 1)));
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
        case SC_ComboBoxListBoxPopup:
            // A pop-up button's menu is wider than the button by its margin
            // and the column of ticks, so each choice's text opens right
            // over the button's own.
            if (combo && !combo->editable) {
                return visualRect(option->direction, r, r.adjusted(-(1 + T::menuMargin + T::menuIcon + T::menuGap), 0, 0, 0));
            }
            break;
        default:
            break;
        }
        break;
    }
    case CC_GroupBox: {
        // The heading over the box's top left corner, bold, its checkbox
        // before it; the box under them.
        const auto *group = qstyleoption_cast<const QStyleOptionGroupBox *>(option);
        if (!group) {
            break;
        }
        const bool checkable = group->subControls & SC_GroupBoxCheckBox;
        const bool titled = checkable || !group->text.isEmpty();
        const bool flat = group->features & QStyleOptionFrame::Flat;
        const int check = pixelMetric(PM_IndicatorWidth, option, widget);
        QFont bold = widget ? widget->font() : QApplication::font();
        bold.setBold(true);
        const QFontMetrics metrics(bold);
        const int line = titled ? qMax(metrics.height(), checkable ? check : 0) : 0;
        const QRect frame = r.adjusted(0, titled ? line + T::boxTitleGap : 0, 0, 0);
        const int start = flat ? 0 : T::boxTitle;
        switch (subControl) {
        case SC_GroupBoxFrame:
            return frame;
        case SC_GroupBoxContents:
            return flat ? frame.adjusted(0, T::boxPadding, 0, 0) : frame.adjusted(T::boxPadding, T::boxPadding, -T::boxPadding, -T::boxPadding);
        case SC_GroupBoxCheckBox:
            return visualRect(option->direction, r, QRect(r.left() + start - ringRoom, r.top() + (line - check) / 2, check, check));
        case SC_GroupBoxLabel: {
            const int x = r.left() + start + (checkable ? check - ringRoom + pixelMetric(PM_CheckBoxLabelSpacing, option, widget) : 0);
            const int width = qMin(metrics.horizontalAdvance(group->text) + 2, r.right() + 1 - x);
            return visualRect(option->direction, r, QRect(x, r.top(), width, line));
        }
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
    case CC_GroupBox: {
        const auto *group = qstyleoption_cast<const QStyleOptionGroupBox *>(option);
        if (!group) {
            break;
        }
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        if (group->subControls & SC_GroupBoxFrame) {
            const QRect frame = subControlRect(CC_GroupBox, option, SC_GroupBoxFrame, widget);
            if (group->features & QStyleOptionFrame::Flat) {
                // A flat one is a heading and a rule.
                painter->fillRect(QRect(frame.left(), frame.top(), frame.width(), 1), color(m.separator));
            } else {
                panel(painter, frame, m);
            }
        }
        if ((group->subControls & SC_GroupBoxLabel) && !group->text.isEmpty()) {
            const QRect label = subControlRect(CC_GroupBox, option, SC_GroupBoxLabel, widget);
            QFont bold = painter->font();
            bold.setBold(true);
            painter->setFont(bold);
            painter->setPen(group->textColor.isValid() ? group->textColor : group->palette.color(enabled(group) ? QPalette::Active : QPalette::Disabled, QPalette::WindowText));
            const QString title = QFontMetrics(bold).elidedText(group->text, Qt::ElideRight, label.width(), Qt::TextHideMnemonic);
            painter->drawText(label, int(Qt::AlignVCenter | visualAlignment(group->direction, Qt::AlignLeft)) | Qt::TextSingleLine | Qt::TextHideMnemonic, title);
        }
        painter->restore();
        if (group->subControls & SC_GroupBoxCheckBox) {
            QStyleOptionButton check;
            check.QStyleOption::operator=(*group);
            check.rect = subControlRect(CC_GroupBox, option, SC_GroupBoxCheckBox, widget);
            if (!(group->activeSubControls & SC_GroupBoxCheckBox)) {
                check.state.setFlag(State_Sunken, false);
            }
            drawPrimitive(PE_IndicatorCheckBox, &check, painter, widget);
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
    case CC_ToolButton: {
        // The small buttons of a dock widget's title and of the calendar:
        // a glyph or a word, on a face while the pointer is on it.
        const bool onDock = widget && widget->inherits("QDockWidgetTitleButton");
        const auto *button = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        if (!button || !(onDock || calendarButton(widget))) {
            break;
        }
        Paint paint(painter, option);
        const QRectF r = option->rect;
        if (option->state & (State_Sunken | State_On)) {
            fill(painter, r, T::toolRadius, color(m.facePressed));
        } else if ((option->state & State_MouseOver) && enabled(option)) {
            fill(painter, r, T::toolRadius, color(m.face));
        }
        const QString name = widget->objectName();
        if (onDock) {
            const QPointF c(r.center().x() + 0.5, r.center().y() + 0.5);
            painter->setBrush(Qt::NoBrush);
            painter->setPen(QPen(color(m.textSecondary), 1.3, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            if (name == QLatin1String("qt_dockwidget_closebutton")) {
                painter->drawLine(QPointF(c.x() - 3, c.y() - 3), QPointF(c.x() + 3, c.y() + 3));
                painter->drawLine(QPointF(c.x() + 3, c.y() - 3), QPointF(c.x() - 3, c.y() + 3));
            } else {
                // To lift it out of the window: one pane off another.
                painter->drawRoundedRect(QRectF(c.x() - 4.5, c.y() - 1.5, 6, 6), 1, 1);
                QPainterPath behind;
                behind.moveTo(c.x() - 1.5, c.y() - 3.5);
                behind.lineTo(c.x() - 1.5, c.y() - 4.5);
                behind.lineTo(c.x() + 4.5, c.y() - 4.5);
                behind.lineTo(c.x() + 4.5, c.y() + 1.5);
                behind.lineTo(c.x() + 3.5, c.y() + 1.5);
                painter->drawPath(behind);
            }
            return;
        }
        const QColor ink = option->palette.color(QPalette::Active, QPalette::Text);
        if (name == QLatin1String("qt_calendar_prevmonth") || name == QLatin1String("qt_calendar_nextmonth")) {
            const bool back = (name == QLatin1String("qt_calendar_prevmonth")) != (option->direction == Qt::RightToLeft);
            chevron(painter, r, back ? Qt::LeftArrow : Qt::RightArrow, ink, 3.5);
            return;
        }
        painter->setFont(button->font);
        painter->setPen(ink);
        painter->drawText(r, Qt::AlignCenter | Qt::TextSingleLine, button->text);
        return;
    }
    case CC_Dial: {
        // A round knob with a dot at where it is turned to; dots round it
        // where the dial shows its steps.
        const auto *dial = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!dial) {
            break;
        }
        Paint paint(painter, option);
        const QRectF r = option->rect;
        const bool stepped = (dial->subControls & SC_DialTickmarks) && dial->tickPosition != QSlider::NoTicks && dial->tickInterval > 0;
        const qreal across = qMin<qreal>(qMin(r.width(), r.height()) - (stepped ? 16 : 6), 64);
        if (across < 8) {
            return;
        }
        const QPointF c(r.center().x() + 0.5, r.center().y() + 0.5);
        const qreal reach = across / 2;
        const auto at = [&](int position, qreal length) {
            const qreal a = dialAngle(dial, position);
            return QPointF(c.x() + length * qCos(a), c.y() - length * qSin(a));
        };
        if (stepped && dial->maximum > dial->minimum) {
            painter->setBrush(color(m.textTertiary));
            // No more dots than can be told apart.
            int step = dial->tickInterval;
            while ((dial->maximum - dial->minimum) / step > 48) {
                step *= 2;
            }
            const int last = dial->dialWrapping ? dial->maximum - 1 : dial->maximum;
            for (int v = dial->minimum; v <= last; v += step) {
                painter->drawEllipse(at(v, reach + 5), 1, 1);
            }
        }
        painter->setBrush(QColor(0, 0, 0, 22));
        painter->drawEllipse(QPointF(c.x(), c.y() + 1), reach + 1, reach + 1);
        painter->setBrush(QColor(0, 0, 0, 30));
        painter->drawEllipse(QPointF(c.x(), c.y() + 0.5), reach + 0.5, reach + 0.5);
        painter->setBrush(color(m.knob));
        painter->drawEllipse(c, reach, reach);
        const qreal dot = qMax(1.5, across * 0.055);
        painter->setBrush(enabled(option) && (option->state & State_Sunken) ? accent(option) : color(mode(option->palette).textSecondary));
        painter->drawEllipse(at(dial->sliderPosition, reach - dot - qMax(3.0, across * 0.09)), dot, dot);
        if (ringed(option)) {
            ring(painter, QRectF(c.x() - reach, c.y() - reach, across, across), reach, option);
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
