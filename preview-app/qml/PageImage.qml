import QtQuick

// A PDF page's picture (image://page/ID/PAGE) at the pixel size asked for.
// When the size changes (the zoom did) the new picture is drawn behind the
// old one, which stays up, stretched, until the new one has arrived: no
// page goes blank while it is redrawn.
Item {
    id: page

    property string base
    property int pixelWidth: 0
    property int pixelHeight: 0
    // Which of the two pictures shows, and which is being drawn.
    property int front: 0
    property int pending: -1
    readonly property var layers: [first, second]
    readonly property bool ready: layers[front].status === Image.Ready

    function load() {
        if (base === "" || pixelWidth <= 0 || pixelHeight <= 0)
            return;
        const next = layers[front].status === Image.Null ? front : 1 - front;
        const layer = layers[next];
        layer.source = "";
        layer.sourceSize = Qt.size(pixelWidth, pixelHeight);
        pending = next;
        layer.source = base;
    }
    function arrived(which) {
        if (which !== pending || layers[which].status !== Image.Ready)
            return;
        pending = -1;
        if (which !== front) {
            front = which;
            layers[1 - which].source = "";
        }
    }

    onPixelWidthChanged: Qt.callLater(load)
    onPixelHeightChanged: Qt.callLater(load)
    onBaseChanged: Qt.callLater(load)
    Component.onCompleted: load()

    Image {
        id: first
        anchors.fill: parent
        z: page.front === 0 ? 1 : 0
        asynchronous: true
        cache: false
        onStatusChanged: page.arrived(0)
    }
    Image {
        id: second
        anchors.fill: parent
        z: page.front === 1 ? 1 : 0
        asynchronous: true
        cache: false
        onStatusChanged: page.arrived(1)
    }
}
