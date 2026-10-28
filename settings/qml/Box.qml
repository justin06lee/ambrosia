import QtQuick
import Ambrosia
import Settings

// A group of rows on a rounded fill, each parted from the next by a
// hairline 10 in from either side.
Rectangle {
    id: box

    default property alias rows: column.data
    // The rows on show (a Repeater among them takes no room).
    readonly property var shown: Array.prototype.filter.call(column.visibleChildren, item => item.height > 0)

    width: Look.boxWidth
    height: column.implicitHeight
    radius: Look.boxRadius
    color: Look.box

    Column {
        id: column
        width: parent.width
        spacing: 1
    }
    Repeater {
        model: Math.max(0, box.shown.length - 1)
        Rectangle {
            required property int index
            x: Look.boxPadding
            y: box.shown[index].y + box.shown[index].height
            width: box.width - 2 * Look.boxPadding
            height: 1
            color: Look.hairline
        }
    }
}
