import QtQuick
import Ambrosia
import Settings

// The ⓘ at a row's end that opens its details (Battery Health, a user):
// 17 points, in secondary text.
Item {
    id: button

    signal clicked()

    width: 17
    height: 17
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Show Detail")

    Glyph {
        anchors.centerIn: parent
        name: "info"
        size: 18.7
        color: Theme.color.label.secondary
    }
    MouseArea {
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
