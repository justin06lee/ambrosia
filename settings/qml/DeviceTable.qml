import QtQuick
import Ambrosia
import Settings

// A table across the foot of a box, as Sound lists its devices: Name and
// Type over a rule, a row each, the one in use chosen (gray, or the accent
// color while the table has the focus). Clicking a row, or the arrow keys,
// says which was chosen.
FocusScope {
    id: table

    property var rows: [] // [{name, title, kind, current}]
    signal chosen(string name)

    readonly property int current: rows.findIndex(row => row.current)

    width: parent ? parent.width : Look.boxWidth
    height: 1 + Look.tableHeader + rows.length * Look.tableRow
    activeFocusOnTab: true
    Accessible.role: Accessible.Table

    Keys.onUpPressed: if (current > 0) chosen(rows[current - 1].name)
    Keys.onDownPressed: if (current < rows.length - 1) chosen(rows[current + 1].name)

    // The fill follows the box's lower corners; a hairline parts it from
    // what is above.
    Rectangle {
        anchors.fill: parent
        color: Look.tableFill
        bottomLeftRadius: Look.boxRadius
        bottomRightRadius: Look.boxRadius
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Look.hairline
    }
    Repeater {
        model: [qsTr("Name"), qsTr("Type")]
        Label {
            required property int index
            required property string modelData
            x: (index === 0 ? 0 : Look.tableNameWidth) + 10
            y: 1 + (Look.tableHeader - 1 - height) / 2
            text: modelData
            style: Theme.text.caption
        }
    }
    Rectangle {
        y: Look.tableHeader
        width: parent.width
        height: 1
        color: Look.tableRule
    }
    Repeater {
        model: table.rows
        Rectangle {
            id: row
            required property int index
            required property var modelData
            readonly property bool last: index === table.rows.length - 1
            readonly property bool emphasized: modelData.current && table.activeFocus
            y: 1 + Look.tableHeader + index * Look.tableRow
            width: table.width
            height: Look.tableRow
            color: !modelData.current ? "transparent" : emphasized ? Theme.accent.bg : Look.tableChosen
            bottomLeftRadius: last ? Look.boxRadius : 0
            bottomRightRadius: last ? Look.boxRadius : 0
            Accessible.role: Accessible.Row
            Accessible.name: modelData.title

            Label {
                x: 10
                width: Look.tableNameWidth - 20
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.title
                color: row.emphasized ? Theme.accent.fg : Theme.color.label.primary
            }
            Label {
                x: Look.tableNameWidth + 12
                width: table.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.kind
                color: row.emphasized ? Theme.accent.fg : Theme.color.label.primary
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    table.forceActiveFocus();
                    table.chosen(row.modelData.name);
                }
            }
        }
    }
}
