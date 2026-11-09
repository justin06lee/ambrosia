import QtQuick
import Qt.labs.platform as Platform
import Settings

// System Settings' menus, exported to Ambrosia's menu bar over DBusMenu
// with their shortcuts (Files' MenuBar.qml). Ctrl is Command here, as
// Ambrosia's Mac-first keyboard delivers it; the window's own shortcuts
// take the keys, and SettingsWindow.act runs each once.
Platform.MenuBar {
    id: bar

    required property var settings
    // The text field with the keyboard, for Edit's items.
    readonly property var field: settings.activeFocusItem instanceof TextInput ? settings.activeFocusItem : null

    Platform.Menu {
        onAboutToShow: bar.settings.menusOpen += 1
        onAboutToHide: bar.settings.menusOpen = Math.max(0, bar.settings.menusOpen - 1)
        title: "Edit"
        Platform.MenuItem { text: "Cut"; shortcut: "Ctrl+X"; enabled: bar.field !== null; onTriggered: bar.field?.cut() }
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; enabled: bar.field !== null; onTriggered: bar.field?.copy() }
        Platform.MenuItem { text: "Paste"; shortcut: "Ctrl+V"; enabled: bar.field !== null; onTriggered: bar.field?.paste() }
        Platform.MenuItem { text: "Select All"; shortcut: "Ctrl+A"; enabled: bar.field !== null; onTriggered: bar.field?.selectAll() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Find"; shortcut: "Ctrl+F"; onTriggered: bar.settings.act("find", bar.settings.findPane) }
    }
    Platform.Menu {
        onAboutToShow: bar.settings.menusOpen += 1
        onAboutToHide: bar.settings.menusOpen = Math.max(0, bar.settings.menusOpen - 1)
        title: "View"
        Platform.MenuItem { text: "Back"; shortcut: "Ctrl+["; enabled: bar.settings.canGoBack; onTriggered: bar.settings.act("back", bar.settings.back) }
        Platform.MenuItem { text: "Forward"; shortcut: "Ctrl+]"; enabled: bar.settings.canGoForward; onTriggered: bar.settings.act("forward", bar.settings.forward) }
    }
    Platform.Menu {
        onAboutToShow: bar.settings.menusOpen += 1
        onAboutToHide: bar.settings.menusOpen = Math.max(0, bar.settings.menusOpen - 1)
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.settings.act("minimize", bar.settings.showMinimized) }
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.settings.act("close", bar.settings.close) }
    }
}
