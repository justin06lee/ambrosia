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
    readonly property int indent: 15          // each level of an open folder
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

    // The column view
    readonly property int columnWidth: 245
    readonly property int columnMin: 120
    readonly property int columnTop: 52      // the dividers' top, under the toolbar
    readonly property int columnRowsTop: 58
    readonly property int columnRow: 24
    readonly property real columnInset: 10.5 // a selection's, either side
    readonly property int columnIcon: 18
    readonly property int columnIconX: 16
    readonly property int columnText: 40
    readonly property int columnChevron: 20  // the chevron's right, from the column's right
    readonly property int previewIcon: 128

    // The gallery view: the item selected, large, over the filmstrip
    readonly property int galleryTop: 52       // the large item's space, under the toolbar
    readonly property real galleryScale: 0.8   // an icon's share of that space
    readonly property int galleryStrip: 64     // the filmstrip, along the bottom
    readonly property int galleryCell: 59
    readonly property int galleryThumb: 48
    readonly property int gallerySelection: 54 // the rounded square behind the one selected
    readonly property int gallerySelectionRadius: 8
    readonly property real galleryStripLeft: 2.5

    // The preview pane, on the right of the gallery view
    readonly property int previewPane: 240
    readonly property int previewPaneFoot: 70    // its lower part, on the window's color
    readonly property int previewPaneMinContent: 240 // narrower than this beside it, the pane hides
    readonly property int previewPaneIcon: 50
    readonly property int previewPaneIconX: 9
    readonly property int previewPaneIconY: 71
    readonly property real previewPaneNameX: 68.5
    readonly property int previewPaneNameBase: 93   // baselines, from the window's top
    readonly property int previewPaneKindBase: 113
    readonly property int previewPaneTextX: 10
    readonly property int previewPaneInfoBase: 153
    readonly property int previewPaneRowBase: 175
    readonly property int previewPaneRow: 23
    readonly property int previewPaneValueRight: 11 // the values' right, from the window's right

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
    readonly property color gallerySelected: dark ? "#5b5b58" : "#bdbdbd"
    readonly property color previewPaneFill: dark ? "#181815" : "#f4f4f4"
    readonly property color previewPaneRule: dark ? "#232323" : "#e6e6e6"
}
