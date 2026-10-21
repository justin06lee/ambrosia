import QtQuick
import Ambrosia

// A file's icon from our own art: the folder, or a document page carrying
// the file's extension as its badge when there is room for it.
Item {
    id: icon

    property string kind: "document" // "folder" or "document"
    property string badge
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/Files/art/" + (icon.kind === "folder" ? "folder" : icon.size <= 32 ? "document-small" : "document") + ".svg"
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        smooth: true
        mipmap: true
    }
    Text {
        visible: icon.kind !== "folder" && icon.size >= 48 && icon.badge !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.size * 0.73
        text: icon.badge
        font.family: Theme.uiFont
        font.pixelSize: icon.size * 0.17
        font.weight: 500
        color: "#b3b3b3"
    }
}
