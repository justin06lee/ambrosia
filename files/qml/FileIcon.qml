import QtQuick
import QtQuick.Window
import Ambrosia

// A file's icon from our own art: the folder (in its tag's color), or a
// document page carrying the file's extension as its badge when there is
// room for it; or, once it is made, the file's thumbnail (a picture, a
// page of text), fitted to the square with a hairline edge as Finder draws
// them.
Item {
    id: icon

    property string kind: "document" // "folder" or "document"
    property string badge
    // A folder takes its first colored tag's color ("purple"), as in macOS 26.
    property string tint
    property real size: 16
    // Its thumbnail's image source (the model's thumb), or "".
    property string thumb
    readonly property bool showsThumb: picture.status === Image.Ready && picture.implicitWidth > 1


    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        visible: !icon.showsThumb
        source: icon.kind === "folder" && icon.tint !== "" ? "image://folder/" + icon.tint
            : "qrc:/qt/qml/Files/art/" + (icon.kind === "folder" ? "folder" : icon.size <= 32 ? "document-small" : "document") + ".svg"
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        smooth: true
        mipmap: true
    }
    Image {
        id: picture
        anchors.fill: parent
        visible: icon.showsThumb
        source: icon.thumb
        fillMode: Image.PreserveAspectFit
        // A 1×1 image means none could be made: the art stays.
        sourceSize: Qt.size(Math.ceil(icon.size * Screen.devicePixelRatio), Math.ceil(icon.size * Screen.devicePixelRatio))
        smooth: true
        mipmap: true
    }
    Rectangle {
        visible: icon.showsThumb && icon.size >= 24
        anchors.centerIn: parent
        width: picture.paintedWidth
        height: picture.paintedHeight
        color: "transparent"
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)
    }
    Text {
        visible: icon.kind !== "folder" && icon.size >= 48 && icon.badge !== "" && !icon.showsThumb
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.size * 0.73
        text: icon.badge
        font.family: Theme.uiFont
        font.pixelSize: icon.size * 0.17
        font.weight: 500
        color: "#b3b3b3"
    }
}
