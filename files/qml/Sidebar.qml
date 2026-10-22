import QtQuick
import QtQuick.Effects
import Ambrosia
import Files

// The floating sidebar, Files' default (macOS 26's Finder): an inset,
// rounded glass panel holding the traffic lights and the places. Its
// stand-in is SidebarFlush; both take the window as `finder` and fill the
// space FinderWindow gives them.
Item {
    id: sidebar

    required property var finder

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Finder.sidebarRadius
        color: Finder.sidebar
        border.width: 0.5
        border.color: Finder.sidebarRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.4 : 0.09
            shadowBlur: 0.5
            shadowVerticalOffset: 1
            blurMax: 24
        }
    }

    TrafficLights {
        x: Finder.lightsX - Finder.sidebarInset
        y: Finder.lightsY - Finder.sidebarInset
        window: sidebar.finder.window
    }

    SidebarList {
        anchors.fill: parent
        anchors.topMargin: Finder.sidebarFirstRow
        finder: sidebar.finder
    }
}
