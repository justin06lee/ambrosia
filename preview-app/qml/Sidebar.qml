import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import Preview
import "view.mjs" as View

// The sidebar, flush and full height as Preview's: a PDF's pages (or a
// window's pictures) as thumbnails 159 across, the one in view on a
// highlight, each with its number (or name) under it; or the PDF's table
// of contents. A click goes there.
Item {
    id: sidebar

    required property Window window
    readonly property var view: window.view
    readonly property bool pdf: window.pdf

    ListView {
        id: thumbs
        anchors.fill: parent
        visible: sidebar.window.sidebarMode === "thumbnails"
        clip: true
        bottomMargin: 10
        boundsBehavior: Flickable.StopAtBounds
        model: !visible ? 0 : sidebar.pdf ? sidebar.window.doc.pageCount : sidebar.window.files.length
        // The list keeps the one in view in sight.
        currentIndex: sidebar.view?.currentPage ?? 0
        highlight: null
        highlightMoveDuration: 0
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: cell
            required property int index
            readonly property bool current: ListView.isCurrentItem
            readonly property int quarter: sidebar.view?.turns[index] ?? 0
            readonly property size natural: sidebar.pdf ? (sidebar.window.doc.pageSizes[index] ?? Qt.size(612, 792)) : App.imageSize(sidebar.window.files[index])
            readonly property var shown: View.turned(natural, quarter)
            // As tall as its shape makes it, within reason for a very long or very wide one.
            readonly property int thumbHeight: shown.width > 0 ? View.clamp(Math.round(Look.thumbWidth * shown.height / shown.width), 40, 280) : 120
            readonly property color under: current ? Look.highlight(sidebar.window.looksActive) : Look.sidebarFill

            width: thumbs.width
            height: Look.thumbPad + thumbHeight + Look.thumbLabel + Look.thumbGap

            Rectangle {
                x: (parent.width - width) / 2
                width: Look.thumbWidth + 2 * Look.thumbPad
                height: parent.height - Look.thumbGap
                radius: Look.thumbHighlightRadius
                color: cell.under
                visible: cell.current
            }
            Item {
                id: frame
                x: (parent.width - width) / 2
                y: Look.thumbPad
                width: Look.thumbWidth
                height: cell.thumbHeight
                clip: true

                Rectangle { anchors.fill: parent; color: "white"; visible: sidebar.pdf }
                Image {
                    anchors.centerIn: parent
                    width: cell.quarter % 2 !== 0 ? parent.height : parent.width
                    height: cell.quarter % 2 !== 0 ? parent.width : parent.height
                    rotation: cell.quarter * 90
                    source: sidebar.pdf ? "image://page/" + sidebar.window.doc.id + "/" + cell.index : sidebar.window.files[cell.index]
                    sourceSize.width: Math.round(Look.thumbWidth * Screen.devicePixelRatio * (cell.quarter % 2 !== 0 ? cell.thumbHeight / Look.thumbWidth : 1))
                    fillMode: Image.PreserveAspectFit
                    autoTransform: true
                    asynchronous: true
                    mipmap: true
                }
            }
            // The thumbnail's corners, rounded by what it lies on.
            Rectangle {
                anchors.fill: frame
                anchors.margins: -3
                radius: Look.thumbRadius + 3
                color: "transparent"
                border.width: 3
                border.color: cell.under
            }
            Label {
                x: frame.x
                y: frame.y + frame.height
                width: frame.width
                height: Look.thumbLabel
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
                text: sidebar.pdf ? cell.index + 1 : App.name(sidebar.window.files[cell.index])
                style: Theme.text.footnote
                color: cell.current ? (sidebar.window.looksActive ? Theme.accent.fg : Theme.color.label.primary) : Look.thumbLabelColor
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    sidebar.view.goToPage(cell.index);
                    sidebar.window.takeKeys();
                }
            }
        }
    }

    ListView {
        id: outline
        anchors.fill: parent
        anchors.topMargin: 4
        visible: sidebar.window.sidebarMode === "outline"
        clip: true
        bottomMargin: 10
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? sidebar.window.doc.outline : []
        // The entry the page in view belongs to: the last at or before it.
        readonly property int here: {
            const page = sidebar.view?.currentPage ?? 0;
            const entries = sidebar.window.doc.outline;
            let at = -1;
            for (let i = 0; i < entries.length && entries[i].page <= page; ++i)
                at = i;
            return at;
        }
        Controls.ScrollBar.vertical: ScrollThumb {}

        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool current: outline.here === index
            width: outline.width
            height: 28

            Rectangle {
                x: 10
                width: parent.width - 20
                height: parent.height
                radius: 8
                color: Look.highlight(sidebar.window.looksActive)
                visible: entry.current
            }
            Label {
                x: 20 + entry.modelData.level * 14
                width: parent.width - x - 20
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: entry.modelData.title
                color: entry.current && sidebar.window.looksActive ? Theme.accent.fg : Theme.color.label.primary
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    sidebar.view.goToPage(entry.modelData.page, entry.modelData.y);
                    sidebar.window.takeKeys();
                }
            }
        }
    }
}
