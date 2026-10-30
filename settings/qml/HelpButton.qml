import QtQuick
import Ambrosia
import Settings

// The help button at a page's foot: a 24 point circle with a question mark,
// at the right, 20 below the last box.
Rectangle {
    id: button

    signal clicked()

    width: Look.help
    height: Look.help
    radius: width / 2
    color: Look.helpFace
    Accessible.role: Accessible.Button
    Accessible.name: "Help"

    Glyph {
        anchors.centerIn: parent
        name: "help"
        size: 17
        color: Theme.color.label.primary
    }
    MouseArea { anchors.fill: parent; onClicked: button.clicked() }
}
