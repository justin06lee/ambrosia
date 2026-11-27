pragma Singleton
import QtQuick
import Ambrosia

// Font Book's sizes and colors, measured from macOS 27's (2026-11-28: the
// grid, samples and list views, a typeface's page, the info pane and a
// font file's preview, with the window behind others, in Dark: the grays
// there are an inactive window's). The light colors are not measured: that
// Mac stays in Dark.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 26
    readonly property int width: 1000
    readonly property int height: 650
    readonly property int minWidth: 640
    readonly property int minHeight: 380

    // The toolbar: 52 tall, its capsules 36, 7 apart and 8 off the edge.
    // From the right: the search, the size slider with the info button in
    // one capsule (154), the views (three faces 32 by 28 in 115).
    readonly property int toolbar: 52
    readonly property int control: 36
    readonly property real gap: 7
    readonly property real edge: 8
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23
    readonly property int sidebarButtonX: 106
    readonly property int titleAfterSidebar: 21
    readonly property real searchWidth: 257.5
    readonly property real sizeWidth: 154
    readonly property real segment: 35.33
    readonly property real segmentFace: 32
    readonly property real stylesWidth: 129

    // The sidebar: 150 wide, flush and full height. Its headings 32 tall
    // (the words 22 down), rows 32 with the chosen one's fill 10 off each
    // side; a glyph at 22, the name at 47.5.
    readonly property int sidebarWidth: 150
    readonly property int sidebarTop: 40
    readonly property int sidebarRow: 32
    readonly property int sidebarInset: 10
    readonly property real sidebarGlyphX: 22
    readonly property real sidebarTextX: 47.5

    // The views begin 26 under the toolbar and 26 from the left, and end
    // 43 short of the right (26 and the scroller's 17). A card is 115
    // square with corners of 13, at least 18 from the next; rows of cards
    // 167 apart. A sample's card is 196 tall with a line of 34, 8 from the
    // next. The list's headings are 28 tall; its rows 27 apart, every other
    // one on a band 26 tall, 10 in from each side.
    readonly property int pad: 26
    readonly property int padRight: 43
    readonly property int card: 115
    readonly property int cardRadius: 13
    readonly property int cardGap: 18
    readonly property int cardLabel: 52
    readonly property int sampleGap: 8
    readonly property int header: 28
    readonly property int listRow: 27
    readonly property real listTop: 9.5
    readonly property int listInset: 10
    readonly property int scroller: 17
    readonly property int infoWidth: 250
    readonly property int infoPad: 17

    // A font file's preview: 500 by 432 under a title bar 32 tall; two
    // pop-ups 230 by 24 at 16, 48; the buttons' bar 45 tall.
    readonly property int previewWidth: 500
    readonly property int previewHeight: 432
    readonly property int previewRadius: 16
    readonly property int titleBar: 32
    readonly property int previewBar: 45

    readonly property color toolbarFill: dark ? "#282827" : "#f6f6f6"
    readonly property color sidebarFill: dark ? "#292624" : "#f0f0f0"
    readonly property color sidebarRule: dark ? "#3d3b3a" : "#dcdcdc"
    readonly property color ground: dark ? "#21201f" : "#ffffff"
    readonly property color hairline: dark ? "#31302f" : "#e2e2e2"
    readonly property color cardFill: dark ? "#292929" : "#f5f5f5"
    readonly property color cardRim: dark ? "#3e3e3e" : "#e0e0e0"
    readonly property color sampleFill: dark ? "#262423" : "#f7f7f7"
    readonly property color sampleRim: dark ? "#403e3d" : "#e0e0e0"
    readonly property color band: dark ? "#2b2a2a" : "#f4f5f5"
    readonly property color headerRule: dark ? "#464443" : "#dcdcdc"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color capsule: dark ? "#3c3b3a" : "#ffffff"
    readonly property color capsuleRim: dark ? "#14ffffff" : "#ffffff"
    readonly property color capsuleDivider: dark ? "#555453" : "#e2e2e2"
    readonly property color segmentChosen: dark ? "#504f4e" : "#e9e9e9"
    readonly property color pressed: dark ? "#22ffffff" : "#14000000"
    readonly property color track: dark ? "#4f4e4d" : "#dcdcdc"
    readonly property color trackFilled: dark ? "#676766" : "#b4b4b4"
    readonly property color trackFilledActive: dark ? "#a0a09f" : "#8a8a8a"
    readonly property color knob: dark ? "#f7f7f7" : "#ffffff"
    // A toolbar glyph and the title: in the window in front, behind, and
    // when what it does can't be done.
    readonly property color glyph: dark ? "#dfdfdf" : "#4a4a4a"
    readonly property color glyphInactive: dark ? "#6d6c6b" : "#b4b4b4"
    readonly property color glyphOff: dark ? "#5a5958" : "#c6c6c6"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#5f5f5d" : "#a8a8a8"
    readonly property color subtitle: dark ? "#9a9a98" : "#7e7e7e"
    // What a view says: a name, what stands under it, a heading.
    readonly property color text: dark ? "#dedede" : "#262626"
    readonly property color textInactive: dark ? "#9f9f9e" : "#5a5a5a"
    readonly property color note: dark ? "#979594" : "#7e7e7e"
    readonly property color heading: dark ? "#767271" : "#8a8a8a"
    readonly property color sidebarHeading: dark ? "#8a8685" : "#8a8a8a"
    readonly property color sidebarHeadingInactive: dark ? "#5c5857" : "#b0b0b0"
    readonly property color sidebarText: dark ? "#dfdfdf" : "#262626"
    readonly property color sidebarTextInactive: dark ? "#706c6b" : "#9a9a9a"
    readonly property color sidebarChosen: dark ? "#3f3b3a" : "#dedede"
    readonly property color sidebarChosenInactive: dark ? "#373332" : "#e4e4e4"
    readonly property color chosenInactive: dark ? "#3d3d3d" : "#dcdcdc"
    readonly property color menu: dark ? "#2b2a29" : "#f4f4f4"
    readonly property color menuRim: dark ? "#3affffff" : "#22000000"
    readonly property color menuRule: dark ? "#1fffffff" : "#1a000000"
    readonly property int menuRow: 24
    readonly property color previewBarFill: dark ? "#292827" : "#f6f6f6"
    readonly property color previewGround: dark ? "#252322" : "#ececec"
    readonly property color previewRule: dark ? "#3a3938" : "#d6d6d6"
    readonly property color popUp: dark ? "#353332" : "#ffffff"
    readonly property color popUpOff: dark ? "#2d2b2a" : "#f0f0f0"

    function chosen(active) {
        return active ? Theme.accent.bg : chosenInactive;
    }
}
