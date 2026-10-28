import QtQuick
import Ambrosia
import Settings

// The sidebar's search field: a capsule with the magnifier and "Search";
// what's typed filters the panes, Return opens the first, Escape clears it.
Rectangle {
    id: field

    property alias text: input.text
    signal accepted()
    function focusField() {
        input.forceActiveFocus();
        input.selectAll();
    }

    width: Look.searchWidth
    height: Look.searchHeight
    radius: height / 2
    color: Look.search

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
        x: Look.searchGlyphX - Look.searchX
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 15
        color: Theme.color.label.secondary
    }
    TextInput {
        id: input
        x: Look.searchTextX - Look.searchX
        width: parent.width - x - (clear.visible ? 26 : 10)
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
        Keys.onEscapePressed: text = ""
        onAccepted: field.accepted()
    }
    Label {
        x: input.x
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === ""
        text: "Search"
        color: Theme.color.label.secondary
    }
    // Clears what's typed.
    Rectangle {
        id: clear
        visible: input.text !== ""
        x: parent.width - 7 - width
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Theme.color.label.tertiary
        Glyph {
            anchors.centerIn: parent
            name: "cross"
            size: 10
            color: Look.search
        }
        TapHandler { onTapped: input.text = "" }
    }
}
