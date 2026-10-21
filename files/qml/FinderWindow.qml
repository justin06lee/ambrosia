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
                App.shown(win, loadMs);
            }
        }
    }
    property bool shownOnce: false

    onVisibleChanged: if (visible) App.decorate(win, Finder.windowRadius)
    Component.onCompleted: if (visible) App.decorate(win, Finder.windowRadius)

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Finder.windowRadius
        color: Finder.content
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

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

    Item {
        focus: true
        Keys.onPressed: (event) => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;
            const columns = win.view === "icon" ? Math.max(1, Math.floor((main.width - Finder.iconLeft) / Finder.iconCell)) : 1;
            switch (event.key) {
            case Qt.Key_Down:
                if (ctrl) win.openSelection();
                else win.select(win.current < 0 ? 0 : Math.min(folder.count - 1, win.current + columns), shift, false);
                break;
            case Qt.Key_Up:
                if (ctrl) win.up();
                else win.select(win.current < 0 ? folder.count - 1 : Math.max(0, win.current - columns), shift, false);
                break;
            case Qt.Key_Right:
                if (win.view === "icon") win.select(Math.min(folder.count - 1, win.current + 1), shift, false);
                break;
            case Qt.Key_Left:
                if (win.view === "icon") win.select(Math.max(0, win.current - 1), shift, false);
                break;
            case Qt.Key_BracketLeft:
                if (ctrl) win.back();
                break;
            case Qt.Key_BracketRight:
                if (ctrl) win.forward();
                break;
            case Qt.Key_1:
                if (ctrl) win.view = "icon";
                break;
            case Qt.Key_2:
                if (ctrl) win.view = "list";
                break;
            case Qt.Key_O:
                if (ctrl) win.openSelection();
                break;
            case Qt.Key_N:
                if (ctrl && !shift) App.openWindow(win.url);
                break;
            case Qt.Key_W:
                if (ctrl) win.close();
                break;
            case Qt.Key_A:
                if (ctrl) {
                    const all = {};
                    for (let i = 0; i < folder.count; ++i) all[i] = true;
                    win.selected = all;
                }
                break;
            case Qt.Key_Period:
            case Qt.Key_Greater:
                if (ctrl && shift) folder.showHidden = !folder.showHidden;
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
}
