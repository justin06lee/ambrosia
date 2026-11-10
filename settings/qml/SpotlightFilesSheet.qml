import QtQuick
import Ambrosia
import Settings

// Spotlight's ⓘ on Files: which kinds of file Search shows, laid out as the
// Mac's sheet (a heading and a line under it, a box of switches, Done). The
// shell sorts a file into a kind by its name's ending (shell/Search.qml) and
// leaves out those turned off here ("files:images" in searchOff). Left
// out: the Mac's list of Hidden File Types.
Sheet {
    id: sheet

    // The page's: the kinds turned off, and how one is turned on or off.
    required property var off
    signal allow(string kind, bool on)

    sheetWidth: 500
    below: 24
    onAccepted: close()

    Item {
        width: parent.width
        height: heading.height
        Column {
            id: heading
            x: Look.boxPadding
            width: parent.width - 2 * x
            spacing: 2
            Label {
                text: qsTr("Files")
                font.weight: 600
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                style: Theme.text.caption
                color: Theme.color.label.secondary
                lineHeightMode: Text.FixedHeight
                lineHeight: 14
                text: qsTr("These kinds of file are shown in Spotlight results when Files is on.")
            }
        }
    }
    Box {
        width: parent.width
        Repeater {
            model: [
                { kind: "developer", name: qsTr("Developer") },
                { kind: "documents", name: qsTr("Documents") },
                { kind: "images", name: qsTr("Images") },
                { kind: "movies", name: qsTr("Movies") },
                { kind: "music", name: qsTr("Music") },
                { kind: "others", name: qsTr("Others") },
                { kind: "pdfs", name: qsTr("PDFs") },
                { kind: "presentations", name: qsTr("Presentations") },
                { kind: "spreadsheets", name: qsTr("Spreadsheets") },
            ]
            FormRow {
                id: row
                required property var modelData
                label: modelData.name
                Switch {
                    checked: !sheet.off.includes("files:" + row.modelData.kind)
                    onToggled: sheet.allow("files:" + row.modelData.kind, !checked)
                }
            }
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
}
