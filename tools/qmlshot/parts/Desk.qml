import QtQuick
import Quickshell
import Ambrosia
import "../../../out/build/qmlshot/shell"

// The desktop as the shell puts it up, for a sheet to open something on:
// the shell's own wallpaper, menu bar, Dock, Search, banners and the layer for menus,
// on a screen that is this item, with a few apps running and Kate in front.
// A sheet says what happens next in `then`, run once everything has loaded.
Item {
    id: desk

    width: 1440
    height: 900

    readonly property ShellScreen screen: Quickshell.screens[0]
    readonly property alias bar: bar
    readonly property alias dock: dock
    readonly property alias welcome: welcome
    readonly property alias installer: installer
    // What the app in front publishes as its menus (see DBusMenuSource).
    property var menus: [
        { text: "File", children: [
            { text: "New", shortcut: [["Control", "N"]] }, { text: "Open…", shortcut: [["Control", "O"]] },
            { text: "Open Recent", children: ["DESIGN.md", "tokens.ts", "-", "Clear List"] }, "-",
            { text: "Save", shortcut: [["Control", "S"]] }, { text: "Save As…", shortcut: [["Control", "Shift", "S"]] },
            { text: "Revert", enabled: false }, "-", { text: "Print…", shortcut: [["Control", "P"]] }, "-",
            { text: "Close", shortcut: [["Control", "W"]] }, "-", { text: "Quit", shortcut: [["Control", "Q"]] }] },
        { text: "Edit", children: ["Undo", "Redo", "-", "Cut", "Copy", "Paste"] },
        { text: "View", children: ["Zoom In", "Zoom Out"] },
        { text: "Selection", children: ["Select All"] },
        { text: "Go", children: ["Go to Line…"] },
        { text: "Tools", children: ["Spelling…"] },
        { text: "Window", children: ["Minimize", "Zoom"] },
        { text: "Settings", children: ["Configure Keyboard Shortcuts…", "Configure Toolbars…", "-",
            { text: "Configure Kate…", shortcut: [["Control", "comma"]] }] },
        { text: "Help", children: ["Kate Handbook", "-", "About Kate", "About KDE"] },
    ]
    property var running: ["org.ambrosia.files", "org.kde.kate", "org.kde.kcalc"]
    property string active: "org.kde.kate"
    property var then: null
    // How long qmlshot lets it settle: the wallpaper fades in, panels spring open.
    property int shotWait: 1500

    Binding { target: Theme; property: "dark"; value: Settings.dark }

    Component.onCompleted: {
        screen.shotHost = desk;
        screen.shotBackdrop = wallpaper.contentItem;
        Quickshell.shotMenus = { "org.kde.kate": menus };
        Settings.dark = shotDark;
        Settings.dock = ["org.ambrosia.files", "org.kde.konsole", "org.kde.kate", "org.kde.gwenview",
            "org.kde.okular", "org.kde.discover", "org.ambrosia.settings"];
        Apps.tasks.shotRunning = running;
        Apps.tasks.shotActive = active;
        ready.start();
    }
    Timer {
        id: ready
        interval: 300
        onTriggered: if (desk.then) desk.then()
    }

    Wallpaper { id: wallpaper; screen: desk.screen }
    MenuBar { id: bar; screen: desk.screen }
    Overlay { home: desk.screen; bar: bar }
    Dock { id: dock; screen: desk.screen }
    Search { screen: desk.screen; home: desk.screen }
    Notifications {}
    Welcome { id: welcome; home: desk.screen }
    Installer { id: installer; home: desk.screen }
}
