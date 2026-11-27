import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The info pane, 250 wide beside the views: the chosen typeface's name and
// how many styles it has, its alphabet, and four parts that open by their
// headings (what it can write; its names; its copyright and what it lets
// be done with it; its file). With nothing chosen it says so.
Item {
    id: pane

    required property var window
    readonly property var family: window.infoFamily
    readonly property var details: family ? Library.details(family.family) : null
    readonly property var told: family ? Book.info(family, details) : null
    // Which parts are open, by key: kept while the window is.
    property var open: ({})
    readonly property real inner: width - 2 * Look.infoPad
    readonly property color ink: window.looksActive ? Look.text : Look.textInactive

    width: Look.infoWidth

    Rectangle { anchors.fill: parent; color: Look.sidebarFill }
    Rectangle { width: 1; height: parent.height; color: Look.sidebarRule }
    // Nothing under it takes the wheel or a click meant for it.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (wheel) => wheel.accepted = true }

    Column {
        visible: pane.family === null
        anchors.centerIn: parent
        width: pane.inner
        spacing: 6
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "infoRing"
            size: 56
            color: Look.heading
        }
        Item { width: 1; height: 2 }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No Fonts Selected"
            font.weight: 700
            color: pane.ink
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "Select a font to view its detailed information."
            style: Theme.text.footnote
            color: Look.note
        }
    }

    component Part: Column {
        id: part
        property string key
        property string title
        readonly property bool isOpen: pane.open[key] === true
        default property alias body: content.data
        width: pane.inner
        Rectangle { width: parent.width; height: 1; color: Look.sidebarRule }
        Item {
            width: parent.width
            height: 52
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: part.title
                font.pixelSize: 15
                font.weight: 700
                color: Look.heading
            }
            Glyph {
                x: parent.width - width - 4
                anchors.verticalCenter: parent.verticalCenter
                name: part.isOpen ? "chevronDown" : "chevronRight"
                size: 11
                color: Look.heading
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const open = Object.assign({}, pane.open);
                    open[part.key] = !part.isOpen;
                    pane.open = open;
                }
            }
        }
        Column {
            id: content
            visible: part.isOpen
            width: parent.width
            spacing: 12
            bottomPadding: 16
        }
    }
    // A name over what the font says for it; several sayings, each with
    // how many styles say it.
    component Rows: Repeater {
        delegate: Column {
            id: entry
            required property var modelData
            width: pane.inner
            spacing: 2
            Label {
                text: entry.modelData.label
                style: Theme.text.footnote
                font.weight: 600
                color: Look.note
            }
            Repeater {
                model: entry.modelData.values
                Column {
                    required property var modelData
                    width: pane.inner
                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: modelData.text
                        color: pane.ink
                    }
                    Label {
                        visible: modelData.note !== ""
                        text: modelData.note
                        style: Theme.text.footnote
                        color: Look.note
                        bottomPadding: 4
                    }
                }
            }
        }
    }

    Flickable {
        visible: pane.family !== null
        anchors.fill: parent
        contentHeight: column.height + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: ScrollThumb {}

        Column {
            id: column
            x: Look.infoPad
            y: 15
            width: pane.inner

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: pane.family?.family ?? ""
                font.pixelSize: 16
                font.weight: 700
                color: pane.window.looksActive ? Theme.color.label.primary : Look.textInactive
            }
            Item { width: 1; height: 3 }
            Label {
                text: Book.stylesText(pane.family?.styles.length ?? 0)
                font.pixelSize: 14
                color: pane.window.looksActive ? Theme.color.label.primary : Look.textInactive
            }
            Item { width: 1; height: 18 }
            Text {
                width: parent.width
                wrapMode: Text.WrapAnywhere
                text: pane.family ? Book.specimen(pane.family) : ""
                font.family: pane.family?.family ?? ""
                font.styleName: pane.family ? pane.window.plain(pane.family).name : ""
                font.pixelSize: 18
                color: pane.ink
            }
            Item { width: 1; height: 16 }

            Part {
                key: "language"
                title: "Language Support"
                Repeater {
                    model: pane.told?.language ?? []
                    Label {
                        required property var modelData
                        width: pane.inner
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        text: "<b>" + modelData.label + ":</b> " + modelData.text
                        color: pane.ink
                    }
                }
            }
            Part {
                key: "identifiers"
                title: "Identifiers"
                Rows { model: pane.told?.identifiers ?? [] }
            }
            Part {
                key: "usage"
                title: "Usage"
                Rows { model: pane.told?.usage ?? [] }
            }
            Part {
                key: "details"
                title: "Details"
                Rows { model: pane.told?.details ?? [] }
            }
            Rectangle { width: parent.width; height: 1; color: Look.sidebarRule }
        }
    }
}
