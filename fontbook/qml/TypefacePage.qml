import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// A typeface's page. As a specimen: the style chosen on the toolbar, its
// alphabet under "Preview" and every character it draws under
// "Repertoire", each in a box (44 at the slider's usual place, at least 20
// apart, the row filling the width). As samples: a card for each of its
// styles. Either heading folds what is under it away.
Item {
    id: page

    required property var window
    readonly property var family: window.openedFamily
    readonly property var style: family?.styles[window.openedStyle] ?? null
    readonly property int size: Book.specimenSize(window.sizes.page)
    readonly property int box: Book.glyphBox(window.sizes.page)
    readonly property real avail: Math.max(box, width - 50 - 67)
    readonly property var fit: Book.columns(avail, box, 20)
    readonly property color ink: window.looksActive ? Look.text : Look.textInactive
    property bool previewOpen: true
    property bool repertoireOpen: true

    clip: true

    Repertoire {
        id: repertoire
        file: page.style?.file ?? ""
        index: page.style?.index ?? 0
    }

    component Heading: Item {
        id: heading
        property string text
        property bool open: true
        signal toggled()
        width: page.width
        height: 44
        Label {
            x: 50
            anchors.verticalCenter: parent.verticalCenter
            text: heading.text
            style: Theme.text.headline
            font.pixelSize: 15
            font.weight: 700
            color: Look.heading
        }
        Glyph {
            x: parent.width - 79 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: heading.open ? "chevronDown" : "chevronRight"
            size: 12
            color: Look.heading
        }
        MouseArea { anchors.fill: parent; onClicked: heading.toggled() }
    }

    GridView {
        id: grid
        visible: page.window.pageMode === "specimen"
        x: 50
        width: page.fit.count * cellWidth + 1
        height: parent.height
        bottomMargin: 24
        cellWidth: page.box + page.fit.gap
        cellHeight: page.box + 25
        model: page.repertoireOpen ? repertoire : null
        boundsBehavior: Flickable.StopAtBounds
        // What is over the boxes grows and shrinks (a fold, a new width,
        // another style): a page that stood at its top stays there.
        property real origin: 0
        onOriginYChanged: {
            if (Math.abs(contentY - origin) < 2)
                contentY = originY;
            origin = originY;
        }
        Controls.ScrollBar.vertical: ScrollThumb {
            parent: page
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }

        header: Item {
            width: grid.width
            height: top.height
            Column {
            id: top
            x: -50
            width: page.width
            Item { width: 1; height: 39 }
            Heading {
                text: "Preview"
                open: page.previewOpen
                onToggled: page.previewOpen = !page.previewOpen
            }
            Item { width: 1; height: 12; visible: page.previewOpen }
            Text {
                visible: page.previewOpen
                x: 50
                width: page.width - 50 - 67
                wrapMode: Text.Wrap
                text: page.family ? Book.specimen(page.family) : ""
                font.family: page.family?.family ?? ""
                font.styleName: page.style?.name ?? ""
                font.pixelSize: page.size
                color: page.ink
            }
            Item { width: 1; height: page.previewOpen ? 48 : 8 }
            Heading {
                text: "Repertoire"
                open: page.repertoireOpen
                onToggled: page.repertoireOpen = !page.repertoireOpen
            }
            Item { width: 1; height: 37 }
            }
        }

        delegate: Item {
            id: cell
            required property string glyph
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                width: page.box
                height: page.box
                radius: 7
                color: Look.cardFill
                border.width: 1
                border.color: Look.cardRim
                Text {
                    anchors.centerIn: parent
                    text: cell.glyph
                    font.family: page.family?.family ?? ""
                    font.styleName: page.style?.name ?? ""
                    font.pixelSize: page.box * 0.5
                    color: page.ink
                }
            }
        }
    }

    ListView {
        id: list
        visible: page.window.pageMode === "samples"
        anchors.fill: parent
        topMargin: Look.pad
        bottomMargin: 18
        spacing: Look.sampleGap
        model: visible ? (page.family?.styles ?? []) : []
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: styleCell
            required property var modelData
            required property int index
            width: list.width
            height: card.height
            SampleCard {
                id: card
                x: Look.pad
                width: parent.width - Look.pad - Look.padRight
                window: page.window
                title: styleCell.modelData.name
                subtitle: styleCell.modelData.postscript
                footer: styleCell.modelData.format
                sample: page.family ? Book.line(page.family) : ""
                family: page.family?.family ?? ""
                styleName: styleCell.modelData.name
                size: Book.sampleSize(page.window.sizes.page + 0.12)
                locked: !styleCell.modelData.user
                chosen: page.window.openedStyle === styleCell.index
            }
            MouseArea {
                anchors.fill: card
                onPressed: page.window.openedStyle = styleCell.index
            }
        }
    }
}
