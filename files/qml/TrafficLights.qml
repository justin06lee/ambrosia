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
            { color: Theme.windowControls.close, glyph: Theme.windowGlyphs.close, act: () => lights.window.close() },
            { color: Theme.windowControls.minimize, glyph: Theme.windowGlyphs.minimize, act: () => lights.window.showMinimized() },
            { color: Theme.windowControls.zoom, glyph: Theme.windowGlyphs.zoom,
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
                // The tokens' glyph, filled on the light's own box (the KWin frame draws the same).
                anchors.fill: parent
                visible: hover.hovered
                scale: light.width / Theme.size.windowControls.diameter
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.rgba(0, 0, 0, Theme.windowGlyphs.opacity)
                    PathSvg { path: light.modelData.glyph }
                }
            }
            TapHandler { onTapped: light.modelData.act() }
        }
    }
}
