import QtQuick
import Ambrosia

// A pop-up button, as in the search's criteria row: the current choice and
// the up-down chevron on a rounded fill; a click opens its menu over it.
Rectangle {
    id: button

    property var items: [] // [{text, value}], as PopupMenu takes them
    property var current
    signal chosen(var value)

    readonly property string text: items.find(item => item.value === current)?.text ?? ""

    implicitWidth: label.implicitWidth + 44
    height: Finder.popupButton
    radius: 5
    color: Finder.popupFill

    Label {
        id: label
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: button.text
    }
    Glyph {
        x: parent.width - 12 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: "chevronUpDown"
        size: 12
        color: Theme.color.label.primary
    }
    TapHandler {
        onTapped: menu.openOver(button)
    }
    PopupMenu {
        id: menu
        items: button.items
        current: button.current
        onChosen: (value) => button.chosen(value)
    }
}
