import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's icon view: big icons on a grid, names centered beneath.
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model

    function positionAt(row) { grid.positionViewAtIndex(row, GridView.Contain); }

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

        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const cell = grid.indexAt(point.position.x, point.position.y + grid.contentY);
                if (cell < 0)
                    pane.finder.clearSelection();
                else
                    pane.finder.click(cell, tap.point.modifiers);
            }
            onDoubleTapped: (point) => {
                const cell = grid.indexAt(point.position.x, point.position.y + grid.contentY);
                if (cell >= 0)
                    pane.finder.open(cell);
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
            readonly property bool selected: pane.finder.selected[index] === true

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
            }
            Rectangle {
                anchors.centerIn: name
                width: name.paintedWidth + 10
                height: name.paintedHeight + 2
                radius: 4
                visible: cell.selected
                color: pane.finder.active ? Theme.accent.bg : Finder.selectionInactive
            }
            Label {
                id: name
                anchors.horizontalCenter: parent.horizontalCenter
                y: icon.y + icon.height + 6
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideMiddle
                text: cell.name
                style: Theme.text.callout
                color: cell.selected && pane.finder.active ? Theme.accent.fg : Theme.color.label.primary
            }
        }
    }
}
