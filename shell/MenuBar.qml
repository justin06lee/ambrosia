import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import Ambrosia

// The menu bar: the system mark, the focused app's name and menus on the
// left; status, the control center and the clock on the right. Thin glass:
// the material's tint over the compositor's blur.
PanelWindow {
    id: bar

    // The focused app's name and menus. Until the KWin window bridge lands
    // these are the file manager's, as the Mac shows Finder's.
    property string appName: "Files"
    property var menus: ["File", "Edit", "View", "Go", "Window", "Help"]

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.size.menubar.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ambrosia-menubar"
    BackgroundEffect.blurRegion: Region { item: glass }

    Rectangle {
        id: glass
        anchors.fill: parent
        color: Theme.color.material.thin.tint

        // The hairline under the bar.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 0.5
            color: Theme.color.separator
        }
    }

    Row {
        anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

        MenuBarItem { icon: "drop"; iconSize: 15 }
        MenuBarItem { text: bar.appName; bold: true }
        Repeater {
            model: bar.menus
            MenuBarItem { required property string modelData; text: modelData }
        }
    }

    Row {
        anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

        MenuBarItem { icon: "battery"; visible: UPower.displayDevice.isLaptopBattery }
        MenuBarItem { icon: "wifi" }
        MenuBarItem { icon: "search" }
        MenuBarItem { icon: "controls" }
        MenuBarItem {
            text: Qt.formatDateTime(clock.date, "ddd MMM d  h:mm AP")
            padding: Theme.space.s2
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
