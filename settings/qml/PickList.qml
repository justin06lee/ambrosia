import QtQuick
import Ambrosia
import Settings

// A list added to from elsewhere (Login Items, Preferred Languages), as System
// Settings draws it: an optional header, 24-tall rows, and under them a bar
// with + and − (the chosen row). `items` are [{value, text}].
Rectangle {
    id: list

    property var items: []
    property string title
    property string column
    // What's on the right of every row (Kind's Application).
    property string detail
    property bool canRemove: true
    signal addRequested()
    signal removeRequested(string value)

    property string chosen

    width: parent ? parent.width : Look.boxWidth
    height: column.height
    radius: Look.boxRadius
    color: Look.box

    Column {
        id: column
        width: parent.width
        Item {
            visible: list.title !== ""
            width: parent.width
            height: 28
            Label {
                x: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                text: list.title
                style: Theme.text.caption
                color: Theme.color.label.secondary
            }
            Label {
                x: 242
                anchors.verticalCenter: parent.verticalCenter
                text: list.column
                style: Theme.text.caption
                color: Theme.color.label.secondary
            }
        }
        Repeater {
            model: list.items
            Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool isChosen: list.chosen === modelData.value
                width: column.width
                height: 24
                color: isChosen ? Theme.accent.bg : index % 2 ? "transparent" : Look.hairline
                Label {
                    x: Look.boxPadding
                    width: list.detail !== "" ? 226 : parent.width - 2 * x
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.text
                    color: row.isChosen ? Theme.accent.fg : Theme.color.label.primary
                }
                Label {
                    x: 242
                    anchors.verticalCenter: parent.verticalCenter
                    text: list.detail
                    color: row.isChosen ? Theme.accent.fg : Theme.color.label.primary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: list.chosen = row.modelData.value
                }
            }
        }
        Item {
            visible: list.items.length === 0
            width: parent.width
            height: 24
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Look.hairline
        }
        Row {
            x: 4
            height: Look.editListBar - 1
            Item {
                width: 25
                height: parent.height
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Add")
                Label {
                    anchors.centerIn: parent
                    text: "+"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: list.addRequested()
                }
            }
            Item {
                readonly property bool usable: list.chosen !== "" && list.canRemove
                width: 25
                height: parent.height
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Remove")
                Label {
                    anchors.centerIn: parent
                    text: "−"
                    color: parent.usable ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: parent.usable
                    onClicked: {
                        const value = list.chosen;
                        list.chosen = "";
                        list.removeRequested(value);
                    }
                }
            }
        }
    }
}
