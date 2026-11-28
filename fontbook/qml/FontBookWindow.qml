import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Qt.labs.platform as Platform
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// Font Book's window, measured from macOS 27's (Look.qml): the sidebar of
// places down its left side, the toolbar 52 tall over the typefaces as
// cards, samples or a list, a typeface's own page, and the info pane on
// the right when asked for. Frameless: it draws its own corners and lights
// (KWin draws the shadow; App.decorate asks for it) and is moved by its
// toolbar and resized by its edges. The Library reads the fonts; what is
// listed, in what order and in what words is fontbook.mjs's.
Window {
    id: win

    // The place listed, how, and at what size in each view (0 to 1).
    property string section: "all"
    property string view: "grid"
    property var sizes: ({ grid: 0.5, samples: 0.46, list: 0, page: 0.34 })
    property bool infoShown: false
    property bool sidebarShown: true
    // The chosen typeface's name; the one whose page is open, with the
    // style shown there and how.
    property string selected: ""
    property string opened: ""
    property int openedStyle: 0
    property string pageMode: "specimen"
    // The list view's opened typefaces.
    property var expanded: []
    // { name: [family] }, and the one being renamed in the sidebar.
    property var collections: ({})
    property string renaming: ""

    readonly property var families: Library.families
    readonly property var listedFamilies: Book.listed(families, { section: section, search: toolbar.search.text, collections: collections })
    readonly property var selectedFamily: selected === "" ? null : (families.find(family => family.family === selected) ?? null)
    readonly property var openedFamily: opened === "" ? null : (families.find(family => family.family === opened) ?? null)
    readonly property var infoFamily: opened !== "" ? openedFamily : selectedFamily
    readonly property bool canRemove: infoFamily !== null && infoFamily.user && !toolbar.search.editing
    readonly property string sizeKey: opened !== "" ? "page" : view
    readonly property real size: sizes[sizeKey] ?? 0.5
    readonly property var pane: view === "grid" ? gridPane.item : view === "samples" ? samplesPane.item : listPane.item

    // A window keeps its active look while one of its menus is open, as on
    // a Mac; --active draws it active for grabs.
    property int menusOpen: 0
    // Something of Ambrosia's own is open over the screen (the app menu,
    // the control center): its menu bar says so through the menu named for
    // the app (MenuBar.qml).
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || App.active
    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int corner: maximized ? 0 : Look.windowRadius
    onActiveChanged: if (active) menusOpen = 0

    // The plainest of a typeface's styles (the Library puts the upright,
    // regular ones first): the one its samples are drawn in.
    function plain(family) {
        const styles = family?.styles ?? [];
        return styles.find(style => style.slant === 0 && style.width === 100 && style.weight === 80)
            ?? styles.find(style => style.slant === 0 && style.width === 100 && style.weight >= 80)
            ?? styles.find(style => style.slant === 0) ?? styles[0] ?? { name: "", file: "" };
    }
    function go(key) {
        if (section !== key) {
            section = key;
            selected = "";
        }
        opened = "";
        takeKeys();
    }
    function select(family) {
        selected = family;
        takeKeys();
    }
    function setView(which) {
        opened = "";
        view = which;
    }
    function setSize(to) {
        const sizes = Object.assign({}, win.sizes);
        sizes[sizeKey] = Math.max(0, Math.min(1, to));
        win.sizes = sizes;
    }
    function open(family) {
        const item = families.find(entry => entry.family === family);
        if (!item)
            return;
        selected = family;
        openedStyle = Math.max(0, item.styles.indexOf(plain(item)));
        opened = family;
        takeKeys();
    }
    function openStyle(family, style) {
        open(family);
        const at = openedFamily?.styles.findIndex(entry => entry.name === style) ?? -1;
        if (at >= 0)
            openedStyle = at;
    }
    // A typeface asked for from outside (a font file opened, one just
    // installed): its page, in a place that lists it.
    function show(family) {
        toolbar.search.text = "";
        if (!listedFamilies.some(entry => entry.family === family))
            section = "all";
        open(family);
    }
    function back() {
        const was = opened;
        opened = "";
        const at = listedFamilies.findIndex(entry => entry.family === was);
        if (at >= 0 && pane)
            pane.reveal(at);
        takeKeys();
    }
    // The typeface before or after the one whose page is open.
    function step(by) {
        const at = listedFamilies.findIndex(entry => entry.family === opened);
        const to = at + by;
        if (at >= 0 && to >= 0 && to < listedFamilies.length)
            open(listedFamilies[to].family);
    }
    function move(by) {
        if (listedFamilies.length === 0)
            return;
        const at = listedFamilies.findIndex(entry => entry.family === selected);
        const to = Math.max(0, Math.min(listedFamilies.length - 1, at < 0 ? (by > 0 ? 0 : listedFamilies.length - 1) : at + by));
        selected = listedFamilies[to].family;
        if (pane)
            pane.reveal(to);
    }
    function toggleExpanded(family) {
        expanded = expanded.includes(family) ? expanded.filter(name => name !== family) : expanded.concat([family]);
    }
    function find() {
        toolbar.search.focusField();
    }
    function addFonts() {
        App.chooseFonts();
    }
    function install(files) {
        const done = Library.install(files);
        if (done.installed.length > 0) {
            toolbar.search.text = "";
            opened = "";
            section = "mine";
            selected = done.installed[0];
            const at = listedFamilies.findIndex(entry => entry.family === selected);
            if (at >= 0 && pane)
                Qt.callLater(pane.reveal, at);
        }
        if (done.failed.length > 0)
            say(done.failed.length === 1 ? "“" + done.failed[0] + "” isn’t a font Font Book can read." : done.failed.length + " of the files aren’t fonts Font Book can read.", done.failed.length === 1 ? "" : done.failed.join(", "));
    }
    function revealSelected() {
        if (infoFamily !== null)
            App.reveal(opened !== "" ? (infoFamily.styles[openedStyle]?.file ?? "") : plain(infoFamily).file);
    }
    function removeFamily(family) {
        const item = families.find(entry => entry.family === family);
        if (!item || !item.user)
            return;
        alert.ask("Are you sure you want to remove the “" + family + "” family?",
            "Its font files will be moved to the Trash.",
            [{ text: "Remove", role: "remove", primary: true }, { text: "Cancel", role: "cancel", cancel: true }],
            (role) => {
                if (role !== "remove")
                    return;
                if (opened === family)
                    opened = "";
                if (selected === family)
                    selected = "";
                if (Library.remove(family) === 0)
                    say("The “" + family + "” family couldn’t be removed.", "");
            });
    }
    function removeSelected() {
        if (canRemove)
            removeFamily(infoFamily.family);
    }
    function say(title, detail) {
        alert.ask(title, detail, [{ text: "OK", role: "ok", primary: true, cancel: true }], null);
    }
    function menuFor(family) {
        familyMenu.family = family;
        familyMenu.open();
    }

    // Collections.
    function newCollection(member) {
        const name = Book.freshName(collections, "");
        let made = Book.withCollection(collections, name);
        if (typeof member === "string" && member !== "")
            made = Book.withMember(made, name, member);
        collections = made;
        sidebarShown = true;
        if (typeof member !== "string" || member === "") {
            opened = "";
            section = "collection:" + name;
            selected = "";
        }
        renaming = name;
    }
    function finishRenaming(from, to) {
        if (renaming !== from)
            return;
        renaming = "";
        const made = Book.renamed(collections, from, to);
        if (made !== collections) {
            collections = made;
            if (section === "collection:" + from)
                section = "collection:" + to.trim();
        }
        takeKeys();
    }
    function deleteCollection(name) {
        collections = Book.withoutCollection(collections, name);
        if (section === "collection:" + name)
            section = "all";
    }

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
    function takeKeys() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }
    // Letters typed one after another choose the first typeface whose name
    // begins with them.
    property string typed: ""
    property real typedAt: 0
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))
            return;
        const page = opened !== "";
        switch (event.key) {
        case Qt.Key_Left:
            if (page) step(-1);
            else if (view === "grid") move(-1);
            else if (view === "list" && expanded.includes(selected)) toggleExpanded(selected);
            break;
        case Qt.Key_Right:
            if (page) step(1);
            else if (view === "grid") move(1);
            else if (view === "list" && selected !== "" && !expanded.includes(selected)) toggleExpanded(selected);
            break;
        case Qt.Key_Up:
            if (page) openedStyle = Math.max(0, openedStyle - 1);
            else move(-(pane?.perRow ?? 1));
            break;
        case Qt.Key_Down:
            if (page) openedStyle = Math.min((openedFamily?.styles.length ?? 1) - 1, openedStyle + 1);
            else move(pane?.perRow ?? 1);
            break;
        case Qt.Key_PageUp: if (!page) move(-(pane?.perRow ?? 1) * (pane?.pageRows ?? 1)); else return; break;
        case Qt.Key_PageDown: if (!page) move((pane?.perRow ?? 1) * (pane?.pageRows ?? 1)); else return; break;
        case Qt.Key_Home: if (!page) move(-listedFamilies.length); else return; break;
        case Qt.Key_End: if (!page) move(listedFamilies.length); else return; break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!page && selected !== "") open(selected);
            break;
        case Qt.Key_Escape:
            if (page)
                back();
            else if (toolbar.search.text !== "")
                toolbar.search.text = "";
            else
                selected = "";
            break;
        case Qt.Key_Backspace:
        case Qt.Key_Delete:
            removeSelected();
            break;
        default: {
            if (page || event.text.length !== 1 || event.text < " ")
                return;
            const now = Date.now();
            typed = (now - typedAt < 900 ? typed : "") + event.text.toLowerCase();
            typedAt = now;
            const at = listedFamilies.findIndex(entry => entry.family.toLowerCase().startsWith(typed));
            if (at >= 0) {
                selected = listedFamilies[at].family;
                if (pane)
                    pane.reveal(at);
            }
        }
        }
        event.accepted = true;
    }

    width: Look.width
    height: Math.min(Look.height, Screen.height - 150)
    minimumWidth: Look.minWidth
    minimumHeight: Look.minHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    // It opens where it was last, as large (../kit/placing.h).
    property string frameName: "main"
    title: "Font Book"

    readonly property Appearance appearance: Appearance {}
    MenuBar { book: win }

    // What is kept from one launch to the next (not for grabs, which ask
    // for a view).
    Settings {
        id: kept
        category: "window"
        property string view: "grid"
        property string sizes: ""
        property bool info: false
        property bool sidebar: true
        property string section: "all"
        property string collections: "{}"
    }
    readonly property bool remembers: App.view === "" && App.family === ""
    property bool ready: false
    onViewChanged: if (remembers && ready) kept.view = view
    onSizesChanged: if (remembers && ready) kept.sizes = JSON.stringify(sizes)
    onInfoShownChanged: if (remembers && ready) kept.info = infoShown
    onSidebarShownChanged: if (remembers && ready) kept.sidebar = sidebarShown
    onSectionChanged: if (remembers && ready) kept.section = section
    onCollectionsChanged: if (ready) kept.collections = JSON.stringify(collections)

    Connections {
        target: Library
        // A typeface that is gone isn't chosen or open any more.
        function onChanged() {
            if (win.selected !== "" && win.selectedFamily === null)
                win.selected = "";
            if (win.opened !== "" && win.openedFamily === null)
                win.opened = "";
        }
    }
    Connections {
        target: App
        function onAddRequested(files) {
            win.install(files);
        }
    }

    Component.onCompleted: {
        collections = Book.parseCollections(kept.collections);
        if (remembers) {
            if (["grid", "samples", "list"].includes(kept.view))
                view = kept.view;
            try {
                const read = JSON.parse(kept.sizes || "{}");
                const sizes = Object.assign({}, win.sizes);
                for (const key of ["grid", "samples", "list", "page"]) {
                    if (typeof read[key] === "number")
                        sizes[key] = Math.max(0, Math.min(1, read[key]));
                }
                win.sizes = sizes;
            } catch (error) {
            }
            infoShown = kept.info;
            sidebarShown = kept.sidebar;
            // A collection that is gone, or a language no longer read,
            // lists nothing: All Fonts then.
            if (Book.sections(Library.languages, collections).some(part => part.items.some(item => item.key === kept.section)))
                section = kept.section;
        } else {
            if (["grid", "samples", "list"].includes(App.view))
                view = App.view;
            infoShown = App.info;
            if (App.family !== "")
                open(App.family);
        }
        ready = true;
        takeKeys();
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win, false);
        }
    }

    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close); onActivatedAmbiguously: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized); onActivatedAmbiguously: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", Qt.quit); onActivatedAmbiguously: win.act("quit", Qt.quit) }
    Shortcut { sequences: ["Ctrl+N", "Meta+N"]; onActivated: win.act("newCollection", win.newCollection); onActivatedAmbiguously: win.act("newCollection", win.newCollection) }
    Shortcut { sequences: ["Ctrl+O", "Meta+O"]; onActivated: win.act("add", win.addFonts); onActivatedAmbiguously: win.act("add", win.addFonts) }
    Shortcut { sequences: ["Ctrl+R", "Meta+R"]; onActivated: win.act("reveal", win.revealSelected); onActivatedAmbiguously: win.act("reveal", win.revealSelected) }
    Shortcut { sequences: ["Ctrl+F", "Meta+F"]; onActivated: win.act("search", win.find); onActivatedAmbiguously: win.act("search", win.find) }
    Shortcut { sequences: ["Ctrl+[", "Meta+["]; enabled: win.opened !== ""; onActivated: win.act("back", win.back); onActivatedAmbiguously: win.act("back", win.back) }
    Shortcut { sequences: ["Ctrl+1", "Meta+1"]; onActivated: win.act("grid", () => win.setView("grid")); onActivatedAmbiguously: win.act("grid", () => win.setView("grid")) }
    Shortcut { sequences: ["Ctrl+2", "Meta+2"]; onActivated: win.act("samples", () => win.setView("samples")); onActivatedAmbiguously: win.act("samples", () => win.setView("samples")) }
    Shortcut { sequences: ["Ctrl+3", "Meta+3"]; onActivated: win.act("list", () => win.setView("list")); onActivatedAmbiguously: win.act("list", () => win.setView("list")) }
    Shortcut { sequences: ["Ctrl++", "Meta++", "Ctrl+=", "Meta+="]; onActivated: win.act("larger", () => win.setSize(win.size + 0.1)); onActivatedAmbiguously: win.act("larger", () => win.setSize(win.size + 0.1)) }
    Shortcut { sequences: ["Ctrl+-", "Meta+-"]; onActivated: win.act("smaller", () => win.setSize(win.size - 0.1)); onActivatedAmbiguously: win.act("smaller", () => win.setSize(win.size - 0.1)) }
    Shortcut { sequences: ["Ctrl+I", "Meta+I"]; onActivated: win.act("info", () => win.infoShown = !win.infoShown); onActivatedAmbiguously: win.act("info", () => win.infoShown = !win.infoShown) }

    Item {
        id: frame
        anchors.fill: parent

        Item {
            id: keys
            focus: true
            Keys.onPressed: (event) => win.keyPressed(event)
        }

        Sidebar {
            id: sidebar
            visible: win.sidebarShown
            height: parent.height
            window: win
        }

        // Under the toolbar, beside the sidebar: the views and the info
        // pane, cut to the window's bottom corners (not when drawn
        // off-screen, where a mask draws nothing: a grab's are square).
        Item {
            id: body
            x: toolbar.start
            y: Look.toolbar
            width: parent.width - x
            height: parent.height - Look.toolbar
            layer.enabled: !win.maximized && !App.offscreen
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bodyShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Look.ground }

            Item {
                id: views
                width: parent.width - (win.infoShown ? Look.infoWidth : 0)
                height: parent.height

                // A view is made when first shown and kept, so each holds
                // its place while another is looked at.
                Loader {
                    id: gridPane
                    property bool used: false
                    readonly property bool current: win.view === "grid" && win.opened === ""
                    onCurrentChanged: if (current) used = true
                    Component.onCompleted: if (current) used = true
                    anchors.fill: parent
                    active: used
                    visible: current
                    sourceComponent: GridPane { window: win }
                }
                Loader {
                    id: samplesPane
                    property bool used: false
                    readonly property bool current: win.view === "samples" && win.opened === ""
                    onCurrentChanged: if (current) used = true
                    Component.onCompleted: if (current) used = true
                    anchors.fill: parent
                    active: used
                    visible: current
                    sourceComponent: SamplesPane { window: win }
                }
                Loader {
                    id: listPane
                    property bool used: false
                    readonly property bool current: win.view === "list" && win.opened === ""
                    onCurrentChanged: if (current) used = true
                    Component.onCompleted: if (current) used = true
                    anchors.fill: parent
                    active: used
                    visible: current
                    sourceComponent: ListPane { window: win }
                }
                Loader {
                    anchors.fill: parent
                    active: win.opened !== ""
                    sourceComponent: TypefacePage { window: win }
                }

                // Nothing to list: why.
                Column {
                    visible: win.opened === "" && win.listedFamilies.length === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 60, 320)
                    spacing: 6
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: toolbar.search.text !== "" ? "No Results" : "No Fonts"
                        style: Theme.text.title3
                        font.weight: 700
                        color: Look.heading
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: toolbar.search.text !== "" ? "No typeface here has “" + toolbar.search.text + "” in its name."
                            : win.section === "mine" ? "Fonts you add appear here. Choose File > Add Fonts to Current User…, or drop font files on this window."
                            : win.section.startsWith("collection:") ? "Add a typeface to this collection from its menu (a right click on it)."
                            : "No typeface on this computer belongs here."
                        color: Look.note
                    }
                }
            }
            InfoPane {
                visible: win.infoShown
                x: parent.width - width
                height: parent.height
                window: win
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
                bottomLeftRadius: win.sidebarShown ? 0 : Look.windowRadius
                bottomRightRadius: Look.windowRadius
                color: "black"
            }
        }

        Rectangle {
            x: toolbar.start
            width: parent.width - x
            height: Look.toolbar
            topLeftRadius: win.sidebarShown ? 0 : win.corner
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
            Rectangle {
                y: parent.height
                width: parent.width
                height: 1
                color: Look.hairline
                visible: win.opened !== "" || win.view !== "list"
            }
        }
        Toolbar {
            id: toolbar
            width: parent.width
            window: win
        }

        // Font files dropped on the window are added.
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    win.install(drop.urls);
                    drop.accept();
                }
            }
        }

        Alert {
            id: alert
            anchors.fill: parent
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

    // A typeface's own menu (a right click on it).
    Platform.Menu {
        id: familyMenu
        property string family
        readonly property var item: win.families.find(entry => entry.family === family) ?? null
        readonly property string inCollection: win.section.startsWith("collection:") ? win.section.slice(11) : ""

        Platform.MenuItem { text: "Open"; onTriggered: win.open(familyMenu.family) }
        Platform.MenuItem { text: "Show in Files"; onTriggered: App.reveal(win.plain(familyMenu.item).file) }
        Platform.MenuSeparator {}
        Platform.Menu {
            id: addTo
            title: "Add to Collection"
            Platform.MenuItem { text: "New Collection"; onTriggered: win.newCollection(familyMenu.family) }
            Platform.MenuSeparator { visible: Book.collectionNames(win.collections).length > 0 }
            Instantiator {
                model: Book.collectionNames(win.collections)
                delegate: Platform.MenuItem {
                    required property string modelData
                    text: modelData
                    onTriggered: win.collections = Book.withMember(win.collections, modelData, familyMenu.family)
                }
                onObjectAdded: (index, object) => addTo.insertItem(index + 2, object)
                onObjectRemoved: (index, object) => addTo.removeItem(object)
            }
        }
        Platform.MenuItem {
            visible: familyMenu.inCollection !== ""
            text: "Remove from “" + familyMenu.inCollection + "”"
            onTriggered: win.collections = Book.withoutMember(win.collections, familyMenu.inCollection, familyMenu.family)
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: "Remove “" + familyMenu.family + "” Family…"
            enabled: familyMenu.item?.user ?? false
            onTriggered: win.removeFamily(familyMenu.family)
        }
    }
}
