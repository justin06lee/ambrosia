import QtQuick
import Qt.labs.platform as Platform
import Notes

// The window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and NotesWindow.act runs each once.
Platform.MenuBar {
    id: bar

    required property var notes
    readonly property var edit: notes.edit
    readonly property bool can: notes.editable

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.notes.shellOpen = true
        onAboutToHide: bar.notes.shellOpen = false
        title: "Notes"
        Platform.MenuItem { text: "About Notes"; onTriggered: About.show("Notes", "org.ambrosia.notes") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Settings…"; shortcut: "Ctrl+,"; onTriggered: bar.notes.act("settings", bar.notes.showSettings) }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.notes.menusOpen += 1
        onAboutToHide: bar.notes.menusOpen = Math.max(0, bar.notes.menusOpen - 1)
    }
    component Kind: Platform.MenuItem {
        property string kind
        checkable: true
        checked: bar.notes.currentKind === kind
        enabled: bar.can
        onTriggered: bar.notes.act(kind, () => bar.notes.format(kind, false))
    }

    Menu {
        title: "File"
        Platform.MenuItem { text: "New Note"; shortcut: "Ctrl+N"; onTriggered: bar.notes.act("new", bar.notes.newNote) }
        Platform.MenuItem { text: "New Folder"; shortcut: "Ctrl+Shift+N"; onTriggered: bar.notes.act("newFolder", bar.notes.newFolder) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.notes.act("close", bar.notes.close) }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: bar.notes.open?.pinned ? "Unpin Note" : "Pin Note"
            enabled: bar.notes.open !== null && !bar.notes.inDeleted
            onTriggered: bar.notes.togglePin(bar.notes.chosen)
        }
        Platform.MenuItem { text: "Recover Note"; enabled: bar.notes.open !== null && bar.notes.inDeleted; onTriggered: bar.notes.recover(bar.notes.chosen) }
        Platform.MenuItem {
            text: bar.notes.inDeleted ? "Delete Note Permanently…" : "Delete Note"
            enabled: bar.notes.open !== null
            onTriggered: bar.notes.deleteNote(bar.notes.chosen)
        }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Export as PDF…"; enabled: bar.notes.open !== null; onTriggered: bar.notes.exportPdf() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Print…"; shortcut: "Ctrl+P"; enabled: bar.notes.open !== null; onTriggered: bar.notes.act("print", bar.notes.printOut) }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Undo"; shortcut: "Ctrl+Z"; enabled: bar.can && (bar.edit?.canUndo ?? false); onTriggered: bar.edit.undo() }
        Platform.MenuItem { text: "Redo"; shortcut: "Ctrl+Shift+Z"; enabled: bar.can && (bar.edit?.canRedo ?? false); onTriggered: bar.edit.redo() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Cut"; shortcut: "Ctrl+X"; enabled: bar.can && (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.notes.clip("cut") }
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; enabled: (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.notes.clip("copy") }
        Platform.MenuItem { text: "Paste"; shortcut: "Ctrl+V"; enabled: bar.can; onTriggered: bar.notes.clip("paste") }
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; enabled: bar.notes.open !== null; onTriggered: bar.edit.selectAll() }
        Platform.MenuSeparator {}
        Menu {
            title: "Find"
            Platform.MenuItem { text: "Note List Search…"; shortcut: "Ctrl+Alt+F"; onTriggered: bar.notes.act("search", bar.notes.search) }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "Find…"; shortcut: "Ctrl+F"; enabled: bar.notes.open !== null; onTriggered: bar.notes.act("find", () => bar.notes.find(false)) }
            Platform.MenuItem { text: "Find and Replace…"; shortcut: "Ctrl+Shift+F"; enabled: bar.can; onTriggered: bar.notes.act("replace", () => bar.notes.find(true)) }
            Platform.MenuItem { text: "Find Next"; shortcut: "Ctrl+G"; enabled: bar.notes.open !== null; onTriggered: bar.notes.act("findNext", () => bar.notes.findNext(1)) }
            Platform.MenuItem { text: "Find Previous"; shortcut: "Ctrl+Shift+G"; enabled: bar.notes.open !== null; onTriggered: bar.notes.act("findPrevious", () => bar.notes.findNext(-1)) }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "Use Selection for Find"; shortcut: "Ctrl+E"; enabled: (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.notes.act("findSelection", bar.notes.findSelection) }
            Platform.MenuItem { text: "Jump to Selection"; shortcut: "Ctrl+J"; enabled: bar.notes.open !== null; onTriggered: bar.notes.act("jump", bar.notes.jump) }
        }
    }
    Menu {
        title: "Format"
        Kind { text: "Title"; kind: "title"; shortcut: "Ctrl+Shift+T" }
        Kind { text: "Heading"; kind: "heading"; shortcut: "Ctrl+Shift+H" }
        Kind { text: "Subheading"; kind: "subheading"; shortcut: "Ctrl+Shift+J" }
        Kind { text: "Body"; kind: "body"; shortcut: "Ctrl+Shift+B" }
        Kind { text: "Monostyled"; kind: "mono"; shortcut: "Ctrl+Shift+M" }
        Kind { text: "Bulleted List"; kind: "bullet"; shortcut: "Ctrl+Shift+7" }
        Kind { text: "Dashed List"; kind: "dash"; shortcut: "Ctrl+Shift+8" }
        Kind { text: "Numbered List"; kind: "number"; shortcut: "Ctrl+Shift+9" }
        Platform.MenuSeparator {}
        Kind { text: "Checklist"; kind: "check"; shortcut: "Ctrl+Shift+L" }
        Platform.MenuItem {
            text: bar.notes.currentChecked ? "Mark as Unchecked" : "Mark as Checked"
            shortcut: "Ctrl+Shift+U"
            enabled: bar.can && bar.notes.currentKind === "check"
            onTriggered: bar.notes.act("checked", () => bar.notes.format("checked", false))
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: "Block Quote"
            shortcut: "Ctrl+'"
            checkable: true
            checked: bar.notes.currentQuote
            enabled: bar.can
            onTriggered: bar.notes.act("quote", () => bar.notes.format("quote", false))
        }
        Platform.MenuSeparator {}
        Menu {
            title: "Font"
            Platform.MenuItem { text: "Bold"; shortcut: "Ctrl+B"; enabled: bar.can; onTriggered: bar.notes.act("bold", () => bar.notes.format("bold", false)) }
            Platform.MenuItem { text: "Italic"; shortcut: "Ctrl+I"; enabled: bar.can; onTriggered: bar.notes.act("italic", () => bar.notes.format("italic", false)) }
            Platform.MenuItem { text: "Underline"; shortcut: "Ctrl+U"; enabled: bar.can; onTriggered: bar.notes.act("underline", () => bar.notes.format("underline", false)) }
            Platform.MenuItem { text: "Strikethrough"; enabled: bar.can; onTriggered: bar.notes.format("strike", false) }
        }
        Menu {
            title: "Indentation"
            Platform.MenuItem { text: "Increase"; shortcut: "Ctrl+]"; enabled: bar.can; onTriggered: bar.notes.act("in", () => bar.notes.format("in", false)) }
            Platform.MenuItem { text: "Decrease"; shortcut: "Ctrl+["; enabled: bar.can; onTriggered: bar.notes.act("out", () => bar.notes.format("out", false)) }
        }
    }
    Menu {
        title: "View"
        Platform.MenuItem { text: bar.notes.sidebarShown ? "Hide Folders" : "Show Folders"; shortcut: "Ctrl+Alt+S"; onTriggered: bar.notes.act("folders", () => bar.notes.sidebarShown = !bar.notes.sidebarShown) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Sort by Date Edited"; checkable: true; checked: Prefs.sortBy === "edited"; onTriggered: Prefs.sortBy = "edited" }
        Platform.MenuItem { text: "Sort by Date Created"; checkable: true; checked: Prefs.sortBy === "created"; onTriggered: Prefs.sortBy = "created" }
        Platform.MenuItem { text: "Sort by Title"; checkable: true; checked: Prefs.sortBy === "title"; onTriggered: Prefs.sortBy = "title" }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Group Notes by Date"; checkable: true; checked: Prefs.grouped; enabled: Prefs.sortBy !== "title"; onTriggered: Prefs.grouped = !Prefs.grouped }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.notes.act("minimize", bar.notes.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.notes.toggleZoom() }
    }
}
