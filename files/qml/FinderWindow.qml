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
    readonly property bool hasSelection: Object.keys(selected).length > 0

    readonly property alias model: folder

    // A window keeps its active look while one of its menus is open, as on
    // a Mac: the menu bar's menu takes the keyboard, so Qt calls the window
    // inactive. The count clears whenever the window has the keyboard again.
    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0
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
        go(cut <= 7 && s.startsWith("file://") ? "file:///" : s.slice(0, cut));
        // Coming up out of a folder selects it, as Finder does.
        reselect = s.slice(cut + 1);
    }
    property string reselect: ""
    function show_(target, from) {
        clearSelection();
        if (from !== "" && from.toString().startsWith(target.toString()))
            reselect = decodeURIComponent(from.toString().slice(target.toString().replace(/\/+$/, "").length + 1)).split("/")[0];
        url = target;
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
        if (folder.isDirAt(row))
            go(target);
        else
            App.openFile(target);
    }
    function openSelection() {
        for (const row of Object.keys(selected))
            open(Number(row));
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
    Connections {
        target: folder
        function onRowsInserted(parent, first, last) {
            win.shiftRows(first, last - first + 1);
            if (win.pendingExpand.length > 0)
                Qt.callLater(win.expandPending);
        }
        function onRowsRemoved(parent, first, last) { win.shiftRows(first, -(last - first + 1)); }
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

        Sidebar {
            id: sidebar
            x: Finder.sidebarInset
            y: Finder.sidebarInset
            width: Finder.sidebarWidth
            height: parent.height - 2 * Finder.sidebarInset
            finder: win
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
                focus: true
                sourceComponent: win.view === "icon" ? iconPane : listPane
            }
            Component {
                id: listPane
                ListPane { finder: win; focus: true }
            }
            Component {
                id: iconPane
                IconPane { finder: win; focus: true }
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
                width: parent.width
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
            if (win.view === "icon") win.select(Math.min(folder.count - 1, win.current + 1), shift, false);
            else if (win.current >= 0) folder.setExpanded(win.current, true, event.modifiers & Qt.AltModifier);
            break;
        case Qt.Key_Left:
            if (win.view === "icon") win.select(Math.max(0, win.current - 1), shift, false);
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
        case Qt.Key_O:
            if (ctrl && shift) win.act("documents", () => win.goPlace("documents"));
            else if (ctrl) win.act("open", win.openSelection);
            break;
        case Qt.Key_F:
            if (ctrl && shift) win.act("recents", () => win.goPlace("recents"));
            break;
        case Qt.Key_D:
            if (ctrl && shift) win.act("desktop", () => win.goPlace("desktop"));
            break;
        case Qt.Key_L:
            if (ctrl && alt) win.act("downloads", () => win.goPlace("downloads"));
            break;
        case Qt.Key_H:
            if (ctrl && shift) win.act("home", () => win.goPlace("home"));
            break;
        case Qt.Key_C:
            if (ctrl && shift) win.act("computer", () => win.goPlace("computer"));
            break;
        case Qt.Key_N:
            if (ctrl && !shift) win.act("new", () => App.openWindow(win.url));
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
            win.clearSelection();
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
