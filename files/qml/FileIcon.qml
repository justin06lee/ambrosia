import QtQuick
import QtQuick.Window
import Ambrosia

// A file's icon from our own art: the folder (in its tag's color), a song's
// generic audio tile, or a document page carrying the file's extension as
// its badge when there is room for it; or, once it is made, the file's
// thumbnail (a picture, a page, a video's frame, a font's "Aa", a cover),
// framed as Finder frames them at icon sizes: fitted into 7/8 of the
// square, rounded, with a hairline and a soft shadow (drawn with it).
Item {
    id: icon

    property string kind: "document" // "folder" or "document"
    property string badge
    // A folder takes its first colored tag's color ("purple"), as in macOS 26.
    property string tint
    property real size: 16
    // Its thumbnail's image source (the model's thumb), or "".
    property string thumb
    // A song, by the source's hint: Finder's audio tile until (and unless)
    // its cover is read.
    property bool audio: thumb.endsWith("/audio")
    readonly property bool showsThumb: picture.status === Image.Ready && picture.implicitWidth > 1

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        visible: !icon.showsThumb
        source: icon.kind === "folder" && icon.tint !== "" ? "image://folder/" + icon.tint
            : "qrc:/qt/qml/Files/art/" + (icon.kind === "folder" ? "folder" : icon.audio ? "audio" : icon.size <= 32 ? "document-small" : "document") + ".svg"
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        smooth: true
        mipmap: true
    }
    Image {
        id: picture
        anchors.fill: parent
        visible: icon.showsThumb
        // Small ones (the list's and columns' rows) as they are, without a
        // frame.
        source: icon.thumb === "" ? "" : icon.size >= 24 ? icon.thumb + "/tile" : icon.thumb
        fillMode: Image.PreserveAspectFit
        // A 1×1 image means none could be made: the art stays.
        sourceSize: Qt.size(Math.ceil(icon.size * Screen.devicePixelRatio), Math.ceil(icon.size * Screen.devicePixelRatio))
        smooth: true
        mipmap: true
    }
    Text {
        visible: icon.kind !== "folder" && !icon.audio && icon.size >= 48 && icon.badge !== "" && !icon.showsThumb
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.size * 0.73
        text: icon.badge
        font.family: Theme.uiFont
        font.pixelSize: icon.size * 0.17
        font.weight: 500
        color: "#b3b3b3"
    }
}
