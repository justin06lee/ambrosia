import QtQuick
import Quickshell
import Quickshell.Wayland

// Stand-in for a layer-shell panel: its content is an item on the sheet's
// screen, held to the edges it anchors to and stacked by its layer.
QtObject {
    id: window

    default property alias data: content.data
    property alias contentItem: content
    property ShellScreen screen: null
    property ShotAnchors anchors: ShotAnchors {}
    property ShotMargins margins: ShotMargins {}
    property real implicitWidth: 0
    property real implicitHeight: 0
    readonly property real width: anchors.left && anchors.right ? (screen?.width ?? 0) : implicitWidth
    readonly property real height: anchors.top && anchors.bottom ? (screen?.height ?? 0) : implicitHeight
    readonly property real devicePixelRatio: screen?.devicePixelRatio ?? 1
    property int exclusiveZone: 0
    property int exclusionMode: 0
    property bool aboveWindows: true
    property bool focusable: false
    property bool visible: true
    property color color: "white"
    property QtObject mask: null

    readonly property Item shotContent: ShotContent {
        id: content
        shotWindow: window
        blurRegion: window.BackgroundEffect.blurRegion
        parent: window.screen?.shotHost ?? null
        visible: window.visible
        x: window.anchors.left ? window.margins.left
            : window.anchors.right ? (parent?.width ?? 0) - width - window.margins.right
            : ((parent?.width ?? 0) - width) / 2
        y: window.anchors.top ? window.margins.top
            : window.anchors.bottom ? (parent?.height ?? 0) - height - window.margins.bottom
            : ((parent?.height ?? 0) - height) / 2
        // Background 0, Bottom 1, Top 2, Overlay 3.
        z: window.WlrLayershell.layer
        width: window.width
        height: window.height

        Rectangle {
            anchors.fill: parent
            z: -2
            color: window.color
        }
    }
}
