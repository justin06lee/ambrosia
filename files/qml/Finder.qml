pragma Singleton
import QtQuick
import Ambrosia

// Finder's measurements, taken from this Mac's Finder (macOS 26) at 2x and
// given in points, and the window colors Files paints, measured the same
// way. Text, accent and window-control colors come from the theme.
QtObject {
    readonly property bool dark: Theme.dark

    // The window
    readonly property int windowRadius: 26
    readonly property int minWidth: 520
    readonly property int minHeight: 300

    // The floating sidebar
    readonly property int sidebarInset: 8
    readonly property int sidebarWidth: 171
    readonly property int sidebarRadius: windowRadius - sidebarInset
    readonly property int sidebarFirstRow: 44   // top of the first row, from the sidebar's top
    readonly property int sidebarRow: 32
    readonly property int sidebarHeader: 24    // a section title's row
    readonly property int sidebarGap: 12       // between a section and the next title
    readonly property int sidebarIconX: 29     // the glyph's center, from the sidebar's left
    readonly property int sidebarLabelX: 46
    readonly property int sidebarGlyph: 18

    // Traffic lights
    readonly property int lightsX: 19
    readonly property int lightsY: 19
    readonly property int lightSize: 14
    readonly property int lightPitch: 23

    // The toolbar: glass capsules 36 tall, 8 from the top
    readonly property int toolbarTop: 8
    readonly property int control: 36
    readonly property int toolbarGap: 8           // sidebar to the back/forward capsule
    readonly property int navWidth: 73
    readonly property int titleGap: 14
    readonly property int segment: 36
    readonly property int segmentPillWidth: 34
    readonly property int segmentPill: 28
    readonly property int capsuleGap: 18
    readonly property int searchGap: 20
    readonly property int groupWidth: 48
    readonly property int toolbarGlyph: 20

    // The list
    readonly property int headerTop: 50
    readonly property int headerHeight: 30
    readonly property int rowsTop: 85
    readonly property int row: 20
    readonly property real rowInsetLeft: 10.5
    readonly property real rowInsetRight: 10.5
    readonly property int nameText: 47        // from the list's left edge
    readonly property int disclosureX: 18
    readonly property int rowRadius: 6
    readonly property int listIcon: 16
    readonly property int dateColumn: 180
    readonly property int sizeColumn: 97
    readonly property int kindColumn: 122

    // The icon view
    readonly property int iconSize: 64
    readonly property int iconCell: 112
    readonly property int iconTop: 55
    readonly property int iconLeft: 9

    readonly property int pathBar: 28

    // Window colors, light and dark
    readonly property color content: dark ? "#282824" : "#ffffff"
    readonly property color sidebar: dark ? "#191915" : "#f8f8f8"
    readonly property color sidebarRim: dark ? "#1affffff" : "#ffffff"
    readonly property color stripe: dark ? "#32322e" : "#f4f5f5"
    readonly property color separator: dark ? "#454541" : "#dddddd"
    readonly property color capsule: dark ? "#1d1d19" : "#f9f9f9"
    readonly property color capsuleRim: dark ? "#1fffffff" : "#ffffff"
    readonly property color segmentSelected: dark ? "#3a3a36" : "#e0e0e0"
    readonly property color lightInactive: dark ? "#4a4a46" : "#dcdcdc"
    readonly property color selectionInactive: dark ? "#46463f" : "#dcdcdc"
}
