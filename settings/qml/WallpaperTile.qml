import QtQuick
import Ambrosia
import Settings

// A wallpaper to choose: its picture, 108.5 × 72, under a caption if it has
// one; chosen, it draws in from a rim. A color's is a circle.
Item {
    id: tile

    property url source
    property url second
    property color color: "black"
    property string name
    property bool caption: false
    property bool dynamic: false // the half-circle badge of one that follows the appearance
    property bool round: false
    property bool chosen: false
    signal clicked()

    readonly property real pictureHeight: round ? 48.5 : 72

    width: round ? 48.5 : 108.5
    height: caption ? 100 : pictureHeight
    Accessible.role: Accessible.RadioButton
    Accessible.name: name
    Accessible.checked: chosen

    Rectangle {
        visible: tile.chosen
        x: -0.5
        y: -0.5
        width: parent.width + 1
        height: tile.pictureHeight + 1
        radius: tile.round ? width / 2 : Look.tileRadius + 1
        color: "transparent"
        border.width: 2
        border.color: Look.tileRing
    }
    WallpaperPicture {
        readonly property real inset: tile.chosen ? 2.5 : 0
        x: inset
        y: inset
        width: tile.width - 2 * inset
        height: tile.pictureHeight - 2 * inset
        radius: tile.round ? width / 2 : Look.tileRadius - inset / 2.5 * 2
        source: tile.source
        second: tile.second
        color: tile.color
    }
    Rectangle {
        visible: tile.dynamic
        x: 6
        y: tile.pictureHeight - 18
        width: 12
        height: 12
        radius: 6
        color: "#d9ffffff"
        Glyph {
            anchors.centerIn: parent
            size: 10
            name: "appearance"
            color: "#404040"
        }
    }
    Label {
        visible: tile.caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: 74
        text: tile.name
        style: Theme.text.footnote
    }
    MouseArea {
        anchors.fill: parent
        onClicked: tile.clicked()
    }
}
