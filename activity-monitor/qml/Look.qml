pragma Singleton
import QtQuick
import Ambrosia

// Activity Monitor's sizes and colors, measured from macOS 27's (2026-11-27,
// each tab, a selected row, the inspector and the quit alert, with the
// window behind others, in Dark: the grays there are an inactive window's).
// The light colors are not measured: that Mac stays in Dark.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 26
    readonly property int width: 960
    readonly property int height: 858
    readonly property int minWidth: 690
    readonly property int minHeight: 360

    // The toolbar: 52 tall, its capsules 36. From the right: the search,
    // the five tabs (74 each, the chosen one's face 68 by 28), the views'
    // pop-down, and Quit with Inspect in one capsule.
    readonly property int toolbar: 52
    readonly property int control: 36
    readonly property real gap: 9
    readonly property real edge: 8
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23
    readonly property real titleX: 108.5
    readonly property real searchWidth: 182
    readonly property int tabWidth: 74
    readonly property int tabFace: 28
    readonly property real actionsWidth: 73
    readonly property real viewsWidth: 44

    // The table: its header 28 under the toolbar, rows 24 with 5 above the
    // first, every other one a shade lighter all the way down. An icon is
    // 14, at 29; names begin at 54.5. Between two columns, 17: a number
    // ends 10.5 before the next column's rule, its heading 12.5 before.
    readonly property int header: 28
    readonly property int row: 24
    readonly property int rowsTop: 5
    readonly property int icon: 14
    readonly property real iconX: 29
    readonly property real nameX: 54.5
    readonly property real cellPad: 10.5
    readonly property real headPad: 12.5
    readonly property int trailing: 26
    readonly property int minName: 150
    readonly property int textSize: 12

    // Under the table: a rule, then a box 90 tall and 580 wide (590 on
    // Network) in three panes, 12 under the rule and 14 off the bottom.
    readonly property int panel: 116
    readonly property int box: 90
    readonly property int boxTop: 12
    readonly property int boxWidth: 580
    readonly property int statRow: 20
    readonly property int history: 120

    readonly property color toolbarFill: dark ? "#282827" : "#f6f6f6"
    readonly property color ground: dark ? "#212020" : "#ffffff"
    readonly property color band: dark ? "#2b2a2a" : "#f4f5f5"
    readonly property color headerRule: dark ? "#414140" : "#dcdcdc"
    readonly property color columnRule: dark ? "#494948" : "#d6d6d6"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color capsule: dark ? "#3b3b3a" : "#ffffff"
    readonly property color capsuleRim: dark ? "#14ffffff" : "#ffffff"
    readonly property color capsuleDivider: dark ? "#555453" : "#e2e2e2"
    readonly property color tabChosen: dark ? "#4f4f4e" : "#e9e9e9"
    readonly property color pressed: dark ? "#22ffffff" : "#14000000"
    // A toolbar glyph, a tab's name and the title: in the window in front,
    // behind, and when what it does can't be done.
    readonly property color glyph: dark ? "#dfdfdf" : "#4a4a4a"
    readonly property color glyphInactive: dark ? "#6e6e6d" : "#b4b4b4"
    readonly property color glyphOff: dark ? "#5c5c5b" : "#c6c6c6"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#5f5f5d" : "#a8a8a8"
    readonly property color subtitle: dark ? "#9a9a98" : "#7e7e7e"
    readonly property color headText: dark ? "#ffffff" : "#262626"
    readonly property color sortArrow: dark ? "#7a7a79" : "#8c8c8c"
    readonly property color text: dark ? "#dddddd" : "#262626"
    // The chosen row behind other windows; in front it is the accent.
    readonly property color chosenInactive: dark ? "#3d3d3d" : "#dcdcdc"
    readonly property color boxFill: dark ? "#2a2929" : "#f6f6f6"
    readonly property color boxRule: dark ? "#9c9c9c" : "#b9b9b9"
    readonly property color statText: dark ? "#dfdede" : "#262626"
    readonly property color graphTitle: dark ? "#9f9f9f" : "#6e6e6e"
    readonly property color red: dark ? "#f74342" : "#ff3b30"
    readonly property color blue: dark ? "#4acbfa" : "#2aa7e8"
    readonly property color green: dark ? "#3ec95a" : "#34c759"
    readonly property color yellow: dark ? "#ffd60a" : "#f5c400"
    readonly property color menu: dark ? "#2b2a29" : "#f4f4f4"
    readonly property color menuRim: dark ? "#3affffff" : "#22000000"
    readonly property color menuRule: dark ? "#1fffffff" : "#1a000000"
    readonly property int menuRow: 24

    // A process's inspector: 559 by 338 under a title bar 32 tall, labels
    // at 20.5 and what they name at 109, 22 a line; three tabs on one face
    // over a box.
    readonly property int inspectorWidth: 559
    readonly property int inspectorHeight: 338
    readonly property int inspectorRadius: 16
    readonly property int titleBar: 32
    readonly property color inspectorBar: dark ? "#292828" : "#f6f6f6"
    readonly property color inspectorGround: dark ? "#222120" : "#ececec"
    readonly property color inspectorBox: dark ? "#292827" : "#e6e6e6"
    readonly property color inspectorBoxRim: dark ? "#434241" : "#d2d2d2"
    readonly property color segments: dark ? "#323130" : "#dedede"
    readonly property color segmentChosen: dark ? "#41403f" : "#ffffff"
    readonly property color link: dark ? "#419cff" : "#0068d9"
    readonly property color well: dark ? "#1a1a19" : "#ffffff"

    function chosen(active) {
        return active ? Theme.accent.bg : chosenInactive;
    }
}
