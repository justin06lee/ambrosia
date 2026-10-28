import QtQuick
import Ambrosia
import Settings

// A pop-up button as macOS 26's System Settings draws it: the choice in
// plain text, then the up-down chevrons on a small capsule; a click opens
// its menu with the choice over the text.
Item {
    id: button

    property var items: [] // [{text, value}], as PopupMenu takes them
    property var current
    signal chosen(var value)

    readonly property string text: items.find(item => item.value === current)?.text ?? ""

    implicitWidth: label.implicitWidth + Look.popupTextGap + Look.popupChevronWidth + Look.popupEnd
    implicitHeight: Look.popupHeight
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.ComboBox
    Accessible.name: text

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: button.text
    }
    Rectangle {
        x: parent.width - Look.popupEnd - width
        anchors.verticalCenter: parent.verticalCenter
        width: Look.popupChevronWidth
        height: Look.popupChevronHeight
        radius: width / 2
        color: Look.face
        Glyph {
            anchors.centerIn: parent
            name: "chevronUpDown"
            size: 11
            color: Theme.color.label.primary
        }
    }
    TapHandler {
        onTapped: {
            menu.openOver(button);
            menu.x = label.x - 25; // the menu's text over the button's
        }
    }
    PopupMenu {
        id: menu
        items: button.items
        current: button.current
        onChosen: (value) => button.chosen(value)
    }
}
