import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The typefaces as cards: each 115 square (the size slider's middle) with
// the letters that stand for it in its own plain style, how many styles it
// has, and its name underneath. As many across as fit at least 18 apart,
// the row filling the width. A click chooses one; two open its page.
Item {
    id: pane

    required property var window
    readonly property int card: Book.cardSize(window.sizes.grid)
    readonly property real avail: Math.max(card, width - Look.pad - Look.padRight)
    readonly property var fit: Book.columns(avail, card, Look.cardGap)
    readonly property int perRow: fit.count
    readonly property int pageRows: Math.max(1, Math.floor(height / grid.cellHeight))

    function reveal(index) {
        grid.positionViewAtIndex(index, GridView.Contain);
    }

    clip: true

    GridView {
        id: grid
        x: Look.pad
        width: pane.perRow * cellWidth + 1
        height: parent.height
        topMargin: Look.pad
        bottomMargin: 12
        cellWidth: pane.card + pane.fit.gap
        cellHeight: pane.card + Look.cardLabel
        model: pane.window.listedFamilies
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        Controls.ScrollBar.vertical: ScrollThumb {
            parent: pane
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool chosen: pane.window.selected === modelData.family
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: face
                width: pane.card
                height: pane.card
                radius: Look.cardRadius * pane.card / Look.card
                color: Look.cardFill
                border.width: cell.chosen ? 2.5 : 1
                border.color: cell.chosen ? Look.chosen(pane.window.looksActive) : Look.cardRim

                Text {
                    width: parent.width - 12
                    height: parent.height * 0.72
                    x: 6
                    y: parent.height * 0.08
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                    text: Book.sample(cell.modelData)
                    font.family: cell.modelData.family
                    font.styleName: pane.window.plain(cell.modelData).name
                    font.pixelSize: pane.card * 0.47
                    color: pane.window.looksActive ? Look.text : Look.textInactive
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 15 - height / 2
                    text: Book.stylesText(cell.modelData.styles.length)
                    style: Theme.text.caption
                    color: Look.note
                }
            }
            Rectangle {
                // The chosen one's name stands on the accent.
                visible: cell.chosen
                anchors.fill: name
                anchors.leftMargin: (name.width - name.contentWidth) / 2 - 5
                anchors.rightMargin: (name.width - name.contentWidth) / 2 - 5
                anchors.topMargin: -1
                anchors.bottomMargin: -1
                radius: 5
                color: Look.chosen(pane.window.looksActive)
            }
            Label {
                id: name
                y: pane.card + 8
                width: pane.card
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.modelData.family
                style: Theme.text.footnote
                font.pixelSize: 12
                font.weight: 500
                lineHeight: 15
                lineHeightMode: Text.FixedHeight
                color: cell.chosen && pane.window.looksActive ? Theme.accent.fg : pane.window.looksActive ? Look.text : Look.textInactive
            }
            MouseArea {
                width: pane.card
                height: parent.height - 6
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (mouse) => {
                    pane.window.select(cell.modelData.family);
                    if (mouse.button === Qt.RightButton)
                        pane.window.menuFor(cell.modelData.family);
                }
                onDoubleClicked: (mouse) => { if (mouse.button === Qt.LeftButton) pane.window.open(cell.modelData.family); }
            }
        }
    }
    // A click on the ground chooses nothing.
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: pane.window.select("")
    }
}
