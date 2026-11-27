import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Ambrosia

// A Mac app's Settings window, as an app of ours shows its own from the
// menu named for it (Preferences.qml shows it). Measured from macOS 27's
// Finder Settings in Dark (2026-11-27): 377 wide; under the 32 bar a strip
// 56 tall, the bar's color, with the tabs in its middle, each a glyph over
// its name on a 48-tall rounded fill when chosen (55 wide at least, the
// name and 13 otherwise, 1 apart); a hairline, then the tab's page on a
// ground a little darker. The window is as tall as its page asks, and
// changes with the tab. Ours is a plain window in the session's frame.
// One source for every app: each compiles it in (its CMakeLists.txt takes
// ../kit).
Window {
    id: prefs

    // [{ title, glyph, page }]: the tab's name, its glyph (one of `glyphs`
    // by name, or { stroke, fill } paths in a 24 box) and its page, a
    // Component whose root says how tall it is (implicitHeight).
    property var tabs: []
    property int current: 0

    readonly property real bar: Theme.size.titlebar.height
    // The system's appearance, read here (as AboutWindow.qml).
    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    // The strip is the frame's bar going on; the Mac's page is 7 levels
    // darker than its bar in Dark (#292826 over #22201f).
    readonly property color strip: colors.bg.window
    readonly property color ground: dark ? Qt.darker(strip, 1.2) : strip
    readonly property real stripHeight: 56

    // The glyphs tabs are commonly given, drawn by us in a 24 box.
    readonly property var glyphs: ({
        gear: { stroke: "M10.19 4.72L10.65 2.50L13.35 2.50L13.81 4.72A7.50 7.50 0 0 1 15.87 5.57L17.76 4.32L19.68 6.24L18.43 8.13A7.50 7.50 0 0 1 19.28 10.19L21.50 10.65L21.50 13.35L19.28 13.81A7.50 7.50 0 0 1 18.43 15.87L19.68 17.76L17.76 19.68L15.87 18.43A7.50 7.50 0 0 1 13.81 19.28L13.35 21.50L10.65 21.50L10.19 19.28A7.50 7.50 0 0 1 8.13 18.43L6.24 19.68L4.32 17.76L5.57 15.87A7.50 7.50 0 0 1 4.72 13.81L2.50 13.35L2.50 10.65L4.72 10.19A7.50 7.50 0 0 1 5.57 8.13L4.32 6.24L6.24 4.32L8.13 5.57A7.50 7.50 0 0 1 10.19 4.72ZM15.10 12.00A3.10 3.10 0 1 0 8.90 12.00A3.10 3.10 0 1 0 15.10 12.00Z" },
        gears: { stroke: "M7.87 4.26L8.19 2.47L10.21 2.47L10.53 4.26A5.50 5.50 0 0 1 12.04 4.89L13.52 3.84L14.96 5.28L13.91 6.76A5.50 5.50 0 0 1 14.54 8.27L16.33 8.59L16.33 10.61L14.54 10.93A5.50 5.50 0 0 1 13.91 12.44L14.96 13.92L13.52 15.36L12.04 14.31A5.50 5.50 0 0 1 10.53 14.94L10.21 16.73L8.19 16.73L7.87 14.94A5.50 5.50 0 0 1 6.36 14.31L4.88 15.36L3.44 13.92L4.49 12.44A5.50 5.50 0 0 1 3.86 10.93L2.07 10.61L2.07 8.59L3.86 8.27A5.50 5.50 0 0 1 4.49 6.76L3.44 5.28L4.88 3.84L6.36 4.89A5.50 5.50 0 0 1 7.87 4.26ZM11.40 9.60A2.20 2.20 0 1 0 7.00 9.60A2.20 2.20 0 1 0 11.40 9.60ZM16.58 13.64L16.80 12.27L18.40 12.27L18.62 13.64A3.70 3.70 0 0 1 19.75 14.19L20.96 13.49L21.96 14.75L21.02 15.78A3.70 3.70 0 0 1 21.29 17.00L22.59 17.51L22.23 19.08L20.84 18.98A3.70 3.70 0 0 1 20.06 19.96L20.47 21.30L19.02 22.00L18.23 20.85A3.70 3.70 0 0 1 16.97 20.85L16.18 22.00L14.73 21.30L15.14 19.96A3.70 3.70 0 0 1 14.36 18.98L12.97 19.08L12.61 17.51L13.91 17.00A3.70 3.70 0 0 1 14.18 15.78L13.24 14.75L14.24 13.49L15.45 14.19A3.70 3.70 0 0 1 16.58 13.64ZM19.10 17.20A1.50 1.50 0 1 0 16.10 17.20A1.50 1.50 0 1 0 19.10 17.20Z" },
        sidebar: { stroke: "M6 4.5h12a3 3 0 0 1 3 3v9a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-9a3 3 0 0 1 3-3zM9.6 4.5v15M5.4 8.3h1.9M5.4 11h1.9M5.4 13.7h1.9" },
        document: { stroke: "M7 3.5h6.5L18.5 8.5v10.5a1.5 1.5 0 0 1-1.5 1.5H7a1.5 1.5 0 0 1-1.5-1.5V5A1.5 1.5 0 0 1 7 3.5zM13.5 3.5V8.5h5" },
        folder: { stroke: "M3.5 7.2a2 2 0 0 1 2-2h3.6l2 2.3h7.4a2 2 0 0 1 2 2v7.8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z" },
    })

    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinimizeButtonHint
    // As tall as the page; fixed (no zoom, no resizing by hand).
    readonly property real tall: stripHeight + 0.5 + (page.item?.implicitHeight ?? 100)
    width: 377
    height: tall
    minimumWidth: 377
    maximumWidth: 377
    minimumHeight: tall
    maximumHeight: tall
    color: ground

    Rectangle {
        width: prefs.width
        height: prefs.stripHeight
        color: prefs.strip

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1
            // A window that isn't in front has its tabs dimmed.
            opacity: prefs.active ? 1 : 0.78

            Repeater {
                model: prefs.tabs

                Rectangle {
                    id: tab

                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === prefs.current
                    readonly property var shape: typeof modelData.glyph === "string" ? prefs.glyphs[modelData.glyph] ?? ({}) : modelData.glyph ?? ({})
                    readonly property color ink: chosen ? prefs.colors.label.primary : prefs.colors.label.secondary

                    width: Math.max(55, Math.ceil(name.implicitWidth) + 13)
                    height: 48
                    radius: 8
                    color: !chosen ? "transparent" : prefs.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
                    border.width: chosen ? 0.5 : 0
                    border.color: prefs.dark ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(0, 0, 0, 0.08)
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.title

                    Shape {
                        x: (tab.width - 24) / 2
                        y: 4
                        width: 24
                        height: 24
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: tab.shape.stroke ? tab.ink : "transparent"
                            strokeWidth: tab.shape.width ?? 1.4
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: tab.shape.stroke ?? "" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: tab.shape.fill ? tab.ink : "transparent"
                            fillRule: ShapePath.WindingFill
                            PathSvg { path: tab.shape.fill ?? "" }
                        }
                    }
                    Text {
                        id: name
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40 - baselineOffset
                        text: tab.modelData.title
                        color: tab.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }
                    TapHandler { onTapped: prefs.current = tab.index }
                }
            }
        }
    }
    Rectangle {
        y: prefs.stripHeight
        width: prefs.width
        height: 0.5
        color: prefs.dark ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0, 0, 0, 0.1)
    }
    Loader {
        id: page
        y: prefs.stripHeight + 0.5
        width: prefs.width
        sourceComponent: prefs.tabs[prefs.current]?.page ?? null
    }

    Shortcut { sequences: ["Ctrl+W"]; onActivated: prefs.close() }
}
