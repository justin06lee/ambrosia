import QtQuick
import Ambrosia
import ActivityMonitor

// The toolbar's search field (Preview's): a capsule with the magnifier and
// "Search". The table keeps the processes whose names hold what's typed, as
// it is typed; Escape clears it and gives the keys back to the table.
// Where the toolbar has no room it is a round button until it is used.
Rectangle {
    id: field

    required property Window window
    property alias text: input.text
    property string note: ""
    // No room for the field: a round button that opens it.
    property bool collapsed: false
    readonly property bool editing: input.activeFocus
    signal next(int direction)
    signal dismissed()

    function focusField() {
        input.forceActiveFocus();
        input.selectAll();
    }

    height: Look.control
    radius: height / 2
    color: Look.capsule
    border.width: 0.5
    border.color: Look.capsuleRim

    // The focus ring.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 3
        border.color: Theme.accent.highlight
        visible: input.activeFocus
    }
    Glyph {
        x: field.collapsed ? (field.width - width) / 2 : 11
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 17
        color: !field.enabled ? Look.glyphOff : field.window.looksActive ? Look.subtitle : Look.glyphInactive
    }
    TextInput {
        id: input
        visible: !field.collapsed
        x: 36
        width: parent.width - x - 12 - (count.visible ? count.width + 8 : 0) - (clear.visible ? 22 : 0)
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.uiFont
        font.pixelSize: Theme.text.body.size
        font.letterSpacing: Theme.text.body.tracking
        color: Theme.color.label.primary
        selectionColor: Theme.accent.highlight
        selectedTextColor: Theme.color.label.primary
        renderType: Text.NativeRendering
        clip: true
        selectByMouse: true
        Keys.onEscapePressed: {
            text = "";
            field.dismissed();
        }
        Keys.onReturnPressed: (event) => field.next(event.modifiers & Qt.ShiftModifier ? -1 : 1)
        Keys.onEnterPressed: (event) => field.next(event.modifiers & Qt.ShiftModifier ? -1 : 1)
    }
    Label {
        x: input.x
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === "" && !field.collapsed
        text: "Search"
        font.weight: 500
        color: field.window.looksActive ? Look.subtitle : Look.glyphInactive
    }
    Label {
        id: count
        visible: field.note !== "" && input.text !== ""
        x: parent.width - width - (clear.visible ? 30 : 12)
        anchors.verticalCenter: parent.verticalCenter
        text: field.note
        style: Theme.text.footnote
        color: Look.subtitle
    }
    MouseArea {
        anchors.fill: parent
        visible: field.collapsed
        onClicked: field.focusField()
    }
    // Clears what's typed.
    Rectangle {
        id: clear
        visible: input.text !== ""
        x: parent.width - 11 - width
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Look.subtitle
        Glyph {
            anchors.centerIn: parent
            name: "cross"
            size: 10
            color: Look.capsule
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }
}
