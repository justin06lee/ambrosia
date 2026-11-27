import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import Preview
import "view.mjs" as View

// A picture on the window's ground, in the middle of it. One that was
// shrunk to fit as it opened keeps fitting as the window is resized, until
// it is zoomed by hand; a small one stays at its own size. In a window of
// several, `window.index` says which shows.
Item {
    id: view

    required property Window window

    readonly property var files: window.files
    readonly property int index: window.index
    readonly property url source: files[index] ?? ""
    readonly property size natural: App.imageSize(source)
    readonly property bool failed: natural.width <= 0 || natural.height <= 0
    // 1 is a picture point for each of the screen's.
    property real zoom: 1
    // "window": the zoom follows the view; "": it stays as set.
    property string fitting: ""
    property real renderZoom: zoom
    // Until the view has had its first size: the picture is placed then.
    property bool fresh: true
    // Quarter turns clockwise, by picture.
    property var turns: ({})
    readonly property int quarter: turns[index] ?? 0
    readonly property var shown: View.turned(natural, quarter)
    readonly property real least: 0.02
    readonly property real most: 32
    readonly property int pageCount: files.length
    readonly property int currentPage: index
    readonly property bool hasSelection: !failed
    readonly property bool canSelectAll: false
    readonly property bool canFind: false
    // A drawing keeps its lines sharp however far it is zoomed.
    readonly property bool drawing: /\.svgz?$/i.test(source.toString())

    function fitted() {
        return View.fit(shown.width, shown.height, flick.width, flick.height);
    }
    // As a picture opens: at its own size if that fits, else fitted, and
    // following the view from then on.
    function reset() {
        if (failed || flick.width <= 0 || flick.height <= 0)
            return;
        const fit = fitted();
        fitting = fit <= 1.0001 ? "window" : "";
        zoom = View.clamp(Math.min(1, fit), least, most);
        renderZoom = zoom;
        fresh = false;
        flick.contentX = 0;
        flick.contentY = 0;
    }
    function refit() {
        if (fitting === "window" && !failed && flick.width > 0 && flick.height > 0)
            setZoom(fitted());
    }
    function setZoom(next, px, py) {
        next = View.clamp(next, least, most);
        if (Math.abs(next - zoom) < 1e-6)
            return;
        const x = px ?? flick.width / 2, y = py ?? flick.height / 2;
        const fx = slot.width > 0 ? (flick.contentX + x - slot.x) / slot.width : 0.5;
        const fy = slot.height > 0 ? (flick.contentY + y - slot.y) / slot.height : 0.5;
        zoom = next;
        flick.contentX = View.hold(fx, slot.width, slot.x, x, flick.width, flick.contentWidth);
        flick.contentY = View.hold(fy, slot.height, slot.y, y, flick.height, flick.contentHeight);
        settle.restart();
    }
    function zoomIn() {
        fitting = "";
        setZoom(View.zoomed(zoom, 1, least, most));
    }
    function zoomOut() {
        fitting = "";
        setZoom(View.zoomed(zoom, -1, least, most));
    }
    // A picture pixel for each of the screen's.
    function actualSize() {
        fitting = "";
        setZoom(1 / Screen.devicePixelRatio);
    }
    function zoomToFit() {
        fitting = "window";
        refit();
    }
    function rotate(direction) {
        const next = Object.assign({}, turns);
        next[index] = (quarter + direction + 4) % 4;
        turns = next;
        refit();
    }
    function goToPage(page) {
        if (page >= 0 && page < files.length)
            window.index = page;
    }
    function scroll(dx, dy) {
        flick.contentX = View.clamp(flick.contentX + dx, 0, Math.max(0, flick.contentWidth - flick.width));
        flick.contentY = View.clamp(flick.contentY + dy, 0, Math.max(0, flick.contentHeight - flick.height));
    }
    // An arrow scrolls a picture larger than the view; otherwise it goes to
    // the picture before or after.
    function arrow(dx, dy) {
        const room = dx !== 0 ? flick.contentWidth > flick.width + 1 : flick.contentHeight > flick.height + 1;
        if (room)
            scroll(dx * 40, dy * 40);
        else
            goToPage(index + (dx !== 0 ? dx : dy));
    }
    function pageStep(direction) {
        if (flick.contentHeight > flick.height + 1)
            scroll(0, direction * Math.max(40, flick.height - 40));
        else
            goToPage(index + direction);
    }
    function toStart() {
        flick.contentY = 0;
        if (flick.contentHeight <= flick.height + 1)
            goToPage(0);
    }
    function toEnd() {
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
        if (flick.contentHeight <= flick.height + 1)
            goToPage(files.length - 1);
    }
    function selectAll() {}
    function clearSelection() {}
    function copy() {
        if (!failed)
            App.copyPicture(source, quarter);
    }
    function findNext(direction) {}

    Timer {
        id: settle
        interval: 140
        onTriggered: view.renderZoom = view.zoom
    }

    onWidthChanged: fresh ? reset() : refit()
    onHeightChanged: fresh ? reset() : refit()
    onSourceChanged: Qt.callLater(reset)

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, slot.width)
        contentHeight: Math.max(height, slot.height)
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton
        clip: true

        Controls.ScrollBar.vertical: ScrollThumb {}
        Controls.ScrollBar.horizontal: ScrollThumb {}

        Item {
            width: flick.contentWidth
            height: flick.contentHeight
            TapHandler { onTapped: view.window.takeKeys() }
        }

        Item {
            id: slot
            x: Math.round((flick.contentWidth - width) / 2)
            y: Math.round((flick.contentHeight - height) / 2)
            width: Math.round(view.shown.width * view.zoom)
            height: Math.round(view.shown.height * view.zoom)

            Image {
                anchors.centerIn: parent
                width: view.quarter % 2 !== 0 ? parent.height : parent.width
                height: view.quarter % 2 !== 0 ? parent.width : parent.height
                rotation: view.quarter * 90
                source: view.failed ? "" : view.source
                autoTransform: true
                asynchronous: true
                cache: false
                mipmap: true
                // A drawing is drawn again for the zoom; a very large
                // picture is read at a size a texture can hold.
                sourceSize: {
                    const longer = Math.max(view.natural.width, view.natural.height);
                    if (view.drawing) {
                        const scale = Math.min(Math.max(1, view.renderZoom) * Screen.devicePixelRatio, 8192 / Math.max(1, longer));
                        return Qt.size(Math.round(view.natural.width * scale), Math.round(view.natural.height * scale));
                    }
                    if (longer > 8192)
                        return Qt.size(Math.round(view.natural.width * 8192 / longer), Math.round(view.natural.height * 8192 / longer));
                    return undefined;
                }
            }
        }
    }

    PinchHandler {
        target: null
        onScaleChanged: (delta) => {
            view.fitting = "";
            view.setZoom(view.zoom * delta, centroid.position.x, centroid.position.y);
        }
    }
}
