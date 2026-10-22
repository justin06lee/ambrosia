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
        Platform.MenuItem { text: "New Folder"; shortcut: "Ctrl+Shift+N"; enabled: bar.finder.local; onTriggered: bar.finder.act("newFolder", bar.finder.newFolder) }
        Platform.MenuItem { text: "Open"; shortcut: "Ctrl+O"; enabled: bar.finder.hasSelection; onTriggered: bar.finder.act("open", bar.finder.openSelection) }
        Platform.MenuItem { text: "Close Window"; shortcut: "Ctrl+W"; onTriggered: bar.finder.act("close", bar.finder.close) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Get Info"; shortcut: "Ctrl+I"; onTriggered: bar.finder.act("info", bar.finder.getInfo) }
        Platform.MenuItem { text: "Rename"; enabled: bar.finder.selectedCount === 1 && bar.finder.local; onTriggered: bar.finder.act("rename", bar.finder.renameSelection) }
        Platform.MenuItem { text: "Duplicate"; shortcut: "Ctrl+D"; enabled: bar.finder.hasSelection && bar.finder.local; onTriggered: bar.finder.act("duplicate", bar.finder.duplicate) }
        Platform.MenuItem {
            text: bar.finder.selectedCount === 1 ? "Quick Look “" + bar.finder.model.nameAt(bar.finder.shownRow) + "”"
                : bar.finder.selectedCount > 1 ? "Quick Look " + bar.finder.selectedCount + " Items" : "Quick Look"
            shortcut: "Ctrl+Y"
            enabled: bar.finder.hasSelection
            onTriggered: bar.finder.act("look", bar.finder.toggleLook)
        }
        Platform.MenuSeparator {}
        // In the Trash, the same key puts items back where they came from.
        Platform.MenuItem {
            text: bar.finder.inTrash ? "Put Back" : "Move to Trash"
            shortcut: "Ctrl+Backspace"
            enabled: bar.finder.hasSelection
            onTriggered: bar.finder.act("trash", bar.finder.trashSelection)
        }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "Edit"
        Platform.MenuItem { text: FileOps.undoText; shortcut: "Ctrl+Z"; enabled: FileOps.canUndo; onTriggered: bar.finder.act("undo", FileOps.undo) }
        Platform.MenuItem { text: FileOps.redoText; shortcut: "Ctrl+Shift+Z"; enabled: FileOps.canRedo; onTriggered: bar.finder.act("redo", FileOps.redo) }
        Platform.MenuSeparator {}
        // Finder cuts no files: Copy, then Paste or Move Item Here.
        Platform.MenuItem { text: "Cut"; shortcut: "Ctrl+X"; enabled: false }
        Platform.MenuItem {
            text: bar.finder.selectedCount === 1 ? "Copy “" + bar.finder.model.nameAt(bar.finder.current) + "”"
                : bar.finder.selectedCount > 1 ? "Copy " + bar.finder.selectedCount + " Items" : "Copy"
            shortcut: "Ctrl+C"
            enabled: bar.finder.hasSelection
            onTriggered: bar.finder.act("copy", bar.finder.copySelection)
        }
        Platform.MenuItem {
            text: FileOps.clipboardCount === 1 ? "Paste Item" : FileOps.clipboardCount > 1 ? "Paste " + FileOps.clipboardCount + " Items" : "Paste"
            shortcut: "Ctrl+V"
            enabled: FileOps.clipboardCount > 0 && bar.finder.local
            onTriggered: bar.finder.act("paste", () => bar.finder.paste(false))
        }
        // Finder shows this one in Paste's place while Option is down; a
        // menu over DBusMenu can't swap items, so it has its own.
        Platform.MenuItem {
            text: FileOps.clipboardCount > 1 ? "Move " + FileOps.clipboardCount + " Items Here" : "Move Item Here"
            shortcut: "Ctrl+Alt+V"
            enabled: FileOps.clipboardCount > 0 && bar.finder.local
            onTriggered: bar.finder.act("moveHere", () => bar.finder.paste(true))
        }
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; onTriggered: bar.finder.act("all", bar.finder.selectAll) }
    }
    Platform.Menu {
        onAboutToShow: bar.finder.menusOpen += 1
        onAboutToHide: bar.finder.menusOpen = Math.max(0, bar.finder.menusOpen - 1)
        title: "View"
        Platform.MenuItem { text: "as Icons"; shortcut: "Ctrl+1"; checkable: true; checked: bar.finder.view === "icon"; onTriggered: bar.finder.act("icons", () => bar.finder.view = "icon") }
        Platform.MenuItem { text: "as List"; shortcut: "Ctrl+2"; checkable: true; checked: bar.finder.view === "list"; onTriggered: bar.finder.act("list", () => bar.finder.view = "list") }
        Platform.MenuItem { text: "as Columns"; shortcut: "Ctrl+3"; checkable: true; checked: bar.finder.view === "column"; onTriggered: bar.finder.act("columns", () => bar.finder.view = "column") }
        Platform.MenuItem { text: "as Gallery"; shortcut: "Ctrl+4"; checkable: true; checked: bar.finder.view === "gallery"; onTriggered: bar.finder.act("gallery", () => bar.finder.view = "gallery") }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: bar.finder.showPreview ? "Hide Preview" : "Show Preview"
            shortcut: "Ctrl+Shift+P"
            enabled: bar.finder.view === "column" || bar.finder.view === "gallery"
            onTriggered: bar.finder.act("preview", () => bar.finder.showPreview = !bar.finder.showPreview)
        }
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
