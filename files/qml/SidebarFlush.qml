import QtQuick
import Ambrosia
import Files

// The flush sidebar, the other variant behind the same interface as
// Sidebar: a full-height pane along the window's left edge, split from the
// folder by a hairline, as Ambrosia's behind-window glass would draw it
// (design/DECISIONS.md). A stub, chosen with --sidebar flush or
// sidebar=flush in ~/.config/ambrosia/files.conf: it has no blur yet and
// isn't measured against anything.
Item {
    id: sidebar

    required property var finder

    // Rounded where the window is, square against the folder.
    Rectangle {
        anchors.fill: parent
        radius: Finder.windowRadius
        color: Finder.sidebar
    }
    Rectangle {
        x: Finder.windowRadius
        width: parent.width - x
        height: parent.height
        color: Finder.sidebar
    }
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Finder.separator
    }

    TrafficLights {
        x: Finder.lightsX
        y: Finder.lightsY
        window: sidebar.finder.window
    }

    SidebarList {
        anchors.fill: parent
        anchors.topMargin: Finder.sidebarInset + Finder.sidebarFirstRow
        anchors.rightMargin: 1
        leading: Finder.sidebarInset
        finder: sidebar.finder
    }
}
