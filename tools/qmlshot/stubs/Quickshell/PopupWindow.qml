import QtQuick
import Quickshell
import Quickshell.Wayland

// Stand-in for a popup of another window: its content is an item on the
// same screen, placed from the spot on that window it hangs from, above it.
QtObject {
    id: popup

    default property alias data: content.data
    property alias contentItem: content
    property ShotPopupAnchor anchor: ShotPopupAnchor {}
    readonly property ShellScreen screen: anchor.window?.screen ?? null
    property real implicitWidth: 0
    property real implicitHeight: 0
    readonly property real width: implicitWidth
    readonly property real height: implicitHeight
    readonly property real devicePixelRatio: screen?.devicePixelRatio ?? 1
    property bool visible: false
    property bool grabFocus: false
    property color color: "white"
    property QtObject mask: null

    readonly property Item shotContent: ShotContent {
        id: content
        shotWindow: popup
        blurRegion: popup.BackgroundEffect.blurRegion
        parent: popup.screen?.shotHost ?? null
        visible: popup.visible
        x: (popup.anchor.window?.contentItem.x ?? 0) + popup.anchor.rect.x
        y: (popup.anchor.window?.contentItem.y ?? 0) + popup.anchor.rect.y
        z: (popup.anchor.window?.contentItem.z ?? 0) + 0.5
        width: popup.width
        height: popup.height

        Rectangle {
            anchors.fill: parent
            z: -2
            color: popup.color
        }
    }
}
