import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's icon view: big icons on a grid, names centered beneath. As in
// Finder, the icons run on up under the toolbar, fading.
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model

    // An icon in view, below the toolbar, scrolling as little as it takes.
    function positionAt(row) {
        const columns = Math.max(1, Math.floor(grid.width / grid.cellWidth));
        const top = Math.floor(row / columns) * grid.cellHeight;
        let to = grid.contentY;
        if (top < to + grid.topMargin)
            to = top - grid.topMargin;
        else if (top + grid.cellHeight > to + grid.height - grid.bottomMargin)
            to = top + grid.cellHeight - grid.height + grid.bottomMargin;
        grid.contentY = Math.max(-grid.topMargin, Math.min(to, grid.contentHeight + grid.bottomMargin - grid.height));
    }

    // Drops: on a folder, into it; anywhere else, into this folder.
    property int dropCell: -1
    function dragOver(drag) {
        const cell = grid.indexAt(drag.x, drag.y + hits.y + grid.contentY);
        dropCell = cell >= 0 && model.isDirAt(cell) && !(finder.dragging && finder.selected[cell]) ? cell : -1;
        drag.accept(Qt.MoveAction);
    }

    // Clicks and drags on the icons, from below the toolbar (its empty
    // space above them still moves the window), and under the icons, so a
    // name being edited takes its own clicks.
    Item {
        id: hits
        x: grid.x
        y: Finder.iconTop
        width: grid.width
        height: pane.height - y

        function cellAt(point) { return grid.indexAt(point.x, point.y + y + grid.contentY); }

        // A click on the name of the one item selected renames it, once
        // it's clear the click isn't the first of a double click.
        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const cell = hits.cellAt(point.position);
                renameSoon.stop();
                if (cell < 0) {
                    pane.finder.clearSelection();
                    return;
                }
                const again = pane.finder.selectedCount === 1 && pane.finder.selected[cell] === true
                    && tap.point.modifiers === Qt.NoModifier && grid.onName(cell, point.position.x, point.position.y + hits.y);
                pane.finder.click(cell, tap.point.modifiers);
                if (again) {
                    renameSoon.cell = cell;
                    renameSoon.start();
                }
            }
            onDoubleTapped: (point) => {
                renameSoon.stop();
                const cell = hits.cellAt(point.position);
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
                const cell = hits.cellAt(centroid.pressPosition);
                if (cell >= 0)
                    pane.finder.startDrag(cell);
            }
        }

    }

    // The icons, from the window's top: they scroll up under the toolbar,
    // from below the window's rounded corners.
    Item {
        id: view
        y: Finder.windowRadius
        width: parent.width
        height: parent.height - y
        clip: true

        GridView {
            id: grid
            x: Finder.iconLeft
            y: -view.y
            width: pane.width - x
            height: pane.height
            topMargin: Finder.iconTop
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

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                topPadding: grid.topMargin
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
                required property string thumb
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
                    thumb: cell.thumb
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
    }

    // Finder's soft edge: the icons fade out under the toolbar.
    Rectangle {
        y: Finder.windowRadius
        width: parent.width
        height: Finder.iconTop - y
        gradient: Gradient {
            GradientStop { position: 0; color: Finder.content }
            GradientStop { position: 0.3; color: Qt.alpha(Finder.content, 0.62) }
            GradientStop { position: 1; color: Qt.alpha(Finder.content, 0) }
        }
    }

    // Over the icons and the empty space around them, below the toolbar.
    DropArea {
        id: drops
        anchors.fill: hits
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
        anchors.fill: hits
        anchors.margins: 2
        radius: Finder.rowRadius
        color: "transparent"
        border.width: 3
        border.color: Theme.accent.bg
        visible: drops.containsDrag && pane.dropCell < 0 && !pane.finder.dragging
    }
}
