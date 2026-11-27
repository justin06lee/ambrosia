import QtQuick
import Ambrosia
import ActivityMonitor

// A pane of the panel: names down the left, their numbers down the right,
// a rule under each of the first `ruled`. A row may color its number (the
// graph's blue and red).
Item {
    id: pane

    // [{ label, value, color }]
    property var rows: []
    property int ruled: 0
    // The first row's middle, and from one row to the next.
    property real first: 14.75
    property real pitch: Look.statRow
    property real leftPad: 12.5
    property real rightPad: 10

    Repeater {
        model: pane.rows
        Item {
            id: row
            required property var modelData
            required property int index
            y: pane.first + index * pane.pitch - height / 2
            width: pane.width
            height: pane.pitch

            Text {
                x: pane.leftPad
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                font.family: Theme.uiFont
                font.pixelSize: Look.textSize
                color: Look.statText
                renderType: Text.NativeRendering
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: pane.rightPad
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.value
                font.family: Theme.uiFont
                font.pixelSize: Look.textSize
                font.features: { "tnum": 1 }
                color: row.modelData.color ?? Look.statText
                renderType: Text.NativeRendering
            }
        }
    }
    Repeater {
        model: pane.ruled
        Rectangle {
            required property int index
            x: pane.leftPad
            y: 24 + index * pane.pitch
            width: pane.width - pane.leftPad - pane.rightPad
            height: 1
            color: Look.boxRule
        }
    }
}
