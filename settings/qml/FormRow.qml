import QtQuick
import Ambrosia
import Settings

// A row of a box: its label (and a line of description under it) on the
// left, its control or value on the right, 10 in from either side. 36 tall
// for text or a switch, 40 for a 24 point control, more for more.
Item {
    id: row

    property string label
    property string description
    // A value shown on the right, in secondary text, when there's no control.
    property string value
    default property alias control: slot.data

    width: parent ? parent.width : Look.boxWidth
    implicitHeight: Math.max(Look.textRow, labels.implicitHeight + 2 * Look.boxPadding, slot.height + 16)

    Column {
        id: labels
        x: Look.boxPadding
        width: slot.x - x - 12
        anchors.verticalCenter: parent.verticalCenter
        Label {
            width: parent.width
            text: row.label
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            style: Theme.text.caption
            wrapMode: Text.WordWrap
            color: Theme.color.label.secondary
        }
    }
    Item {
        id: slot
        x: row.width - Look.boxPadding - width
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Label {
        visible: row.value !== ""
        x: row.width - Look.boxPadding - width
        anchors.verticalCenter: parent.verticalCenter
        text: row.value
        color: Theme.color.label.secondary
    }
}
