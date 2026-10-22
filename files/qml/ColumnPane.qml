import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// Finder's column view: the folders from the columns' root down to the
// window's side by side, each greying the item that leads on; then what the
// one item selected holds, or a preview of it if it's a file. The window's
// folder is the column in focus: keys, the selection and file operations
// work there as in the other views. Each column reads its own folder, and
// the window's model takes a column's listing as it moves into it.
FocusScope {
    id: pane

    required property var finder
    readonly property var model: finder.model

    function clean(u) { return u.toString().replace(/\/+$/, ""); }

    // The folders from the root down to the window's.
    readonly property var chain: {
        const root = clean(finder.columnRoot), here = clean(finder.url);
        if (here !== root && !here.startsWith(root + "/") && !(root === "file://" && here.startsWith("file:///")))
            return [here];
        const out = [root];
        let at = root;
        for (const part of here.slice(root.length).split("/").filter(s => s !== "")) {
            at += "/" + part;
            out.push(at);
        }
        return out;
    }
    // ... and after them the one item selected: a folder's column, or a file's preview.
    readonly property var wanted: {
        const list = chain.map(u => ({ url: u, preview: false }));
        const one = Object.keys(finder.selectedSet);
        if (one.length === 1 && finder.current >= 0)
            list.push({ url: clean(one[0]), preview: !finder.model.isDirAt(finder.current) });
        return list;
    }
    readonly property int focusIndex: chain.length - 1

    // The columns shown, kept in step with wanted at the end of each change
    // (a move into a column passes through no selection on its way), so a
    // column that stays keeps its place, its scroll and its reading.
    ListModel { id: columns }
    onWantedChanged: Qt.callLater(sync)
    Component.onCompleted: sync()
    function sync() {
        let keep = 0;
        while (keep < columns.count && keep < wanted.length
               && columns.get(keep).url === wanted[keep].url && columns.get(keep).preview === wanted[keep].preview)
            ++keep;
        if (keep < columns.count)
            columns.remove(keep, columns.count - keep);
        for (let i = keep; i < wanted.length; ++i)
            columns.append({ url: wanted[i].url, preview: wanted[i].preview, w: Finder.columnWidth });
        Qt.callLater(reveal);
    }

    // The focused column and the one after it in view, scrolling as little
    // as it takes.
    function reveal() {
        if (columns.count === 0)
            return;
        let x = 0;
        for (let i = 0; i < Math.min(focusIndex, columns.count); ++i)
            x += columns.get(i).w;
        let end = 0;
        for (let i = 0; i < columns.count; ++i)
            end += columns.get(i).w;
        let to = strip.contentX;
        if (end - to > strip.width)
            to = end - strip.width;
        if (x < to)
            to = x;
        to = Math.max(0, Math.min(to, end - strip.width));
        if (Math.abs(to - strip.contentX) > 0.5) {
            scroll.to = to;
            scroll.restart();
        }
    }
    NumberAnimation { id: scroll; target: strip; property: "contentX"; duration: Theme.fade.base; easing.type: Easing.OutCubic }

    // The window's row in the focused column.
    function positionAt(row) {
        const col = repeater.itemAt(focusIndex);
        if (col && !col.preview)
            col.positionAt(finder.model.urlAt(row));
        reveal();
    }

    Flickable {
        id: strip
        anchors.fill: parent
        contentWidth: lane.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton // the mouse drags items; the touchpad scrolls
        clip: true

        Row {
            id: lane
            height: strip.height
            Repeater {
                id: repeater
                model: columns
                delegate: Item {
                    id: slot
                    required property int index
                    required property string url
                    required property bool preview
                    required property real w
                    width: w
                    height: lane.height
                    function positionAt(target) { loader.item?.positionAt?.(target); }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        sourceComponent: slot.preview ? previewColumn : folderColumn
                    }
                    Component {
                        id: folderColumn
                        FolderColumn {
                            owner: pane
                            index: slot.index
                            url: slot.url
                        }
                    }
                    Component {
                        id: previewColumn
                        PreviewColumn { owner: pane }
                    }

                    // The divider on the column's right; dragging it sizes
                    // the column (with Option, every column).
                    Rectangle {
                        x: parent.width - 1
                        y: Finder.columnTop
                        width: 1
                        height: parent.height - y
                        color: Finder.separator
                    }
                    Item {
                        x: parent.width - 4
                        y: Finder.columnTop
                        width: 8
                        height: parent.height - y
                        HoverHandler { cursorShape: Qt.SizeHorCursor }
                        DragHandler {
                            property real from: 0
                            target: null
                            yAxis.enabled: false
                            cursorShape: Qt.SizeHorCursor
                            onActiveChanged: if (active) from = slot.w
                            onTranslationChanged: {
                                if (!active)
                                    return;
                                const w = Math.max(Finder.columnMin, from + translation.x);
                                if (centroid.modifiers & Qt.AltModifier) {
                                    for (let i = 0; i < columns.count; ++i)
                                        columns.setProperty(i, "w", w);
                                } else {
                                    columns.setProperty(slot.index, "w", w);
                                }
                            }
                        }
                    }
                }
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
    }

    // One folder's column.
    component FolderColumn: Item {
        id: col

        required property var owner // the ColumnPane (inline components can't see its id)
        required property int index
        required property string url
        readonly property bool focused: index === owner.focusIndex
        // In a column before the focused one, the item leading on.
        readonly property string lead: index < owner.focusIndex && index + 1 < owner.wanted.length ? owner.wanted[index + 1].url : ""

        anchors.fill: parent

        FolderModel {
            id: folder
            url: col.url
            sortColumn: owner.model.sortColumn
            ascending: owner.model.ascending
            showHidden: owner.model.showHidden
        }

        function positionAt(target) {
            const row = folder.rowsOf([target])[0];
            if (row >= 0)
                list.positionViewAtIndex(row, ListView.Contain);
        }
        // A row's place in the window's folder (the focused column's rows
        // are the window's, read separately).
        function windowRow(row) {
            return row < 0 ? -1 : owner.model.rowsOf([folder.urlAt(row)])[0];
        }
        // Into this column, with this row's item selected (or none).
        function take(row) {
            owner.finder.browse(col.url, row >= 0 ? folder.urlAt(row) : null);
            return windowRow(row);
        }

        ListView {
            id: list
            y: Finder.columnTop
            width: parent.width
            height: parent.height - y
            topMargin: Finder.columnRowsTop - Finder.columnTop
            bottomMargin: 6
            clip: true
            model: folder
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            acceptedButtons: Qt.NoButton
            keyNavigationEnabled: false
            // No current item: a view gives its current item the keyboard
            // whenever its rows change, which would close a name being edited.
            currentIndex: -1
            highlightFollowsCurrentItem: false

            function rowAt(point) { return indexAt(point.x, point.y + contentY); }
            function onName(row, x) {
                const item = itemAtIndex(row);
                return item !== null && x >= item.nameStart && x <= item.nameEnd;
            }

            // A click selects in the focused column (with Ctrl or Shift, adds
            // to the selection), and moves the window into any other; a
            // click on the name of the one item selected renames it.
            TapHandler {
                id: tap
                acceptedModifiers: Qt.KeyboardModifierMask
                onTapped: (point) => {
                    const row = list.rowAt(point.position);
                    renameSoon.stop();
                    if (!col.focused) {
                        col.take(row);
                        return;
                    }
                    const at = col.windowRow(row);
                    if (at < 0) {
                        owner.finder.clearSelection();
                        return;
                    }
                    const again = owner.finder.selectedCount === 1 && owner.finder.selected[at] === true
                        && tap.point.modifiers === Qt.NoModifier && list.onName(row, point.position.x);
                    owner.finder.click(at, tap.point.modifiers);
                    if (again) {
                        renameSoon.row = at;
                        renameSoon.start();
                    }
                }
                onDoubleTapped: (point) => {
                    renameSoon.stop();
                    const at = col.focused ? col.windowRow(list.rowAt(point.position)) : col.take(list.rowAt(point.position));
                    if (at >= 0)
                        owner.finder.open(at);
                }
            }
            Timer {
                id: renameSoon
                property int row: -1
                interval: 600
                onTriggered: owner.finder.beginRename(row)
            }
            DragHandler {
                target: null
                enabled: !owner.finder.renaming
                onActiveChanged: {
                    if (!active)
                        return;
                    renameSoon.stop();
                    const row = list.rowAt(centroid.pressPosition);
                    if (row < 0)
                        return;
                    const at = col.focused ? col.windowRow(row) : col.take(row);
                    if (at >= 0)
                        owner.finder.startDrag(at);
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
                required property bool isDir
                required property string badge
                required property url url
                readonly property string key: owner.clean(url)
                // Selected in the focused column; leading on in an earlier one.
                readonly property bool chosen: col.focused ? owner.finder.selectedSet[url.toString()] === true : key === col.lead
                readonly property bool lit: (chosen && col.focused && owner.finder.looksActive) || drops.row === index
                readonly property bool renaming: col.focused && owner.finder.renaming && owner.finder.editing.toString() === url.toString()
                readonly property real nameStart: nameLabel.x
                readonly property real nameEnd: nameLabel.x + nameLabel.paintedWidth

                width: list.width
                height: Finder.columnRow

                Rectangle {
                    x: Finder.columnInset
                    width: parent.width - 2 * Finder.columnInset
                    height: parent.height
                    radius: Finder.rowRadius
                    visible: rowItem.chosen || drops.row === rowItem.index
                    color: rowItem.lit ? Theme.accent.bg : Finder.selectionInactive
                }
                readonly property color ink: lit ? Theme.accent.fg : Theme.color.label.primary

                FileIcon {
                    x: Finder.columnIconX
                    anchors.verticalCenter: parent.verticalCenter
                    size: Finder.columnIcon
                    kind: rowItem.isDir ? "folder" : "document"
                    badge: rowItem.badge
                }
                Label {
                    id: nameLabel
                    visible: !rowItem.renaming
                    x: Finder.columnText
                    width: parent.width - x - Finder.columnChevron - 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.name
                    elide: Text.ElideMiddle
                    color: rowItem.ink
                }
                Loader {
                    active: rowItem.renaming
                    x: nameLabel.x - 5
                    width: Math.min(item ? item.implicitWidth : 0, parent.width - x - Finder.columnInset - 2)
                    height: Finder.columnRow - 4
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: RenameField {
                        finder: owner.finder
                        name: rowItem.name
                        isDir: rowItem.isDir
                    }
                }
                Glyph {
                    visible: rowItem.isDir
                    x: parent.width - Finder.columnChevron - width
                    anchors.verticalCenter: parent.verticalCenter
                    name: "disclosure"
                    size: 12
                    color: rowItem.lit ? Theme.accent.fg : Theme.color.label.secondary
                }
            }
        }

        // Drops: on a folder's row, into it; anywhere else in the column,
        // into the column's folder (ringed, as Finder does).
        DropArea {
            id: drops
            property int row: -1
            anchors.fill: list
            keys: ["text/uri-list"]
            function over(drag) {
                const at = list.indexAt(drag.x, drag.y + list.contentY);
                row = at >= 0 && folder.isDirAt(at) && !(owner.finder.dragging && owner.finder.selectedSet[folder.urlAt(at).toString()]) ? at : -1;
                drag.accept(Qt.MoveAction);
            }
            onEntered: (drag) => over(drag)
            onPositionChanged: (drag) => over(drag)
            onExited: row = -1
            onDropped: (drop) => {
                const at = row;
                row = -1;
                drop.accept(owner.finder.dropOn(drop.urls, at >= 0 ? folder.urlAt(at) : Qt.url(col.url)));
            }
        }
        Rectangle {
            anchors.fill: list
            anchors.margins: 2
            radius: Finder.rowRadius
            color: "transparent"
            border.width: 3
            border.color: Theme.accent.bg
            visible: drops.containsDrag && drops.row < 0 && !(owner.finder.dragging && col.focused)
        }
    }

    // The one file selected: its icon, name, kind and size, and dates.
    component PreviewColumn: Item {
        id: preview
        required property var owner
        anchors.fill: parent
        readonly property var info: owner.finder.current >= 0 && owner.finder.selectedCount === 1 ? owner.model.infoAt(owner.finder.current) : ({})

        Column {
            x: 16
            y: Finder.columnRowsTop + 22
            width: parent.width - 32
            spacing: 6

            FileIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Finder.previewIcon
                kind: preview.info.isDir ? "folder" : "document"
                badge: preview.info.badge ?? ""
            }
            Item { width: 1; height: 8 }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: preview.info.name ?? ""
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideMiddle
                font.weight: 700
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: [preview.info.kind, preview.info.sizeText].filter(s => s && s !== "--").join(" – ")
                elide: Text.ElideRight
                color: Theme.color.label.secondary
            }
            Item { width: 1; height: 10 }
            Label {
                text: "Information"
                style: Theme.text.caption
                font.weight: 700
                color: Theme.color.label.secondary
            }
            Rectangle { width: parent.width; height: 1; color: Finder.separator }
            Item {
                width: parent.width
                height: Finder.columnRow
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Modified"
                    color: Theme.color.label.secondary
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: preview.info.dateText ?? ""
                }
            }
        }
    }
}
