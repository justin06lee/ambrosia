import QtQuick
import QtQuick.Window
import org.ambrosia.kwin as AmbrosiaKWin
import Ambrosia

// Where a window will land, shown while it is dragged to a screen's edge or
// corner: a pane of glass a little inside the place, as a Mac shows a tile's
// preview, in place of KWin's own outline (the session's kwinrc names this
// file). KWin gives `outline`: the place (geometry), the room this window
// has to cover (unifiedGeometry), and whether to show at all (active).
Window {
    id: window

    // How far inside the place the glass is drawn.
    readonly property int inset: Theme.space.s2

    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    color: "transparent"
    x: outline.unifiedGeometry.x
    y: outline.unifiedGeometry.y
    width: outline.unifiedGeometry.width
    height: outline.unifiedGeometry.height
    visible: outline.active

    // KWin's colors are the color scheme's: dark when its window color is.
    SystemPalette { id: system }
    Binding { target: Theme; property: "dark"; value: system.window.hslLightness < 0.5 }

    // KWin blurs behind its own windows only where it is told to.
    AmbrosiaKWin.BlurBehind { item: glass; radius: glass.radius; material: "clear" }

    Rectangle {
        id: glass
        x: outline.geometry.x - outline.unifiedGeometry.x + window.inset
        y: outline.geometry.y - outline.unifiedGeometry.y + window.inset
        width: Math.max(outline.geometry.width - 2 * window.inset, 0)
        height: Math.max(outline.geometry.height - 2 * window.inset, 0)
        radius: Theme.radius.window
        color: Theme.color.material.clear.tint
        border.width: 1
        border.color: Theme.color.glass.edge

        opacity: outline.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.fast } }

        // The lit rim just inside the edge, as on the shell's glass.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.color.glass.rim
        }
    }
}
