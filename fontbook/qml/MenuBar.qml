import QtQuick
import Qt.labs.platform as Platform
import FontBook

// The window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and FontBookWindow.act runs each
// once.
Platform.MenuBar {
    id: bar

    required property var book

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.book.shellOpen = true
        onAboutToHide: bar.book.shellOpen = false
        title: "Font Book"
        Platform.MenuItem { text: "About Font Book"; onTriggered: About.show("Font Book", "org.ambrosia.fontbook") }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.book.menusOpen += 1
        onAboutToHide: bar.book.menusOpen = Math.max(0, bar.book.menusOpen - 1)
    }

    Menu {
        title: "File"
        Platform.MenuItem { text: "New Collection"; shortcut: "Ctrl+N"; onTriggered: bar.book.act("newCollection", bar.book.newCollection) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Add Fonts to Current User…"; shortcut: "Ctrl+O"; onTriggered: bar.book.act("add", bar.book.addFonts) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Show in Files"; shortcut: "Ctrl+R"; enabled: bar.book.infoFamily !== null; onTriggered: bar.book.act("reveal", bar.book.revealSelected) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.book.act("close", bar.book.close) }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Remove"; enabled: bar.book.canRemove; onTriggered: bar.book.removeSelected() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Search"; shortcut: "Ctrl+F"; onTriggered: bar.book.act("search", bar.book.find) }
    }
    Menu {
        title: "View"
        Platform.MenuItem { text: "Back"; shortcut: "Ctrl+["; enabled: bar.book.opened !== ""; onTriggered: bar.book.act("back", bar.book.back) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "View as Grid"; shortcut: "Ctrl+1"; checkable: true; checked: bar.book.opened === "" && bar.book.view === "grid"; onTriggered: bar.book.act("grid", () => bar.book.setView("grid")) }
        Platform.MenuItem { text: "View as Samples"; shortcut: "Ctrl+2"; checkable: true; checked: bar.book.opened === "" && bar.book.view === "samples"; onTriggered: bar.book.act("samples", () => bar.book.setView("samples")) }
        Platform.MenuItem { text: "View as List"; shortcut: "Ctrl+3"; checkable: true; checked: bar.book.opened === "" && bar.book.view === "list"; onTriggered: bar.book.act("list", () => bar.book.setView("list")) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Increase Font Size"; shortcut: "Ctrl++"; onTriggered: bar.book.act("larger", () => bar.book.setSize(bar.book.size + 0.1)) }
        Platform.MenuItem { text: "Decrease Font Size"; shortcut: "Ctrl+-"; onTriggered: bar.book.act("smaller", () => bar.book.setSize(bar.book.size - 0.1)) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Next Typeface"; enabled: bar.book.opened !== ""; onTriggered: bar.book.step(1) }
        Platform.MenuItem { text: "Previous Typeface"; enabled: bar.book.opened !== ""; onTriggered: bar.book.step(-1) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: bar.book.infoShown ? "Hide Info Pane" : "Show Info Pane"; shortcut: "Ctrl+I"; onTriggered: bar.book.act("info", () => bar.book.infoShown = !bar.book.infoShown) }
        Platform.MenuItem { text: bar.book.sidebarShown ? "Hide Sidebar" : "Show Sidebar"; onTriggered: bar.book.sidebarShown = !bar.book.sidebarShown }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.book.act("minimize", bar.book.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.book.toggleZoom() }
    }
}
