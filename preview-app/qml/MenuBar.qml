import QtQuick
import Qt.labs.platform as Platform
import Preview

// A window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and PreviewWindow.act runs each
// once.
Platform.MenuBar {
    id: bar

    required property var preview
    readonly property var view: preview.view

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.preview.shellOpen = true
        onAboutToHide: bar.preview.shellOpen = false
        title: "Preview"
        Platform.MenuItem { text: "About Preview"; onTriggered: About.show("Preview", "org.ambrosia.preview") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Settings…"; shortcut: "Ctrl+,"; onTriggered: bar.preview.act("settings", () => Preferences.show("Preview", "SettingsWindow")) }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.preview.menusOpen += 1
        onAboutToHide: bar.preview.menusOpen = Math.max(0, bar.preview.menusOpen - 1)
    }

    Menu {
        title: "File"
        Platform.MenuItem { text: "Open…"; shortcut: "Ctrl+O"; onTriggered: bar.preview.act("open", () => App.chooseFiles()) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close Window"; shortcut: "Ctrl+W"; onTriggered: bar.preview.act("close", bar.preview.close) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Export…"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.exportAs(false) }
        Platform.MenuItem { text: "Export as PDF…"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.exportAs(true) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Print…"; shortcut: "Ctrl+P"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("print", bar.preview.printOut) }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; enabled: bar.view?.hasSelection ?? false; onTriggered: bar.preview.act("copy", bar.preview.copy) }
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; enabled: bar.view?.canSelectAll ?? false; onTriggered: bar.preview.act("selectAll", bar.preview.selectAll) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Find…"; shortcut: "Ctrl+F"; enabled: bar.preview.canFind; onTriggered: bar.preview.act("find", bar.preview.find) }
        Platform.MenuItem { text: "Find Next"; shortcut: "Ctrl+G"; enabled: bar.preview.canFind; onTriggered: bar.preview.act("findNext", () => bar.preview.findNext(1)) }
        Platform.MenuItem { text: "Find Previous"; shortcut: "Ctrl+Shift+G"; enabled: bar.preview.canFind; onTriggered: bar.preview.act("findPrevious", () => bar.preview.findNext(-1)) }
    }
    Menu {
        title: "View"
        Platform.MenuItem { text: "Hide Sidebar"; shortcut: "Ctrl+Alt+1"; checkable: true; checked: bar.preview.sidebarMode === "none"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("sidebarNone", () => bar.preview.sidebarMode = "none") }
        Platform.MenuItem { text: "Thumbnails"; shortcut: "Ctrl+Alt+2"; checkable: true; checked: bar.preview.sidebarMode === "thumbnails"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("sidebarThumbnails", () => bar.preview.sidebarMode = "thumbnails") }
        Platform.MenuItem { text: "Table of Contents"; shortcut: "Ctrl+Alt+3"; checkable: true; checked: bar.preview.sidebarMode === "outline"; enabled: bar.preview.hasOutline; onTriggered: bar.preview.act("sidebarOutline", () => bar.preview.sidebarMode = "outline") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Actual Size"; shortcut: "Ctrl+0"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("actualSize", () => bar.view.actualSize()) }
        Platform.MenuItem { text: "Zoom to Fit"; shortcut: "Ctrl+9"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("zoomToFit", () => bar.view.zoomToFit()) }
        Platform.MenuItem { text: "Zoom In"; shortcut: "Ctrl++"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("zoomIn", () => bar.view.zoomIn()) }
        Platform.MenuItem { text: "Zoom Out"; shortcut: "Ctrl+-"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("zoomOut", () => bar.view.zoomOut()) }
    }
    Menu {
        title: "Go"
        Platform.MenuItem { text: "Previous Item"; shortcut: "Alt+Up"; enabled: (bar.view?.currentPage ?? 0) > 0; onTriggered: bar.preview.act("previous", () => bar.view.goToPage(bar.view.currentPage - 1)) }
        Platform.MenuItem { text: "Next Item"; shortcut: "Alt+Down"; enabled: (bar.view?.currentPage ?? 0) < (bar.view?.pageCount ?? 0) - 1; onTriggered: bar.preview.act("next", () => bar.view.goToPage(bar.view.currentPage + 1)) }
    }
    Menu {
        title: "Tools"
        Platform.MenuItem { text: "Rotate Left"; shortcut: "Ctrl+L"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("rotateLeft", () => bar.view.rotate(-1)) }
        Platform.MenuItem { text: "Rotate Right"; shortcut: "Ctrl+R"; enabled: bar.preview.showsDocument; onTriggered: bar.preview.act("rotateRight", () => bar.view.rotate(1)) }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.preview.act("minimize", bar.preview.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.preview.toggleZoom() }
        // Full screen and back, as the green light and ⌃⌘F (the session's key).
        Platform.MenuItem { text: bar.preview.visibility === Window.FullScreen ? "Exit Full Screen" : "Enter Full Screen"; onTriggered: bar.preview.visibility === Window.FullScreen ? bar.preview.showNormal() : bar.preview.showFullScreen() }
    }
}
