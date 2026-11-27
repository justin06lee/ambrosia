import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import TextEditor

// A menu that drops from a control inside the window (Preview's and Files'
// PopupMenu.qml), scrolling when it is longer than the window has room
// for, as the list of fonts is: the current choice checked; the pointer or
// the arrow keys light a row in the accent color, and a click, Return or
// Space chooses it.
Controls.Popup {
    id: menu

    // [{text, value}]; an item without a value is a separator.
    property var items: []
    property var current
    property int lit: -1
    readonly property int currentIndex: items.findIndex(item => item.value === current)
    property real minimumWidth: 0
    property real maximumHeight: 420
    signal chosen(var value)

    // Opens under the control, a little below it.
    function openUnder(control) {
        parent = control;
        x = 0;
        y = control.height + 4;
        open();
    }
    function openAt(item, atX, atY) {
        parent = item;
        x = atX;
        y = atY;
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
                rows.positionViewAtIndex(i, ListView.Contain);
                return;
            }
        }
    }

    padding: 5
    margins: 6
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    // As wide as its longest row: the check mark's room, the text, a margin.
    readonly property real widest: Math.max(0, ...items.map(item => metrics.advanceWidth(item.text ?? "")))
    implicitWidth: Math.max(minimumWidth, Math.ceil(widest) + 40 + 2 * padding)
    implicitHeight: Math.min(rows.contentHeight, maximumHeight) + 2 * padding
    FontMetrics {
        id: metrics
        font.family: Theme.uiFont
        font.pixelSize: Theme.text.body.size
        font.weight: Theme.text.body.weight
        font.letterSpacing: Theme.text.body.tracking
    }
    onOpened: {
        lit = currentIndex;
        if (currentIndex >= 0)
            rows.positionViewAtIndex(currentIndex, ListView.Center);
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

    contentItem: ListView {
        id: rows
        focus: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: menu.items
        Keys.onUpPressed: menu.step(-1)
        Keys.onDownPressed: menu.step(1)
        Keys.onReturnPressed: menu.choose(menu.lit)
        Keys.onEnterPressed: menu.choose(menu.lit)
        Keys.onSpacePressed: menu.choose(menu.lit)
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool separator: modelData.value === undefined
            readonly property bool lit: !separator && menu.lit === index
            readonly property bool usable: !separator && modelData.enabled !== false
            width: ListView.view.width
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
                visible: !row.separator
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text ?? ""
                color: row.lit ? Theme.accent.fg : row.usable ? Theme.color.label.primary : Theme.color.label.tertiary
            }
            HoverHandler {
                onHoveredChanged: if (hovered && row.usable) menu.lit = row.index
            }
            // Not a TapHandler: a tap would reach what lies under the
            // menu too (Files' ContextMenu.qml).
            MouseArea {
                anchors.fill: parent
                onClicked: menu.choose(row.index)
            }
        }
    }
}
