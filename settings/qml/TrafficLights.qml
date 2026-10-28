import QtQuick
import QtQuick.Shapes
import Ambrosia
import Settings

// Close, minimize and zoom, as Files draws them (files/qml/TrafficLights.qml).
// Gray while the window is inactive; their glyphs show while the pointer is
// over them. Settings keeps its width, so zoom fills the screen's height
// (App.zoom) and shows plus, as System Settings' does; `zoomable: false`
// grays it out.
Row {
    id: lights

    required property Window window
    readonly property bool active: window.looksActive
    property bool zoomable: true

    spacing: Look.lightPitch - Look.lightSize

    HoverHandler { id: hover }

    Repeater {
        model: [
            { color: Theme.windowControls.close, glyph: Theme.windowGlyphs.close, act: () => lights.window.close() },
            { color: Theme.windowControls.minimize, glyph: Theme.windowGlyphs.minimize, act: () => lights.window.showMinimized() },
            { color: Theme.windowControls.zoom, glyph: Theme.windowGlyphs.plus, off: !lights.zoomable,
              act: () => App.zoom(lights.window) },
        ]

        Rectangle {
            id: light
            required property var modelData
            width: Look.lightSize
            height: width
            radius: width / 2
            color: !modelData.off && (lights.active || hover.hovered) ? modelData.color : Look.lightInactive
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.12)

            Shape {
                // The tokens' glyph, filled on the light's own box (the KWin frame draws the same).
                anchors.fill: parent
                visible: hover.hovered && !light.modelData.off
                scale: light.width / Theme.size.windowControls.diameter
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.rgba(0, 0, 0, Theme.windowGlyphs.opacity)
                    PathSvg { path: light.modelData.glyph }
                }
            }
            TapHandler { enabled: !light.modelData.off; onTapped: light.modelData.act() }
        }
    }
}
