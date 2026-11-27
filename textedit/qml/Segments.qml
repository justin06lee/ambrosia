import QtQuick
import Ambrosia
import TextEditor

// A row of joined buttons on one rounded face, as the format bar's B I U S
// and its four alignments: a short rule between two that aren't chosen, a
// lighter face under each that is. `segments` are { key, on } with either
// a `glyph` (glyphs.js) or a `letter` and how it is set (bold, italic,
// underline, strike).
Rectangle {
    id: group

    property var segments: []
    readonly property real each: width / Math.max(1, segments.length)
    signal tapped(string key)

    height: Look.control
    radius: Look.controlRadius
    color: Look.controlFill

    Repeater {
        model: group.segments
        Item {
            id: segment
            required property var modelData
            required property int index
            readonly property bool first: index === 0
            readonly property bool last: index === group.segments.length - 1
            x: index * group.each
            width: group.each
            height: group.height

            Rectangle {
                anchors.fill: parent
                visible: segment.modelData.on || area.pressed
                color: segment.modelData.on ? Look.controlChosen : Look.controlPressed
                topLeftRadius: segment.first ? group.radius : 0
                bottomLeftRadius: segment.first ? group.radius : 0
                topRightRadius: segment.last ? group.radius : 0
                bottomRightRadius: segment.last ? group.radius : 0
            }
            // The rule before it, unless a chosen face is on either side.
            Rectangle {
                visible: !segment.first && !segment.modelData.on && !group.segments[segment.index - 1].on
                x: -0.5
                y: 5
                width: 1
                height: parent.height - 10
                color: Look.glyphDim
            }
            Glyph {
                visible: !!segment.modelData.glyph
                anchors.centerIn: parent
                name: segment.modelData.glyph ?? ""
                size: 15
                color: Look.glyph
            }
            Text {
                visible: !!segment.modelData.letter
                anchors.centerIn: parent
                text: segment.modelData.letter ?? ""
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: segment.modelData.bold ? 700 : 400
                font.italic: !!segment.modelData.italic
                font.underline: !!segment.modelData.underline
                font.strikeout: !!segment.modelData.strike
                color: Look.glyph
                renderType: Text.NativeRendering
            }
            MouseArea {
                id: area
                anchors.fill: parent
                onClicked: group.tapped(segment.modelData.key)
            }
        }
    }
}
