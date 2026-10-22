import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's list view: sortable column headers, then one row per item on
// alternating stripes that run on down the empty space below.
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model
    readonly property real stripeLeft: Finder.rowInsetLeft
    readonly property real stripeRight: width - Finder.rowInsetRight
    // Column widths, as the header's dividers set them; Name takes the rest.
    property real dateW: Finder.dateColumn
    property real sizeW: Finder.sizeColumn
    property real kindW: Finder.kindColumn
    readonly property real kindX: stripeRight - kindW
    readonly property real sizeX: kindX - sizeW
    readonly property real dateX: sizeX - dateW

    // A divider trades width between the columns either side of it; the
    // first one, between Name and Date Modified, takes it from Name.
    readonly property var minWidth: ({ name: 120, date: 82, size: 56, kind: 70 })
    property var resizeFrom: ({})
    function startResize() { resizeFrom = { date: dateW, size: sizeW, kind: kindW }; }
    function resize(divider, dx) {
        const from = resizeFrom, min = minWidth;
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        if (divider === 1) {
            const room = stripeRight - from.kind - from.size - Finder.nameText - min.name;
            dateW = clamp(from.date - dx, min.date, Math.max(min.date, room));
        } else if (divider === 2) {
            const d = clamp(dx, min.date - from.date, from.size - min.size);
            dateW = from.date + d;
            sizeW = from.size - d;
        } else {
            const d = clamp(dx, min.size - from.size, from.kind - min.kind);
            sizeW = from.size + d;
            kindW = from.kind - d;
        }
    }

    function positionAt(row) { list.positionViewAtIndex(row, ListView.Contain); }

    // Drops: on a folder's row, into it; anywhere else, into this folder.
    property int dropRow: -1
    function dragOver(drag) {
        const row = list.indexAt(drag.x, drag.y + list.contentY);
        dropRow = row >= 0 && model.isDirAt(row) && !(finder.dragging && finder.selected[row]) ? row : -1;
        drag.accept(Qt.MoveAction);
    }

    // A narrow date column takes a shorter date, as Finder's does.
    readonly property real dateWidth: dateW - 12
    Label { id: dateProbe0; visible: false; text: "Sep 28, 2026 at 10:59 PM" }
    Label { id: dateProbe1; visible: false; text: "12/28/26, 10:59 PM" }
    Binding {
        target: pane.model
        property: "dateLevel"
        value: dateProbe0.implicitWidth <= pane.dateWidth ? 0 : dateProbe1.implicitWidth <= pane.dateWidth ? 1 : 2
    }

    // Column headers
    Item {
        id: header
        y: Finder.headerTop
        width: parent.width
        height: Finder.headerHeight

        Repeater {
            model: [
                { column: "name", title: "Name" },
                { column: "date", title: "Date Modified" },
                { column: "size", title: "Size" },
                { column: "kind", title: "Kind" },
            ]
            Item {
                id: column
                required property var modelData
                required property int index
                readonly property bool sorted: pane.model.sortColumn === modelData.column
                readonly property real textX: [Finder.nameText, pane.dateX + 8, pane.sizeX + 7.5, pane.kindX + 8][index]
                readonly property real end: [pane.dateX, pane.sizeX, pane.kindX, pane.stripeRight][index]
                x: index === 0 ? 0 : textX - 8
                width: end - x
                height: header.height

                Label {
                    x: column.textX - column.x
                    width: column.width - x - (column.sorted ? 20 : 4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: column.modelData.title
                    style: Theme.text.caption
                    elide: Text.ElideRight
                    font.weight: column.sorted ? 700 : 400
                    color: column.sorted ? Theme.color.label.primary : Theme.color.label.secondary
                }
                Glyph {
                    visible: column.sorted
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    name: pane.model.ascending ? "sortUp" : "sortDown"
                    size: 14
                    color: Theme.color.label.secondary
                }
                Rectangle {
                    visible: column.index > 0
                    width: 1
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Finder.separator
                }
                TapHandler {
                    onTapped: (point) => {
                        if (column.index > 0 && point.position.x < 5)
                            return; // the divider
                        if (column.sorted)
                            pane.model.ascending = !pane.model.ascending;
                        else
                            pane.model.sortColumn = column.modelData.column;
                    }
                }
                // The divider on the column's left: drag to resize.
                Item {
                    visible: column.index > 0
                    x: -4
                    width: 9
                    height: parent.height
                    HoverHandler { cursorShape: Qt.SizeHorCursor }
                    DragHandler {
                        target: null
                        yAxis.enabled: false
                        cursorShape: Qt.SizeHorCursor
                        onActiveChanged: if (active) pane.startResize()
                        onTranslationChanged: if (active) pane.resize(column.index, translation.x)
                    }
                }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Finder.separator
        }
    }

    // Stripes, behind the rows and down through the empty space.
    Item {
        anchors.fill: list
        clip: true
        Repeater {
            model: Math.ceil(list.height / Finder.row / 2) + 2
            Rectangle {
                required property int index
                readonly property real phase: (list.contentY - list.originY) % (2 * Finder.row)
                x: pane.stripeLeft
                width: pane.stripeRight - pane.stripeLeft
                y: (2 * index + 1) * Finder.row - phase - list.topMargin * 0
                height: Finder.row
                radius: Finder.rowRadius
                color: Finder.stripe
            }
        }
    }

    ListView {
        id: list
        y: Finder.rowsTop
        width: parent.width
        height: parent.height - y
        clip: true
        focus: true
        model: pane.model
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton // the mouse drags items, not the list
        currentIndex: pane.finder.current
        highlightFollowsCurrentItem: false
        keyNavigationEnabled: false

        // Whether a point in a row is on its disclosure triangle, or its name.
        function onTriangle(row, x) {
            if (row < 0 || !pane.model.isDirAt(row))
                return false;
            const depth = list.itemAtIndex(row)?.depth ?? 0;
            return Math.abs(x - (Finder.disclosureX + depth * Finder.indent)) <= 9;
        }
        function onName(row, x) {
            const item = list.itemAtIndex(row);
            return item !== null && x >= item.nameStart && x <= item.nameEnd;
        }

        // One handler for the whole list: a row's click selects it (with
        // Ctrl or Shift, adds to the selection), a double click opens it,
        // and a click below the rows clears the selection. A click on a
        // folder's triangle opens it in place (with Option, everything in
        // it too) and leaves the selection alone.
        // A click on the name of the one item selected renames it, once
        // it's clear the click isn't the first of a double click.
        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const row = list.indexAt(point.position.x, point.position.y + list.contentY);
                renameSoon.stop();
                if (list.onTriangle(row, point.position.x)) {
                    pane.model.setExpanded(row, !pane.model.isExpanded(row), tap.point.modifiers & Qt.AltModifier);
                } else if (row < 0) {
                    pane.finder.clearSelection();
                } else {
                    const again = pane.finder.selectedCount === 1 && pane.finder.selected[row] === true
                        && tap.point.modifiers === Qt.NoModifier && list.onName(row, point.position.x);
                    pane.finder.click(row, tap.point.modifiers);
                    if (again) {
                        renameSoon.row = row;
                        renameSoon.start();
                    }
                }
            }
            onDoubleTapped: (point) => {
                renameSoon.stop();
                const row = list.indexAt(point.position.x, point.position.y + list.contentY);
                if (row >= 0 && !list.onTriangle(row, point.position.x))
                    pane.finder.open(row);
            }
        }
        Timer {
            id: renameSoon
            property int row: -1
            interval: 600
            onTriggered: pane.finder.beginRename(row)
        }
        // Pressing an item and dragging takes the selection along (the item
        // is selected first if it wasn't).
        DragHandler {
            target: null
            enabled: !pane.finder.renaming
            onActiveChanged: {
                if (!active)
                    return;
                renameSoon.stop();
                const p = centroid.pressPosition;
                const row = list.indexAt(p.x, p.y + list.contentY);
                if (row >= 0 && !list.onTriangle(row, p.x))
                    pane.finder.startDrag(row);
            }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
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
            id: rowItem
            required property int index
            required property string name
            required property string dateText
            required property string sizeText
            required property string kind
            required property string kindShort
            required property int depth
            required property bool expanded
            required property bool isDir
            required property string badge
            required property url url
            readonly property bool selected: pane.finder.selected[index] === true || pane.dropRow === index
            readonly property bool renaming: pane.finder.renaming && pane.finder.editing.toString() === url.toString()
            readonly property real nameStart: nameLabel.x
            readonly property real nameEnd: nameLabel.x + nameLabel.paintedWidth

            width: list.width
            height: Finder.row

            Rectangle {
                x: pane.stripeLeft
                width: pane.stripeRight - pane.stripeLeft
                height: parent.height
                radius: Finder.rowRadius
                visible: rowItem.selected
                color: pane.finder.looksActive ? Theme.accent.bg : Finder.selectionInactive
            }
            readonly property color ink: selected && pane.finder.looksActive ? Theme.accent.fg : Theme.color.label.primary
            readonly property color softInk: selected && pane.finder.looksActive ? Theme.accent.fg : Theme.color.label.secondary

            readonly property real indent: depth * Finder.indent

            Glyph {
                visible: rowItem.isDir
                x: Finder.disclosureX + rowItem.indent - width / 2
                anchors.verticalCenter: parent.verticalCenter
                name: "disclosure"
                size: 14
                color: rowItem.softInk
                rotation: rowItem.expanded ? 90 : 0
                Behavior on rotation {
                    enabled: !list.moving
                    NumberAnimation { duration: Theme.fade.base; easing.type: Easing.OutCubic }
                }
            }
            FileIcon {
                x: Finder.nameText - 21 + rowItem.indent
                anchors.verticalCenter: parent.verticalCenter
                size: Finder.listIcon
                kind: rowItem.isDir ? "folder" : "document"
            }
            Label {
                id: nameLabel
                visible: !rowItem.renaming
                x: Finder.nameText + rowItem.indent
                width: pane.dateX - x - 8
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.name
                elide: Text.ElideMiddle
                color: rowItem.ink
            }
            Loader {
                active: rowItem.renaming
                x: nameLabel.x - 5
                width: Math.min(item ? item.implicitWidth : 0, pane.dateX - x - 4)
                height: Finder.row - 2
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: RenameField {
                    finder: pane.finder
                    name: rowItem.name
                    isDir: rowItem.isDir
                }
            }
            Label {
                x: pane.dateX + 8
                width: pane.dateW - 12
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.dateText
                elide: Text.ElideRight
                color: rowItem.softInk
            }
            Label {
                x: pane.sizeX
                width: pane.sizeW - 4.5
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: rowItem.sizeText
                color: rowItem.softInk
            }
            // Finder cuts a kind in the middle, after trying its short name.
            Label {
                id: kindLabel
                x: pane.kindX + 8
                width: pane.kindW - 12
                anchors.verticalCenter: parent.verticalCenter
                text: kindFull.width > width ? rowItem.kindShort : rowItem.kind
                elide: Text.ElideMiddle
                color: rowItem.softInk
                TextMetrics { id: kindFull; font: kindLabel.font; text: rowItem.kind }
            }
        }
    }
    // Over the rows and the empty space below them (not inside the list,
    // whose content ends with its last row).
    DropArea {
        id: drops
        anchors.fill: list
        keys: ["text/uri-list"]
        onEntered: (drag) => pane.dragOver(drag)
        onPositionChanged: (drag) => pane.dragOver(drag)
        onExited: pane.dropRow = -1
        onDropped: (drop) => {
            const row = pane.dropRow;
            pane.dropRow = -1;
            drop.accept(pane.finder.dropOn(drop.urls, row >= 0 ? pane.model.urlAt(row) : pane.finder.url));
        }
    }
    // Into this folder: Finder rings the whole list.
    Rectangle {
        anchors.fill: list
        anchors.margins: 2
        radius: Finder.rowRadius
        color: "transparent"
        border.width: 3
        border.color: Theme.accent.bg
        visible: drops.containsDrag && pane.dropRow < 0 && !pane.finder.dragging
    }
}
