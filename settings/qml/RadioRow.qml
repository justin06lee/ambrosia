import QtQuick
import Ambrosia
import Settings

// A radio button and its label, as Appearance's scroll bar choices: 16 round,
// filled in the accent with a white dot when chosen, the label 21 from its left.
Item {
    id: row

    property string text
    property bool checked: false
    signal clicked()

    implicitWidth: 21 + label.implicitWidth
    implicitHeight: 22.5
    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: checked

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: row.checked ? Theme.accent.bg : Look.face
        Rectangle {
            visible: row.checked
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Theme.accent.fg
        }
    }
    Label {
        id: label
        x: 21
        anchors.verticalCenter: parent.verticalCenter
        text: row.text
    }
    MouseArea {
        anchors.fill: parent
        onClicked: row.clicked()
    }
}
