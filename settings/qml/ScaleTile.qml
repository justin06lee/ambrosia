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
        // Lines of text, word by word, running off the edge.
        Repeater {
            model: [[5, 3, 6, 4], [7, 4, 3, 5], [3, 5, 4, 6], [6, 2, 5, 4], [4, 6, 3, 5], [5, 4, 6, 3], [3, 6, 5, 4], [6, 3, 4, 5]]
            Row {
                required property var modelData
                required property int index
                x: tile.unit
                y: tile.unit * (3.4 + 1.6 * index)
                spacing: tile.unit * 0.55
                Repeater {
                    model: parent.modelData
                    Rectangle {
                        required property int modelData
                        width: tile.unit * 0.62 * modelData
                        height: tile.unit * 0.5
                        radius: height / 2
                        color: Theme.color.label.secondary
                        opacity: 0.7
                    }
                }
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
