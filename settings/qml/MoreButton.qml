import QtQuick
import Ambrosia
import Settings

// A pull-down's button, as Network's foot has it: ⋯ and a small chevron on a
// push button's face, 61.5 wide.
Rectangle {
    id: button

    signal clicked()

    implicitWidth: 61.5
    implicitHeight: Look.popupHeight
    radius: Look.pushRadius
    color: tap.pressed ? Look.facePressed : Look.face
    activeFocusOnTab: true
    Accessible.role: Accessible.ButtonMenu
    Accessible.name: qsTr("More")
    Keys.onSpacePressed: clicked()

    Label {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "⋯"
    }
    Glyph {
        x: parent.width - 8 - width
        anchors.verticalCenter: parent.verticalCenter
        name: "chevronDown"
        size: 10
        color: Theme.color.label.primary
    }
    MouseArea {
        id: tap
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
