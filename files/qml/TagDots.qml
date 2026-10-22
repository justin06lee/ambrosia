import QtQuick
import Ambrosia

// An item's tags as Finder draws them by its name: 10-point dots, the first
// on the right and each further one 5 points to the left and in front, cut
// from the one behind by a ring of the background's color.
Item {
    id: dots

    property var colors: []
    property color ring

    implicitWidth: colors.length > 0 ? Finder.tagDot + (colors.length - 1) * Finder.tagStep : 0
    implicitHeight: Finder.tagDot
    width: implicitWidth
    height: implicitHeight

    Repeater {
        model: dots.colors
        Rectangle {
            required property int index
            required property string modelData
            readonly property int ringWidth: index > 0 ? 1 : 0
            x: (dots.colors.length - 1 - index) * Finder.tagStep - ringWidth
            y: -ringWidth
            z: index
            width: Finder.tagDot + 2 * ringWidth
            height: width
            radius: width / 2
            color: ringWidth > 0 ? dots.ring : "transparent"
            Rectangle {
                anchors.centerIn: parent
                width: Finder.tagDot
                height: width
                radius: width / 2
                color: Finder.tagFill[parent.modelData] ?? Finder.tagFill.gray
                border.width: 1
                border.color: Finder.tagRim[parent.modelData] ?? Finder.tagRim.gray
            }
        }
    }
}
