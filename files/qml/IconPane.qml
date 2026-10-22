import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's icon view: big icons on a grid, names centered beneath.
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model

    function positionAt(row) { grid.positionViewAtIndex(row, GridView.Contain); }

    // Drops: on a folder, into it; anywhere else, into this folder.
    property int dropCell: -1
    function dragOver(drag) {
        const cell = grid.indexAt(drag.x, drag.y + grid.contentY);
        dropCell = cell >= 0 && model.isDirAt(cell) && !(finder.dragging && finder.selected[cell]) ? cell : -1;
        drag.accept(Qt.MoveAction);
    }

    GridView {
        id: grid
        x: Finder.iconLeft
        y: Finder.iconTop
        width: parent.width - x
        height: parent.height - y
        clip: true
        focus: true
        model: pane.model
        reuseItems: true
        cellWidth: Finder.iconCell
        cellHeight: Finder.iconCell
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        acceptedButtons: Qt.NoButton // the mouse drags items, not the grid

        function onName(cell, x, y) {
            const item = grid.itemAtIndex(cell);
            return item !== null && item.onName(x - item.x + grid.contentX, y - item.y + grid.contentY);
        }

        // A click on the name of the one item selected renames it, once
        // it's clear the click isn't the first of a double click.
        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const cell = grid.indexAt(point.position.x, point.position.y + grid.contentY);
                renameSoon.stop();
                if (cell < 0) {
                    pane.finder.clearSelection();
                    return;
                }
                const again = pane.finder.selectedCount === 1 && pane.finder.selected[cell] === true
                    && tap.point.modifiers === Qt.NoModifier && grid.onName(cell, point.position.x, point.position.y);
                pane.finder.click(cell, tap.point.modifiers);
                if (again) {
                    renameSoon.cell = cell;
                    renameSoon.start();
                }
            }
            onDoubleTapped: (point) => {
                renameSoon.stop();
                const cell = grid.indexAt(point.position.x, point.position.y + grid.contentY);
                if (cell >= 0)
                    pane.finder.open(cell);
            }
        }
        Timer {
            id: renameSoon
            property int cell: -1
            interval: 600
            onTriggered: pane.finder.beginRename(cell)
        }
        DragHandler {
            target: null
            enabled: !pane.finder.renaming
            onActiveChanged: {
                if (!active)
                    return;
                renameSoon.stop();
                const p = centroid.pressPosition;
                const cell = grid.indexAt(p.x, p.y + grid.contentY);
                if (cell >= 0)
                    pane.finder.startDrag(cell);
            }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            contentItem: Rectangle {
                implicitWidth: Theme.size.scrollbar.thin
                radius: width / 2
                color: Theme.color.label.tertiary
                opacity: parent.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }
            }
            background: null
        }

        delegate: Item {
            id: cell
            required property int index
            required property string name
            required property bool isDir
            required property string badge
            required property url url
            required property var tags
            readonly property bool selected: pane.finder.selected[index] === true || pane.dropCell === index
            readonly property bool renaming: pane.finder.renaming && pane.finder.editing.toString() === url.toString()
            function onName(x, y) {
                return y >= name.y && y <= name.y + name.paintedHeight
                    && Math.abs(x - width / 2) <= name.paintedWidth / 2;
            }

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                // Finder's selected icon sits on a soft rounded square.
                anchors.horizontalCenter: icon.horizontalCenter
                anchors.verticalCenter: icon.verticalCenter
                width: Finder.iconSize + 12
                height: Finder.iconSize + 12
                radius: 8
                color: Theme.color.fill.secondary
                visible: cell.selected
            }
            FileIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                size: Finder.iconSize
                kind: cell.isDir ? "folder" : "document"
                badge: cell.badge
                tint: cell.isDir && cell.tags.length > 0 ? cell.tags[0] : ""
            }
            // Its tags, before its name (the name moves over for them).
            TagDots {
                id: dots
                visible: !cell.renaming
                x: name.x + name.leftPadding + (name.width - name.leftPadding - name.paintedWidth) / 2 - width - 4
                y: name.y + name.paintedHeight / Math.max(1, name.lineCount) / 2 - height / 2
                colors: cell.tags
                ring: Finder.content
            }
            Rectangle {
                anchors.centerIn: name
                anchors.horizontalCenterOffset: name.leftPadding / 2
                width: name.paintedWidth + 10
                height: name.paintedHeight + 2
                radius: 4
                visible: cell.selected && !cell.renaming
                color: pane.finder.looksActive ? Theme.accent.bg : Finder.selectionInactive
            }
            Loader {
                active: cell.renaming
                anchors.horizontalCenter: parent.horizontalCenter
                y: name.y - 2
                width: Math.min(item ? item.implicitWidth : 0, parent.width - 4)
                height: name.paintedHeight / Math.max(1, name.lineCount) + 4
                sourceComponent: RenameField {
                    finder: pane.finder
                    name: cell.name
                    isDir: cell.isDir
                    style: Theme.text.callout
                    alignment: TextInput.AlignHCenter
                }
            }
            Label {
                id: name
                visible: !cell.renaming
                anchors.horizontalCenter: parent.horizontalCenter
                y: icon.y + icon.height + 6
                width: parent.width - 8
                leftPadding: dots.width > 0 ? dots.width + 4 : 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideMiddle
                text: cell.name
                style: Theme.text.callout
                color: cell.selected && pane.finder.looksActive ? Theme.accent.fg : Theme.color.label.primary
            }
        }
    }
    // Over the icons and the empty space around them.
    DropArea {
        id: drops
        anchors.fill: grid
        keys: ["text/uri-list"]
        onEntered: (drag) => pane.dragOver(drag)
        onPositionChanged: (drag) => pane.dragOver(drag)
        onExited: pane.dropCell = -1
        onDropped: (drop) => {
            const cell = pane.dropCell;
            pane.dropCell = -1;
            drop.accept(pane.finder.dropOn(drop.urls, cell >= 0 ? pane.model.urlAt(cell) : pane.finder.url));
        }
    }
    Rectangle {
        anchors.fill: grid
        anchors.margins: 2
        radius: Finder.rowRadius
        color: "transparent"
        border.width: 3
        border.color: Theme.accent.bg
        visible: drops.containsDrag && pane.dropCell < 0 && !pane.finder.dragging
    }
}
