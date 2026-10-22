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
    readonly property real kindX: stripeRight - Finder.kindColumn
    readonly property real sizeX: kindX - Finder.sizeColumn
    readonly property real dateX: sizeX - Finder.dateColumn

    function positionAt(row) { list.positionViewAtIndex(row, ListView.Contain); }

    // A narrow date column takes a shorter date, as Finder's does.
    readonly property real dateWidth: Finder.dateColumn - 12
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
                { column: "name", title: "Name", x: Finder.nameText, end: pane.dateX },
                { column: "date", title: "Date Modified", x: pane.dateX + 8, end: pane.sizeX },
                { column: "size", title: "Size", x: pane.sizeX + 7.5, end: pane.kindX },
                { column: "kind", title: "Kind", x: pane.kindX + 8, end: pane.stripeRight },
            ]
            Item {
                id: column
                required property var modelData
                required property int index
                readonly property bool sorted: pane.model.sortColumn === modelData.column
                x: index === 0 ? 0 : modelData.x - 8
                width: modelData.end - x
                height: header.height

                Label {
                    x: column.modelData.x - column.x
                    anchors.verticalCenter: parent.verticalCenter
                    text: column.modelData.title
                    style: Theme.text.caption
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
                    onTapped: {
                        if (column.sorted)
                            pane.model.ascending = !pane.model.ascending;
                        else
                            pane.model.sortColumn = column.modelData.column;
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
        currentIndex: pane.finder.current
        highlightFollowsCurrentItem: false
        keyNavigationEnabled: false

        // Whether a point in a row is on its disclosure triangle.
        function onTriangle(row, x) {
            if (row < 0 || !pane.model.isDirAt(row))
                return false;
            const depth = list.itemAtIndex(row)?.depth ?? 0;
            return Math.abs(x - (Finder.disclosureX + depth * Finder.indent)) <= 9;
        }

        // One handler for the whole list: a row's click selects it (with
        // Ctrl or Shift, adds to the selection), a double click opens it,
        // and a click below the rows clears the selection. A click on a
        // folder's triangle opens it in place (with Option, everything in
        // it too) and leaves the selection alone.
        TapHandler {
            id: tap
            acceptedModifiers: Qt.KeyboardModifierMask
            onTapped: (point) => {
                const row = list.indexAt(point.position.x, point.position.y + list.contentY);
                if (list.onTriangle(row, point.position.x))
                    pane.model.setExpanded(row, !pane.model.isExpanded(row), tap.point.modifiers & Qt.AltModifier);
                else if (row < 0)
                    pane.finder.clearSelection();
                else
                    pane.finder.click(row, tap.point.modifiers);
            }
            onDoubleTapped: (point) => {
                const row = list.indexAt(point.position.x, point.position.y + list.contentY);
                if (row >= 0 && !list.onTriangle(row, point.position.x))
                    pane.finder.open(row);
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
            readonly property bool selected: pane.finder.selected[index] === true

            width: list.width
            height: Finder.row

            Rectangle {
                x: pane.stripeLeft
                width: pane.stripeRight - pane.stripeLeft
                height: parent.height
                radius: Finder.rowRadius
                visible: rowItem.selected
                color: pane.finder.active ? Theme.accent.bg : Finder.selectionInactive
            }
            readonly property color ink: selected && pane.finder.active ? Theme.accent.fg : Theme.color.label.primary
            readonly property color softInk: selected && pane.finder.active ? Theme.accent.fg : Theme.color.label.secondary

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
                x: Finder.nameText + rowItem.indent
                width: pane.dateX - x - 8
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.name
                elide: Text.ElideMiddle
                color: rowItem.ink
            }
            Label {
                x: pane.dateX + 8
                width: Finder.dateColumn - 12
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.dateText
                elide: Text.ElideRight
                color: rowItem.softInk
            }
            Label {
                x: pane.sizeX
                width: Finder.sizeColumn - 4.5
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: rowItem.sizeText
                color: rowItem.softInk
            }
            // Finder cuts a kind in the middle, after trying its short name.
            Label {
                id: kindLabel
                x: pane.kindX + 8
                width: Finder.kindColumn - 12
                anchors.verticalCenter: parent.verticalCenter
                text: kindFull.width > width ? rowItem.kindShort : rowItem.kind
                elide: Text.ElideMiddle
                color: rowItem.softInk
                TextMetrics { id: kindFull; font: kindLabel.font; text: rowItem.kind }
            }
        }
    }
}
