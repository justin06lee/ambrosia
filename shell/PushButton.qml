import QtQuick
import Ambrosia

// A push button: the default one is filled with the accent.
Item {
    id: button

    property string text
    property bool primary
    signal clicked

    implicitWidth: Math.max(label.implicitWidth + 2 * Theme.space.s4, 64)
    implicitHeight: Theme.size.control.regular

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.control
        color: button.primary ? (area.pressed ? Theme.accent.pressed : Theme.accent.bg)
            : (area.pressed ? Theme.color.fill.primary : Theme.color.fill.secondary)
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        style: Theme.text.body
        color: button.primary ? Theme.accent.fg : Theme.color.label.primary
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
