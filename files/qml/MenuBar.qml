import QtQuick
import Qt.labs.platform as Platform
import Files

// Finder's menus, exported to Ambrosia's menu bar over DBusMenu with their
// shortcuts. Ctrl is Command here, as Ambrosia's Mac-first keyboard delivers
// it to apps (FinderWindow.keyPressed takes Super too). Each item runs
// through FinderWindow.act, which ignores a second call for the same key
// press (the window's own key handler sees it too).
Platform.MenuBar {
    id: bar

    required property var finder

    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "File"
        Platform.MenuItem { text: "New Finder Window"; shortcut: "Ctrl+N"; onTriggered: bar.finder.act("new", () => App.openWindow(bar.finder.url)) }
        Platform.MenuItem { text: "Open"; shortcut: "Ctrl+O"; enabled: bar.finder.hasSelection; onTriggered: bar.finder.act("open", bar.finder.openSelection) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close Window"; shortcut: "Ctrl+W"; onTriggered: bar.finder.act("close", bar.finder.close) }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "Edit"
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; onTriggered: bar.finder.act("all", bar.finder.selectAll) }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "View"
        Platform.MenuItem { text: "as Icons"; shortcut: "Ctrl+1"; checkable: true; checked: bar.finder.view === "icon"; onTriggered: bar.finder.act("icons", () => bar.finder.view = "icon") }
        Platform.MenuItem { text: "as List"; shortcut: "Ctrl+2"; checkable: true; checked: bar.finder.view === "list"; onTriggered: bar.finder.act("list", () => bar.finder.view = "list") }
        // Column and gallery views come in a later slice.
        Platform.MenuItem { text: "as Columns"; shortcut: "Ctrl+3"; enabled: false }
        Platform.MenuItem { text: "as Gallery"; shortcut: "Ctrl+4"; enabled: false }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: bar.finder.model.showHidden ? "Hide Hidden Files" : "Show Hidden Files"; shortcut: "Ctrl+Shift+."; onTriggered: bar.finder.act("hidden", () => bar.finder.model.showHidden = !bar.finder.model.showHidden) }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "Go"
        Platform.MenuItem { text: "Back"; shortcut: "Ctrl+["; enabled: bar.finder.canGoBack; onTriggered: bar.finder.act("back", bar.finder.back) }
        Platform.MenuItem { text: "Forward"; shortcut: "Ctrl+]"; enabled: bar.finder.canGoForward; onTriggered: bar.finder.act("forward", bar.finder.forward) }
        Platform.MenuItem { text: "Enclosing Folder"; shortcut: "Ctrl+Up"; onTriggered: bar.finder.act("up", bar.finder.up) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Recents"; shortcut: "Ctrl+Shift+F"; onTriggered: bar.finder.act("recents", () => bar.finder.goPlace("recents")) }
        Platform.MenuItem { text: "Documents"; shortcut: "Ctrl+Shift+O"; onTriggered: bar.finder.act("documents", () => bar.finder.goPlace("documents")) }
        Platform.MenuItem { text: "Desktop"; shortcut: "Ctrl+Shift+D"; onTriggered: bar.finder.act("desktop", () => bar.finder.goPlace("desktop")) }
        Platform.MenuItem { text: "Downloads"; shortcut: "Ctrl+Alt+L"; onTriggered: bar.finder.act("downloads", () => bar.finder.goPlace("downloads")) }
        Platform.MenuItem { text: "Home"; shortcut: "Ctrl+Shift+H"; onTriggered: bar.finder.act("home", () => bar.finder.goPlace("home")) }
        Platform.MenuItem { text: "Computer"; shortcut: "Ctrl+Shift+C"; onTriggered: bar.finder.act("computer", () => bar.finder.goPlace("computer")) }
        Platform.MenuItem { text: "Trash"; onTriggered: bar.finder.act("trash", () => bar.finder.goPlace("trash")) }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "Window"
        Platform.MenuItem { text: "Minimize"; onTriggered: bar.finder.showMinimized() }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.finder.visibility === Window.Maximized ? bar.finder.showNormal() : bar.finder.showMaximized() }
    }
}
