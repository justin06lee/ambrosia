import QtQuick
import Qt.labs.platform as Platform
import TextEditor

// A window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Preview's MenuBar.qml). Ctrl is Command here. The
// keys the text takes itself (cut, copy, paste, undo, select all) are only
// named here; the others are the window's own shortcuts too, and
// EditorWindow.act runs each once.
Platform.MenuBar {
    id: bar

    required property var doc
    readonly property bool rich: doc.rich
    readonly property var edit: doc.edit

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.doc.shellOpen = true
        onAboutToHide: bar.doc.shellOpen = false
        title: "TextEdit"
        Platform.MenuItem { text: "About TextEdit"; onTriggered: About.show("TextEdit", "org.ambrosia.textedit") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Settings…"; shortcut: "Ctrl+,"; onTriggered: bar.doc.act("settings", () => Preferences.show("TextEditor", "SettingsWindow")) }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.doc.menusOpen += 1
        onAboutToHide: bar.doc.menusOpen = Math.max(0, bar.doc.menusOpen - 1)
    }

    Menu {
        title: "File"
        Platform.MenuItem { text: "New"; shortcut: "Ctrl+N"; onTriggered: bar.doc.act("new", () => bar.doc.app.newDocument()) }
        Platform.MenuItem { text: "Open…"; shortcut: "Ctrl+O"; onTriggered: bar.doc.act("open", () => App.chooseFiles()) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.doc.act("close", bar.doc.close) }
        Platform.MenuItem { text: bar.doc.file === "" ? "Save…" : "Save"; shortcut: "Ctrl+S"; onTriggered: bar.doc.act("save", () => bar.doc.save(null)) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Export as PDF…"; onTriggered: bar.doc.exportPdf() }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Undo"; shortcut: "Ctrl+Z"; enabled: bar.edit?.canUndo ?? false; onTriggered: bar.edit.undo() }
        Platform.MenuItem { text: "Redo"; shortcut: "Ctrl+Shift+Z"; enabled: bar.edit?.canRedo ?? false; onTriggered: bar.edit.redo() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Cut"; shortcut: "Ctrl+X"; enabled: (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.edit.cut() }
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; enabled: (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.edit.copy() }
        Platform.MenuItem { text: "Paste"; shortcut: "Ctrl+V"; enabled: bar.edit?.canPaste ?? false; onTriggered: bar.edit.paste() }
        Platform.MenuItem { text: "Delete"; enabled: (bar.edit?.selectedText ?? "") !== ""; onTriggered: bar.edit.remove(bar.edit.selectionStart, bar.edit.selectionEnd) }
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; onTriggered: bar.edit.selectAll() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Find…"; shortcut: "Ctrl+F"; onTriggered: bar.doc.act("find", bar.doc.find) }
        Platform.MenuItem { text: "Find Next"; shortcut: "Ctrl+G"; onTriggered: bar.doc.act("findNext", () => bar.doc.findNext(1)) }
        Platform.MenuItem { text: "Find Previous"; shortcut: "Ctrl+Shift+G"; onTriggered: bar.doc.act("findPrevious", () => bar.doc.findNext(-1)) }
    }
    Menu {
        title: "Format"
        Menu {
            title: "Font"
            Platform.MenuItem { text: "Show Fonts"; shortcut: "Ctrl+T"; enabled: bar.rich; onTriggered: bar.doc.act("fonts", bar.doc.showFonts) }
            Platform.MenuItem { text: "Bold"; shortcut: "Ctrl+B"; enabled: bar.rich; onTriggered: bar.doc.act("bold", () => bar.doc.format("bold")) }
            Platform.MenuItem { text: "Italic"; shortcut: "Ctrl+I"; enabled: bar.rich; onTriggered: bar.doc.act("italic", () => bar.doc.format("italic")) }
            Platform.MenuItem { text: "Underline"; shortcut: "Ctrl+U"; enabled: bar.rich; onTriggered: bar.doc.act("underline", () => bar.doc.format("underline")) }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "Bigger"; shortcut: "Ctrl++"; enabled: bar.rich; onTriggered: bar.doc.act("bigger", () => bar.doc.format("bigger")) }
            Platform.MenuItem { text: "Smaller"; shortcut: "Ctrl+-"; enabled: bar.rich; onTriggered: bar.doc.act("smaller", () => bar.doc.format("smaller")) }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "Show Colors"; shortcut: "Ctrl+Shift+C"; enabled: bar.rich; onTriggered: bar.doc.act("colors", bar.doc.showColors) }
        }
        Menu {
            title: "Text"
            Platform.MenuItem { text: "Align Left"; shortcut: "Ctrl+{"; enabled: bar.rich; onTriggered: bar.doc.act("left", () => bar.doc.format("left")) }
            Platform.MenuItem { text: "Center"; shortcut: "Ctrl+|"; enabled: bar.rich; onTriggered: bar.doc.act("center", () => bar.doc.format("center")) }
            Platform.MenuItem { text: "Justify"; enabled: bar.rich; onTriggered: bar.doc.format("justify") }
            Platform.MenuItem { text: "Align Right"; shortcut: "Ctrl+}"; enabled: bar.rich; onTriggered: bar.doc.act("right", () => bar.doc.format("right")) }
        }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: bar.rich ? "Make Plain Text" : "Make Rich Text"; shortcut: "Ctrl+Shift+T"; onTriggered: bar.doc.act("toggleRich", bar.doc.toggleRich) }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.doc.act("minimize", bar.doc.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.doc.toggleZoom() }
    }
}
