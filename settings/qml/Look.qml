pragma Singleton
import QtQuick
import Ambrosia

// System Settings' measurements, read from this Mac's System Settings
// (macOS 26) through the accessibility API and its 2x pictures, in points
// (docs/settings/FRAME.md), and the window colors it paints, light and
// dark. Text, accent and window-control colors come from the theme.
QtObject {
    readonly property bool dark: Theme.dark

    // The window: as wide as System Settings, which only grows taller.
    readonly property int windowWidth: 723
    readonly property int windowHeight: 744
    readonly property int minHeight: 420
    readonly property int windowRadius: 26

    // The floating sidebar: a panel 8 in from the window's edges.
    readonly property int sidebarInset: 8
    readonly property int sidebarWidth: 215
    readonly property int sidebarRadius: windowRadius - sidebarInset
    // Its search field and list, in the window's points.
    readonly property int searchX: 18
    readonly property int searchY: 61
    readonly property int searchWidth: 195
    readonly property int searchHeight: 28
    readonly property int searchGlyphX: 26
    readonly property int searchTextX: 46
    readonly property int listTop: 98
    readonly property int row: 32
    readonly property int groupGap: 13
    readonly property int rowX: 18                // the selection's left
    readonly property int rowWidth: 195
    readonly property int rowRadius: 8
    readonly property int rowIconX: 24
    readonly property int rowLabelX: 49
    readonly property int icon: 20
    readonly property real iconRadius: 4.5

    // Traffic lights, in the sidebar's top corner: centred in the toolbar
    // band, as far from the panel's edge as from the window's top.
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23

    // The toolbar: a band 52 tall over the content, the back and forward
    // capsule at (231, 8) and the pane's name after it.
    readonly property int toolbar: 52
    readonly property int navX: 231
    readonly property int navY: 8
    readonly property int navWidth: 73
    readonly property int control: 36
    readonly property int titleX: 316

    // The content: boxes 20 in from the sidebar's column and the window's
    // edge, 10 apart; section headings 30 below the box above and 26 above
    // their own.
    readonly property int contentX: 223
    readonly property int margin: 20
    readonly property int displayBand: 158     // Displays' band, under the toolbar
    readonly property int boxWidth: 460
    readonly property int boxRadius: 10
    readonly property int boxGap: 10
    readonly property int boxPadding: 10
    readonly property int headingAbove: 20     // plus the gap between boxes
    readonly property int headingTop: 4        // a page that starts with a heading
    readonly property int textRow: 36          // a row of text, or a switch
    readonly property int controlRow: 40       // a row holding a 24 tall control
    readonly property int navRow: 42           // a row that opens a page
    readonly property int navIconX: 10         // from the box's left
    readonly property int navLabelX: 40
    readonly property int chevronRight: 10     // from the box's right
    // A parent pane's header: its icon, name and what it holds, centred.
    readonly property int headerHeight: 164
    readonly property int headerIcon: 52
    readonly property int headerIconY: 24
    readonly property int headerTitleY: 86
    readonly property int headerTextY: 112
    readonly property int headerTextWidth: 397
    readonly property int helpGap: 20

    // Controls
    readonly property int switchWidth: 36
    readonly property int switchHeight: 16
    readonly property int switchKnob: 20      // 12 tall, 2 in from the track's edge
    readonly property int switchLargeWidth: 44
    readonly property int switchLargeHeight: 20
    readonly property int switchLargeKnob: 26  // 16 tall
    readonly property int popupHeight: 24
    // A list typed into (Wi-Fi's DNS servers): four 24 rows, a 24 bar of + and −.
    readonly property int editListRows: 4
    readonly property int editListRow: 24
    readonly property int editListBar: 24
    readonly property int popupChevronWidth: 16 // the up-down capsule at a pop-up's right
    readonly property int popupChevronHeight: 20
    readonly property int popupEnd: 4
    readonly property int popupTextGap: 6
    readonly property int sliderKnobWidth: 20
    readonly property int sliderKnobHeight: 16
    readonly property int sliderTrack: 6
    readonly property int sliderWidth: 200
    readonly property int segmented: 24
    readonly property int segmentedRadius: 6
    readonly property int check: 16
    readonly property int checkRadius: 4
    readonly property int tableHeader: 28
    readonly property int tableRow: 24
    readonly property int tableNameWidth: 291
    readonly property int help: 24
    readonly property int menuRow: 22

    // Colors, light and dark (the dark ones are as this Mac paints them,
    // tinted a little warm by its wallpaper).
    readonly property color window: dark ? "#272724" : "#ffffff"
    readonly property color sidebar: dark ? "#191916" : "#f8f8f8"
    readonly property color sidebarRim: dark ? "#1affffff" : "#ffffff"
    readonly property color search: dark ? "#2f2f2e" : "#e4e4e4"
    readonly property color selectionInactive: dark ? "#464646" : "#dcdcdc"
    // Under a sheet the sidebar's labels fade to this, its icons and search
    // to the second, and the selection is this gray (dark measured on the
    // Mac, light a guess).
    readonly property real sheetFade: 0.12
    readonly property real sheetFadeIcon: 0.2
    readonly property color selectionUnderSheet: dark ? "#2d2d2b" : "#ebebeb"
    readonly property color box: dark ? "#2d2d2b" : "#f7f7f7"
    readonly property color hairline: dark ? "#373735" : "#ebebeb"
    readonly property color capsule: dark ? "#1c1c1a" : "#f9f9f9"
    readonly property color capsuleRim: dark ? "#1fffffff" : "#ffffff"
    readonly property color capsuleDivider: dark ? "#30302e" : "#ececec"
    readonly property color lightInactive: dark ? "#4a4a46" : "#dcdcdc"
    // A control's face: a button, a pop-up's chevrons, a segment not chosen.
    readonly property color face: dark ? "#3d3d3b" : "#e4e4e4"
    readonly property color track: dark ? "#424240" : "#dfdfdf"
    readonly property color switchOff: dark ? "#414140" : "#dddddd"
    // On, under a sheet (the window drawn inactive): gray, not the accent;
    // dark measured through the sheet's dim, light a guess.
    readonly property color switchInactive: dark ? "#4c4c4a" : "#c4c4c4"
    readonly property color knob: dark ? "#e6e6e6" : "#ffffff"
    readonly property color connected: dark ? "#68ce67" : Theme.color.palette.green // Wi-Fi's dot
    readonly property color notConnected: dark ? "#eb534e" : Theme.color.palette.red // Network's
    readonly property color connecting: Theme.color.palette.yellow
    // Displays: the band of displays across the top and the rule under it;
    // a scale tile's window.
    readonly property color band: dark ? "#282828" : window
    readonly property color bandRule: dark ? "#3e3e3e" : "#e0e0e0"
    // A sheet: its fill, the dark line round it, the lighter rim inside
    // that, and the rule over its buttons. Dark measured on the Mac's
    // Bluetooth sheet; light, not yet captured, is white like the window.
    readonly property color sheet: dark ? "#262724" : "#ffffff"
    readonly property color sheetOutline: dark ? "#030302" : "#33000000"
    readonly property color sheetRim: dark ? "#515250" : "#ffffff"
    readonly property color sheetRule: dark ? "#30302d" : "#e0e0e0"
    readonly property color tileWindow: dark ? "#141414" : "#ffffff"
    readonly property color helpFace: dark ? "#373734" : "#ececec"
    readonly property color menu: dark ? "#262624" : "#f2f2f2"
    readonly property color menuRim: dark ? "#4e4e4c" : "#d3d3d3"
    readonly property color menuRule: dark ? "#3f3f3d" : "#dadada"
    // A table across the foot of a box (Sound's devices): its fill, the rule
    // under its header, a row chosen while the table hasn't the focus.
    readonly property color tableFill: dark ? "#383836" : "#efefef"
    readonly property color tableRule: dark ? "#41413f" : "#e5e5e5"
    readonly property color tableChosen: dark ? "#61615f" : "#dfdfdf"

    // The pane icons' colors: each a rounded square lit from above, as
    // System Settings' are (top, bottom).
    readonly property var tints: ({
        blue: ["#62a6f8", "#3b86f7"],
        green: ["#8ad98b", "#66c566"],
        gray: ["#b0afb4", "#8f8e93"],
        black: ["#333333", "#050505"],
        cyan: ["#7dd3f4", "#57bde4"],
        red: ["#ed716d", "#eb4c47"],
        pink: ["#ed6b80", "#eb445b"],
        indigo: ["#877df7", "#6055ed"],
    })
}
