import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import Preview
import "view.mjs" as View

// A PDF's pages, one under another on the window's ground, as Preview's
// continuous scroll: 10 apart, each drawn only while it is near the view
// and redrawn sharp a moment after the zoom settles. A drag over a page
// selects its text; what the toolbar's search found is marked on the pages.
Item {
    id: view

    required property Window window
    required property Document doc

    // 1 is actual size: a point of the page for a point of the screen.
    property real zoom: 1
    // "width": the zoom follows the view's width, as a new window's does
    // until it is zoomed by hand; "page": the page in view fits whole
    // (Zoom to Fit); "": it stays as set.
    property string fitting: "width"
    // The zoom the pages are drawn for: `zoom`, a moment later.
    property real renderZoom: zoom
    // Quarter turns clockwise, by page.
    property var turns: ({})
    readonly property real least: 0.1
    readonly property real most: 8
    readonly property var plan: View.layout(doc.pageSizes, turns, zoom, Look.pageGap)
    readonly property int pageCount: doc.pageCount
    // The page across the middle of the view.
    readonly property int currentPage: View.pageAt(plan.tops, flick.contentY - pages.y + flick.height / 2)

    // The text selected: on one page, or all of every page.
    property int selectedPage: -1
    property var selectedRects: []
    property string selectedText: ""
    property bool allSelected: false
    readonly property bool hasSelection: allSelected || selectedText !== ""
    readonly property bool canSelectAll: true
    readonly property bool canFind: true

    // The match the search is at (an index into the document's), -1 before
    // any is found; and the page the search began on.
    property int currentMatch: -1
    property int findFrom: 0

    function widest() {
        let most = 0;
        for (let i = 0; i < doc.pageSizes.length; ++i)
            most = Math.max(most, View.turned(doc.pageSizes[i], turns[i] ?? 0).width);
        return most;
    }
    function fitted() {
        if (fitting === "width") {
            const across = widest();
            return across > 0 ? (flick.width - Look.pagesBeside) / across : zoom;
        }
        if (fitting === "page" && doc.pageSizes.length > 0) {
            const size = View.turned(doc.pageSizes[currentPage], turns[currentPage] ?? 0);
            return View.fit(size.width, size.height, flick.width, flick.height);
        }
        return zoom;
    }
    function refit() {
        if (fitting !== "" && flick.width > 0 && flick.height > 0)
            setZoom(fitted());
    }
    // Zooms about a point of the view (its middle unless given).
    function setZoom(next, px, py) {
        next = View.clamp(next, least, most);
        if (Math.abs(next - zoom) < 1e-6)
            return;
        const x = px ?? flick.width / 2, y = py ?? flick.height / 2;
        const fx = pages.width > 0 ? (flick.contentX + x - pages.x) / pages.width : 0.5;
        const fy = pages.height > 0 ? (flick.contentY + y - pages.y) / pages.height : 0;
        zoom = next;
        flick.contentX = View.hold(fx, pages.width, pages.x, x, flick.width, flick.contentWidth);
        flick.contentY = View.hold(fy, pages.height, pages.y, y, flick.height, flick.contentHeight);
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
    function actualSize() {
        fitting = "";
        setZoom(1);
    }
    function zoomToFit() {
        fitting = "page";
        refit();
        goToPage(currentPage);
    }
    // Turns the page in view a quarter: -1 to the left, 1 to the right.
    function rotate(direction) {
        const page = currentPage;
        const next = Object.assign({}, turns);
        next[page] = ((turns[page] ?? 0) + direction + 4) % 4;
        turns = next;
        refit();
        goToPage(page);
    }
    function goToPage(page, y) {
        if (page < 0 || page >= pageCount)
            return;
        flick.contentY = View.clamp(pages.y + plan.tops[page] + (y ?? 0) * zoom, 0, Math.max(0, flick.contentHeight - flick.height));
    }
    function scroll(dx, dy) {
        flick.contentX = View.clamp(flick.contentX + dx, 0, Math.max(0, flick.contentWidth - flick.width));
        flick.contentY = View.clamp(flick.contentY + dy, 0, Math.max(0, flick.contentHeight - flick.height));
    }
    function arrow(dx, dy) {
        scroll(dx * 40, dy * 40);
    }
    function pageStep(direction) {
        scroll(0, direction * Math.max(40, flick.height - 40));
    }
    function toStart() {
        flick.contentY = 0;
    }
    function toEnd() {
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    function select(page, from, to) {
        const got = doc.select(page, from, to);
        allSelected = false;
        selectedPage = page;
        selectedRects = got.rects ?? [];
        selectedText = got.text ?? "";
    }
    function selectAll() {
        clearSelection();
        allSelected = true;
    }
    function clearSelection() {
        allSelected = false;
        selectedPage = -1;
        selectedRects = [];
        selectedText = "";
    }
    function copy() {
        if (allSelected)
            App.copy(doc.allText());
        else if (selectedText !== "")
            App.copy(selectedText);
    }

    // Shows a match a third of the way down the view.
    function reveal(index) {
        const at = doc.match(index);
        if (at.page === undefined)
            return;
        const turned = (turns[at.page] ?? 0) !== 0;
        flick.contentY = View.clamp(pages.y + plan.tops[at.page] + (turned ? 0 : at.y * zoom) - flick.height / 3, 0, Math.max(0, flick.contentHeight - flick.height));
    }
    function findNext(direction) {
        const count = doc.matchCount;
        if (count === 0)
            return;
        currentMatch = currentMatch < 0 ? Math.max(0, doc.matchFrom(currentPage)) : (currentMatch + direction + count) % count;
        reveal(currentMatch);
    }
    Connections {
        target: view.doc
        function onFindChanged() {
            view.currentMatch = -1;
            view.findFrom = view.currentPage;
        }
        function onMatchesChanged() {
            if (view.currentMatch >= 0 || view.doc.matchCount === 0)
                return;
            // The first match on or after the page the search began on; one
            // before it only once every page has been gone through.
            const first = view.doc.matchFrom(view.findFrom);
            if (first < 0 || (view.doc.searching && view.doc.match(first).page < view.findFrom))
                return;
            view.currentMatch = first;
            view.reveal(first);
        }
    }

    Timer {
        id: settle
        interval: 140
        onTriggered: view.renderZoom = view.zoom
    }

    onWidthChanged: refit()
    onHeightChanged: if (fitting === "page") refit()
    Connections {
        target: view.doc
        function onLoaded() {
            view.turns = ({});
            view.clearSelection();
            Qt.callLater(view.refit);
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, view.plan.width)
        contentHeight: Math.max(height, view.plan.height)
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton // the mouse selects text; it doesn't drag the pages
        clip: true

        Controls.ScrollBar.vertical: ScrollThumb {}
        Controls.ScrollBar.horizontal: ScrollThumb {}

        // The ground: a click on it lets the selection go, and the wheel
        // with Command (Ctrl here) zooms about the pointer.
        Item {
            width: flick.contentWidth
            height: flick.contentHeight
            TapHandler { onTapped: view.clearSelection() }
            WheelHandler {
                acceptedModifiers: Qt.ControlModifier
                onWheel: (event) => {
                    view.fitting = "";
                    view.setZoom(view.zoom * Math.pow(1.002, event.angleDelta.y), point.position.x - flick.contentX, point.position.y - flick.contentY);
                }
            }
        }

        Item {
            id: pages
            x: Math.round((flick.contentWidth - width) / 2)
            y: Math.round(Math.max(0, (flick.height - height) / 2))
            width: view.plan.width
            height: view.plan.height

            Repeater {
                model: view.doc.pageCount

                Item {
                    id: slot
                    required property int index
                    readonly property size points: view.doc.pageSizes[index] ?? Qt.size(612, 792)
                    readonly property int quarter: view.turns[index] ?? 0
                    readonly property bool sideways: quarter % 2 !== 0
                    // Near enough the view to be worth drawing.
                    readonly property bool near: y + height > flick.contentY - pages.y - 900 && y < flick.contentY - pages.y + flick.height + 900

                    x: Math.round((pages.width - width) / 2)
                    y: view.plan.tops[index] ?? 0
                    // A page on its side is as much wider than tall by an
                    // even count, so that turned about its middle its
                    // picture lands on whole pixels.
                    width: {
                        const across = Math.round((sideways ? points.height : points.width) * view.zoom);
                        return sideways && (across - height) % 2 !== 0 ? across + 1 : across;
                    }
                    height: Math.round((sideways ? points.width : points.height) * view.zoom)

                    Rectangle { anchors.fill: parent; color: "white" }

                    // The page as it lies before any turn; what is marked on
                    // it turns with it.
                    Item {
                        id: sheet
                        anchors.centerIn: parent
                        width: slot.sideways ? parent.height : parent.width
                        height: slot.sideways ? parent.width : parent.height
                        rotation: slot.quarter * 90

                        Loader {
                            anchors.fill: parent
                            active: slot.near
                            sourceComponent: PageImage {
                                base: "image://page/" + view.doc.id + "/" + slot.index
                                pixelWidth: Math.round(slot.points.width * view.renderZoom * Screen.devicePixelRatio)
                                pixelHeight: Math.round(slot.points.height * view.renderZoom * Screen.devicePixelRatio)
                            }
                        }

                        // What the search found here.
                        Repeater {
                            model: {
                                view.doc.matchRevision;
                                return slot.near && view.doc.find !== "" ? view.doc.matchesOn(slot.index) : [];
                            }
                            Rectangle {
                                required property var modelData
                                readonly property bool current: modelData.match === view.currentMatch
                                x: modelData.x * view.zoom - 1
                                y: modelData.y * view.zoom - 1
                                width: modelData.width * view.zoom + 2
                                height: modelData.height * view.zoom + 2
                                radius: 2
                                color: current ? Look.foundCurrent : Look.found
                            }
                        }
                        // The text selected here.
                        Repeater {
                            model: view.selectedPage === slot.index ? view.selectedRects
                                : view.allSelected && slot.near ? (view.doc.selectAll(slot.index).rects ?? []) : []
                            Rectangle {
                                required property var modelData
                                x: modelData.x * view.zoom
                                y: modelData.y * view.zoom
                                width: modelData.width * view.zoom
                                height: modelData.height * view.zoom
                                color: Qt.alpha(Theme.accent.bg, 0.35)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            property point from
                            onPressed: (mouse) => {
                                from = Qt.point(mouse.x / view.zoom, mouse.y / view.zoom);
                                view.clearSelection();
                                view.window.takeKeys();
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed)
                                    view.select(slot.index, from, Qt.point(mouse.x / view.zoom, mouse.y / view.zoom));
                            }
                        }
                    }
                }
            }
        }
    }

    // Two fingers apart or together on the trackpad zoom about them.
    PinchHandler {
        target: null
        onScaleChanged: (delta) => {
            view.fitting = "";
            view.setZoom(view.zoom * delta, centroid.position.x, centroid.position.y);
        }
    }
}
