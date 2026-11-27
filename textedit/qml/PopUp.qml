import QtQuick
import Ambrosia
import TextEditor

// A pop-up button of the format bar: what is chosen (as words or a glyph)
// and its chevrons on a rounded face; a press drops its menu.
Rectangle {
    id: button

    property string text
    property string glyph
    // "chevronUpDown" for a choice among many, "chevronDown" for a menu.
    property string chevron: "chevronUpDown"
    property var items: []
    property var current
    property real menuWidth: 0
    property real menuHeight: 420
    signal chosen(var value)

    height: Look.control
    radius: Look.controlRadius
    color: area.pressed || menu.visible ? Look.controlPressed : Look.controlFill

    Glyph {
        visible: button.glyph !== ""
        x: 7
        anchors.verticalCenter: parent.verticalCenter
        name: button.glyph
        size: 15
        color: Look.glyph
    }
    Label {
        visible: button.glyph === ""
        x: 7
        width: parent.width - 7 - 19
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: button.text
        // Smaller than the menus' type: "Helvetica" is 46 wide in a Mac's.
        font.pixelSize: 11
        font.weight: 500
        color: Look.controlText
    }
    Glyph {
        x: parent.width - 17
        anchors.verticalCenter: parent.verticalCenter
        name: button.chevron
        size: 12
        color: Look.glyph
    }
    MouseArea {
        id: area
        anchors.fill: parent
        onPressed: menu.visible ? menu.close() : menu.openUnder(button)
    }
    PopupMenu {
        id: menu
        items: button.items
        current: button.current
        minimumWidth: Math.max(button.width, button.menuWidth)
        maximumHeight: button.menuHeight
        onChosen: (value) => button.chosen(value)
    }
}
