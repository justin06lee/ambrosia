import QtQuick
import QtQuick.Window
import Ambrosia

// An item as the gallery shows it: a picture on this computer as itself,
// fitted to the box; anything else (and a picture while it loads) as its
// icon, iconSize square in the middle.
Item {
    id: thumb

    property url url
    property bool isDir
    property string badge
    property string tint // a folder's tag color
    property real iconSize: Math.min(width, height)

    // The pictures Qt reads itself, by the extension the badge carries.
    readonly property bool picture: !isDir && url.toString().startsWith("file:")
        && ["PNG", "JPG", "JPEG", "GIF", "WEBP", "BMP", "SVG", "TIF", "TIFF"].indexOf(badge) >= 0

    Image {
        id: image
        anchors.fill: parent
        visible: status === Image.Ready
        source: thumb.picture ? thumb.url : ""
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        // Read at the size it shows, not the size it is.
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        smooth: true
    }
    FileIcon {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        size: thumb.iconSize
        kind: thumb.isDir ? "folder" : "document"
        badge: thumb.badge
        tint: thumb.tint
    }
}
