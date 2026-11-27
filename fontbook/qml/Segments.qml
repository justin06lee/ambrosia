import QtQuick
import Ambrosia
import FontBook

// The views' switch on the toolbar: a capsule of glyphs, the chosen one on
// a lighter face 32 by 28, a rule between two that aren't chosen.
Capsule {
    id: segments

    required property Window window
    // [{ key, glyph }]
    property var items: []
    property string current
    signal chosen(string key)

    width: items.length * Look.segment + 9

    Item {
        width: segments.width
        height: Look.control

        Repeater {
            model: segments.items

            Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool on: segments.current === modelData.key
                x: 4.5 + index * Look.segment
                width: Look.segment
                height: Look.control

                Rectangle {
                    visible: segment.on || area.pressed
                    anchors.centerIn: parent
                    width: Look.segmentFace
                    height: 28
                    radius: 14
                    color: segment.on ? Look.segmentChosen : Look.pressed
                }
                Rectangle {
                    // Between this one and the next, neither chosen.
                    visible: segment.index < segments.items.length - 1 && !segment.on && segments.current !== segments.items[segment.index + 1].key
                    x: parent.width - 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 16
                    color: Look.capsuleDivider
                }
                Glyph {
                    anchors.centerIn: parent
                    name: segment.modelData.glyph
                    size: 18
                    color: segments.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    onClicked: segments.chosen(segment.modelData.key)
                }
            }
        }
    }
}
