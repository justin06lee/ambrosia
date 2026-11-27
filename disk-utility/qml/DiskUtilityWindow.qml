import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Ambrosia
import DiskUtility
import "disks.mjs" as Logic

// Disk Utility's window, measured from macOS 27's (Look.qml): the sidebar
// of disks and volumes down its left side, the toolbar 66 tall with its
// named buttons, and what is chosen on the page. Frameless: it draws its
// own corners and lights (KWin draws the shadow; App.decorate asks for it)
// and is moved by its toolbar and resized by its edges. Disks reads
// UDisks2 and does what is asked; what is listed, said and allowed is
// disks.mjs's.
Window {
    id: win

    // Every device, or only volumes; the disks shut in the sidebar; the
    // key of what is chosen.
    property bool everything: false
    property bool sidebarShown: true
    property var collapsed: []
    property string chosen: ""
    // A disk image just opened: chosen once it shows.
    property string wanted: ""
    // The key of the volume whose name is being changed in the sidebar.
    property string renaming: ""
    signal infoRequested(string key)

    readonly property var all: Logic.model(Array.from(Disks.blocks), Array.from(Disks.drives))
    readonly property var sections: Logic.sidebar(all, everything, collapsed)
    readonly property var item: Logic.find(all, chosen)
    readonly property var told: Logic.page(all, item, Disks.system)
    readonly property var may: Logic.can(all, item, Disks.checkable)
    readonly property string iconOf: told?.icon ?? "internal"

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

    // What is chosen is always something listed: when it goes (ejected, or
    // a disk's own row not listed among volumes), the first that is.
    function settle() {
        if (!Disks.ready)
            return;
        const keys = Logic.keys(Logic.sidebar(all, everything, []));
        if (wanted !== "") {
            const disk = Logic.find(all, wanted);
            if (disk) {
                const first = disk.kind === "disk" && disk.volumes.length > 0 ? disk.volumes[0].key : disk.key;
                wanted = "";
                chosen = keys.includes(first) ? first : disk.key;
                collapsed = collapsed.filter(key => key !== disk.key);
            }
        }
        if (chosen !== "" && keys.includes(chosen))
            return;
        // A disk chosen, then only volumes listed: its first volume.
        const was = Logic.find(all, chosen);
        if (was && was.kind === "disk" && was.volumes.length > 0 && keys.includes(was.volumes[0].key)) {
            chosen = was.volumes[0].key;
            return;
        }
        chosen = Logic.first(all, everything);
    }
    onAllChanged: settle()
    onEverythingChanged: {
        if (remembers && ready)
            kept.everything = everything;
        settle();
    }

    function choose(key) {
        chosen = key;
        takeKeys();
    }
    function toggleShut(key) {
        collapsed = collapsed.includes(key) ? collapsed.filter(entry => entry !== key) : collapsed.concat([key]);
        // What was chosen under a disk now shut: the disk.
        if (!Logic.keys(sections).includes(chosen))
            chosen = key;
    }
    function move(by) {
        const keys = Logic.keys(sections);
        if (keys.length === 0)
            return;
        const at = keys.indexOf(chosen);
        chosen = keys[Math.max(0, Math.min(keys.length - 1, at < 0 ? 0 : at + by))];
    }
    function nameOf(thing) {
        return thing?.name ?? "";
    }
    function deviceOf(thing) {
        return String(thing?.block?.device ?? "").replace(/^\/dev\//, "");
    }

    function toggleMount() {
        if (!item || !may.mount)
            return;
        if (may.mountLabel === "Unmount") {
            Disks.unmount(Logic.mountedOn(all, item), Logic.unlockedOn(all, item));
            return;
        }
        const parts = item.kind === "disk" ? item.volumes : [item];
        const open = parts.filter(part => !part.locked && !part.mounted && part.fs.filesystem).map(part => part.fs.path);
        if (open.length > 0)
            Disks.mount(open);
        // An encrypted one asks for its password, one at a time.
        const locked = parts.find(part => part.locked);
        if (locked)
            sheets.askPassword(iconOf, locked.name, (password) => Disks.unlock(locked.block.path, password));
    }
    function eject(key) {
        const disk = Logic.diskOf(all, Logic.find(all, key));
        if (!disk || !disk.block || disk.section === "internal" || disk.system)
            return;
        const how = disk.section === "image" ? "loop" : disk.drive?.canPowerOff ? "off" : disk.drive?.ejectable ? "eject" : "";
        Disks.eject(Logic.mountedOn(all, disk), Logic.unlockedOn(all, disk), disk.block.path, disk.drive?.path ?? "", how);
    }
    function reveal() {
        const parts = !item ? [] : item.kind === "disk" ? item.volumes : [item];
        const mounted = parts.find(part => part.mounted);
        if (mounted)
            App.reveal(mounted.mountPoint);
    }
    function showInfo() {
        if (item)
            infoRequested(chosen);
    }
    function openImage() {
        App.chooseImage();
    }

    function startRename() {
        if (item && may.rename && sheets.mode === "")
            renaming = chosen;
    }
    // What was typed, or "" to leave the name as it is.
    function rename(key, typed) {
        if (renaming !== key)
            return;
        renaming = "";
        takeKeys();
        const thing = Logic.find(all, key);
        if (!thing || thing.kind !== "volume")
            return;
        const label = Logic.labelFor(thing.fs.type, typed);
        if (label === "" || label === thing.fs.label)
            return;
        renamed = thing.name;
        Disks.rename(thing.fs.path, thing.mounted, label);
    }
    property string renamed: ""

    // File ▸ New Image ▸ Blank Image…: where and what, then the making.
    function askImage() {
        if (sheets.mode !== "")
            return;
        renaming = "";
        sheets.askImage(Logic.eraseFormats(Disks.formats), makeImage);
    }
    function makeImage(path, file, bytes, format, name, scheme) {
        const open = Array.from(Disks.blocks).some(block => block.loop && block.backingFile === path);
        if (open) {
            sheets.ask("image", "“" + file + "” can’t be replaced because it is open.", "Eject the disk image, then try again.",
                [{ text: "OK", role: "ok", primary: true, cancel: true }], () => sheets.backToImage());
            return;
        }
        const go = () => {
            sheets.progress("image", "Creating “" + file + "”", "", "");
            sheets.say("Creating “" + file + "”");
            if (scheme !== "")
                sheets.say("Creating the partition map.");
            sheets.say("Formatting as " + (Logic.eraseFormats(Disks.formats).find(entry => entry.type === format)?.name ?? format) + ".");
            Disks.newImage(path, bytes, format, name, scheme);
        };
        if (!App.exists(path)) {
            go();
            return;
        }
        sheets.ask("image", "“" + file + "” already exists. Do you want to replace it?",
            "A file with the same name already exists in “" + App.folderName(path.replace(/\/[^/]*$/, "") || "/") + "”. Replacing it will overwrite its current contents.",
            [{ text: "Cancel", role: "cancel", cancel: true }, { text: "Replace", role: "replace", primary: true }],
            (role) => role === "replace" ? go() : sheets.backToImage());
    }

    function askFirstAid() {
        if (!item || !may.firstAid)
            return;
        sheets.ask(iconOf, "Run First Aid on “" + item.name + "”?",
            "First Aid will check the volume for errors. It will then repair the volume if necessary.",
            [{ text: "Cancel", role: "cancel", cancel: true }, { text: "Run", role: "run", primary: true }],
            (role) => {
                if (role === "run")
                    runFirstAid();
            });
    }
    function runFirstAid() {
        const volume = item;
        if (!volume || volume.kind !== "volume")
            return;
        sheets.progress(iconOf, "Running First Aid on “" + volume.name + "”", "", "");
        sheets.say("Running First Aid on “" + volume.name + "” (" + deviceOf(volume) + ")");
        Disks.firstAid(volume.fs.path, volume.mounted);
    }
    function askErase() {
        if (!item || !may.erase)
            return;
        const thing = item;
        const whole = thing.kind === "disk";
        sheets.askErase(iconOf, thing.name, whole, Logic.eraseFormats(Disks.formats), whole ? "" : thing.fs.type, (name, format, scheme) => {
            sheets.progress(iconOf, "Erasing “" + thing.name + "” and creating “" + (name !== "" ? name : "Untitled") + "”", "", "");
            sheets.say("Erasing “" + thing.name + "” (" + deviceOf(thing) + ") and creating “" + (name !== "" ? name : "Untitled") + "”");
            if (Logic.mountedOn(all, thing).length > 0)
                sheets.say("Unmounting disk.");
            if (scheme !== "")
                sheets.say("Creating the partition map.");
            sheets.say("Formatting as " + (Logic.eraseFormats(Disks.formats).find(entry => entry.type === format)?.name ?? format) + ".");
            Disks.erase(thing.block.path, Logic.mountedOn(all, thing), Logic.unlockedOn(all, thing), format, name, scheme);
        });
    }

    Connections {
        target: Disks
        function onFirstAidLine(line) {
            sheets.say(line);
        }
        function onFirstAidDone(ok, code, detail) {
            if (detail !== "")
                sheets.say(detail);
            sheets.finish(ok, ok ? "First Aid process is complete." : "First Aid process has failed.",
                ok ? "Click Done to continue."
                   : code === "busy" ? "The volume couldn’t be unmounted because it is in use. Quit the apps using it and try again."
                   : code === "dismissed" || code === "denied" ? "First Aid needs an administrator’s leave to check this volume."
                   : "If possible back up the data on this volume. Click Done to continue.");
        }
        function onEraseDone(ok, code, detail) {
            if (!ok && code === "dismissed") {
                sheets.close();
                return;
            }
            if (detail !== "")
                sheets.say(detail);
            sheets.say(ok ? "Operation successful." : "Operation failed.");
            sheets.finish(ok, ok ? "Erase process is complete." : "Erase process has failed.",
                ok ? "Click Done to continue."
                   : code === "busy" ? "The disk couldn’t be unmounted because it is in use. Quit the apps using it and try again."
                   : "Click Done to continue.");
        }
        function onRenameDone(ok, code, detail) {
            if (ok || code === "dismissed")
                return;
            sheets.ask(win.iconOf, "“" + win.renamed + "” couldn’t be renamed" + (code === "busy" ? " because one or more apps may be using it." : "."),
                code === "busy" ? "Quit the apps using it and try again." : detail,
                [{ text: "OK", role: "ok", primary: true, cancel: true }], null);
        }
        function onImageDone(ok, step, code, detail) {
            if (sheets.mode !== "progress")
                return;
            if (!ok && code === "dismissed") {
                sheets.close();
                return;
            }
            if (detail !== "")
                sheets.say(detail);
            sheets.say(ok ? "Operation successful." : "Operation failed.");
            sheets.finish(ok, ok ? "Operation successful." : "Operation failed.",
                ok ? "Click Done to continue."
                   : step === "file" ? "The disk image’s file couldn’t be made there."
                   : code === "denied" ? "Opening a disk image needs an administrator’s leave."
                   : "Click Done to continue.");
        }
        function onUnlockDone(block, ok, code, detail) {
            if (sheets.mode !== "unlock")
                return;
            if (ok || code === "dismissed")
                sheets.close();
            else
                sheets.wrongPassword();
        }
        function onFailed(what, code, detail) {
            const name = win.nameOf(win.item);
            const title = what === "unmount" || what === "eject"
                ? (code === "busy" ? "“" + name + "” couldn’t be " + (what === "eject" ? "ejected" : "unmounted") + " because one or more apps may be using it."
                                   : "“" + name + "” couldn’t be " + (what === "eject" ? "ejected." : "unmounted."))
                : what === "mount" ? "“" + name + "” couldn’t be mounted."
                : "The disk image couldn’t be opened.";
            sheets.ask(win.iconOf, title, code === "busy" ? "Quit the apps using it and try again." : detail,
                [{ text: "OK", role: "ok", primary: true, cancel: true }], null);
        }
        function onAttached(block) {
            win.wanted = block;
            win.settle();
        }
    }
    Connections {
        target: App
        function onImageChosen(file) {
            Disks.attach(file);
        }
        function onFolderChosen(path) {
            sheets.folderChosen(path);
        }
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
        if (sheets.mode === "")
            keys.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))
            return;
        const row = Logic.keys(sections).includes(chosen) ? sections.reduce((found, section) => found ?? section.rows.find(entry => entry.key === chosen), undefined) : undefined;
        switch (event.key) {
        case Qt.Key_Up: move(-1); break;
        case Qt.Key_Down: move(1); break;
        case Qt.Key_Return: case Qt.Key_Enter:
            if (!may.rename)
                return;
            startRename();
            break;
        case Qt.Key_Home: move(-1000); break;
        case Qt.Key_End: move(1000); break;
        case Qt.Key_Left:
            if (row && row.children && !row.shut) toggleShut(chosen);
            break;
        case Qt.Key_Right:
            if (row && row.children && row.shut) toggleShut(chosen);
            break;
        default:
            return;
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
    title: "Disk Utility"

    readonly property Appearance appearance: Appearance {}
    MenuBar { disks: win }

    // What is kept from one launch to the next (not for grabs, which ask
    // for what they show).
    Settings {
        id: kept
        category: "window"
        property bool everything: false
        property bool sidebar: true
    }
    readonly property bool remembers: App.show === "" && !App.all && App.sheet === ""
    property bool ready: false
    onSidebarShownChanged: if (remembers && ready) kept.sidebar = sidebarShown
    property bool grabbed: false
    // For grabs: the device asked for, and a sheet over it, once the disks
    // are read.
    function stage() {
        if (grabbed || remembers || !Disks.ready)
            return;
        grabbed = true;
        if (App.show !== "") {
            const key = Logic.keyOf(all, App.show, App.all);
            if (key !== "")
                chosen = key;
        }
        if (App.sheet === "erase")
            askErase();
        else if (App.sheet === "image")
            askImage();
        else if (App.sheet === "rename")
            startRename();
        else if (App.sheet === "firstaid")
            askFirstAid();
        else if (App.sheet === "info")
            showInfo();
    }
    Connections {
        target: Disks
        function onChanged() {
            Qt.callLater(win.stage);
        }
        function onToolsChanged() {
            Qt.callLater(win.stage);
        }
    }

    Component.onCompleted: {
        if (remembers) {
            everything = kept.everything;
            sidebarShown = kept.sidebar;
        } else {
            everything = App.all;
        }
        ready = true;
        settle();
        takeKeys();
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win);
        }
    }
    // The room on a volume changes without a word from UDisks2: looked at
    // again while the window shows.
    Timer {
        interval: 5000
        repeat: true
        running: win.visible && win.visibility !== Window.Minimized
        onTriggered: Disks.refresh()
    }

    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close); onActivatedAmbiguously: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized); onActivatedAmbiguously: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", Qt.quit); onActivatedAmbiguously: win.act("quit", Qt.quit) }
    Shortcut { sequences: ["Ctrl+N", "Meta+N"]; onActivated: win.act("new", win.askImage); onActivatedAmbiguously: win.act("new", win.askImage) }
    Shortcut { sequences: ["Ctrl+Alt+O", "Meta+Alt+O"]; onActivated: win.act("open", win.openImage); onActivatedAmbiguously: win.act("open", win.openImage) }
    Shortcut { sequences: ["Ctrl+I", "Meta+I"]; onActivated: win.act("info", win.showInfo); onActivatedAmbiguously: win.act("info", win.showInfo) }
    Shortcut { sequences: ["Ctrl+E", "Meta+E"]; onActivated: win.act("eject", () => win.eject(win.chosen)); onActivatedAmbiguously: win.act("eject", () => win.eject(win.chosen)) }
    Shortcut { sequences: ["Ctrl+Shift+E", "Meta+Shift+E"]; onActivated: win.act("erase", win.askErase); onActivatedAmbiguously: win.act("erase", win.askErase) }
    Shortcut { sequences: ["Ctrl+1", "Meta+1"]; onActivated: win.act("volumes", () => win.everything = false); onActivatedAmbiguously: win.act("volumes", () => win.everything = false) }
    Shortcut { sequences: ["Ctrl+2", "Meta+2"]; onActivated: win.act("devices", () => win.everything = true); onActivatedAmbiguously: win.act("devices", () => win.everything = true) }

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

        // Under the toolbar, beside the sidebar: the page, cut to the
        // window's bottom corners (not when drawn off-screen, where a mask
        // draws nothing: a grab's are square).
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

            Flickable {
                id: scroller
                anchors.fill: parent
                contentHeight: page.tableY + page.rows * Look.tableRow + 1 + Look.pad
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                DiskPage {
                    id: page
                    width: body.width
                    height: scroller.contentHeight
                    window: win
                    told: win.told
                }
            }
            // Nothing to show: why.
            Label {
                visible: Disks.ready && win.told === null
                anchors.centerIn: parent
                width: Math.min(parent.width - 60, 360)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Disks.available ? "No disk is selected." : "Disk Utility can’t reach the system’s disk service (UDisks2)."
                style: Theme.text.title3
                font.weight: 700
                color: Look.faint
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
                y: parent.height - 0.5
                width: parent.width
                height: 0.5
                color: Look.hairline
            }
        }
        Toolbar {
            id: toolbar
            width: parent.width
            window: win
        }

        Sheets {
            id: sheets
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
}
