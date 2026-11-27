import QtQuick
import Qt.labs.platform as Platform
import ActivityMonitor
import "monitor.mjs" as Monitor

// The window's menus, exported to Ambrosia's menu bar over DBusMenu with
// their shortcuts (as Settings' MenuBar.qml). Ctrl is Command here; the
// window's own shortcuts take the keys, and MonitorWindow.act runs each
// once.
Platform.MenuBar {
    id: bar

    required property var monitor

    // The menu named for the app. Ambrosia's menu bar shows its rows in its
    // own menu of that name, over Hide and Quit (shell/AppMenu.qml), as a
    // Mac's app menu has them; elsewhere it is one more menu.
    Platform.Menu {
        // Ambrosia's menu bar holds this one open while anything of its own
        // is (the app menu, Window, the control center): the window stays lit.
        onAboutToShow: bar.monitor.shellOpen = true
        onAboutToHide: bar.monitor.shellOpen = false
        title: "Activity Monitor"
        Platform.MenuItem { text: "About Activity Monitor"; onTriggered: About.show("Activity Monitor", "org.ambrosia.activitymonitor") }
    }

    component Menu: Platform.Menu {
        onAboutToShow: bar.monitor.menusOpen += 1
        onAboutToHide: bar.monitor.menusOpen = Math.max(0, bar.monitor.menusOpen - 1)
    }

    Menu {
        title: "File"
        Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: bar.monitor.act("close", bar.monitor.close) }
    }
    Menu {
        title: "Edit"
        Platform.MenuItem { text: "Copy"; shortcut: "Ctrl+C"; enabled: bar.monitor.selected >= 0; onTriggered: bar.monitor.act("copy", bar.monitor.copy) }
    }
    Menu {
        id: viewMenu
        title: "View"
        Menu {
            title: "Update Frequency"
            Platform.MenuItem { text: "Very often (1 sec)"; checkable: true; checked: Sampler.interval === 1000; onTriggered: Sampler.interval = 1000 }
            Platform.MenuItem { text: "Often (2 sec)"; checkable: true; checked: Sampler.interval === 2000; onTriggered: Sampler.interval = 2000 }
            Platform.MenuItem { text: "Normally (5 sec)"; checkable: true; checked: Sampler.interval === 5000; onTriggered: Sampler.interval = 5000 }
        }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "All Processes"; checkable: true; checked: bar.monitor.category === "all"; onTriggered: bar.monitor.view("all") }
        Platform.MenuItem { text: "My Processes"; checkable: true; checked: bar.monitor.category === "mine"; onTriggered: bar.monitor.view("mine") }
        Platform.MenuItem { text: "System Processes"; checkable: true; checked: bar.monitor.category === "system"; onTriggered: bar.monitor.view("system") }
        Platform.MenuItem { text: "Other Users’ Processes"; checkable: true; checked: bar.monitor.category === "others"; onTriggered: bar.monitor.view("others") }
        Platform.MenuItem { text: "Active Processes"; checkable: true; checked: bar.monitor.category === "active"; onTriggered: bar.monitor.view("active") }
        Platform.MenuItem { text: "Inactive Processes"; checkable: true; checked: bar.monitor.category === "inactive"; onTriggered: bar.monitor.view("inactive") }
        Platform.MenuItem { text: "Selected Processes"; checkable: true; checked: bar.monitor.category === "selected"; enabled: bar.monitor.selected >= 0 || bar.monitor.category === "selected"; onTriggered: bar.monitor.view("selected") }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Filter Processes"; shortcut: "Ctrl+Alt+F"; onTriggered: bar.monitor.act("filter", bar.monitor.filter) }
        Platform.MenuItem { text: "Inspect Process"; shortcut: "Ctrl+I"; enabled: bar.monitor.selected >= 0; onTriggered: bar.monitor.act("inspect", bar.monitor.inspectSelected) }
        Platform.MenuItem { text: "Quit Process"; shortcut: "Ctrl+Alt+Q"; enabled: bar.monitor.canQuit; onTriggered: bar.monitor.act("quitProcess", bar.monitor.quitSelected) }
    }
    Menu {
        title: "Window"
        Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: bar.monitor.act("minimize", bar.monitor.showMinimized) }
        Platform.MenuItem { text: "Zoom"; onTriggered: bar.monitor.toggleZoom() }
    }
}
