import QtQuick
import QtQuick.Effects
import Ambrosia
import Files
import org.ambrosia.glass

// The floating sidebar, Files' default (macOS 26's Finder): an inset,
// rounded glass panel holding the traffic lights and the places. Its
// stand-in is SidebarFlush; both take the window as `finder` and fill the
// space FinderWindow gives them.
Item {
    id: sidebar

    required property var finder

    // Glass where the compositor has our effect (org.ambrosia.glass), and
    // see-through only in the window in front, as a Mac's sidebar is: the
    // window leaves a hole under it then (Backing.qml). Solid otherwise.
    readonly property bool glassy: pane.available
    readonly property bool clear: glassy && sidebar.finder.looksActive
    readonly property int room: 24

    // The panel's shadow on the window around it, cut away under the panel
    // itself: glass is only as dark as its tint.
    Item {
        id: cast
        anchors.fill: parent
        anchors.margins: -sidebar.room
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: outline
        }

        Rectangle {
            x: sidebar.room
            y: sidebar.room
            width: sidebar.width
            height: sidebar.height
            radius: Finder.sidebarRadius
            color: Finder.sidebar
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
    }

    Item {
        id: outline
        anchors.fill: cast
        visible: false
        layer.enabled: true

        Rectangle {
            x: sidebar.room
            y: sidebar.room
            width: sidebar.width
            height: sidebar.height
            radius: Finder.sidebarRadius
        }
    }

    GlassPane {
        id: pane
        anchors.fill: parent
        radius: Finder.sidebarRadius
        material: "regular"
        visible: panel.color.a < 1
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Finder.sidebarRadius
        color: sidebar.clear ? Finder.sidebarGlass : Finder.sidebar
        border.width: 0.5
        border.color: Finder.sidebarRim

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    TrafficLights {
        // Another app's panel has none: Cancel closes it.
        visible: !sidebar.finder.isPanel
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
