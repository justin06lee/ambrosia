pragma Singleton
import QtQuick
import Ambrosia

// TextEdit's sizes and colors, measured from macOS 27's TextEdit
// (2026-11-27: a plain text and a rich text document, each in a window
// behind the others, in Dark). The light colors are not measured (that Mac
// stays in Dark): they are Files' and Settings', and the format bar's by
// eye from them.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 15
    // A new document's window, plain and rich, and how much of a rich
    // one isn't its text (RTF's \vieww and \viewh say the rest).
    readonly property int plainWidth: 673
    readonly property int plainHeight: 439
    readonly property int richWidth: 603
    readonly property int richHeight: 505
    readonly property int viewAside: 27
    readonly property int viewAbove: 85
    readonly property int minWidth: 320
    readonly property int richMinWidth: 585
    readonly property int minHeight: 180

    // The title bar, the format bar under it (no line between them), the
    // ruler under that: where each ends, from the window's top.
    readonly property real titleBar: 32.5
    readonly property real formatBar: 68.5
    readonly property real ruler: 100.5
    readonly property int lightsX: 9
    readonly property int lightsY: 9
    readonly property int lightSize: 14
    readonly property int lightPitch: 23
    readonly property real titleIconX: 84.5
    readonly property real titleX: 103

    // The format bar's controls: 20 tall from 40 down, corners 6.
    readonly property int controlY: 40
    readonly property int control: 20
    readonly property int controlRadius: 6

    // The ruler: its line at 83, a mark every centimetre (28.35) from 5,
    // the longer ones with their number every second one.
    readonly property real rulerLine: 83
    readonly property real rulerOrigin: 5.5
    readonly property real centimetre: 28.3465
    readonly property real inch: 72

    // The text's own margins: rich text starts at the ruler's zero.
    readonly property int richInset: 5
    readonly property int plainInset: 10

    readonly property color bar: dark ? "#2b2928" : "#f4f4f4"
    readonly property color barLine: dark ? "#313130" : "#dcdcdc"
    readonly property color controlFill: dark ? "#454342" : "#e3e3e3"
    readonly property color controlChosen: dark ? "#6a6867" : "#c4c4c4"
    readonly property color controlPressed: dark ? "#585655" : "#d2d2d2"
    readonly property color field: dark ? "#191918" : "#ffffff"
    readonly property color fieldButton: dark ? "#333332" : "#e3e3e3"
    readonly property color glyph: dark ? "#ececec" : "#2a2a2a"
    readonly property color glyphDim: dark ? "#7f7d7d" : "#a2a2a2"
    readonly property color controlText: dark ? "#e5e5e4" : "#262626"
    readonly property color rulerFill: dark ? "#222120" : "#fafafa"
    readonly property color rulerMark: dark ? "#585857" : "#b4b4b4"
    readonly property color rulerEdge: dark ? "#383736" : "#dcdcdc"
    readonly property color rulerNumber: dark ? "#dddddd" : "#3c3c3c"
    readonly property color marker: dark ? "#9b9b9a" : "#7a7a7a"
    readonly property color page: dark ? "#1c1c1c" : "#ffffff"
    readonly property color text: dark ? "#ffffff" : "#000000"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#646261" : "#a8a8a8"
    readonly property color titleNote: dark ? "#9a9a98" : "#7e7e7e"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color menu: dark ? "#2b2a29" : "#f4f4f4"
    readonly property color menuRim: dark ? "#3affffff" : "#22000000"
    readonly property color menuRule: dark ? "#1fffffff" : "#1a000000"
    readonly property int menuRow: 24
    // Selected text in the window in front, and behind.
    readonly property color selection: Qt.alpha(Theme.accent.bg, dark ? 0.55 : 0.3)
    readonly property color selectionInactive: dark ? "#464646" : "#d4d4d4"

    // The colors the text color well offers: black is the text's own
    // color (white in Dark, as a Mac's TextEdit shows it).
    readonly property var textColors: [
        "#000000", "#424242", "#7a7a7a", "#a9a9a9", "#d6d6d6", "#ffffff", "#941100", "#945200",
        "#ff2600", "#ff9300", "#fffb00", "#8efa00", "#00f900", "#00fdff", "#0096ff", "#0433ff",
        "#ff7e79", "#ffd479", "#fffc79", "#d4fb79", "#73fa79", "#73fdff", "#76d6ff", "#7a81ff",
        "#941751", "#531b93", "#011993", "#005493", "#009193", "#009051", "#4f8f00", "#929000",
        "#ff40ff", "#9437ff", "#d783ff", "#ff8ad8", "#ff2f92", "#aa7942", "#fff5d6", "#d5e8d4",
    ]
    // A highlighter's colors; none is the first.
    readonly property var highlights: ["", "#fff176", "#b9f18c", "#a5d8ff", "#ffb3d1", "#d7b8ff", "#ffc98a"]

    // A length on the device's own pixels: 32.5 is 33 at 1x, itself at 2x.
    function snap(length, ratio) {
        return Math.round(length * ratio) / ratio;
    }
}
