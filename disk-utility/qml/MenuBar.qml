import QtQuick
import Qt.labs.platform as Platform
import DiskUtility

// The window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and DiskUtilityWindow.act runs
// each once.
Platform.MenuBar {
    id: bar

    required property var disks

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.disks.shellOpen = true
        onAboutToHide: bar.disks.shellOpen = false
        title: "Disk Utility"
        Platform.MenuItem { text: "About Disk Utility"; onTriggered: About.show("Disk Utility", "org.ambrosia.diskutility") }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.disks.menusOpen += 1
        onAboutToHide: bar.disks.menusOpen = Math.max(0, bar.disks.menusOpen - 1)
    }

    Menu {
        title: "File"
        Platform.Menu {
            title: "New Image"
            Platform.MenuItem { text: "Blank Image…"; shortcut: "Ctrl+N"; onTriggered: bar.disks.act("new", bar.disks.askImage) }
        }
        Platform.MenuItem { text: "Open Disk Image…"; shortcut: "Ctrl+Alt+O"; onTriggered: bar.disks.act("open", bar.disks.openImage) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Run First Aid…"; enabled: bar.disks.may.firstAid; onTriggered: bar.disks.askFirstAid() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Get Info"; shortcut: "Ctrl+I"; enabled: bar.disks.may.info; onTriggered: bar.disks.act("info", bar.disks.showInfo) }
        Platform.MenuItem { text: "Rename"; enabled: bar.disks.may.rename; onTriggered: bar.disks.startRename() }
        Platform.MenuItem { text: "Show in Files"; enabled: bar.disks.item?.mounted ?? false; onTriggered: bar.disks.reveal() }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: bar.disks.item ? (bar.disks.may.mountLabel + " “" + bar.disks.item.name + "”") : "Unmount"
            enabled: bar.disks.may.mount
            onTriggered: bar.disks.toggleMount()
        }
        Platform.MenuItem {
            text: bar.disks.item ? ("Eject “" + bar.disks.item.name + "”") : "Eject"
            shortcut: "Ctrl+E"
            enabled: bar.disks.may.eject
            onTriggered: bar.disks.act("eject", () => bar.disks.eject(bar.disks.chosen))
        }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.disks.act("close", bar.disks.close) }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Erase…"; shortcut: "Ctrl+Shift+E"; enabled: bar.disks.may.erase; onTriggered: bar.disks.act("erase", bar.disks.askErase) }
    }
    Menu {
        title: "View"
        Platform.MenuItem { text: "Show Only Volumes"; shortcut: "Ctrl+1"; checkable: true; checked: !bar.disks.everything; onTriggered: bar.disks.act("volumes", () => bar.disks.everything = false) }
        Platform.MenuItem { text: "Show All Devices"; shortcut: "Ctrl+2"; checkable: true; checked: bar.disks.everything; onTriggered: bar.disks.act("devices", () => bar.disks.everything = true) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: bar.disks.sidebarShown ? "Hide Sidebar" : "Show Sidebar"; onTriggered: bar.disks.sidebarShown = !bar.disks.sidebarShown }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.disks.act("minimize", bar.disks.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.disks.toggleZoom() }
    }
}
