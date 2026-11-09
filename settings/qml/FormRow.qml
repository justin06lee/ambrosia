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
    // Set, the row is laid from the top as System Settings lays its rows of
    // sliders and pop-ups: the label 10 down, the control's first line (this
    // tall) centred on it, and 10 under the control.
    property real firstLine: 0
    default property alias control: slot.data

    readonly property bool fromTop: firstLine > 0
    width: parent ? parent.width : Look.boxWidth
    implicitHeight: fromTop
        ? Math.max(Look.textRow, labels.implicitHeight + 2 * Look.boxPadding, slot.y + slot.height + Look.boxPadding)
        : Math.max(Look.textRow, labels.implicitHeight + 2 * Look.boxPadding, slot.height + 16)

    Column {
        id: labels
        x: Look.boxPadding
        y: row.fromTop ? Look.boxPadding : (row.height - height) / 2
        width: slot.x - x - 12
        spacing: row.description !== "" ? 2 : 0
        Label {
            id: title
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
            lineHeightMode: Text.FixedHeight
            lineHeight: 14
            color: Theme.color.label.secondary
        }
    }
    Item {
        id: slot
        x: row.width - Look.boxPadding - width
        y: row.fromTop ? Look.boxPadding + (title.height - row.firstLine) / 2 : (row.height - height) / 2
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
