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
        windows.sort((a, b) => get(a, TaskManager.AbstractTasksModel.LastActivated) - get(b, TaskManager.AbstractTasksModel.LastActivated));
        for (const window of windows) tasksModel.requestActivate(window);
    }
    function newWindow(row) {
        tasksModel.requestNewInstance(tasksModel.makeModelIndex(row));
    }
    // Hides the app: minimizes each of its windows.
    function hide(row) {
        for (const window of windowsOf(row)) {
            if (!get(window, TaskManager.AbstractTasksModel.IsMinimized)) tasksModel.requestToggleMinimized(window);
        }
    }
    // Quits the app: asks each of its windows to close.
    function quit(row) {
        tasksModel.requestClose(tasksModel.makeModelIndex(row));
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
