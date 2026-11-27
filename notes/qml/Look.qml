pragma Singleton
import QtQuick
import Ambrosia

// Notes' sizes and colors, measured from macOS 27's (2026-11-28, in Dark,
// its window behind others: the grays there are an inactive window's; the
// front window's and the light colors are ours, not measured: that Mac
// stays in Dark). Only the frame was looked at: the bars, the sidebar's
// and the list's rows by their runs of color, the Format menu.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 26
    readonly property int width: 1000
    readonly property int height: 660
    readonly property int minWidth: 620
    readonly property int minHeight: 320

    // The bar: 52 tall, its round buttons 36 across from 9 down, 7.5 from
    // a column's edge and 8 from each other. The lights 14 across from 19.
    readonly property int toolbar: 52
    readonly property int control: 36
    readonly property int controlY: 9
    readonly property real edge: 7.5
    readonly property int gap: 8
    readonly property int lightsX: 19
    readonly property int lightsY: 20
    readonly property int lightSize: 14
    readonly property int lightPitch: 23

    // The sidebar: 228 wide, flush and full height. A heading 19 tall (11
    // bold, 17 in), rows 32 with the chosen one's fill 10 off each side and
    // 1 off top and bottom, cornered by 8: the glyph from 16, the name from
    // 40, the count ending 19 from the right.
    readonly property int sidebarWidth: 228
    readonly property int sidebarHeading: 19
    readonly property int sidebarRow: 32
    readonly property int sidebarInset: 10
    readonly property real sidebarGlyphX: 16
    readonly property real sidebarTextX: 40
    readonly property real sidebarCountInset: 19

    // The list: 280 wide. Its name in the bar 21 in (13 bold on a baseline
    // 24 down, the count 11 on 38). A heading 40 tall, 15 bold from 17 on
    // a baseline 24.5 down, the one at the top held under the bar on the
    // bar's color; 10 over the first heading, 20 between a section and the
    // next heading. A row 56 tall on a fill 10 off each side cornered by
    // 8: its name 13 bold from 35 on a baseline 24, the line under it 12
    // on 39.5; a rule under each from 35 to 16 short of the right.
    readonly property int listWidth: 280
    readonly property real listTitleX: 21
    readonly property real listTitleBase: 24
    readonly property real listCountBase: 38
    readonly property int listHeading: 40
    readonly property real listHeadingX: 17
    readonly property real listHeadingBase: 24.5
    readonly property int listTop: 10
    readonly property int listSectionGap: 20
    readonly property int listRow: 56
    readonly property int listInset: 10
    readonly property real listTextX: 35
    readonly property real listNameBase: 24
    readonly property real listLineBase: 39.5
    readonly property real listRuleEnd: 16

    // The note: its text 24 in from each side; over it the date, 12, its
    // middle 15.5 down. New Note 8.5 after the list's edge; the Format
    // group 43 after that, each of its buttons 39 wide.
    readonly property int noteInset: 24
    readonly property real noteDateY: 15.5
    readonly property int noteTextY: 36
    readonly property real composeX: 8.5
    readonly property int groupAfterCompose: 43
    readonly property int groupCell: 39

    // The Format menu: 178 wide, cornered by 18; B I U S 29 apart from
    // 21.5 in, 19 down; a rule 38 down; the kinds from 36.5 in, the first
    // centered 59 down and each 29.3 under the last, the current one's
    // check centered 22 in; a rule, then Block Quote.
    readonly property int formatWidth: 178
    readonly property int formatRadius: 18
    readonly property real formatMarkX: 21.5
    readonly property real formatMarkPitch: 29
    readonly property real formatMarkY: 19
    readonly property real formatRule: 38
    readonly property real formatFirst: 59
    readonly property real formatPitch: 29.3
    readonly property real formatTextX: 36.5
    readonly property real formatCheckX: 22

    readonly property color sidebarFill: dark ? "#282624" : "#eeeeed"
    readonly property color listFill: dark ? "#212020" : "#fbfbfb"
    readonly property color listBar: dark ? "#292827" : "#f4f4f4"
    readonly property color noteFill: dark ? "#1c1c1c" : "#ffffff"
    readonly property color noteBar: dark ? "#272726" : "#f6f6f6"
    readonly property color hairline: dark ? "#313030" : "#e2e2e2"
    readonly property color divider: dark ? "#333333" : "#dcdcdc"
    readonly property color rule: dark ? "#3c3b3b" : "#e4e4e4"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color capsule: dark ? "#3c3a39" : "#ffffff"
    readonly property color capsuleRim: dark ? "#14ffffff" : "#ffffff"
    readonly property color pressed: dark ? "#22ffffff" : "#14000000"
    readonly property color glyph: dark ? "#dfdfdf" : "#4a4a4a"
    readonly property color glyphInactive: dark ? "#6f6c6b" : "#b4b4b4"
    readonly property color glyphOff: dark ? "#5a5958" : "#c6c6c6"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#626160" : "#a8a8a8"
    readonly property color subtitle: dark ? "#9b9a9a" : "#7e7e7e"

    // Notes' own color: the insertion point, a ticked item, the chosen
    // folder's glyph, and the chosen note while the list has the keys.
    readonly property color tint: dark ? "#ffd60a" : "#e3ac00"
    readonly property color chosenNote: dark ? "#8f7216" : "#fbdc6c"
    readonly property color chosenNoteQuiet: dark ? "#464545" : "#dedede"
    readonly property color chosenNoteInactive: dark ? "#3d3d3d" : "#e6e6e6"
    readonly property color selection: dark ? "#66ffd60a" : "#80ffd60a"
    readonly property color selectionInactive: dark ? "#3a3a3a" : "#dcdcdc"

    readonly property color sidebarHeadingInk: dark ? "#8a8685" : "#8a8a8a"
    readonly property color sidebarHeadingInactive: dark ? "#5c5a58" : "#b0b0b0"
    readonly property color sidebarText: dark ? "#dfdfdf" : "#262626"
    readonly property color sidebarTextInactive: dark ? "#949392" : "#6a6a6a"
    readonly property color sidebarCount: dark ? "#8a8685" : "#8a8a8a"
    readonly property color sidebarCountInactive: dark ? "#5b5957" : "#b0b0b0"
    readonly property color sidebarGlyphInactive: dark ? "#92908f" : "#9a9a9a"
    readonly property color sidebarChosen: dark ? "#3f3b3a" : "#dedede"
    readonly property color sidebarChosenInactive: dark ? "#363432" : "#e4e4e4"

    readonly property color text: dark ? "#dddddd" : "#262626"
    readonly property color note: dark ? "#989898" : "#7e7e7e"
    readonly property color faint: dark ? "#6e6e6e" : "#a0a0a0"
    readonly property color chevron: dark ? "#757575" : "#a0a0a0"
    readonly property color noteText: dark ? "#d7d7d7" : "#1d1d1d"
    readonly property color ring: dark ? "#7c7c7c" : "#a8a8a8"
    readonly property color quoteBar: dark ? "#6e6e6e" : "#b8b8b8"

    readonly property color menuFill: dark ? "#2d2c2b" : "#f6f6f6"
    readonly property color menuRim: dark ? "#33ffffff" : "#26000000"
    readonly property color menuLit: dark ? "#1affffff" : "#12000000"
    readonly property color sheetFill: dark ? "#2e2c2b" : "#f6f6f6"
    readonly property color dim: dark ? "#66000000" : "#33000000"
    readonly property color field: dark ? "#1f1e1d" : "#ffffff"
}
