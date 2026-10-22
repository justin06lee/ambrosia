import QtQuick
import QtQuick.Window
import Ambrosia
import Files

// One Finder window: the floating sidebar, the toolbar, the folder in the
// chosen view and the path bar, on a frameless window that draws its own
// corners (KWin draws the shadow; App.decorate asks for it).
Window {
    id: win

    required property url startUrl
    property url url: startUrl
    property string view: "list"
    property bool first: false
    // The Columns view's first column. Going somewhere (the sidebar, Back,
    // the path bar) starts the columns there; moving through them doesn't.
    property url columnRoot: startUrl
    onViewChanged: {
        if (view === "column")
            columnRoot = url;
        galleryKeep();
    }
    // View > Show Preview: the pane on the gallery's right, and the Columns
    // view's last column for a file. The pane hides when the window is too
    // narrow for it.
    property bool showPreview: true
    readonly property bool previewShown: view === "gallery" && showPreview
        && main.width - Finder.previewPane >= Finder.previewPaneMinContent

    // Back and forward, as Finder keeps them per window.
    property var history: [startUrl]
    property int historyIndex: 0
    readonly property bool canGoBack: historyIndex > 0
    readonly property bool canGoForward: historyIndex < history.length - 1

    // The selection: rows → true, the row keys act on, and where a Shift
    // range starts.
    property var selected: ({})
    property int current: -1
    property int anchor: -1
    readonly property int selectedCount: Object.keys(selected).length
    // The selection's items by URL, for views showing other models' rows.
    readonly property var selectedSet: {
        const set = {};
        for (const row of Object.keys(selected))
            set[folder.urlAt(Number(row)).toString()] = true;
        return set;
    }
    readonly property bool hasSelection: selectedCount > 0
    // The item shown large (the gallery, the preview pane): the one the keys
    // act on, or else the first selected; and its roles (name, kind,
    // sizeText, …), read again whenever the selection is set again.
    readonly property int shownRow: selected[current] ? current : hasSelection ? Number(Object.keys(selected)[0]) : -1
    readonly property var shownInfo: shownRow >= 0 && selected ? folder.infoAt(shownRow) : ({})
    // Where New Folder, Paste and renaming work: folders on this computer.
    readonly property bool local: url.toString().startsWith("file:")
    readonly property bool inTrash: url.toString().startsWith("trash:")

    readonly property alias model: folder

    // A window keeps its active look while one of its menus is open, as on
    // a Mac: the menu bar's menu takes the keyboard, so Qt calls the window
    // inactive. The count clears whenever the window has the keyboard again.
    // (--active draws the first window active, for grabs.)
    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0 || (first && App.active)
    onActiveChanged: if (active) menusOpen = 0
    readonly property var window: win

    width: 920
    height: 580
    minimumWidth: Finder.minWidth
    minimumHeight: Finder.minHeight
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: folder.name

    Binding { target: Theme; property: "dark"; value: App.dark }
    Binding {
        // The system accent, as the nearest of Ambrosia's accents.
        target: Theme
        property: "accentName"
        when: App.accent.valid
        value: {
            const want = App.accent;
            let best = "blue", distance = 1e9;
            for (const name of ["blue", "purple", "pink", "red", "orange", "honey", "green", "graphite"]) {
                const c = Theme.lightColors.accents[name].bg;
                const d = (c.r - want.r) ** 2 + (c.g - want.g) ** 2 + (c.b - want.b) ** 2;
                if (d < distance) { distance = d; best = name; }
            }
            return best;
        }
    }

    function go(target) {
        const next = typeof target === "string" ? Qt.url(target) : target;
        if (next.toString() === url.toString())
            return;
        history = history.slice(0, historyIndex + 1).concat([next]);
        historyIndex = history.length - 1;
        show_(next, "");
    }
    function back() {
        if (!canGoBack)
            return;
        const from = url;
        historyIndex -= 1;
        show_(history[historyIndex], from);
    }
    function forward() {
        if (!canGoForward)
            return;
        historyIndex += 1;
        show_(history[historyIndex], "");
    }
    function up() {
        const s = url.toString().replace(/\/+$/, "");
        const cut = s.lastIndexOf("/");
        if (cut < 0 || s.endsWith(":") || s === "file://")
            return;
        // Coming up out of a folder selects it, as Finder does.
        reselect = decodeURIComponent(s.slice(cut + 1));
        go(cut <= 7 && s.startsWith("file://") ? "file:///" : s.slice(0, cut));
    }
    function parentOf(target) {
        const s = target.toString().replace(/\/+$/, "");
        const cut = s.lastIndexOf("/");
        return cut <= 7 && s.startsWith("file://") ? "file:///" : s.slice(0, cut);
    }
    property string reselect: ""
    function show_(target, from) {
        clearSelection();
        editing = "";
        pending = null;
        if (from !== "" && from.toString().startsWith(target.toString()))
            reselect = decodeURIComponent(from.toString().slice(target.toString().replace(/\/+$/, "").length + 1)).split("/")[0];
        columnRoot = target;
        galleryAt = 0;
        url = target;
        if (!folder.loading && reselect === "")
            galleryKeep(); // a folder already read shows at once
    }
    // The Columns view: the window moves to a folder one of its columns
    // shows, and selects item there (or, with first, its first item; or
    // nothing). The columns stay, and so does the place in the history.
    property bool selectFirst: false
    function browse(target, item, first) {
        const next = typeof target === "string" ? Qt.url(target) : target;
        // The folder can show (and select its first item) inside the move.
        const wantFirst = first === true;
        selectFirst = wantFirst;
        if (next.toString() !== url.toString()) {
            clearSelection();
            editing = "";
            pending = null;
            const h = history.slice();
            h[historyIndex] = next;
            history = h;
            url = next;
        }
        if (item)
            selectWhenShown([item], false);
        else if (!wantFirst)
            clearSelection();
        else if (selectFirst && !folder.loading && folder.count > 0)
            firstShown();
    }
    // The gallery always shows an item: when the one it showed goes, the
    // one now in its place; in a folder just shown, the first.
    property int galleryAt: 0
    onCurrentChanged: if (current >= 0) galleryAt = current
    function galleryKeep() {
        if (view === "gallery" && !hasSelection && !pending && folder.count > 0)
            select(Math.min(galleryAt, folder.count - 1), false, false);
    }
    function firstShown() {
        selectFirst = false;
        if (folder.count > 0)
            select(0, false, false);
    }
    // Into the folder selected, or out to the one around this one.
    function columnInto() {
        if (selectedCount === 1 && current >= 0 && folder.isDirAt(current))
            browse(folder.urlAt(current), null, true);
    }
    function columnOut() {
        if (url.toString().replace(/\/+$/, "") !== columnRoot.toString().replace(/\/+$/, ""))
            browse(parentOf(url), url);
    }

    // Go menu places, by the sidebar's place for them.
    readonly property var placeAt: ({
        recents: [0, 0], desktop: [1, 0], documents: [1, 1], downloads: [1, 2],
        home: [2, 0], computer: [2, 1], trash: [2, 2],
    })
    function goPlace(name) {
        const at = placeAt[name];
        go(Places.sections[at[0]].items[at[1]].url);
    }

    function clearSelection() {
        selected = {};
        current = -1;
        anchor = -1;
    }
    function select(row, extend, toggle) {
        if (row < 0 || row >= folder.count)
            return;
        let next = {};
        if (toggle) {
            next = Object.assign({}, selected);
            if (next[row])
                delete next[row];
            else
                next[row] = true;
            anchor = row;
        } else if (extend && anchor >= 0) {
            for (let i = Math.min(anchor, row); i <= Math.max(anchor, row); ++i)
                next[i] = true;
        } else {
            next[row] = true;
            anchor = row;
        }
        selected = next;
        current = row;
        pane.item.positionAt(row);
    }
    function click(row, modifiers) {
        select(row, modifiers & Qt.ShiftModifier, modifiers & Qt.ControlModifier);
    }
    function open(row) {
        const target = folder.urlAt(row);
        if (folder.isDirAt(row) && view === "column")
            browse(target, null, true);
        else if (folder.isDirAt(row))
            go(target);
        else
            App.openFile(target);
    }
    function openSelection() {
        for (const row of Object.keys(selected))
            open(Number(row));
    }
    // The selection's items, in row order.
    function selectedUrls() {
        return Object.keys(selected).map(Number).sort((a, b) => a - b).map(row => folder.urlAt(row));
    }

    // File operations (FileOps, through KIO, undoable). What one of them
    // makes in this folder is selected once the folder shows it: its reread
    // can come before the operation ends, or after.
    property var started: ({}) // FileOps id → {select, edit}
    function run(id, then) {
        if (id >= 0)
            started[id] = then ?? {};
    }
    Connections {
        target: FileOps
        function onFinished(id, urls, ok) {
            const then = win.started[id];
            if (then === undefined)
                return;
            delete win.started[id];
            if (ok && then.select && urls.length > 0)
                win.selectWhenShown(Array.from(urls), then.edit === true);
        }
    }
    property var pending: null
    function selectWhenShown(urls, edit) {
        pending = { urls: urls, edit: edit, until: Date.now() + 3000 };
        selectPending();
    }
    function selectPending() {
        if (!pending)
            return;
        const rows = folder.rowsOf(pending.urls).filter(row => row >= 0);
        if (rows.length < pending.urls.length && Date.now() < pending.until)
            return;
        const p = pending;
        pending = null;
        if (rows.length === 0)
            return;
        const next = {};
        for (const row of rows)
            next[row] = true;
        selected = next;
        current = rows[0];
        anchor = rows[0];
        pane.item.positionAt(rows[0]);
        if (p.edit)
            beginRename(rows[0]);
    }

    function newFolder() {
        if (local)
            run(FileOps.newFolder(url), { select: true, edit: true });
    }
    function duplicate() {
        if (hasSelection && local)
            run(FileOps.duplicate(selectedUrls()), { select: true });
    }
    function trashSelection() {
        if (!hasSelection)
            return;
        run(inTrash ? FileOps.putBack(selectedUrls()) : FileOps.trash(selectedUrls()));
    }
    function copySelection() {
        if (hasSelection)
            FileOps.copyToClipboard(selectedUrls());
    }
    function paste(move) {
        if (local)
            run(FileOps.paste(url, move), { select: true });
    }

    // Renaming in place: the item whose name is being edited, and its field.
    property url editing: ""
    property var editor: null
    readonly property bool renaming: editing.toString() !== ""
    function beginRename(row) {
        if (row < 0 || !folder.urlAt(row).toString().startsWith("file:"))
            return;
        select(row, false, false);
        editing = folder.urlAt(row);
    }
    function renameSelection() {
        if (selectedCount === 1)
            beginRename(Number(Object.keys(selected)[0]));
    }
    // The field is done: text is the new name, or undefined to keep the old.
    function endRename(text) {
        const target = editing;
        editing = "";
        pane.forceActiveFocus();
        if (text !== undefined)
            run(FileOps.rename(target, text), { select: true });
    }

    // Dragging items out: a real drag (text/uri-list) that this and other
    // windows, other apps and the Dock's Trash take; whoever takes it does
    // the work.
    property bool dragging: false
    property var dragUrls: []
    Item {
        id: dragItem
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.mimeData: ({ "text/uri-list": win.dragUrls.map(u => u.toString()).join("\r\n") })
        Drag.imageSourceSize: Qt.size(48, 48)
        Drag.onDragFinished: win.dragging = false
    }
    function startDrag(row) {
        if (!selected[row])
            select(row, false, false);
        dragUrls = selectedUrls();
        dragItem.Drag.imageSource = "qrc:/qt/qml/Files/art/" + (folder.isDirAt(row) ? "folder" : "document") + ".svg";
        dragging = true;
        dragItem.Drag.active = true;
    }
    // Items dropped on a folder (dir): moved within a disk, copied across
    // disks or with Option held, as Finder does; on the Trash, trashed.
    // Returns the action taken, for the drag's source.
    function dropOn(urls, dir) {
        urls = Array.from(urls);
        if (urls.length === 0)
            return Qt.IgnoreAction;
        if (dir.toString().startsWith("trash:")) {
            run(FileOps.trash(urls));
            return Qt.MoveAction;
        }
        const copy = (App.modifiers() & Qt.AltModifier) || !FileOps.dropMoves(urls, dir);
        const here = dir.toString() === url.toString();
        run(copy ? FileOps.copy(urls, dir) : FileOps.move(urls, dir), { select: here });
        return copy ? Qt.CopyAction : Qt.MoveAction;
    }

    MenuBar { finder: win }

    // Runs a command once per key press: the menu bar's shortcut and the
    // window's key handler can both see the same press.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        if (renaming) {
            // ⌘⌫ deletes a word in the name field; it never trashes then.
            if (name === "trash")
                return;
            editor?.commit();
        }
        run();
    }
    function selectAll() {
        const all = {};
        for (let i = 0; i < folder.count; ++i)
            all[i] = true;
        selected = all;
    }

    FolderModel {
        id: folder
        url: win.url
        onLoaded: {
            if (win.reselect !== "") {
                const row = indexOf(win.reselect);
                win.reselect = "";
                if (row >= 0)
                    win.select(row, false, false);
            }
            win.selectPending();
            if (win.selectFirst && !win.hasSelection)
                win.firstShown();
            win.galleryKeep();
            if (!win.shownOnce) {
                win.shownOnce = true;
                if (win.first) {
                    win.pendingExpand = App.expand;
                    win.expandPending();
                    if (App.select !== "")
                        win.select(indexOf(App.select), false, false);
                }
                App.shown(win, loadMs, firstMs);
            }
        }
    }
    property bool shownOnce: false

    // --expand: opens the given folders in place as their rows appear.
    property var pendingExpand: []
    function expandPending() {
        const base = folder.url.toString().replace(/\/+$/, "");
        const left = [];
        for (const path of pendingExpand) {
            let row = -1;
            for (let i = 0; i < folder.count && row < 0; ++i)
                if (decodeURIComponent(folder.urlAt(i).toString()) === decodeURIComponent(base + "/" + path))
                    row = i;
            if (row >= 0)
                folder.setExpanded(row, true, false);
            else
                left.push(path);
        }
        pendingExpand = left;
    }

    // Rows coming and going above the selection (a folder opening in place)
    // move it with its items.
    function shiftRows(first, count) {
        const move = (row) => row >= first ? (count < 0 && row < first - count ? -1 : row + count) : row;
        const next = {};
        for (const key of Object.keys(selected)) {
            const row = move(Number(key));
            if (row >= 0)
                next[row] = true;
        }
        selected = next;
        current = current < 0 ? -1 : move(current);
        anchor = anchor < 0 ? -1 : move(anchor);
    }
    // A reset (a reread changed too much to line up) keeps the selection
    // by its items.
    property var keepSelected: []
    Connections {
        target: folder
        function onRowsInserted(parent, first, last) {
            win.shiftRows(first, last - first + 1);
            if (win.pendingExpand.length > 0)
                Qt.callLater(win.expandPending);
            if (win.pending)
                Qt.callLater(win.selectPending);
        }
        function onRowsRemoved(parent, first, last) {
            win.shiftRows(first, -(last - first + 1));
            Qt.callLater(win.galleryKeep);
        }
        function onModelAboutToBeReset() { win.keepSelected = win.selectedUrls(); }
        function onModelReset() {
            const urls = win.keepSelected;
            win.keepSelected = [];
            win.clearSelection();
            Qt.callLater(win.galleryKeep);
            if (urls.length === 0)
                return;
            const next = {};
            for (const row of folder.rowsOf(urls))
                if (row >= 0)
                    next[row] = true;
            win.selected = next;
            const rows = Object.keys(next).map(Number);
            if (rows.length > 0)
                win.current = win.anchor = Math.min(...rows);
        }
    }

    onVisibleChanged: if (visible) App.decorate(win, Finder.windowRadius)
    Component.onCompleted: if (visible) App.decorate(win, Finder.windowRadius)

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Finder.windowRadius
        color: Finder.content
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

        Keys.onPressed: (event) => win.keyPressed(event)

        // What Finder's status bar says, for screen readers, and for
        // files/bench/probe.py, which times every app by when it says it.
        Accessible.role: Accessible.Pane
        Accessible.name: folder.loading ? "" : folder.count.toLocaleString(Qt.locale("en_US"), "f", 0) + " items"

        // The window moves by its toolbar's empty space.
        DragHandler {
            target: null
            onActiveChanged: if (active) win.startSystemMove()
        }

        // The sidebar: the floating inset glass panel (macOS 26's Finder)
        // or, with --sidebar flush, the flush one along the window's edge, a
        // stub for now. Both take the window and fill this space.
        Loader {
            id: sidebar
            readonly property bool flush: App.sidebar === "flush"
            x: flush ? 0 : Finder.sidebarInset
            y: x
            width: flush ? Finder.sidebarInset + Finder.sidebarWidth : Finder.sidebarWidth
            height: parent.height - 2 * y
            sourceComponent: flush ? flushSidebar : floatingSidebar
        }
        Component {
            id: floatingSidebar
            Sidebar { finder: win }
        }
        Component {
            id: flushSidebar
            SidebarFlush { finder: win }
        }

        Item {
            id: main
            x: sidebar.x + sidebar.width
            width: parent.width - x
            height: parent.height

            Loader {
                id: pane
                anchors.fill: parent
                anchors.bottomMargin: Finder.pathBar
                anchors.rightMargin: win.previewShown ? Finder.previewPane : 0
                focus: true
                sourceComponent: ({ icon: iconPane, column: columnPane, gallery: galleryPane })[win.view] ?? listPane
            }
            Component {
                id: galleryPane
                GalleryPane { finder: win; focus: true }
            }
            Component {
                id: columnPane
                ColumnPane { finder: win; focus: true }
            }
            Component {
                id: listPane
                ListPane { finder: win; focus: true }
            }
            Component {
                id: iconPane
                IconPane { finder: win; focus: true }
            }

            PreviewPane {
                visible: win.previewShown
                x: parent.width - width
                width: Finder.previewPane
                height: parent.height
                finder: win
            }

            Toolbar {
                x: Finder.toolbarGap
                width: parent.width - x
                finder: win
            }

            Label {
                visible: folder.error !== ""
                anchors.centerIn: pane
                text: folder.error
                color: Theme.color.label.secondary
            }

            PathBar {
                anchors.bottom: parent.bottom
                width: parent.width - (win.previewShown ? Finder.previewPane : 0)
                finder: win
            }
        }

        // Resizing by the edges and corners.
        Repeater {
            model: [
                { edges: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.TopEdge, x: 8, y: 0, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.TopEdge | Qt.LeftEdge, x: 0, y: 0, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
                { edges: Qt.TopEdge | Qt.RightEdge, x: -10, y: 0, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: -10, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.RightEdge, x: -10, y: -10, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
            ]
            Item {
                required property var modelData
                x: modelData.x < 0 ? frame.width + modelData.x : modelData.x
                y: modelData.y < 0 ? frame.height + modelData.y : modelData.y
                width: modelData.w < 0 ? frame.width + modelData.w : modelData.w
                height: modelData.h < 0 ? frame.height + modelData.h : modelData.h
                HoverHandler { cursorShape: parent.modelData.shape }
                DragHandler {
                    target: null
                    onActiveChanged: if (active) win.startSystemResize(parent.modelData.edges)
                }
            }
        }
    }

    // Keyboard, Finder's keys (Ctrl stands for Command, as everywhere in
    // Ambrosia).
    property string typed: ""
    Timer { id: typeReset; interval: 1000; onTriggered: win.typed = "" }

    // On the frame, the focused pane's keys come here unless it took them.
    function keyPressed(event) {
        if (renaming)
            return; // the name field's keys
        // Command is Ctrl (what the Mac-first keyboard gives apps), or
        // Super itself.
        const ctrl = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
        const shift = event.modifiers & Qt.ShiftModifier;
        const alt = event.modifiers & Qt.AltModifier;
        const columns = win.view === "icon" ? Math.max(1, Math.floor((main.width - Finder.iconLeft) / Finder.iconCell)) : 1;
        switch (event.key) {
        case Qt.Key_Down:
            if (ctrl) win.openSelection();
            else win.select(win.current < 0 ? 0 : Math.min(folder.count - 1, win.current + columns), shift, false);
            break;
        case Qt.Key_Up:
            if (ctrl) win.act("up", win.up);
            else win.select(win.current < 0 ? folder.count - 1 : Math.max(0, win.current - columns), shift, false);
            break;
        case Qt.Key_Right:
            if (win.view === "column") win.columnInto();
            else if (win.view === "icon" || win.view === "gallery") win.select(Math.min(folder.count - 1, win.current + 1), shift, false);
            else if (win.current >= 0) folder.setExpanded(win.current, true, event.modifiers & Qt.AltModifier);
            break;
        case Qt.Key_Left:
            if (win.view === "column") win.columnOut();
            else if (win.view === "icon" || win.view === "gallery") win.select(Math.max(0, win.current - 1), shift, false);
            else if (win.current >= 0 && folder.isExpanded(win.current)) folder.setExpanded(win.current, false, event.modifiers & Qt.AltModifier);
            else if (folder.parentRow(win.current) >= 0) win.select(folder.parentRow(win.current), false, false);
            break;
        case Qt.Key_BracketLeft:
            if (ctrl) win.act("back", win.back);
            break;
        case Qt.Key_BracketRight:
            if (ctrl) win.act("forward", win.forward);
            break;
        case Qt.Key_1:
            if (ctrl) win.act("icons", () => win.view = "icon");
            break;
        case Qt.Key_2:
            if (ctrl) win.act("list", () => win.view = "list");
            break;
        case Qt.Key_3:
            if (ctrl) win.act("columns", () => win.view = "column");
            break;
        case Qt.Key_4:
            if (ctrl) win.act("gallery", () => win.view = "gallery");
            break;
        case Qt.Key_P:
            if (ctrl && shift) win.act("preview", () => win.showPreview = !win.showPreview);
            break;
        case Qt.Key_O:
            if (ctrl && shift) win.act("documents", () => win.goPlace("documents"));
            else if (ctrl) win.act("open", win.openSelection);
            break;
        case Qt.Key_F:
            if (ctrl && shift) win.act("recents", () => win.goPlace("recents"));
            break;
        case Qt.Key_D:
            if (ctrl && shift) win.act("desktop", () => win.goPlace("desktop"));
            else if (ctrl) win.act("duplicate", win.duplicate);
            break;
        case Qt.Key_L:
            if (ctrl && alt) win.act("downloads", () => win.goPlace("downloads"));
            break;
        case Qt.Key_H:
            if (ctrl && shift) win.act("home", () => win.goPlace("home"));
            break;
        case Qt.Key_C:
            if (ctrl && shift) win.act("computer", () => win.goPlace("computer"));
            else if (ctrl) win.act("copy", win.copySelection);
            break;
        case Qt.Key_V:
            if (ctrl && alt) win.act("moveHere", () => win.paste(true));
            else if (ctrl) win.act("paste", () => win.paste(false));
            break;
        case Qt.Key_Z:
            if (ctrl && shift) win.act("redo", FileOps.redo);
            else if (ctrl) win.act("undo", FileOps.undo);
            break;
        case Qt.Key_N:
            if (ctrl && shift) win.act("newFolder", win.newFolder);
            else if (ctrl) win.act("new", () => App.openWindow(win.url));
            break;
        case Qt.Key_Backspace:
            if (ctrl) win.act("trash", win.trashSelection);
            else return;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (ctrl) win.act("open", win.openSelection);
            else win.act("rename", win.renameSelection);
            break;
        case Qt.Key_W:
            if (ctrl) win.act("close", win.close);
            break;
        case Qt.Key_A:
            if (ctrl) win.act("all", win.selectAll);
            break;
        case Qt.Key_Period:
        case Qt.Key_Greater:
            if (ctrl && shift) win.act("hidden", () => folder.showHidden = !folder.showHidden);
            break;
        case Qt.Key_Escape:
            if (win.view !== "gallery") win.clearSelection();
            break;
        default:
            // Type-select: typing a name's start selects it.
            if (!ctrl && event.text.length === 1 && event.text >= " ") {
                win.typed += event.text;
                typeReset.restart();
                const row = folder.match(win.typed, 0);
                if (row >= 0) win.select(row, false, false);
                break;
            }
            return;
        }
        event.accepted = true;
    }
}
