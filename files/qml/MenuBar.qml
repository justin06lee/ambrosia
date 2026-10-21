import QtQuick
import Qt.labs.platform as Platform
import Files

// Finder's menus, exported to Ambrosia's menu bar over DBusMenu. Each item
// runs through FinderWindow.act, which ignores a second call for the same
// key press (the window's own key handler sees it too).
Platform.MenuBar {
    id: bar

    required property var finder
    readonly property var places: Places.sections

    function place(section, index) { return places[section].items[index].url; }

    Platform.Menu {
        title: "File"
        Platform.MenuItem { text: "New Finder Window"; shortcut: "Ctrl+N"; onTriggered: bar.finder.act("new", () => App.openWindow(bar.finder.url)) }
        Platform.MenuItem { text: "Open"; shortcut: "Ctrl+O"; enabled: bar.finder.hasSelection; onTriggered: bar.finder.act("open", bar.finder.openSelection) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close Window"; shortcut: "Ctrl+W"; onTriggered: bar.finder.act("close", bar.finder.close) }
    }
    Platform.Menu {
        title: "Edit"
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; onTriggered: bar.finder.act("all", bar.finder.selectAll) }
    }
    Platform.Menu {
        title: "View"
        Platform.MenuItem { text: "as Icons"; shortcut: "Ctrl+1"; checkable: true; checked: bar.finder.view === "icon"; onTriggered: bar.finder.act("icons", () => bar.finder.view = "icon") }
        Platform.MenuItem { text: "as List"; shortcut: "Ctrl+2"; checkable: true; checked: bar.finder.view === "list"; onTriggered: bar.finder.act("list", () => bar.finder.view = "list") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: bar.finder.model.showHidden ? "Hide Hidden Files" : "Show Hidden Files"; shortcut: "Ctrl+Shift+."; onTriggered: bar.finder.act("hidden", () => bar.finder.model.showHidden = !bar.finder.model.showHidden) }
    }
    Platform.Menu {
        title: "Go"
        Platform.MenuItem { text: "Back"; shortcut: "Ctrl+["; enabled: bar.finder.canGoBack; onTriggered: bar.finder.act("back", bar.finder.back) }
        Platform.MenuItem { text: "Forward"; shortcut: "Ctrl+]"; enabled: bar.finder.canGoForward; onTriggered: bar.finder.act("forward", bar.finder.forward) }
        Platform.MenuItem { text: "Enclosing Folder"; shortcut: "Ctrl+Up"; onTriggered: bar.finder.act("up", bar.finder.up) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Recents"; onTriggered: bar.finder.go(bar.place(0, 0)) }
        Platform.MenuItem { text: "Documents"; onTriggered: bar.finder.go(bar.place(1, 1)) }
        Platform.MenuItem { text: "Desktop"; onTriggered: bar.finder.go(bar.place(1, 0)) }
        Platform.MenuItem { text: "Downloads"; onTriggered: bar.finder.go(bar.place(1, 2)) }
        Platform.MenuItem { text: "Home"; onTriggered: bar.finder.go(bar.place(2, 0)) }
        Platform.MenuItem { text: "Computer"; onTriggered: bar.finder.go(bar.place(2, 1)) }
        Platform.MenuItem { text: "Trash"; onTriggered: bar.finder.go(bar.place(2, 2)) }
    }
    Platform.Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; onTriggered: bar.finder.showMinimized() }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.finder.visibility === Window.Maximized ? bar.finder.showNormal() : bar.finder.showMaximized() }
    }
}
