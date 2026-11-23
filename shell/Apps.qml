pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import org.kde.taskmanager as TaskManager

// The apps and windows KWin knows about, through Plasma's task manager model
// (KWin hands its window list only to clients its desktop files allow; see
// session/org.ambrosia.shell.desktop). Feeds the Dock and the menu bar.
Singleton {
    id: apps

    // One row per app: the Dock's pinned apps in order, then the others
    // that have windows. Rows for apps with windows are groups of them.
    readonly property TaskManager.TasksModel tasks: tasksModel

    // The focused app, for the menu bar; empty when no window has focus.
    // Held still while a menu is open (`frozen`), since the menu takes the
    // keyboard from the app.
    property bool frozen: false
    property string activeName: ""
    property string activeId: ""
    // Where the focused window publishes its menus (com.canonical.dbusmenu).
    property string menuService: ""
    property string menuPath: ""
    property int activeRow: -1
    property int activeChild: -1

    function get(index, role) {
        return tasksModel.data(index, role);
    }

    function update() {
        if (frozen) return;
        const index = tasksModel.activeTask;
        if (!index.valid) {
            activeName = activeId = menuService = menuPath = "";
            activeRow = activeChild = -1;
            return;
        }
        const top = index.parent.valid ? index.parent : index;
        activeRow = top.row;
        activeChild = index.parent.valid ? index.row : -1;
        activeId = get(index, TaskManager.AbstractTasksModel.AppId) ?? "";
        activeName = get(index, TaskManager.AbstractTasksModel.AppName) || get(index, Qt.DisplayRole) || "";
        menuService = get(index, TaskManager.AbstractTasksModel.ApplicationMenuServiceName) ?? "";
        menuPath = get(index, TaskManager.AbstractTasksModel.ApplicationMenuObjectPath) ?? "";
    }

    // The windows of an app's row: its children when grouped, else itself.
    function windowsOf(row) {
        const top = tasksModel.makeModelIndex(row);
        const count = tasksModel.rowCount(top);
        if (count === 0) return get(top, TaskManager.AbstractTasksModel.IsWindow) ? [top] : [];
        const list = [];
        for (let i = 0; i < count; i++) list.push(tasksModel.makeModelIndex(row, i));
        return list;
    }

    // Brings every window of the app forward, the one used last on top, as
    // clicking an app in the Dock does on a Mac. Starts it if it isn't running.
    function activate(row) {
        const windows = windowsOf(row);
        if (windows.length === 0) {
            tasksModel.requestActivate(tasksModel.makeModelIndex(row));
            return;
        }
        // An app with every window put away is hidden, or as good as: its
        // windows come back at once, as a hidden app's do on a Mac, not one
        // by one out of the Dock. KWin is told first and given a moment.
        if (windows.every(window => get(window, TaskManager.AbstractTasksModel.IsMinimized))) {
            kwin("Ambrosia Show Without Motion");
            reveal.row = row;
            reveal.restart();
            return;
        }
        raise(windows);
    }
    function raise(windows) {
        windows.sort((a, b) => get(a, TaskManager.AbstractTasksModel.LastActivated) - get(b, TaskManager.AbstractTasksModel.LastActivated));
        for (const window of windows) tasksModel.requestActivate(window);
    }
    Timer {
        id: reveal
        property int row: -1
        interval: 100
        onTriggered: apps.raise(apps.windowsOf(row))
    }
    // The app of a desktop entry brought forward, or started if no window of
    // it is open (a notification's app, clicked in the center).
    function activateEntry(entryId) {
        const id = entryId.replace(/\.desktop$/, "");
        for (let row = 0; row < tasksModel.rowCount(); row++) {
            const appId = (get(tasksModel.makeModelIndex(row), TaskManager.AbstractTasksModel.AppId) ?? "").replace(/\.desktop$/, "");
            if (appId === id && windowsOf(row).length > 0) {
                activate(row);
                return;
            }
        }
        Session.launch(id);
    }
    function newWindow(row) {
        tasksModel.requestNewInstance(tasksModel.makeModelIndex(row));
    }
    // One of KWin's actions, by the name its shortcut goes by: its own, or
    // one of our effect's (session/kwin-effects/ambrosia_windows).
    function kwin(action) {
        Quickshell.execDetached(["busctl", "--user", "call", "org.kde.kglobalaccel", "/component/kwin",
            "org.kde.kglobalaccel.Component", "invokeShortcut", "s", action]);
    }
    // Hiding is that effect's: the app in front, every other app, and all
    // of them back. Its windows are put away at once, with no motion.
    function hideFront() {
        kwin("Ambrosia Hide App");
    }
    function hideOthers() {
        kwin("Ambrosia Hide Others");
    }
    function showAll() {
        kwin("Ambrosia Show All");
    }
    // Mission Control, and an app's windows spread out with the rest put
    // away: our KWin effect's too (session/kwin-effects/ambrosia_mission).
    // It spreads the windows of whichever app is in front, so the app
    // comes forward first.
    function missionControl() {
        kwin("Ambrosia Mission Control");
    }
    function showWindows(row) {
        activate(row);
        spread.restart();
    }
    Timer {
        id: spread
        interval: 250
        onTriggered: apps.kwin("Ambrosia App Windows")
    }
    // Quits the app: asks each of its windows to close.
    function quit(row) {
        tasksModel.requestClose(tasksModel.makeModelIndex(row));
    }
    // Ends the app without asking it: its windows' processes are killed.
    function forceQuit(row) {
        const pids = [];
        for (const window of windowsOf(row)) {
            const pid = get(window, TaskManager.AbstractTasksModel.AppPid);
            if (pid > 0 && !pids.includes(String(pid))) pids.push(String(pid));
        }
        if (pids.length > 0) Quickshell.execDetached(["kill", "-KILL"].concat(pids));
    }

    // Window actions take the window as { row, child }, captured when the
    // menu offering them opened: by the time one runs, the menu has had the
    // keyboard and the window may not have focus back yet.
    function focusedWindow() {
        return { row: activeRow, child: activeChild };
    }
    function indexOf(window) {
        return window.row < 0 ? null : tasksModel.makeModelIndex(window.row, window.child);
    }
    function minimizeWindow(window) {
        const index = indexOf(window);
        if (index && !get(index, TaskManager.AbstractTasksModel.IsMinimized)) tasksModel.requestToggleMinimized(index);
    }
    function zoomWindow(window) {
        const index = indexOf(window);
        if (index) tasksModel.requestToggleMaximized(index);
    }
    function fullScreenWindow(window) {
        const index = indexOf(window);
        if (index) tasksModel.requestToggleFullScreen(index);
    }
    function closeWindow(window) {
        const index = indexOf(window);
        if (index) tasksModel.requestClose(index);
    }
    // Sends the window to a half or a quarter of the screen, or its middle:
    // KWin's own action, by the name its shortcut goes by, on the window in
    // front (which this one is made first).
    function placeWindow(window, where) {
        const index = indexOf(window);
        if (!index) return;
        tasksModel.requestActivate(index);
        kwin(where);
    }
    // A menu's rows for where a window can go: a Mac's Move & Resize.
    function placeEntries(window) {
        const any = window.row >= 0;
        const to = (text, where) => ({ text: text, enabled: any, action: () => apps.placeWindow(window, where) });
        return [
            to("Left", "Window Quick Tile Left"),
            to("Right", "Window Quick Tile Right"),
            to("Top", "Window Quick Tile Top"),
            to("Bottom", "Window Quick Tile Bottom"),
            { separator: true },
            to("Top Left", "Window Quick Tile Top Left"),
            to("Top Right", "Window Quick Tile Top Right"),
            to("Bottom Left", "Window Quick Tile Bottom Left"),
            to("Bottom Right", "Window Quick Tile Bottom Right"),
        ];
    }

    // The desktop entry for an app id as the task model gives it: running
    // apps' ids are bare (org.kde.dolphin), pinned ones end in .desktop.
    function entryFor(appId, name) {
        DesktopEntries.applications.values; // re-read once the entries are scanned
        const id = (appId ?? "").replace(/\.desktop$/, "");
        return (id && (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)))
            || (name && DesktopEntries.heuristicLookup(name)) || null;
    }

    function isPinned(id) {
        return Settings.dock.indexOf(id) >= 0;
    }
    function pin(id) {
        if (!isPinned(id)) Settings.dock = Settings.dock.concat([id]);
    }
    function unpin(id) {
        Settings.dock = Settings.dock.filter(pinned => pinned !== id);
    }

    // After a menu closes, give the app a moment to get focus back before
    // reading which app is focused, so the menu bar doesn't flicker to Files.
    onFrozenChanged: if (!frozen) settle.restart()
    Timer {
        id: settle
        interval: 150
        onTriggered: apps.update()
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        // A pinned app's windows take its launcher's place, as on a Mac.
        // (launchInPlace only works with the launchers kept separate.)
        separateLaunchers: true
        launchInPlace: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        // Re-read when the desktop files are (re)scanned.
        launcherList: {
            DesktopEntries.applications.values;
            return Settings.dock.filter(id => DesktopEntries.byId(id)).map(id => `applications:${id}.desktop`);
        }

        onActiveTaskChanged: apps.update()
        onDataChanged: apps.update()
        onRowsInserted: apps.update()
        onRowsRemoved: apps.update()
        onModelReset: apps.update()
        onLayoutChanged: apps.update()
    }

    // Plasma's app menu service only collects apps' menus while a menu view
    // holds this name on the session bus; the menu bar is that view.
    Process {
        running: true
        command: ["dbus-test-tool", "black-hole", "--session", "--name=org.kde.kappmenuview"]
    }
}
