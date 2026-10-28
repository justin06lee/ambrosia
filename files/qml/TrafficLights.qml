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
            { color: Theme.windowControls.close, rim: Theme.windowControls.closeRim, glyph: Theme.windowGlyphs.close, act: () => lights.window.close() },
            { color: Theme.windowControls.minimize, rim: Theme.windowControls.minimizeRim, glyph: Theme.windowGlyphs.minimize, act: () => lights.window.showMinimized() },
            { color: Theme.windowControls.zoom, rim: Theme.windowControls.zoomRim, glyph: Theme.windowGlyphs.zoom,
              act: () => lights.window.visibility === Window.Maximized ? lights.window.showNormal() : lights.window.showMaximized() },
        ]

        Rectangle {
            id: light
            required property var modelData
            width: Finder.lightSize
            height: width
            radius: width / 2
            readonly property bool lit: lights.active || hover.hovered
            color: lit ? modelData.color : Finder.lightInactive
            // Half a point inside the edge: a deeper shade while lit, black when not.
            border.width: 0.5
            border.color: lit ? modelData.rim : Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.12)

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
