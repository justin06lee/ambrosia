import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The typefaces as samples: a card each, one under another 8 apart, with a
// line of text in the typeface's plain style at the slider's size.
Item {
    id: pane

    required property var window
    readonly property int size: Book.sampleSize(window.sizes.samples)
    readonly property int perRow: 1
    readonly property int pageRows: Math.max(1, Math.floor(height / (196 + 1.3 * (size - 34) + Look.sampleGap)))

    function reveal(index) {
        list.positionViewAtIndex(index, ListView.Contain);
    }

    clip: true

    ListView {
        id: list
        anchors.fill: parent
        topMargin: Look.pad
        bottomMargin: 18
        spacing: Look.sampleGap
        model: pane.window.listedFamilies
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: cell
            required property var modelData
            width: list.width
            height: card.height

            SampleCard {
                id: card
                x: Look.pad
                width: parent.width - Look.pad - Look.padRight
                window: pane.window
                title: cell.modelData.family
                subtitle: Book.stylesText(cell.modelData.styles.length)
                footer: pane.window.plain(cell.modelData).name
                sample: Book.line(cell.modelData)
                family: cell.modelData.family
                styleName: pane.window.plain(cell.modelData).name
                size: pane.size
                locked: !cell.modelData.user
                chosen: pane.window.selected === cell.modelData.family
            }
            MouseArea {
                anchors.fill: card
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
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: pane.window.select("")
    }
}
