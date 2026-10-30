import QtQuick
import Ambrosia
import Settings

// A choice of look in Appearance: its picture, ringed in the accent when
// chosen, its name under it, bold when chosen.
Item {
    id: tile

    property string mode
    property string text
    property bool chosen: false
    signal clicked()

    width: 74
    height: 66
    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: chosen

    Rectangle {
        visible: tile.chosen
        x: 0.5
        y: -0.5
        width: 73
        height: 51
        radius: 9
        color: "transparent"
        border.width: 2.5
        border.color: Theme.accent.bg
    }
    Image {
        x: 3.5
        y: 3
        width: 67
        height: 44
        sourceSize: Qt.size(134, 88)
        source: "qrc:/qt/qml/Settings/art/appearance-" + (tile.mode === "auto" ? "light" : tile.mode) + ".svg"
    }
    // Auto's: light on the left, dark on the right.
    Item {
        visible: tile.mode === "auto"
        x: 37
        y: 3
        width: 33.5
        height: 44
        clip: true
        Image {
            x: -33.5
            width: 67
            height: 44
            sourceSize: Qt.size(134, 88)
            source: "qrc:/qt/qml/Settings/art/appearance-dark.svg"
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52
        text: tile.text
        style: Theme.text.caption
        font.weight: tile.chosen ? 600 : 400
        color: tile.chosen ? Theme.color.label.primary : Theme.color.label.secondary
    }
    MouseArea {
        anchors.fill: parent
        onClicked: tile.clicked()
    }
}
