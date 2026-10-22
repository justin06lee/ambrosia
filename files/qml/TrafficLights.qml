import QtQuick
import QtQuick.Shapes
import Ambrosia

// Close, minimize and zoom, Finder's size and spacing. Gray while the
// window is inactive; their glyphs show while the pointer is over them.
Row {
    id: lights

    required property Window window
    readonly property bool active: window.looksActive

    spacing: Finder.lightPitch - Finder.lightSize

    HoverHandler { id: hover }

    Repeater {
        model: [
            { color: Theme.windowControls.close, glyph: "M4 4l6 6M10 4l-6 6", act: () => lights.window.close() },
            { color: Theme.windowControls.minimize, glyph: "M3.5 7h7", act: () => lights.window.showMinimized() },
            { color: Theme.windowControls.zoom, glyph: "M4.5 3.5h6v6M9.5 10.5h-6v-6",
              act: () => lights.window.visibility === Window.Maximized ? lights.window.showNormal() : lights.window.showMaximized() },
        ]

        Rectangle {
            id: light
            required property var modelData
            width: Finder.lightSize
            height: width
            radius: width / 2
            color: lights.active || hover.hovered ? modelData.color : Finder.lightInactive
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.12)

            Shape {
                // The glyph, on a 14-unit box.
                anchors.fill: parent
                visible: hover.hovered
                scale: light.width / 14
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(0, 0, 0, 0.55)
                    strokeWidth: 1.3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: light.modelData.glyph }
                }
            }
            TapHandler { onTapped: light.modelData.act() }
        }
    }
}
