import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import Settings

// The menu a pop-up button opens (Files' PopupMenu.qml): the current choice
// checked and over the control; the pointer or the arrow keys light a row
// in the accent color, and a click, Return or Space chooses it.
Controls.Popup {
    id: menu

    // [{text, value}]; an item without a value is a separator.
    property var items: []
    property var current
    property int lit: -1
    readonly property int currentIndex: items.findIndex(item => item.value === current)
    property real minimumWidth: 0
    signal chosen(var value)

    // Opens with the current row over the control (its text where the
    // control's is), as a Mac pop-up button's menu does.
    function openOver(control) {
        parent = control;
        x = -10;
        y = (control.height - Look.menuRow) / 2 - padding - Math.max(0, currentIndex) * Look.menuRow;
        minimumWidth = control.width;
        open();
    }
    // Opens under a control, as a pull-down (a ⋯ button's) does, moved
    // left as far as it must to stay in the window.
    function openUnder(control) {
        parent = control;
        x = Math.min(0, control.Window.width - Look.boxPadding - control.mapToItem(null, 0, 0).x - implicitWidth);
        y = control.height + 4;
        minimumWidth = 0;
        open();
    }
    function choose(i) {
        const item = items[i];
        if (!item || item.value === undefined || item.enabled === false)
            return;
        close();
        chosen(item.value);
    }
    function step(by) {
        let i = lit;
        for (let k = 0; k < items.length; ++k) {
            i = (i + by + items.length) % items.length;
            if (items[i].value !== undefined && items[i].enabled !== false) {
                lit = i;
                return;
            }
        }
    }

    padding: 5
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    // As wide as its widest row asks (rows take the menu's width, so the
    // column's own would be circular), or the control's.
    readonly property real widest: {
        let widest = 0;
        for (const row of rows.children)
            widest = Math.max(widest, row.implicitWidth ?? 0);
        return widest;
    }
    implicitWidth: Math.max(minimumWidth, widest + 2 * padding)
    onOpened: {
        lit = currentIndex;
        rows.forceActiveFocus();
    }

    background: Rectangle {
        radius: 8
        color: Look.menu
        border.width: 0.5
        border.color: Look.menuRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.5 : 0.2
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            blurMax: 24
        }
    }

    contentItem: Column {
        id: rows
        focus: true
        Keys.onUpPressed: menu.step(-1)
        Keys.onDownPressed: menu.step(1)
        Keys.onReturnPressed: menu.choose(menu.lit)
        Keys.onEnterPressed: menu.choose(menu.lit)
        Keys.onSpacePressed: menu.choose(menu.lit)

        Repeater {
            model: menu.items
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool separator: modelData.value === undefined
                readonly property bool lit: !separator && menu.lit === index
                readonly property bool usable: !separator && modelData.enabled !== false
                width: menu.availableWidth
                implicitWidth: label.implicitWidth + 34
                height: separator ? 11 : Look.menuRow

                Rectangle {
                    visible: row.separator
                    anchors.centerIn: parent
                    width: parent.width - 18
                    height: 1
                    color: Look.menuRule
                }
                Rectangle {
                    visible: row.lit
                    anchors.fill: parent
                    radius: 5
                    color: Theme.accent.bg
                }
                Glyph {
                    visible: !row.separator && menu.current === row.modelData.value
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 13
                    color: row.lit ? Theme.accent.fg : Theme.color.label.primary
                }
                Label {
                    id: label
                    visible: !row.separator
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text ?? ""
                    color: row.lit ? Theme.accent.fg : row.usable ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                HoverHandler {
                    onHoveredChanged: if (hovered && row.usable) menu.lit = row.index
                }
                TapHandler {
                    onTapped: menu.choose(row.index)
                }
            }
        }
    }
}
