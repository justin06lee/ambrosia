import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// Activity Monitor's window, measured from macOS 27's (Look.qml): the
// toolbar 52 tall with the five tabs, the processes in a table under their
// headings, and the panel about the whole computer along the bottom.
// Frameless: it draws its own corners and lights (KWin draws the shadow;
// App.decorate asks for it) and is moved by its toolbar and resized by its
// edges. The Sampler reads the kernel; what is listed, in what order and in
// what words is monitor.mjs's.
Window {
    id: win

    // The tab in view, which processes it lists, and how each tab is
    // sorted ({ key, descending } by tab; a tab not yet touched goes by its
    // first column, the most on top).
    property string tabKey: "cpu"
    property string category: "mine"
    property var sorts: ({})
    readonly property var tab: Monitor.tab(tabKey)
    readonly property var sort: sorts[tabKey] ?? { key: tab.first, descending: true }
    // The processes picked when Selected Processes was asked for.
    property var picked: []
    // The chosen process's id, or -1.
    property int selected: -1
    readonly property var selectedProcess: selected < 0 ? null : (all.find(p => p.pid === selected) ?? null)
    // The kernel's own can't be quit.
    readonly property bool canQuit: selectedProcess !== null && selected > 1
    // Every process as last read, and those the table lists, in order.
    property var all: []
    property var rows: []
    // Which of the disks' and the network's two graphs is drawn.
    property string diskGraph: "io"
    property string networkGraph: "packets"

    signal inspectRequested(int pid)

    // A window keeps its active look while one of its menus is open, as on
    // a Mac; --active draws it active for grabs.
    property int menusOpen: 0
    // Something of Ambrosia's own is open over the screen (the app menu,
    // the control center): its menu bar says so through the menu named for
    // the app (MenuBar.qml). Yes or no, not a count: a missed word from
    // the bar must not leave the window lit for good.
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || App.active
    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int corner: maximized ? 0 : Look.windowRadius
    onActiveChanged: if (active) menusOpen = 0

    // The whole computer's numbers for the panel, made of each reading and
    // the one before it.
    readonly property QtObject stats: QtObject {
        property var now: ({})
        property var before: null
        property var cpu: ({ user: 0, system: 0, idle: 100 })
        property var memory: Monitor.memory({}, 0, 0)
        property int threads: 0
        property int count: 0
        property var rates: ({ reads: 0, writes: 0, readBytes: 0, writtenBytes: 0, packetsIn: 0, packetsOut: 0, bytesIn: 0, bytesOut: 0 })
        property var cpuHistory: []
        property var memoryHistory: []
        property var energyHistory: []
        property var ioHistory: []
        property var diskDataHistory: []
        property var packetsHistory: []
        property var networkDataHistory: []

        function absorb(system, processes) {
            const seconds = system.seconds;
            threads = system.threads;
            count = system.count;
            memory = Monitor.memory(system.meminfo, system.some, system.full);
            if (before !== null && seconds > 0) {
                cpu = Monitor.cpuShares(before.cpu, system.cpu);
                const per = (name) => Monitor.rate(before[name], system[name], seconds);
                rates = { reads: per("reads"), writes: per("writes"), readBytes: per("readBytes"), writtenBytes: per("writtenBytes"),
                          packetsIn: per("packetsIn"), packetsOut: per("packetsOut"), bytesIn: per("bytesIn"), bytesOut: per("bytesOut") };
                let energy = 0;
                for (const process of processes) {
                    if (process.energy > 0)
                        energy += process.energy;
                }
                const limit = Look.history;
                cpuHistory = Monitor.pushed(cpuHistory, { up: cpu.user, down: cpu.system }, limit);
                energyHistory = Monitor.pushed(energyHistory, energy, limit);
                ioHistory = Monitor.pushed(ioHistory, { up: rates.reads, down: rates.writes }, limit);
                diskDataHistory = Monitor.pushed(diskDataHistory, { up: rates.readBytes, down: rates.writtenBytes }, limit);
                packetsHistory = Monitor.pushed(packetsHistory, { up: rates.packetsIn, down: rates.packetsOut }, limit);
                networkDataHistory = Monitor.pushed(networkDataHistory, { up: rates.bytesIn, down: rates.bytesOut }, limit);
            }
            memoryHistory = Monitor.pushed(memoryHistory, memory.pressure, Look.history);
            before = system;
            now = system;
        }
    }

    // A new reading: every process with its energy impact, the panel's
    // numbers, and the table's rows again.
    function absorb() {
        // Into an array of our own: what the Sampler hands over is its list
        // seen through a window, and nothing written to that stays.
        const read = Sampler.processes;
        const processes = [];
        for (let i = 0; i < read.length; ++i) {
            const process = read[i];
            process.energy = Monitor.energy(process.cpu, process.wakeups);
            processes.push(process);
        }
        stats.absorb(Sampler.system, processes);
        all = processes;
        relist();
    }
    function relist() {
        rows = Monitor.listed(all, { category: category, me: Sampler.me, chosen: picked, search: toolbar.search.text, sortKey: sort.key, descending: sort.descending });
        // A process that has ended, or that the view no longer lists, isn't
        // chosen any more.
        if (selected >= 0 && !rows.some(p => p.pid === selected))
            selected = -1;
    }
    onCategoryChanged: relist()
    onSortChanged: relist()

    function view(which) {
        // Selected Processes keeps the ones chosen as it is asked for.
        if (which === "selected")
            picked = selected >= 0 ? [selected] : picked;
        category = which;
        relist();
    }
    function sortBy(key) {
        const sorts = Object.assign({}, win.sorts);
        // Again on the same heading turns the order; a new one starts with
        // the most on top, names from A.
        sorts[tabKey] = sort.key === key ? { key: key, descending: !sort.descending } : { key: key, descending: key !== "name" && key !== "user" };
        win.sorts = sorts;
    }
    function move(by) {
        if (rows.length === 0)
            return;
        const at = rows.findIndex(p => p.pid === selected);
        const to = Math.max(0, Math.min(rows.length - 1, at < 0 ? (by > 0 ? 0 : rows.length - 1) : at + by));
        selected = rows[to].pid;
        table.reveal(to);
    }
    function inspectSelected() {
        if (selected >= 0)
            inspectRequested(selected);
    }
    function quitSelected() {
        if (canQuit)
            alert.quit(selectedProcess);
    }
    // The chosen row as text: its name and what its columns say.
    function copy() {
        if (toolbar.search.editing || selectedProcess === null)
            return;
        App.copy([selectedProcess.name].concat(tab.columns.map(column => Monitor.cell(selectedProcess, column))).join("\t"));
    }
    function filter() {
        toolbar.search.focusField();
    }

    // A key that is also a menu item's shortcut is handed to one of the two
    // in turn, the window's own marked ambiguous: either way it runs, once.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        run();
    }
    function takeKeys() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))
            return;
        switch (event.key) {
        case Qt.Key_Up: move(-1); break;
        case Qt.Key_Down: move(1); break;
        case Qt.Key_PageUp: move(-table.pageRows); break;
        case Qt.Key_PageDown: move(table.pageRows); break;
        case Qt.Key_Home: move(-rows.length); break;
        case Qt.Key_End: move(rows.length); break;
        case Qt.Key_Return:
        case Qt.Key_Enter: inspectSelected(); break;
        case Qt.Key_Escape:
            if (toolbar.search.text !== "")
                toolbar.search.text = "";
            else
                selected = -1;
            break;
        default: return;
        }
        event.accepted = true;
    }

    width: Look.width
    height: Math.min(Look.height, Screen.height - 150)
    minimumWidth: Look.minWidth
    minimumHeight: Look.minHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    // It opens where it was last, as large (../kit/placing.h).
    property string frameName: "main"
    title: "Activity Monitor"

    readonly property Appearance appearance: Appearance {}
    MenuBar { monitor: win }

    // What is kept from one launch to the next (not for grabs, which ask
    // for a tab).
    Settings {
        id: kept
        category: "window"
        property string tab: "cpu"
        property string view: "mine"
        property int interval: 5000
        property string diskGraph: "io"
        property string networkGraph: "packets"
    }
    readonly property bool remembers: App.tab === ""
    onTabKeyChanged: if (remembers && ready) kept.tab = tabKey
    onDiskGraphChanged: if (remembers && ready) kept.diskGraph = diskGraph
    onNetworkGraphChanged: if (remembers && ready) kept.networkGraph = networkGraph
    property bool ready: false

    // The Sampler reads only what the tab in view shows.
    Binding { target: Sampler; property: "wakeups"; value: win.tabKey === "cpu" || win.tabKey === "energy" }
    Binding { target: Sampler; property: "disk"; value: win.tabKey === "disk" }
    Binding { target: Sampler; property: "network"; value: win.tabKey === "network" }
    Binding { target: Sampler; property: "sleep"; value: win.tabKey === "energy" }
    Connections {
        target: Sampler
        function onSampled() {
            win.absorb();
        }
        function onIntervalChanged() {
            if (win.remembers && win.ready)
                kept.interval = Sampler.interval;
        }
    }
    Connections {
        target: toolbar.search
        function onTextChanged() {
            win.relist();
        }
    }

    Component.onCompleted: {
        if (remembers) {
            tabKey = Monitor.tab(kept.tab).key;
            if (kept.view !== "selected" && Monitor.categoryTitle(kept.view) !== "")
                category = kept.view;
            Sampler.interval = kept.interval;
            diskGraph = kept.diskGraph === "data" ? "data" : "io";
            networkGraph = kept.networkGraph === "data" ? "data" : "packets";
        } else {
            tabKey = Monitor.tab(App.tab).key;
        }
        ready = true;
        absorb();
        visible = true;
        takeKeys();
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win, false);
        }
    }
    // The view is kept too, but not Selected Processes (those are gone by
    // the next launch).
    onClosing: if (remembers && category !== "selected") kept.view = category

    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close); onActivatedAmbiguously: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized); onActivatedAmbiguously: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", win.close); onActivatedAmbiguously: win.act("quit", win.close) }
    Shortcut { sequences: ["Ctrl+C", "Meta+C"]; enabled: !toolbar.search.editing; onActivated: win.act("copy", win.copy); onActivatedAmbiguously: win.act("copy", win.copy) }
    Shortcut { sequences: ["Ctrl+Alt+F", "Meta+Alt+F", "Ctrl+F", "Meta+F"]; onActivated: win.act("filter", win.filter); onActivatedAmbiguously: win.act("filter", win.filter) }
    Shortcut { sequences: ["Ctrl+I", "Meta+I"]; onActivated: win.act("inspect", win.inspectSelected); onActivatedAmbiguously: win.act("inspect", win.inspectSelected) }
    Shortcut { sequences: ["Ctrl+Alt+Q", "Meta+Alt+Q"]; onActivated: win.act("quitProcess", win.quitSelected); onActivatedAmbiguously: win.act("quitProcess", win.quitSelected) }

    Item {
        id: frame
        anchors.fill: parent

        Item {
            id: keys
            focus: true
            Keys.onPressed: (event) => win.keyPressed(event)
        }

        // Under the toolbar: the table and the panel, cut to the window's
        // bottom corners (not when drawn off-screen, where a mask draws
        // nothing: a grab's corners are square).
        Item {
            id: body
            y: Look.toolbar
            width: parent.width
            height: parent.height - Look.toolbar
            layer.enabled: !win.maximized && !App.offscreen
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bodyShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Look.ground }
            // The headings stand on the toolbar's color, a rule under them.
            Rectangle {
                width: parent.width
                height: Look.header
                color: Look.toolbarFill
            }
            Table {
                id: table
                width: parent.width
                height: parent.height - panel.height
                window: win
            }
            Rectangle {
                y: Look.header - 1
                width: parent.width
                height: 1
                color: Look.headerRule
            }
            Panel {
                id: panel
                y: parent.height - height
                width: parent.width
                window: win
            }
        }
        Item {
            id: bodyShape
            width: body.width
            height: body.height
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                bottomLeftRadius: Look.windowRadius
                bottomRightRadius: Look.windowRadius
                color: "black"
            }
        }

        Rectangle {
            width: parent.width
            height: Look.toolbar
            topLeftRadius: win.corner
            topRightRadius: win.corner
            color: Look.toolbarFill

            // The window moves by its toolbar; two clicks zoom it.
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler {
                onTapped: win.takeKeys()
                onDoubleTapped: win.toggleZoom()
            }
        }
        Toolbar {
            id: toolbar
            width: parent.width
            window: win
        }

        Alert {
            id: alert
            anchors.fill: parent
            window: win
        }

        // The window's rim, over everything.
        Rectangle {
            anchors.fill: parent
            radius: win.corner
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }

        // Resizing by the edges and corners.
        Repeater {
            model: win.maximized ? [] : [
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
}
