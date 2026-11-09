import QtQuick
import Ambrosia
import Settings

// A sheet to choose one of many (a language, a time zone, an app): a title and
// a search field over a list, as System Settings' Add language sheet has it,
// 515 wide, its rows 23 tall.
Sheet {
    id: sheet

    property string title
    property var items: [] // [{value, text}]
    signal picked(string value)

    property string chosen
    readonly property var shown: {
        const words = search.text.trim().toLowerCase();
        return words === "" ? items : items.filter(each => each.text.toLowerCase().includes(words));
    }

    sheetWidth: 515
    below: 24
    onOpenChanged: {
        chosen = "";
        search.text = "";
    }
    onAccepted: {
        if (chosen === "")
            return;
        picked(chosen);
        close();
    }

    Item {
        width: parent.width
        height: 26
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: sheet.title
            font.weight: 600
        }
        Rectangle {
            x: parent.width - width
            width: 162
            height: 26
            radius: 13
            color: Look.face
            Glyph {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                name: "search"
                color: Theme.color.label.secondary
            }
            TextInput {
                id: search
                x: 26
                width: parent.width - 34
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.uiFont
                font.pixelSize: Theme.text.body.size
                color: Theme.color.label.primary
                selectionColor: Theme.accent.highlight
                renderType: Text.NativeRendering
                clip: true
                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search")
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 300
        radius: Look.boxRadius
        color: Look.box
        ListView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: sheet.shown
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool isChosen: sheet.chosen === modelData.value
                width: ListView.view.width
                height: 23
                radius: 4
                color: isChosen ? Theme.accent.bg : "transparent"
                Label {
                    x: 12
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.text
                    color: row.isChosen ? Theme.accent.fg : Theme.color.label.primary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: sheet.chosen = row.modelData.value
                    onDoubleClicked: sheet.accepted()
                }
            }
        }
    }

    trailing: [
        PushButton {
            text: qsTr("Cancel")
            minimumWidth: 80
            onClicked: sheet.close()
        },
        PushButton {
            text: qsTr("Add")
            primary: true
            minimumWidth: 80
            enabled: sheet.chosen !== ""
            onClicked: sheet.accepted()
        }
    ]
}
