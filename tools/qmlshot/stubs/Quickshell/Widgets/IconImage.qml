import QtQuick

// An icon at the size it is given, drawn sharp for a 2x screen.
Item {
    id: icon

    property alias source: image.source
    property alias asynchronous: image.asynchronous
    property alias mipmap: image.mipmap
    property alias status: image.status
    property real implicitSize: 0
    readonly property real actualSize: Math.min(width, height)

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.ceil(icon.width * 2), Math.ceil(icon.height * 2))
        smooth: true
    }
}
