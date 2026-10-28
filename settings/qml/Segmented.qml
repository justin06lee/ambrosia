import QtQuick
import Ambrosia
import Settings

// A segmented control across its box, 24 tall with 6 corners (Sound's
// Output | Input): equal segments, the one chosen filled in the accent color.
Rectangle {
    id: control

    property var items: [] // [{text, value}]
    property var current
    signal chosen(var value)

    implicitWidth: Look.boxWidth - 2 * Look.boxPadding
    implicitHeight: Look.segmented
    radius: Look.segmentedRadius
    color: Look.face
    Accessible.role: Accessible.PageTabList

    Row {
        anchors.fill: parent
        Repeater {
            model: control.items
            Item {
                id: segment
                required property var modelData
                readonly property bool chosen: control.current === modelData.value
                width: control.width / control.items.length
                height: control.height
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text

                Rectangle {
                    anchors.fill: parent
                    radius: Look.segmentedRadius
                    visible: segment.chosen
                    color: Theme.accent.bg
                }
                Label {
                    anchors.centerIn: parent
                    text: segment.modelData.text
                    color: segment.chosen ? Theme.accent.fg : Theme.color.label.primary
                }
                TapHandler { onTapped: control.chosen(segment.modelData.value) }
            }
        }
    }
}
