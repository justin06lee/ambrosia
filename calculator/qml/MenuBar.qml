import QtQuick
import Qt.labs.platform as Platform
import Calculator

// Calculator's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and CalculatorWindow.act runs each
// once.
Platform.MenuBar {
    id: bar

    required property var calculator

    Platform.Menu {
        onAboutToShow: bar.calculator.menusOpen += 1
        onAboutToHide: bar.calculator.menusOpen = Math.max(0, bar.calculator.menusOpen - 1)
        title: "File"
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.calculator.act("close", bar.calculator.close) }
    }
    Platform.Menu {
        onAboutToShow: bar.calculator.menusOpen += 1
        onAboutToHide: bar.calculator.menusOpen = Math.max(0, bar.calculator.menusOpen - 1)
        title: "Edit"
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; onTriggered: bar.calculator.act("copy", bar.calculator.copy) }
        Platform.MenuItem { text: "Paste"; shortcut: "Ctrl+V"; onTriggered: bar.calculator.act("paste", bar.calculator.paste) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Clear"; onTriggered: bar.calculator.press("ac") }
    }
    Platform.Menu {
        onAboutToShow: bar.calculator.menusOpen += 1
        onAboutToHide: bar.calculator.menusOpen = Math.max(0, bar.calculator.menusOpen - 1)
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.calculator.act("minimize", bar.calculator.showMinimized) }
    }
}
