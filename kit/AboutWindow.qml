import QtQuick
import QtQuick.Window
import Ambrosia

// A Mac's About panel, as every app of ours shows it from the menu named
// for it. Measured from macOS 27's (TextEdit's, in Dark, 2026-11-27): 284
// by 204 with the lights over the window's own color and no title; the
// icon in a 66 box 39 down, the name in bold 15 on a baseline at 126.5,
// the version in 11 at 147, two more lines of 11 at 168 and 181, all
// centered. Ours is a plain window in the session's frame, whose bar is
// the window's color: the measures below are the Mac's less the bar.
// One source for every app: each compiles it in (its CMakeLists.txt takes
// ../kit), with About.qml, the one that shows it.
Window {
    id: about

    // The app's name, its version, and its icon's name in the Ambrosia
    // icon theme.
    property string name
    property string version
    property string icon

    readonly property real bar: Theme.size.titlebar.height
    // The system's appearance, read here: not every app of ours tells the
    // theme which is on (Calculator is dark whatever it is), and the frame
    // round the panel follows the system.
    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property color ink: colors.label.primary

    // No title, as a Mac's has none. An empty one, or one of spaces, is
    // filled in with the app's name on the way to the frame: this is a
    // letter that takes no room (a zero-width space).
    title: "\u200B"
    flags: Qt.Dialog | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    // The Mac's size, less the frame's bar; fixed (no zoom, no resizing).
    readonly property real tall: 204 - bar
    width: 284
    height: tall
    minimumWidth: 284
    maximumWidth: 284
    minimumHeight: tall
    maximumHeight: tall
    color: colors.bg.window

    // A baseline's y in the Mac's panel, top of the bar and all.
    component Line: Text {
        property real line
        x: 0
        width: about.width
        y: line - about.bar - baselineOffset
        horizontalAlignment: Text.AlignHCenter
        color: about.ink
        font.family: Theme.uiFont
        font.pixelSize: 11
        renderType: Text.NativeRendering
    }

    // Our icons' tiles fill a little less of their box than a Mac's: the
    // box is 69 for the tile to come out the Mac's 52, its top at 46.
    Image {
        x: (about.width - width) / 2
        y: 38 - about.bar
        width: 69
        height: 69
        sourceSize: Qt.size(138, 138)
        source: about.icon ? "file:///usr/share/icons/Ambrosia/apps/scalable/" + about.icon + ".svg" : ""
    }
    Line { line: 126.5; text: about.name; font.pixelSize: 15; font.weight: Font.Bold }
    Line { line: 147; text: "Version " + about.version }
    Line { line: 168; text: "Part of Ambrosia." }
    Line { line: 181; text: "Released under the MIT License." }

    Shortcut { sequences: ["Ctrl+W"]; onActivated: about.close() }
}
