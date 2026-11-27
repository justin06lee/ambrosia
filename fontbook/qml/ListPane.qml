import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The typefaces as a list under three headings (Typeface, Styles, Format):
// rows 27 apart, every other one on a rounded band; a typeface opens to
// its styles by the mark before its name. The columns are shares of the
// width (52, 23 and 25 of a hundred); a row's are the scroller's 17
// narrower than the headings', as a Mac's.
Item {
    id: pane

    required property var window
    readonly property int size: Book.listSize(window.sizes.list)
    readonly property real row: Math.round(Look.listRow * size / 13)
    readonly property var rows: Book.rows(window.listedFamilies, window.expanded)
    readonly property int perRow: 1
    readonly property int pageRows: Math.max(1, Math.floor((height - Look.header) / row) - 1)
    readonly property real stylesX: Math.round(width * 0.52)
    readonly property real formatX: Math.round(width * 0.75)
    readonly property color ink: window.looksActive ? Look.text : Look.textInactive

    // The row of a typeface's own line.
    function reveal(index) {
        const family = window.listedFamilies[index]?.family;
        const at = rows.findIndex(row => row.kind === "family" && row.family === family);
        if (at >= 0)
            list.positionViewAtIndex(at, ListView.Contain);
    }

    clip: true

    ListView {
        id: list
        y: Look.header
        width: parent.width
        height: parent.height - y
        topMargin: Look.listTop
        bottomMargin: 10
        model: pane.rows
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool family: modelData.kind === "family"
            readonly property bool chosen: pane.window.selected === modelData.family
            readonly property color ink: chosen && pane.window.looksActive ? Theme.accent.fg : pane.ink
            width: list.width
            height: pane.row

            Rectangle {
                visible: line.chosen || line.index % 2 === 1
                x: Look.listInset
                y: 0.5
                width: parent.width - Look.listInset - 28
                height: parent.height - 1
                radius: 5
                color: line.chosen ? Look.chosen(pane.window.looksActive) : Look.band
            }
            Glyph {
                visible: line.family
                x: 15
                anchors.verticalCenter: parent.verticalCenter
                name: line.modelData.open ? "chevronDown" : "chevronRight"
                size: 11
                color: line.ink
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: pane.window.toggleExpanded(line.modelData.family)
                }
            }
            Label {
                x: line.family ? 32 : 50
                width: pane.stylesX - 17 - x - 40
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: line.family ? line.modelData.family : line.modelData.style
                font.pixelSize: pane.size
                color: line.ink
            }
            Glyph {
                visible: line.family && !line.modelData.user
                x: pane.stylesX - 17 - 32
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: 11
                color: line.chosen && pane.window.looksActive ? Theme.accent.fg : Look.heading
            }
            Label {
                visible: line.family
                x: pane.stylesX - 7
                width: pane.formatX - pane.stylesX - 20
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: line.family ? Book.stylesText(line.modelData.styles) : ""
                font.pixelSize: pane.size
                color: line.ink
            }
            Label {
                visible: line.family
                x: pane.formatX - 6
                width: parent.width - x - 34
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: line.family ? (line.modelData.format ?? "") : ""
                font.pixelSize: pane.size
                color: line.ink
            }
            MouseArea {
                anchors.fill: parent
                anchors.leftMargin: line.family ? 28 : 0
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (mouse) => {
                    pane.window.select(line.modelData.family);
                    if (mouse.button === Qt.RightButton)
                        pane.window.menuFor(line.modelData.family);
                }
                onDoubleClicked: (mouse) => {
                    if (mouse.button !== Qt.LeftButton)
                        return;
                    if (line.family)
                        pane.window.open(line.modelData.family);
                    else
                        pane.window.openStyle(line.modelData.family, line.modelData.style);
                }
            }
        }
    }
    MouseArea {
        anchors.fill: list
        z: -1
        onPressed: pane.window.select("")
    }

    // The headings stand on the toolbar's color over a rule.
    Rectangle {
        width: parent.width
        height: Look.header
        color: Look.toolbarFill
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: Look.headerRule
        }
        Repeater {
            model: [{ text: "Typeface", x: 35 }, { text: "Styles", x: pane.stylesX + 10, rule: pane.stylesX }, { text: "Format", x: pane.formatX + 10, rule: pane.formatX }]
            Item {
                required property var modelData
                height: Look.header
                Rectangle {
                    visible: modelData.rule !== undefined
                    x: modelData.rule ?? 0
                    y: 6
                    width: 1
                    height: Look.header - 12
                    color: Look.headerRule
                }
                Label {
                    x: modelData.x
                    y: (Look.header - height) / 2 - 0.5
                    text: modelData.text
                    style: Theme.text.footnote
                    font.weight: 500
                    color: Look.note
                }
            }
        }
    }
}
