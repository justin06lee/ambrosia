// Draws every control the style covers into one picture, with no display:
//
//   ambrosia-style-gallery out.png [--dark] [--base]
//
// --base draws the style underneath (Breeze, or Fusion) instead, to compare.
// The palette is the tokens' own, so the picture is the same on a machine
// with no KDE color scheme installed.

#include "style.h"
#include "tokens.h"

#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QGridLayout>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMenu>
#include <QPainter>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QSlider>
#include <QSpinBox>
#include <QStyleFactory>
#include <QToolButton>

namespace T = Ambrosia::Tokens;

static QPalette palette(const T::Mode &m)
{
    const auto c = [](unsigned argb) { return QColor::fromRgba(argb); };
    QPalette p;
    p.setColor(QPalette::Window, c(m.window));
    p.setColor(QPalette::Base, c(m.base));
    p.setColor(QPalette::AlternateBase, c(m.window));
    p.setColor(QPalette::Button, c(m.window));
    for (const auto role : {QPalette::WindowText, QPalette::Text, QPalette::ButtonText, QPalette::ToolTipText}) {
        p.setColor(role, c(m.text));
        p.setColor(QPalette::Disabled, role, c(m.textTertiary));
    }
    p.setColor(QPalette::PlaceholderText, c(m.textTertiary));
    p.setColor(QPalette::ToolTipBase, c(m.menu));
    p.setColor(QPalette::Highlight, c(m.accent));
    p.setColor(QPalette::HighlightedText, c(m.accentText));
    return p;
}

static QLabel *heading(const QString &text)
{
    auto *label = new QLabel(text);
    QFont font = label->font();
    font.setBold(true);
    label->setFont(font);
    return label;
}

int main(int argc, char **argv)
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "offscreen");
    }
    if (qEnvironmentVariableIsEmpty("QT_SCALE_FACTOR")) {
        qputenv("QT_SCALE_FACTOR", "2");
    }
    QApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 2 || args.at(1).startsWith(QLatin1String("--"))) {
        qWarning("usage: ambrosia-style-gallery out.png [--dark] [--base]");
        return 2;
    }
    const bool dark = args.contains(QLatin1String("--dark"));
    auto *ours = new Ambrosia::Style;
    if (args.contains(QLatin1String("--base"))) {
        app.setStyle(QStyleFactory::create(ours->baseStyle()->name()));
    } else {
        app.setStyle(ours);
    }
    app.setPalette(palette(dark ? T::dark : T::light));

    QWidget window;
    auto *grid = new QGridLayout(&window);
    grid->setContentsMargins(24, 20, 24, 24);
    grid->setHorizontalSpacing(14);
    grid->setVerticalSpacing(12);
    int row = 0;
    const auto line = [&](const QString &title, std::initializer_list<QWidget *> widgets) {
        grid->addWidget(heading(title), row, 0);
        auto *cell = new QHBoxLayout;
        cell->setSpacing(12);
        for (QWidget *w : widgets) {
            cell->addWidget(w);
        }
        cell->addStretch();
        grid->addLayout(cell, row++, 1);
    };

    auto *plain = new QPushButton(QStringLiteral("Cancel"));
    plain->setAutoDefault(false);
    auto *primary = new QPushButton(QStringLiteral("Done"));
    primary->setDefault(true);
    auto *down = new QPushButton(QStringLiteral("Pressed"));
    down->setAutoDefault(false);
    down->setDown(true);
    auto *off = new QPushButton(QStringLiteral("Disabled"));
    off->setAutoDefault(false);
    off->setEnabled(false);
    auto *withMenu = new QPushButton(QStringLiteral("Options"));
    withMenu->setAutoDefault(false);
    withMenu->setMenu(new QMenu(withMenu));
    auto *focused = new QPushButton(QStringLiteral("Focused"));
    focused->setAutoDefault(false);
    line(QStringLiteral("Push buttons"), {plain, primary, down, off, withMenu, focused});

    auto *check = new QCheckBox(QStringLiteral("Off"));
    auto *checked = new QCheckBox(QStringLiteral("On"));
    checked->setChecked(true);
    auto *mixed = new QCheckBox(QStringLiteral("Mixed"));
    mixed->setTristate(true);
    mixed->setCheckState(Qt::PartiallyChecked);
    auto *checkedOff = new QCheckBox(QStringLiteral("Disabled"));
    checkedOff->setChecked(true);
    checkedOff->setEnabled(false);
    line(QStringLiteral("Checkboxes"), {check, checked, mixed, checkedOff});

    auto *radioA = new QRadioButton(QStringLiteral("One"));
    auto *radioB = new QRadioButton(QStringLiteral("The other"));
    radioB->setChecked(true);
    auto *radioOff = new QRadioButton(QStringLiteral("Disabled"));
    radioOff->setEnabled(false);
    line(QStringLiteral("Radio buttons"), {radioA, radioB, radioOff});

    auto *name = new QLineEdit(QStringLiteral("Justin's computer"));
    auto *empty = new QLineEdit;
    empty->setPlaceholderText(QStringLiteral("Search"));
    auto *typing = new QLineEdit(QStringLiteral("Typing here"));
    auto *locked = new QLineEdit(QStringLiteral("Disabled"));
    locked->setEnabled(false);
    line(QStringLiteral("Text fields"), {name, empty, typing, locked});

    auto *popup = new QComboBox;
    popup->addItems({QStringLiteral("Automatic"), QStringLiteral("Light"), QStringLiteral("Dark")});
    auto *editable = new QComboBox;
    editable->setEditable(true);
    editable->addItems({QStringLiteral("Inter"), QStringLiteral("JetBrains Mono")});
    auto *spin = new QSpinBox;
    spin->setRange(0, 100);
    spin->setValue(12);
    auto *popupOff = new QComboBox;
    popupOff->addItem(QStringLiteral("Disabled"));
    popupOff->setEnabled(false);
    line(QStringLiteral("Pop-ups, steppers"), {popup, editable, spin, popupOff});

    auto *slider = new QSlider(Qt::Horizontal);
    slider->setRange(0, 10);
    slider->setValue(4);
    slider->setFixedWidth(160);
    auto *ticked = new QSlider(Qt::Horizontal);
    ticked->setRange(0, 5);
    ticked->setValue(2);
    ticked->setTickPosition(QSlider::TicksBelow);
    ticked->setTickInterval(1);
    ticked->setFixedWidth(160);
    auto *standing = new QSlider(Qt::Vertical);
    standing->setRange(0, 10);
    standing->setValue(7);
    standing->setFixedHeight(64);
    line(QStringLiteral("Sliders"), {slider, ticked, standing});

    auto *progress = new QProgressBar;
    progress->setRange(0, 100);
    progress->setValue(62);
    progress->setTextVisible(false);
    progress->setFixedWidth(160);
    auto *busy = new QProgressBar;
    busy->setRange(0, 0);
    busy->setTextVisible(false);
    busy->setFixedWidth(160);
    line(QStringLiteral("Progress"), {progress, busy});

    auto *list = new QListWidget;
    for (int i = 1; i <= 30; ++i) {
        list->addItem(QStringLiteral("Row %1 of a list long and wide enough to scroll both ways").arg(i));
    }
    list->setFixedSize(300, 96);
    list->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOn);
    auto *tool = new QToolButton;
    tool->setText(QStringLiteral("Tool"));
    auto *toolOn = new QToolButton;
    toolOn->setText(QStringLiteral("Chosen"));
    toolOn->setCheckable(true);
    toolOn->setChecked(true);
    line(QStringLiteral("Scrolling, tools"), {list, tool, toolOn});

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel | QDialogButtonBox::Apply);
    line(QStringLiteral("A dialog's buttons"), {buttons});

    window.show();
    window.activateWindow();
    for (int i = 0; i < 50 && !window.isActiveWindow(); ++i) {
        app.processEvents(QEventLoop::AllEvents, 20);
    }
    // As if the focus had come by the keyboard, which is when a ring shows
    // (Qt only believes a Tab while it is handling the key itself).
    focused->setFocus(Qt::ShortcutFocusReason);
    app.processEvents();
    const QPixmap controls = window.grab();
    // A second picture of the field with the focus, which the button had.
    typing->setFocus(Qt::ShortcutFocusReason);
    app.processEvents();
    const QPixmap typingNow = typing->grab();

    QMenu menu;
    menu.addAction(QStringLiteral("New Window"))->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_N));
    QAction *lit = menu.addAction(QStringLiteral("Open…"));
    lit->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_O));
    QMenu *recent = menu.addMenu(QStringLiteral("Open Recent"));
    recent->addAction(QStringLiteral("DESIGN.md"));
    menu.addSeparator();
    QAction *ticked1 = menu.addAction(QStringLiteral("Show Sidebar"));
    ticked1->setCheckable(true);
    ticked1->setChecked(true);
    QAction *unticked = menu.addAction(QStringLiteral("Show Path Bar"));
    unticked->setCheckable(true);
    menu.addSeparator();
    menu.addAction(QStringLiteral("Move to Trash"))->setEnabled(false);
    menu.addAction(QStringLiteral("Quit"))->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_Q));
    menu.ensurePolished();
    menu.resize(menu.sizeHint());
    menu.setActiveAction(lit);
    const QPixmap menuShot = menu.grab();

    // Everything below is in the window's own units; the picture has
    // `ratio` pixels to each.
    const qreal ratio = controls.devicePixelRatio();
    const int gap = 24;
    const QSize size(window.width() + menu.width() + 2 * gap, qMax(window.height(), menu.height() + 2 * gap));
    QImage sheet(size * ratio, QImage::Format_ARGB32_Premultiplied);
    sheet.setDevicePixelRatio(ratio);
    sheet.fill(app.palette().color(QPalette::Window));
    QPainter painter(&sheet);
    painter.drawPixmap(0, 0, controls);
    // The field with the focus goes where the same field is in the window.
    painter.drawPixmap(typing->mapTo(&window, QPoint(0, 0)), typingNow);
    painter.drawPixmap(window.width() + gap, gap, menuShot);
    painter.end();
    if (!sheet.save(args.at(1))) {
        qWarning("couldn't write %s", qPrintable(args.at(1)));
        return 1;
    }
    return 0;
}
