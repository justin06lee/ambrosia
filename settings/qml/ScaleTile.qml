import QtQuick
import Ambrosia
import Settings

// One of Displays' scale choices: the top corner of a window as it would
// look at that scale (its lights, and lines of text running off its edge),
// in a 45 point tile; the chosen one ringed in the accent. Our own drawing.
Item {
    id: tile

    property real factor: 1
    property bool chosen: false
    // The size of things at 100%, in the tile's points.
    readonly property real unit: 3.6 * factor

    width: 50
    height: 50

    Rectangle {
        id: face
        anchors.fill: parent
        anchors.margins: 2.5
        radius: 6
        color: Look.tileWindow
        border.width: 0.5
        border.color: Look.hairline
        clip: true

        Row {
            x: tile.unit
            y: tile.unit
            spacing: tile.unit * 0.55
            Repeater {
                model: [Theme.windowControls.close, Theme.windowControls.minimize, Theme.windowControls.zoom]
                Rectangle {
                    required property color modelData
                    width: tile.unit
                    height: tile.unit
                    radius: width / 2
                    color: modelData
                }
            }
        }
        // Lines of text, as long as a line runs.
        Repeater {
            model: [1, 0.8, 0.95, 0.7, 0.9, 0.85, 1, 0.6]
            Rectangle {
                required property real modelData
                required property int index
                x: tile.unit
                y: tile.unit * (3.3 + 1.75 * index)
                width: face.width * 1.4 * modelData
                height: tile.unit * 0.7
                radius: height / 2
                color: Theme.color.label.tertiary
            }
        }
    }
    Rectangle {
        visible: tile.chosen
        anchors.fill: parent
        anchors.margins: 0.5
        radius: 8
        color: "transparent"
        border.width: 2.5
        border.color: Theme.accent.bg
    }
}
