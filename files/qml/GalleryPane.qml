import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's gallery view: the item selected, large, over a filmstrip of the
// folder's items along the bottom. Its name, kind and dates are in the
// preview pane on the window's right (PreviewPane.qml).
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model
    readonly property var info: finder.shownInfo

    function positionAt(row) { strip.positionViewAtIndex(row, ListView.Contain); }
    Component.onCompleted: if (finder.current >= 0) Qt.callLater(positionAt, finder.current)

    // The item selected, as large as the space allows.
    Item {
        id: stage
        y: Finder.galleryTop
        width: parent.width
        height: strip.y - y

        Thumbnail {
            id: large
            visible: pane.info.url !== undefined
            anchors.fill: parent
            anchors.margins: 24
            iconSize: Math.min(stage.width, stage.height) * Finder.galleryScale
            url: pane.info.url ?? ""
            isDir: pane.info.isDir ?? false
            badge: pane.info.badge ?? ""
        }

        // Its name while it's being renamed, when the preview pane is hidden
        // (with the pane, the name is edited there).
        Loader {
            active: pane.finder.renaming && !pane.finder.previewShown
                    && pane.finder.editing.toString() === (pane.info.url ?? "").toString()
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: Math.min(item ? item.implicitWidth : 0, stage.width - 32)
            sourceComponent: RenameField {
                finder: pane.finder
                name: pane.info.name ?? ""
                isDir: pane.info.isDir ?? false
                alignment: TextInput.AlignHCenter
            }
        }

        TapHandler {
            onDoubleTapped: if (pane.finder.shownRow >= 0) pane.finder.open(pane.finder.shownRow)
        }
        DragHandler {
            target: null
            enabled: !pane.finder.renaming
            onActiveChanged: if (active && pane.finder.shownRow >= 0) pane.finder.startDrag(pane.finder.shownRow)
        }
    }

    // The filmstrip: every item, the ones selected on a rounded square.
    ListView {
        id: strip
        y: parent.height - Finder.galleryStrip
        width: parent.width
        height: Finder.galleryStrip
        orientation: ListView.Horizontal
        leftMargin: Finder.galleryStripLeft
        rightMargin: Finder.galleryStripLeft
        clip: true
        model: pane.model
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton // the mouse drags items; the touchpad scrolls
        keyNavigationEnabled: false
        currentIndex: -1
        highlightFollowsCurrentItem: false

        function cellAt(point) { return indexAt(point.x + contentX, point.y + contentY); }

        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const cell = strip.cellAt(point.position);
                if (cell >= 0)
                    pane.finder.click(cell, tap.point.modifiers);
            }
            onDoubleTapped: (point) => {
                const cell = strip.cellAt(point.position);
                if (cell >= 0)
                    pane.finder.open(cell);
            }
        }
        DragHandler {
            target: null
            enabled: !pane.finder.renaming
            onActiveChanged: {
                if (!active)
                    return;
                const cell = strip.cellAt(centroid.pressPosition);
                if (cell >= 0)
                    pane.finder.startDrag(cell);
            }
        }

        Controls.ScrollBar.horizontal: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitHeight: Theme.size.scrollbar.thin
                radius: height / 2
                color: Theme.color.label.tertiary
                opacity: parent.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }
            }
            background: null
        }

        delegate: Item {
            id: cell
            required property int index
            required property bool isDir
            required property string badge
            required property url url

            width: Finder.galleryCell
            height: strip.height

            Rectangle {
                anchors.centerIn: parent
                width: Finder.gallerySelection
                height: Finder.gallerySelection
                radius: Finder.gallerySelectionRadius
                color: Finder.gallerySelected
                visible: pane.finder.selected[cell.index] === true || drops.cell === cell.index
            }
            Thumbnail {
                anchors.centerIn: parent
                width: Finder.galleryThumb
                height: Finder.galleryThumb
                url: cell.url
                isDir: cell.isDir
                badge: cell.badge
            }
        }
    }

    // Drops: on a folder in the filmstrip, into it; anywhere else, into this
    // folder (ringed, as Finder does).
    DropArea {
        id: drops
        property int cell: -1
        anchors.fill: parent
        keys: ["text/uri-list"]
        function over(drag) {
            const at = drag.y >= strip.y ? strip.indexAt(drag.x + strip.contentX, drag.y - strip.y + strip.contentY) : -1;
            cell = at >= 0 && pane.model.isDirAt(at) && !(pane.finder.dragging && pane.finder.selected[at]) ? at : -1;
            drag.accept(Qt.MoveAction);
        }
        onEntered: (drag) => over(drag)
        onPositionChanged: (drag) => over(drag)
        onExited: cell = -1
        onDropped: (drop) => {
            const at = cell;
            cell = -1;
            drop.accept(pane.finder.dropOn(drop.urls, at >= 0 ? pane.model.urlAt(at) : pane.finder.url));
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Finder.galleryTop
        anchors.margins: 2
        radius: Finder.rowRadius
        color: "transparent"
        border.width: 3
        border.color: Theme.accent.bg
        visible: drops.containsDrag && drops.cell < 0 && !pane.finder.dragging
    }
}
