pragma Singleton
import QtQuick
import Ambrosia

// Preview's sizes and colors, measured from macOS 27's Preview (2026-11-27,
// a picture and a three-page PDF, each in a window behind the others, in
// Dark: the grays there are an inactive window's). The light colors are
// Files' and Settings', not measured: that Mac stays in Dark.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 26
    readonly property int minWidth: 480
    readonly property int minHeight: 300
    // What a new window leaves of the screen: the menu bar above, the Dock
    // below, a little at the sides.
    readonly property int screenTop: 34
    readonly property int screenBottom: 96
    readonly property int screenSide: 20

    // The toolbar: 52 tall, its capsules 36, 7.5 apart and from the edge.
    readonly property int toolbar: 52
    readonly property int control: 36
    readonly property real gap: 7.5
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23
    readonly property int sidebarButtonX: 96
    readonly property int sidebarButtonWidth: 48
    readonly property real titleX: 165.5
    readonly property int titleAfterSidebar: 20
    readonly property real zoomWidth: 110
    readonly property real searchWidth: 288.5

    // The sidebar: 205 wide, flush and full height; thumbnails 159 across
    // in a highlight 171 across that begins right under the toolbar.
    readonly property int sidebarWidth: 205
    readonly property int thumbWidth: 159
    readonly property int thumbPad: 6
    readonly property int thumbLabel: 19
    readonly property int thumbGap: 10
    readonly property int thumbRadius: 6
    readonly property int thumbHighlightRadius: 10

    // A picture opens with 26 of ground above and below it; a PDF's pages
    // are 10 apart with 96 of ground beside them in a new window.
    readonly property int pictureMargin: 26
    readonly property int pageGap: 10
    readonly property int pagesBeside: 96

    readonly property color toolbarFill: dark ? "#2a2828" : "#f6f6f6"
    readonly property color sidebarFill: dark ? "#292624" : "#f0f0f0"
    readonly property color ground: dark ? "#222120" : "#ebebeb"
    readonly property color hairline: dark ? "#313130" : "#dadada"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color capsule: dark ? "#3d3c3b" : "#ffffff"
    readonly property color capsuleRim: dark ? "#14ffffff" : "#ffffff"
    readonly property color capsuleDivider: dark ? "#555453" : "#e2e2e2"
    readonly property color pressed: dark ? "#22ffffff" : "#14000000"
    // A toolbar glyph and the title: in the window in front, behind, and
    // when what it does can't be done.
    readonly property color glyph: dark ? "#dfdfdf" : "#4a4a4a"
    readonly property color glyphInactive: dark ? "#6d6c6b" : "#b4b4b4"
    readonly property color glyphOff: dark ? "#5a5958" : "#c6c6c6"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#5f5f5d" : "#a8a8a8"
    readonly property color subtitle: dark ? "#9a9a98" : "#7e7e7e"
    readonly property color thumbLabelColor: dark ? "#767371" : "#8a8a8a"
    readonly property color menu: dark ? "#2b2a29" : "#f4f4f4"
    readonly property color menuRim: dark ? "#3affffff" : "#22000000"
    readonly property color menuRule: dark ? "#1fffffff" : "#1a000000"
    readonly property int menuRow: 24
    // Text found in a page, and the one the search is at.
    readonly property color found: "#66ffe100"
    readonly property color foundCurrent: "#b3ff9d0a"

    // The selected thumbnail's highlight: the accent in the window in
    // front, a grayed share of it behind (#3b4963 measured, of blue).
    function highlight(active) {
        const accent = Theme.accent.bg;
        return active ? accent : Qt.rgba(accent.r * 0.25 + (dark ? 0.19 : 0.62), accent.g * 0.25 + (dark ? 0.155 : 0.6), accent.b * 0.25 + (dark ? 0.14 : 0.58), 1);
    }
}
