import QtQuick
import QtQuick.Window
import Ambrosia
import Settings

// System Settings' window: the floating sidebar, the toolbar and the pane
// shown, on a frameless window that draws its own corners (KWin draws the
// shadow; App.decorate asks for it). As wide as System Settings, it only
// grows taller.
Window {
    id: win

    // The page shown (a pane, or a page inside one, as General › About),
    // and the sidebar's pane it belongs to.
    property string current: ""
    readonly property var page: Panes.find(current)
    readonly property string sidebarPane: Panes.parentOf[current] ?? current
    // A place in the page asked for after a "?", as System Settings' URLs
    // have (sound?input opens Sound on its Input side).
    property string anchor: ""

    // Back and forward, through the pages shown.
    property var history: []
    property int historyIndex: -1
    readonly property bool canGoBack: historyIndex > 0
    readonly property bool canGoForward: historyIndex < history.length - 1

    // A window keeps its active look while one of its menus is open, as on
    // a Mac (Files' FinderWindow does the same); --active draws it active
    // for grabs.
    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0 || App.active
    // Under a sheet, as on a Mac, the page and toolbar are dimmed and the
    // sidebar faded, none of them taking clicks (tap handlers under a sheet's
    // dim would still fire); close is grayed, minimize and zoom still work.
    property int sheetsOpen: 0
    readonly property bool underSheet: sheetsOpen > 0
    onActiveChanged: if (active) menusOpen = 0

    width: Look.windowWidth
    height: Look.windowHeight
    minimumWidth: Look.windowWidth
    maximumWidth: Look.windowWidth
    minimumHeight: Look.minHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: page ? page.name : "System Settings"

    readonly property Appearance appearance: Appearance {}
    MenuBar { settings: win }

    // Shows a page: ours in the window, or the KDE module standing in for a
    // pane we haven't built, in its own window (the window stays as it is).
    function paneOf(id) {
        return Panes.find(id.split("?")[0]);
    }
    function choose(asked) {
        const [id, anchor] = asked.split("?");
        const pane = Panes.find(id);
        if (!pane || !Panes.available(pane))
            return;
        if (pane.page === undefined) {
            App.openModule(pane.module);
            return;
        }
        win.anchor = "";
        win.anchor = anchor ?? "";
        if (id === current)
            return;
        history = history.slice(0, historyIndex + 1).concat([id]);
        historyIndex = history.length - 1;
        current = id;
    }
    function back() {
        if (canGoBack)
            current = history[--historyIndex];
    }
    function forward() {
        if (canGoForward)
            current = history[++historyIndex];
    }
    function findPane() {
        sidebar.search.focusField();
    }
    // The last action's name and time: a key that is also a menu item's
    // shortcut reaches both, and runs once (Files' act()).
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        run();
    }

    // Asked for a pane we haven't built (the shell's Network Settings…),
    // Settings opens only its KDE module; otherwise the window, on that
    // pane or on General.
    Component.onCompleted: {
        const first = paneOf(App.pane);
        if (first && first.page === undefined && Panes.available(first)) {
            choose(App.pane);
            Qt.callLater(Qt.quit);
            return;
        }
        choose(first ? App.pane : "general");
        visible = true;
    }
    onVisibleChanged: if (visible) App.decorate(win, Look.windowRadius)

    Connections {
        target: App
        function onShowRequested(pane) {
            const asked = paneOf(pane);
            if (asked)
                win.choose(pane);
            if (!asked || asked.page !== undefined)
                App.activate(win);
        }
    }

    Shortcut { sequences: ["Ctrl+[", "Meta+["]; enabled: !win.underSheet; onActivated: win.act("back", win.back) }
    Shortcut { sequences: ["Ctrl+]", "Meta+]"]; enabled: !win.underSheet; onActivated: win.act("forward", win.forward) }
    Shortcut { sequences: ["Ctrl+F", "Meta+F"]; enabled: !win.underSheet; onActivated: win.act("find", win.findPane) }
    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; enabled: !win.underSheet; onActivated: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", Qt.quit) }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Look.windowRadius
        color: Look.window
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

        // The window moves by its toolbar's empty space and the sidebar's.
        // Off under a sheet: they'd take its clicks too (and its focus).
        DragHandler {
            target: null
            enabled: !win.underSheet
            onActiveChanged: if (active) win.startSystemMove()
        }
        TapHandler {
            // A click on empty space leaves the search field.
            enabled: !win.underSheet
            onTapped: frame.forceActiveFocus()
        }

        Loader {
            id: content
            x: Look.contentX
            y: Look.toolbar
            width: parent.width - x
            height: parent.height - y
            focus: true
            enabled: !win.underSheet
            sourceComponent: ({ general: generalPage, about: aboutPage, wifi: wifiPage, bluetooth: bluetoothPage, network: networkPage, displays: displaysPage, sound: soundPage, controls: controlsPage })[win.page?.page ?? ""] ?? null
            onLoaded: Qt.callLater(App.shown, win)
        }
        Component { id: generalPage; GeneralPage { settings: win } }
        Component { id: aboutPage; AboutPage { settings: win } }
        Component { id: soundPage; SoundPage { settings: win } }
        Component { id: wifiPage; WiFiPage { settings: win } }
        Component { id: bluetoothPage; BluetoothPage { settings: win } }
        Component { id: networkPage; NetworkPage { settings: win } }
        Component { id: displaysPage; DisplaysPage { settings: win } }
        Component { id: controlsPage; ControlsPage { settings: win } }

        Toolbar {
            width: parent.width
            enabled: !win.underSheet
            settings: win
            showsTitle: content.item?.showsTitle ?? true
        }

        Sidebar {
            id: sidebar
            x: Look.sidebarInset
            y: Look.sidebarInset
            width: Look.sidebarWidth
            height: parent.height - 2 * Look.sidebarInset
            settings: win
        }

        // Resizing by the top and bottom edges: the window keeps its width.
        Repeater {
            model: [
                { edges: Qt.TopEdge, y: 0 },
                { edges: Qt.BottomEdge, y: -5 },
            ]
            Item {
                required property var modelData
                x: 24
                y: modelData.y < 0 ? frame.height + modelData.y : modelData.y
                width: frame.width - 48
                height: 5
                HoverHandler { cursorShape: Qt.SizeVerCursor }
                DragHandler {
                    target: null
                    onActiveChanged: if (active) win.startSystemResize(parent.modelData.edges)
                }
            }
        }
    }
}
