import QtQuick
import QtQuick.Shapes
import Ambrosia
import Settings

// Close, minimize and zoom, as Files draws them (files/qml/TrafficLights.qml).
// Gray while the window is inactive; their glyphs show while the pointer is
// over them. Settings keeps its width, so zoom fills the screen's height
// (App.zoom) and shows plus, as System Settings' does; `zoomable: false`
// grays it out, `closable: false` close (under a sheet).
Row {
    id: lights

    required property Window window
    readonly property bool active: window.looksActive
    property bool zoomable: true
    property bool closable: true

    spacing: Look.lightPitch - Look.lightSize

    HoverHandler { id: hover }

    Repeater {
        model: [
            { color: Theme.windowControls.close, rim: Theme.windowControls.closeRim, glyph: Theme.windowGlyphs.close, off: !lights.closable,
              act: () => lights.window.close() },
            { color: Theme.windowControls.minimize, rim: Theme.windowControls.minimizeRim, glyph: Theme.windowGlyphs.minimize, act: () => lights.window.showMinimized() },
            { color: Theme.windowControls.zoom, rim: Theme.windowControls.zoomRim, glyph: Theme.windowGlyphs.plus, off: !lights.zoomable,
              act: () => App.zoom(lights.window) },
        ]

        Rectangle {
            id: light
            required property var modelData
            width: Look.lightSize
            height: width
            radius: width / 2
            readonly property bool lit: !modelData.off && (lights.active || hover.hovered)
            color: lit ? modelData.color : Look.lightInactive
            // Half a point inside the edge: a deeper shade while lit, black when not.
            border.width: 0.5
            border.color: lit ? modelData.rim : Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.12)

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
