pragma Singleton
import QtQuick
import Ambrosia

// Disk Utility's sizes and colors, measured from macOS 27's (2026-11-28: a
// volume's page and a disk's, both ways of listing, the Erase and First Aid
// sheets and the Info window, with the window behind others, in Dark: the
// grays there are an inactive window's; the front window's are Font Book's,
// which were). The light colors are not measured: that Mac stays in Dark.
QtObject {
    readonly property bool dark: Theme.dark

    readonly property int windowRadius: 26
    readonly property int width: 1099
    readonly property int height: 518
    readonly property int minWidth: 780
    readonly property int minHeight: 400

    // The toolbar: 66 tall, its round buttons 36 across from 8 down, each
    // over its name (11 points, centered 54 down). The View button, 46
    // wide, stands 9 after the sidebar and the title 14.5 after that.
    readonly property int toolbar: 66
    readonly property int control: 36
    readonly property int controlY: 8
    readonly property real labelY: 54
    readonly property real edge: 8
    readonly property real toolGap: 15
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23
    readonly property int viewAfterSidebar: 9
    readonly property int viewWidth: 46
    readonly property real titleAfterView: 14.5

    // The sidebar: 256 wide, flush and full height. Its headings 32 tall
    // (the words 23 down, 16 in), rows 32 with the chosen one's fill 10
    // off each side; at each level 16.5 further in: the chevron at 18.5,
    // the glyph centered at 42, the name at 63. The eject mark is centered
    // 25.5 from the right.
    readonly property int sidebarWidth: 256
    readonly property int sidebarTop: 52
    readonly property int sidebarRow: 32
    readonly property int sidebarInset: 10
    readonly property real sidebarIndent: 16.5
    readonly property real sidebarChevronX: 18.5
    readonly property real sidebarGlyphX: 42
    readonly property real sidebarTextX: 63
    readonly property real sidebarEjectX: 25.5

    // A page, from the sidebar's edge and the toolbar's foot: 32 in at each
    // side. The picture 64 square 24 down; the name (24 bold) 114.5 in on
    // a baseline 46 down, the two lines under it on 61.5 and 78.5; the
    // capacity's box 120 by 40 at the right, 34.5 down. A rule 111.5
    // down. The bar 24 tall 139 down (2 in at the left, 6 at the right),
    // its legend's squares 10 across 174 down in columns 261 apart, each
    // name 16.5 after its square and its size 21 under. The table 57 under
    // the legend's last row: rows 31 apart, its halves split by a rule that
    // stops 10 short of top and bottom.
    readonly property int pad: 32
    readonly property int iconY: 24
    readonly property int icon: 64
    readonly property real titleX: 114.5
    readonly property real titleBase: 46
    readonly property real subtitleBase: 61.5
    readonly property real thirdBase: 78.5
    readonly property real boxY: 34.5
    readonly property int boxWidth: 120
    readonly property int boxHeight: 40
    readonly property real ruleY: 111.5
    readonly property int barY: 139
    readonly property int barHeight: 24
    readonly property int barInsetLeft: 2
    readonly property int barInsetRight: 6
    readonly property int legendY: 174
    readonly property int legendColumn: 261
    readonly property int legendRow: 46
    readonly property int tableAfterLegend: 57
    readonly property int tableRow: 31
    readonly property int tablePad: 11

    // A sheet with a form (Erase): 485 wide, the picture 64 at 19, 19, the
    // words from 91; a field 256 by 24 from 145, its name ending at 138;
    // buttons 70 by 24, 12 apart, 19 from the right and the bottom. An
    // alert (First Aid): 260 wide, the picture at 19, 19, its words from 21
    // at 99 down, its two buttons 110 by 28 side by side.
    readonly property int sheetWidth: 485
    readonly property int sheetRadius: 16
    readonly property int alertWidth: 260
    readonly property int alertRadius: 20

    // The Info window: 480 by 302 under a title bar 32 tall, rows 19
    // apart, every other one on a band; a name from 18, what it is from 258.
    readonly property int infoWidth: 480
    readonly property int infoHeight: 302
    readonly property int infoRadius: 16
    readonly property int titleBar: 32
    readonly property int infoRow: 19

    readonly property color toolbarFill: dark ? "#282727" : "#f6f6f6"
    readonly property color sidebarFill: dark ? "#292624" : "#f0f0f0"
    readonly property color ground: dark ? "#21201f" : "#ffffff"
    readonly property color hairline: dark ? "#31302f" : "#e2e2e2"
    readonly property color rule: dark ? "#3c3b3a" : "#dedede"
    readonly property color rim: dark ? "#33ffffff" : "#26000000"
    readonly property color capsule: dark ? "#3c3a3a" : "#ffffff"
    readonly property color capsuleRim: dark ? "#14ffffff" : "#ffffff"
    readonly property color pressed: dark ? "#22ffffff" : "#14000000"
    // A toolbar glyph, its name and the title: in the window in front,
    // behind, and when what it does can't be done.
    readonly property color glyph: dark ? "#dfdfdf" : "#4a4a4a"
    readonly property color glyphInactive: dark ? "#6f6d6d" : "#b4b4b4"
    readonly property color glyphOff: dark ? "#5a5958" : "#c6c6c6"
    readonly property color glyphOffInactive: dark ? "#4b4a4a" : "#d4d4d4"
    readonly property color toolLabel: dark ? "#b4b3b3" : "#6a6a6a"
    readonly property color toolLabelInactive: dark ? "#5e5d5d" : "#b0b0b0"
    readonly property color toolLabelOff: dark ? "#6a6969" : "#bcbcbc"
    readonly property color toolLabelOffInactive: dark ? "#464646" : "#d0d0d0"
    readonly property color title: dark ? "#e6e6e6" : "#262626"
    readonly property color titleInactive: dark ? "#5e5d5d" : "#a8a8a8"
    // What a page says.
    readonly property color text: dark ? "#dfdede" : "#262626"
    readonly property color note: dark ? "#9b9a9a" : "#7e7e7e"
    readonly property color faint: dark ? "#666666" : "#a0a0a0"
    readonly property color boxRim: dark ? "#9b9a9a" : "#a8a8a8"
    readonly property color tableFill: dark ? "#2a2928" : "#f6f6f6"
    readonly property color tableRim: dark ? "#757575" : "#c4c4c4"
    // The bar: a part is drawn in its color at half strength inside a line
    // of the color itself; room not in use is the table's fill.
    readonly property var partColors: dark
        ? ({ blue: "#33a2f1", red: "#f73d33", orange: "#f98d2b", yellow: "#f7cd2e", green: "#3ec95a", purple: "#b65ce6", pink: "#f0508a", teal: "#45c2c9", other: "#a9a9a9" })
        : ({ blue: "#1a84e8", red: "#e8382d", orange: "#ee8414", yellow: "#e6b800", green: "#2faa4a", purple: "#9a4ad0", pink: "#e23a78", teal: "#2aa3ab", other: "#9a9a9a" })
    function partLine(name) {
        return name === "free" ? tableRim : partColors[name] ?? partColors.other;
    }
    function partFill(name) {
        if (name === "free")
            return tableFill;
        const line = Qt.color(partColors[name] ?? partColors.other);
        const under = Qt.color(ground);
        return Qt.rgba((line.r + under.r) / 2, (line.g + under.g) / 2, (line.b + under.b) / 2, 1);
    }

    readonly property color sidebarHeading: dark ? "#8a8685" : "#8a8a8a"
    readonly property color sidebarHeadingInactive: dark ? "#5b5856" : "#b0b0b0"
    readonly property color sidebarText: dark ? "#dfdfdf" : "#262626"
    readonly property color sidebarTextInactive: dark ? "#b7b4b2" : "#6a6a6a"
    readonly property color sidebarDim: dark ? "#6e6a69" : "#a8a8a8"
    readonly property color sidebarDimInactive: dark ? "#55514f" : "#c0c0c0"
    readonly property color sidebarGlyph: dark ? "#b9b6b5" : "#6a6a6a"
    readonly property color sidebarGlyphInactive: dark ? "#989694" : "#9a9a9a"
    readonly property color sidebarChosen: dark ? "#3f3b3a" : "#dedede"
    readonly property color sidebarChosenInactive: dark ? "#373432" : "#e4e4e4"

    readonly property color sheetFill: dark ? "#2e2c2b" : "#f6f6f6"
    readonly property color sheetRim: dark ? "#33ffffff" : "#26000000"
    readonly property color dim: dark ? "#66000000" : "#33000000"
    readonly property color field: dark ? "#1f1e1d" : "#ffffff"
    readonly property color fieldRim: dark ? "#3d3b3a" : "#d0d0d0"
    readonly property color logFill: dark ? "#1f1e1d" : "#ffffff"

    readonly property color infoBar: dark ? "#2c2a29" : "#f6f6f6"
    readonly property color infoGround: dark ? "#242322" : "#ffffff"
    readonly property color infoBand: dark ? "#2e2d2c" : "#f4f5f5"
}
