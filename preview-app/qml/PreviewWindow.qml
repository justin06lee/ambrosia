import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Ambrosia
import Preview
import "view.mjs" as View

// A Preview window, measured from macOS 27's (Look.qml): the toolbar 52
// tall over the document on its dark ground, the sidebar flush down the
// left when it shows. One PDF, or one or more pictures. Frameless: it draws
// its own corners and lights (KWin draws the shadow; App.decorate asks for
// it) and is moved by its toolbar and resized by its edges.
Window {
    id: win

    // What it shows: one PDF, or pictures (`index` says which is up).
    required property var files
    property int index: 0
    readonly property bool pdf: files.length === 1 && App.isPdf(files[0])
    readonly property Document doc: document
    readonly property var view: viewLoader.item
    // There is something to zoom, turn and list: not a locked PDF, nor a
    // file that couldn't be read.
    readonly property bool showsDocument: pdf ? document.pageCount > 0 : files.length > 1 || !(view?.failed ?? true)
    readonly property bool unreadable: pdf ? document.failed : (view?.failed ?? false)

    // "none", "thumbnails" or "outline" (a PDF's table of contents).
    property string sidebarMode: "none"
    readonly property bool sidebarShown: sidebarMode !== "none" && showsDocument
    readonly property real side: sidebarShown ? Look.sidebarWidth : 0
    readonly property bool hasOutline: pdf && document.outline.length > 0
    readonly property bool canFind: pdf && document.pageCount > 0

    readonly property string name: App.name(files[pdf ? 0 : index] ?? "")
    readonly property string subtitle: pdf
        ? (document.pageCount > 1 ? "Page " + ((view?.currentPage ?? 0) + 1) + " of " + document.pageCount : document.pageCount === 1 ? "1 page" : "")
        : files.length > 1 ? files.length + " documents, " + files.length + " total pages" : ""

    // A window keeps its active look while one of its menus is open, as on
    // a Mac; --active draws it active for grabs.
    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0 || App.active
    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int corner: maximized ? 0 : Look.windowRadius
    onActiveChanged: if (active) menusOpen = 0

    // A key that is also a menu item's shortcut is handed to one of the two
    // in turn, the window's own marked ambiguous: either way it runs, once.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        run();
    }
    // The keys go to the document; to the password field while a locked
    // PDF waits for one.
    function takeKeys() {
        if (pdf && document.locked)
            password.forceActiveFocus();
        else
            keys.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }
    function copy() {
        if (!toolbar.search.editing)
            view?.copy();
    }
    function selectAll() {
        if (!toolbar.search.editing)
            view?.selectAll();
    }
    function find() {
        if (canFind)
            toolbar.search.focusField();
    }
    function findNext(direction) {
        if (canFind)
            view.findNext(direction);
    }
    function keyPressed(event) {
        if (!view || !showsDocument || (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier)))
            return;
        switch (event.key) {
        case Qt.Key_Up: view.arrow(0, -1); break;
        case Qt.Key_Down: view.arrow(0, 1); break;
        case Qt.Key_Left: view.arrow(-1, 0); break;
        case Qt.Key_Right: view.arrow(1, 0); break;
        case Qt.Key_Space: view.pageStep(event.modifiers & Qt.ShiftModifier ? -1 : 1); break;
        case Qt.Key_PageUp: view.pageStep(-1); break;
        case Qt.Key_PageDown: view.pageStep(1); break;
        case Qt.Key_Home: view.toStart(); break;
        case Qt.Key_End: view.toEnd(); break;
        case Qt.Key_Escape:
            if (toolbar.search.text !== "")
                toolbar.search.text = "";
            else
                view.clearSelection();
            break;
        default: return;
        }
        event.accepted = true;
    }

    // The window a document opens in (view.mjs): a picture at its own size
    // with a little ground above and below, a PDF's first page at actual
    // size beside the sidebar, either as far as the screen has room.
    function arrange() {
        const screen = { width: Screen.width - 2 * Look.screenSide, height: Screen.height - Look.screenTop - Look.screenBottom };
        const chrome = (side) => ({ side: side, toolbar: Look.toolbar, margin: Look.pictureMargin, beside: Look.pagesBeside, minWidth: Look.minWidth, minHeight: Look.minHeight });
        if (pdf) {
            if (document.pageCount === 0)
                return;
            sidebarMode = App.sidebar !== "" ? App.sidebar : document.pageCount > 1 ? "thumbnails" : "none";
            const pages = View.layout(document.pageSizes, {}, 1, Look.pageGap).height;
            const opened = View.pagesWindow(document.pageSizes[0], pages, screen, chrome(sidebarMode !== "none" ? Look.sidebarWidth : 0));
            width = opened.width;
            height = opened.height;
        } else {
            sidebarMode = App.sidebar === "none" || App.sidebar === "thumbnails" ? App.sidebar : files.length > 1 ? "thumbnails" : "none";
            const size = App.imageSize(files[0]);
            if (size.width <= 0 || size.height <= 0)
                return;
            const opened = View.pictureWindow(size, screen, chrome(sidebarMode !== "none" ? Look.sidebarWidth : 0));
            width = opened.width;
            height = opened.height;
        }
    }

    width: 640
    height: 480
    minimumWidth: Look.minWidth
    minimumHeight: Look.minHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: name

    readonly property Appearance appearance: Appearance {}
    MenuBar { preview: win }
    Document {
        id: document
        source: win.pdf ? win.files[0] : ""
    }

    Component.onCompleted: {
        arrange();
        visible = true;
        takeKeys();
        if (App.zoom > 0 && view) {
            Qt.callLater(() => {
                view.fitting = "";
                view.setZoom(App.zoom);
            });
        }
        if (App.find !== "" && canFind)
            toolbar.search.text = App.find;
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win);
        }
    }

    // What's typed in the search field is looked for a moment after the
    // typing stops.
    Connections {
        target: toolbar.search
        function onTextChanged() {
            findDelay.restart();
        }
    }
    Timer {
        id: findDelay
        interval: 150
        onTriggered: document.find = toolbar.search.text
    }

    Shortcut { sequences: ["Ctrl+O", "Meta+O"]; onActivated: win.act("open", () => App.chooseFiles()); onActivatedAmbiguously: win.act("open", () => App.chooseFiles()) }
    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close); onActivatedAmbiguously: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized); onActivatedAmbiguously: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", Qt.quit); onActivatedAmbiguously: win.act("quit", Qt.quit) }
    Shortcut { sequences: ["Ctrl+C", "Meta+C"]; onActivated: win.act("copy", win.copy); onActivatedAmbiguously: win.act("copy", win.copy) }
    Shortcut { sequences: ["Ctrl+A", "Meta+A"]; onActivated: win.act("selectAll", win.selectAll); onActivatedAmbiguously: win.act("selectAll", win.selectAll) }
    Shortcut { sequences: ["Ctrl+F", "Meta+F"]; onActivated: win.act("find", win.find); onActivatedAmbiguously: win.act("find", win.find) }
    Shortcut { sequences: ["Ctrl+G", "Meta+G"]; onActivated: win.act("findNext", () => win.findNext(1)); onActivatedAmbiguously: win.act("findNext", () => win.findNext(1)) }
    Shortcut { sequences: ["Ctrl+Shift+G", "Meta+Shift+G"]; onActivated: win.act("findPrevious", () => win.findNext(-1)); onActivatedAmbiguously: win.act("findPrevious", () => win.findNext(-1)) }
    Shortcut { sequences: ["Ctrl+Alt+1", "Meta+Alt+1"]; enabled: win.showsDocument; onActivated: win.act("sidebarNone", () => win.sidebarMode = "none"); onActivatedAmbiguously: win.act("sidebarNone", () => win.sidebarMode = "none") }
    Shortcut { sequences: ["Ctrl+Alt+2", "Meta+Alt+2"]; enabled: win.showsDocument; onActivated: win.act("sidebarThumbnails", () => win.sidebarMode = "thumbnails"); onActivatedAmbiguously: win.act("sidebarThumbnails", () => win.sidebarMode = "thumbnails") }
    Shortcut { sequences: ["Ctrl+Alt+3", "Meta+Alt+3"]; enabled: win.hasOutline; onActivated: win.act("sidebarOutline", () => win.sidebarMode = "outline"); onActivatedAmbiguously: win.act("sidebarOutline", () => win.sidebarMode = "outline") }
    Shortcut { sequences: ["Ctrl+0", "Meta+0"]; enabled: win.showsDocument; onActivated: win.act("actualSize", () => win.view.actualSize()); onActivatedAmbiguously: win.act("actualSize", () => win.view.actualSize()) }
    Shortcut { sequences: ["Ctrl+9", "Meta+9"]; enabled: win.showsDocument; onActivated: win.act("zoomToFit", () => win.view.zoomToFit()); onActivatedAmbiguously: win.act("zoomToFit", () => win.view.zoomToFit()) }
    Shortcut { sequences: ["Ctrl++", "Ctrl+=", "Meta++", "Meta+="]; enabled: win.showsDocument; onActivated: win.act("zoomIn", () => win.view.zoomIn()); onActivatedAmbiguously: win.act("zoomIn", () => win.view.zoomIn()) }
    Shortcut { sequences: ["Ctrl+-", "Meta+-"]; enabled: win.showsDocument; onActivated: win.act("zoomOut", () => win.view.zoomOut()); onActivatedAmbiguously: win.act("zoomOut", () => win.view.zoomOut()) }
    Shortcut { sequences: ["Ctrl+L", "Meta+L"]; enabled: win.showsDocument; onActivated: win.act("rotateLeft", () => win.view.rotate(-1)); onActivatedAmbiguously: win.act("rotateLeft", () => win.view.rotate(-1)) }
    Shortcut { sequences: ["Ctrl+R", "Meta+R"]; enabled: win.showsDocument; onActivated: win.act("rotateRight", () => win.view.rotate(1)); onActivatedAmbiguously: win.act("rotateRight", () => win.view.rotate(1)) }
    Shortcut { sequences: ["Alt+Up"]; enabled: win.showsDocument; onActivated: win.act("previous", () => win.view.goToPage(win.view.currentPage - 1)); onActivatedAmbiguously: win.act("previous", () => win.view.goToPage(win.view.currentPage - 1)) }
    Shortcut { sequences: ["Alt+Down"]; enabled: win.showsDocument; onActivated: win.act("next", () => win.view.goToPage(win.view.currentPage + 1)); onActivatedAmbiguously: win.act("next", () => win.view.goToPage(win.view.currentPage + 1)) }

    Item {
        id: frame
        anchors.fill: parent

        Item {
            id: keys
            focus: true
            Keys.onPressed: (event) => win.keyPressed(event)
        }

        // Under the toolbar: the document on its ground and the sidebar,
        // cut to the window's bottom corners.
        Item {
            id: body
            y: Look.toolbar
            width: parent.width
            height: parent.height - Look.toolbar
            layer.enabled: !win.maximized
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bodyShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Look.ground }

            Loader {
                id: viewLoader
                x: win.side
                width: parent.width - x
                height: parent.height
                sourceComponent: win.pdf ? pdfView : imageView
            }
            Component { id: pdfView; PdfView { window: win; doc: document; visible: win.showsDocument } }
            Component { id: imageView; ImageView { window: win } }

            // A file that couldn't be read says so, in a Mac's words.
            Column {
                visible: win.unreadable
                anchors.centerIn: viewLoader
                width: Math.min(viewLoader.width - 48, 420)
                spacing: 6
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "The file “" + win.name + "” could not be opened."
                    style: Theme.text.headline
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "It may be damaged or use a file format that Preview doesn’t recognize."
                    style: Theme.text.footnote
                    color: Theme.color.label.secondary
                }
            }

            // A PDF with a password asks for it here, where its pages go.
            Column {
                id: lockPrompt
                visible: win.pdf && document.locked
                anchors.centerIn: viewLoader
                width: 300
                spacing: 10
                property bool wrong: false

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "lock"
                    size: 56
                    color: Theme.color.label.secondary
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "This PDF is password protected."
                    style: Theme.text.headline
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: lockPrompt.wrong ? "That password didn’t open it. Try again." : "Enter the password to open it."
                    style: Theme.text.footnote
                    color: Theme.color.label.secondary
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    height: 28
                    radius: 7
                    color: Look.capsule
                    border.width: password.activeFocus ? 3 : 0.5
                    border.color: password.activeFocus ? Theme.accent.highlight : Look.capsuleRim
                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.text.body.size
                        color: Theme.color.label.primary
                        selectionColor: Theme.accent.highlight
                        selectedTextColor: Theme.color.label.primary
                        clip: true
                        onAccepted: {
                            if (document.unlock(text)) {
                                win.arrange();
                                win.takeKeys();
                            } else {
                                lockPrompt.wrong = true;
                                selectAll();
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: win.sidebarShown
                width: Look.sidebarWidth
                height: parent.height
                color: Look.sidebarFill
            }
            Sidebar {
                visible: win.sidebarShown
                width: Look.sidebarWidth
                height: parent.height
                window: win
            }
            Rectangle {
                visible: win.sidebarShown
                x: Look.sidebarWidth - 1
                width: 1
                height: parent.height
                color: Look.hairline
            }
        }
        Item {
            id: bodyShape
            width: body.width
            height: body.height
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                bottomLeftRadius: Look.windowRadius
                bottomRightRadius: Look.windowRadius
                color: "black"
            }
        }

        // The toolbar's band, the sidebar's color where it runs up beside
        // it, and the hairline under the band.
        Rectangle {
            width: parent.width
            height: Look.toolbar
            topLeftRadius: win.corner
            topRightRadius: win.corner
            color: Look.toolbarFill

            // The window moves by its toolbar; two clicks zoom it.
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler {
                onTapped: win.takeKeys()
                onDoubleTapped: win.toggleZoom()
            }
        }
        Rectangle {
            visible: win.sidebarShown
            width: Look.sidebarWidth
            height: Look.toolbar
            topLeftRadius: win.corner
            color: Look.sidebarFill
        }
        Rectangle {
            x: win.side
            y: Look.toolbar
            width: parent.width - x
            height: 1
            color: Look.hairline
        }
        Rectangle {
            visible: win.sidebarShown
            x: Look.sidebarWidth - 1
            width: 1
            height: Look.toolbar
            color: Look.hairline
        }

        Toolbar {
            id: toolbar
            width: parent.width
            window: win
        }

        // The window's rim, over everything.
        Rectangle {
            anchors.fill: parent
            radius: win.corner
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }

        // Resizing by the edges and corners.
        Repeater {
            model: win.maximized ? [] : [
                { edges: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.TopEdge, x: 8, y: 0, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.TopEdge | Qt.LeftEdge, x: 0, y: 0, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
                { edges: Qt.TopEdge | Qt.RightEdge, x: -10, y: 0, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: -10, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.RightEdge, x: -10, y: -10, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
            ]
            Item {
                required property var modelData
                x: modelData.x < 0 ? frame.width + modelData.x : modelData.x
                y: modelData.y < 0 ? frame.height + modelData.y : modelData.y
                width: modelData.w < 0 ? frame.width + modelData.w : modelData.w
                height: modelData.h < 0 ? frame.height + modelData.h : modelData.h
                HoverHandler { cursorShape: parent.modelData.shape }
                DragHandler {
                    target: null
                    onActiveChanged: if (active) win.startSystemResize(parent.modelData.edges)
                }
            }
        }
    }
}
