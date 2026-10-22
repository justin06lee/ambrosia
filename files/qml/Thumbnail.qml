import QtQuick
import QtQuick.Window
import Ambrosia

// An item as the gallery shows it: its thumbnail (a picture, a page of
// text) fitted to the box; anything else, and one still being made, as its
// icon, iconSize square in the middle.
Item {
    id: thumb

    property url url
    property string source // the model's thumb: image://thumb/…, or ""
    property bool isDir
    property string badge
    property string tint // a folder's tag color
    property real iconSize: Math.min(width, height)
    // The square it is made to fit (pixels are this times the screen's).
    property real box: Math.max(width, height)

    readonly property bool shown: image.status === Image.Ready && image.implicitWidth > 1
    // Its width over its height, once it is made.
    readonly property real aspect: shown ? image.implicitWidth / image.implicitHeight : 1

    Image {
        id: image
        anchors.fill: parent
        visible: thumb.shown
        source: thumb.source
        fillMode: Image.PreserveAspectFit
        // Made at the size it shows, not the size it is.
        sourceSize: Qt.size(Math.ceil(thumb.box * Screen.devicePixelRatio), Math.ceil(thumb.box * Screen.devicePixelRatio))
        smooth: true
    }
    FileIcon {
        anchors.centerIn: parent
        visible: !thumb.shown
        size: thumb.iconSize
        kind: thumb.isDir ? "folder" : "document"
        badge: thumb.badge
        tint: thumb.tint
        audio: thumb.source.endsWith("/audio")
    }
}
