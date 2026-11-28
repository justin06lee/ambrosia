import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Ambrosia
import Notes
import "notes.mjs" as Logic

// Notes' window, measured from macOS 27's (Look.qml): the folders down its
// left side, the list of the chosen folder's notes, and the chosen note,
// under a bar 52 tall. Frameless: it draws its own corners and lights (KWin
// draws the shadow; App.decorate asks for it) and is moved by its bar and
// resized by its edges. Store keeps the files and the Editor the text;
// what a note's file says, what it is called and where it is listed is
// notes.mjs's. A note is written a moment after it was last changed, and
// when it is left; one left with nothing in it is not kept.
Window {
    id: win

    // Every note, as the list knows it (notes.mjs entry(), with `key`:
    // folder/id); the folders' names; the sidebar's chosen folder; the
    // chosen note's key and the note itself.
    property var rows: []
    property var folderNames: []
    property string folder: Logic.home
    property string chosen: ""
    property var open: null
    property bool dirty: false
    property string query: ""
    property bool searching: false
    property bool sidebarShown: true
    property bool formatShown: false
    // The Find bar is over the note.
    property bool finding: false
    property bool pinnedShut: false
    // A note being dragged from the list: its key, where the pointer is
    // in the window, and the folder under it that would take the note.
    property string dragged: ""
    property point dragAt: Qt.point(0, 0)
    readonly property string dropFolder: dragged !== "" && sidebarShown ? sidebar.folderAt(dragAt.x, dragAt.y, rowOf(dragged)?.folder ?? "") : ""
    // The folder whose name is being changed in the sidebar.
    property string renaming: ""
    // Now, for the list's dates: looked at again each half minute.
    property double now: Date.now()

    readonly property var side: Logic.sidebar(folderNames, rows)
    readonly property bool found: searching && query.trim() !== ""
    readonly property var listed: found ? Logic.found(Logic.inFolder(rows, Logic.everything), query) : Logic.inFolder(rows, folder)
    readonly property var parts: Logic.sections(listed, now, folder === Logic.deleted && !found ? "edited" : Prefs.sortBy, Prefs.grouped, folder !== Logic.deleted || found)
    // The keys in the order listed.
    readonly property var order: {
        const keys = [];
        for (const part of parts) {
            if (part.key === "pinned" && pinnedShut)
                continue;
            for (const row of part.rows)
                keys.push(row.key);
        }
        return keys;
    }
    readonly property string before: {
        const at = order.indexOf(chosen);
        return at > 0 ? order[at - 1] : "";
    }
    readonly property string folderTitle: side.find(entry => entry.key === folder)?.name ?? Logic.home
    readonly property string countTitle: found ? (listed.length === 0 ? "No Results" : listed.length === 1 ? "1 Found" : listed.length + " Found") : Logic.countText(listed.length)
    readonly property bool inDeleted: chosen.startsWith(Logic.deleted + "/")
    // The note can be changed: one is open, and not a deleted one.
    readonly property bool editable: open !== null && !inDeleted
    readonly property var edit: pane.edit
    readonly property string currentKind: open !== null ? hands.kind : ""
    readonly property bool currentQuote: open !== null && hands.quote
    readonly property bool currentChecked: open !== null && hands.checked
    // The date over the note: when it was changed, or made if the list is
    // in that order.
    readonly property double shownDate: open === null ? 0 : Prefs.sortBy === "created" ? open.created : open.modified

    readonly property real listX: sidebarShown ? Look.sidebarWidth : 0
    readonly property real noteX: listX + Look.listWidth + 1

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
    onActiveChanged: {
        if (active) {
            menusOpen = 0;
            sync();
        } else {
            flush();
        }
    }

    function keyOf(folder, id) {
        return folder + "/" + id;
    }
    function rowOf(key) {
        return rows.find(row => row.key === key) ?? null;
    }
    function makeRow(folder, id, note) {
        const row = Logic.entry(folder, id, note);
        row.key = keyOf(folder, id);
        return row;
    }
    function dateOf(row) {
        return Prefs.sortBy === "created" && row.folder !== Logic.deleted ? row.created : row.modified;
    }
    // An id no note in a folder has yet.
    function freeId(folder, id) {
        let free = id;
        for (let n = 2; rowOf(keyOf(folder, free)) !== null; ++n)
            free = id + "-" + n;
        return free;
    }
    function fresh() {
        const stamp = Date.now();
        return { created: stamp, modified: stamp, pinned: false, deleted: 0, from: "", extra: [], paragraphs: [Logic.paragraph(Prefs.firstLine, "")] };
    }

    // Reads everything kept; what was deleted thirty days ago goes.
    function load() {
        const made = [], stamp = Date.now();
        for (const file of Array.from(Store.read())) {
            const row = makeRow(file.folder, file.id, Logic.parse(file.text, file.stamp));
            row.stamp = file.stamp;
            if (Logic.expired([row], stamp).length > 0)
                Store.remove(file.folder, file.id);
            else
                made.push(row);
        }
        folderNames = Array.from(Store.folders());
        rows = made;
        settle();
    }
    // What is kept, looked at again (the Store says its directories
    // changed, or the window came forward): notes another program made,
    // changed or took away are listed, read again and dropped. The note
    // being written in here stays as it is here until it is saved.
    function sync() {
        if (!ready)
            return;
        const seen = {};
        for (const file of Array.from(Store.stamps()))
            seen[keyOf(file.folder, file.id)] = file;
        const made = [];
        let changed = false, shown = null, gone = false;
        for (const row of rows) {
            const file = seen[row.key];
            delete seen[row.key];
            const mine = row.key === chosen;
            if (row.unsaved || (mine && dirty) || (file !== undefined && file.stamp === row.stamp)) {
                made.push(row);
                continue;
            }
            const note = file !== undefined ? read(row) : null;
            changed = true;
            if (note === null) {
                gone = gone || mine;
                continue;
            }
            const again = makeRow(row.folder, row.id, note);
            again.stamp = file.stamp;
            made.push(again);
            if (mine)
                shown = note;
        }
        for (const key of Object.keys(seen)) {
            const file = seen[key];
            const note = read(file);
            if (note === null)
                continue;
            const row = makeRow(file.folder, file.id, note);
            row.stamp = file.stamp;
            made.push(row);
            changed = true;
        }
        const names = Array.from(Store.folders());
        if (names.join("/") !== folderNames.join("/"))
            folderNames = names;
        if (folder !== Logic.everything && folder !== Logic.deleted && !names.includes(folder))
            folder = Logic.home;
        if (!changed)
            return;
        if (gone) {
            chosen = "";
            open = null;
        }
        rows = made;
        if (shown !== null) {
            // The note in the editor, as it now is: the insertion point
            // where it was, as near as can be.
            const at = pane.edit.cursorPosition, top = pane.scrolled;
            open = shown;
            hands.setParagraphs(shown.paragraphs);
            pane.edit.cursorPosition = Math.min(at, pane.edit.length);
            pane.scrolled = top;
            if (finding)
                pane.recount();
        }
        settle();
    }
    function read(row) {
        const file = Store.one(row.folder, row.id);
        return file.text !== undefined ? Logic.parse(file.text, file.stamp) : null;
    }

    // The note in the editor, written if it was changed.
    function flush() {
        saver.stop();
        if (dirty)
            save();
    }
    function save() {
        const row = rowOf(chosen);
        dirty = false;
        if (!row || !open)
            return;
        open.paragraphs = Array.from(hands.paragraphs());
        open.modified = Date.now();
        keep(row, open, false);
        openChanged();
    }
    // A note put on disk and in the list.
    function keep(row, note, unsaved) {
        if (!unsaved && !Store.write(row.folder, row.id, Logic.serialize(note)))
            console.warn("Notes: couldn’t write", row.key);
        const made = makeRow(row.folder, row.id, note);
        made.unsaved = unsaved;
        // When its file was written, as the disk has it: sync() tells by
        // this what another program changed.
        made.stamp = unsaved ? 0 : Store.stampOf(row.folder, row.id);
        rows = rows.some(entry => entry.key === made.key) ? rows.map(entry => entry.key === made.key ? made : entry) : [made].concat(rows);
    }
    // Leaving the chosen note: written, or forgotten if nothing is in it.
    function leave() {
        flush();
        const row = rowOf(chosen);
        if (row && open && row.folder !== Logic.deleted && Logic.isEmpty(open)) {
            Store.remove(row.folder, row.id);
            rows = rows.filter(entry => entry.key !== row.key);
        }
        chosen = "";
        open = null;
    }
    function show(key, note) {
        chosen = key;
        open = note;
        dirty = false;
        hands.setParagraphs(note ? note.paragraphs : []);
        pane.toTop();
        if (finding)
            pane.recount();
    }
    function choose(key) {
        if (key === chosen)
            return;
        formatShown = false;
        leave();
        const row = rowOf(key);
        const note = row ? read(row) : null;
        if (row && note)
            show(key, note);
        else
            show("", null);
    }
    // What is chosen is always something listed: when it isn't (another
    // folder, a search, a note gone), the first that is.
    function settle() {
        if (chosen !== "" && order.includes(chosen))
            return;
        // (A note being written in that a search no longer finds stays.)
        if (found && chosen !== "" && rowOf(chosen) !== null && pane.edit.activeFocus)
            return;
        if (order.length > 0)
            choose(order[0]);
        else if (chosen !== "")
            choose("");
    }
    function step(by) {
        if (order.length === 0)
            return;
        const at = order.indexOf(chosen);
        choose(order[Math.max(0, Math.min(order.length - 1, at < 0 ? 0 : at + by))]);
    }
    function chooseFolder(key) {
        if (found)
            endSearch();
        if (folder === key)
            return;
        folder = key;
        settle();
    }
    onFolderChanged: if (ready) kept.folder = folder
    onFormatShownChanged: if (!formatShown && !alert.visible) focusNote()
    onListedChanged: Qt.callLater(win.settle)
    onPinnedShutChanged: {
        if (ready)
            kept.pinnedShut = pinnedShut;
        Qt.callLater(win.settle);
    }

    function newNote() {
        endSearch();
        formatShown = false;
        leave();
        if (folder === Logic.deleted)
            folder = Logic.home;
        const target = folder === Logic.everything ? Logic.home : folder;
        const note = fresh();
        const row = { folder: target, id: freeId(target, Logic.newId(note.created)) };
        keep(row, note, true);
        show(keyOf(row.folder, row.id), note);
        focusNote();
    }
    // Into Recently Deleted; from there, for good (asked first).
    function deleteNote(key) {
        const row = rowOf(key);
        if (!row)
            return;
        if (row.folder === Logic.deleted) {
            alert.ask("Are you sure you want to delete this note permanently?", "You can’t undo this action.",
                [{ text: "Delete", role: "delete", primary: true }, { text: "Cancel", role: "cancel", cancel: true }],
                (role) => {
                    if (role === "delete")
                        drop(key, true);
                });
            return;
        }
        drop(key, false);
    }
    function drop(key, forGood) {
        const at = order.indexOf(key);
        const next = at >= 0 ? (order[at + 1] ?? order[at - 1] ?? "") : "";
        const mine = key === chosen;
        if (mine)
            flush();
        const row = rowOf(key);
        if (!row)
            return;
        const note = mine ? open : read(row);
        if (mine) {
            chosen = "";
            open = null;
        }
        Store.remove(row.folder, row.id);
        let left = rows.filter(entry => entry.key !== key);
        if (!forGood && note && !Logic.isEmpty(note)) {
            note.deleted = Date.now();
            note.from = row.folder;
            note.pinned = false;
            rows = left;
            keep({ folder: Logic.deleted, id: freeId(Logic.deleted, row.id) }, note, false);
        } else {
            rows = left;
        }
        if (mine) {
            if (next !== "" && rowOf(next))
                choose(next);
            else
                settle();
        }
    }
    // A deleted note back where it was, or in Notes if that is gone.
    function recover(key) {
        const row = rowOf(key);
        if (!row || row.folder !== Logic.deleted)
            return;
        const mine = key === chosen;
        const note = mine ? open : read(row);
        if (!note)
            return;
        const target = note.from !== "" && folderNames.includes(note.from) && note.from !== Logic.deleted ? note.from : Logic.home;
        note.deleted = 0;
        note.from = "";
        if (mine) {
            chosen = "";
            open = null;
        }
        Store.remove(row.folder, row.id);
        rows = rows.filter(entry => entry.key !== key);
        keep({ folder: target, id: freeId(target, row.id) }, note, false);
        settle();
    }
    function togglePin(key) {
        const row = rowOf(key);
        if (!row || row.folder === Logic.deleted)
            return;
        const mine = key === chosen;
        if (mine)
            flush();
        const note = mine ? open : read(row);
        if (!note)
            return;
        note.pinned = !note.pinned;
        keep(row, note, false);
        if (mine)
            openChanged();
    }
    function moveNote(key, target) {
        const row = rowOf(key);
        if (!row || row.folder === target || !folderNames.includes(target))
            return;
        const mine = key === chosen;
        if (mine)
            flush();
        const note = mine ? open : read(row);
        if (!note)
            return;
        if (row.folder === Logic.deleted) {
            note.deleted = 0;
            note.from = "";
        }
        const moved = { folder: target, id: freeId(target, row.id) };
        Store.remove(row.folder, row.id);
        rows = rows.filter(entry => entry.key !== key);
        keep(moved, note, false);
        if (mine) {
            // It stays open if it is still listed; else the next is.
            chosen = keyOf(moved.folder, moved.id);
            Qt.callLater(win.settle);
        }
    }

    // The drag let go: over a folder, the note goes there (into Recently
    // Deleted as Delete does it).
    function dropDragged() {
        const key = dragged, target = dropFolder;
        dragged = "";
        if (key === "" || target === "")
            return;
        if (target === Logic.deleted)
            deleteNote(key);
        else
            moveNote(key, target);
    }
    function newFolder() {
        endSearch();
        const name = Logic.freeName(folderNames);
        if (!Store.createFolder(name))
            return;
        folderNames = Array.from(Store.folders());
        sidebarShown = true;
        chooseFolder(name);
        renaming = name;
    }
    function renameFolder(from, to) {
        renaming = "";
        const wanted = String(to).trim();
        if (wanted === from || !folderNames.includes(from))
            return;
        const fault = Logic.nameFault(wanted, folderNames.filter(name => name !== from));
        if (fault !== "") {
            alert.ask(wanted === "" ? "A folder needs a name." : "The name “" + wanted + "” can’t be used.", fault === "That name is taken." ? "Choose a different name." : "",
                [{ text: "OK", role: "ok", primary: true, cancel: true }], null);
            return;
        }
        flush();
        if (!Store.renameFolder(from, wanted))
            return;
        const was = chosen;
        rows = rows.map(row => {
            if (row.folder !== from)
                return row;
            const made = Object.assign({}, row);
            made.folder = wanted;
            made.key = keyOf(wanted, row.id);
            return made;
        });
        if (was.startsWith(from + "/"))
            chosen = keyOf(wanted, was.slice(from.length + 1));
        folderNames = Array.from(Store.folders());
        if (folder === from)
            folder = wanted;
    }
    function deleteFolder(name) {
        if (name === Logic.home || name === Logic.deleted || !folderNames.includes(name))
            return;
        const inside = rows.filter(row => row.folder === name);
        const go = () => {
            for (const row of inside)
                drop(row.key, false);
            if (!Store.removeFolder(name))
                console.warn("Notes: couldn’t remove the folder", name);
            folderNames = Array.from(Store.folders());
            if (folder === name)
                chooseFolder(Logic.home);
        };
        if (inside.length === 0) {
            go();
            return;
        }
        alert.ask("Are you sure you want to delete “" + name + "”?", "Its notes will be moved to Recently Deleted.",
            [{ text: "Delete", role: "delete", primary: true }, { text: "Cancel", role: "cancel", cancel: true }],
            (role) => {
                if (role === "delete")
                    go();
            });
    }

    function search() {
        toolbar.focusSearch();
    }
    function endSearch() {
        if (!searching)
            return;
        query = "";
        searching = false;
        if (toolbar.activeFocus || !pane.edit.activeFocus)
            focusList();
    }
    // Finding in the note: the bar over it, with the second row for
    // replacing when asked.
    function find(replacing) {
        if (open === null)
            return;
        formatShown = false;
        finding = true;
        if (replacing === true && editable)
            pane.findBar.replacing = true;
        pane.findBar.focusField();
    }
    function findNext(direction) {
        if (open === null)
            return;
        if (pane.findBar.text === "") {
            find(false);
            return;
        }
        pane.findNext(direction);
    }
    function endFind() {
        finding = false;
        takeKeys();
    }
    // What is selected is what to look for.
    function findSelection() {
        const chosen = open !== null ? pane.edit.selectedText : "";
        if (chosen === "" || chosen.includes("\u2029"))
            return;
        pane.findBar.text = chosen;
    }
    function jump() {
        pane.reveal(true);
    }
    function exportPdf() {
        if (open === null)
            return;
        const title = Logic.titleOf(open);
        Saving.show({
            name: title.replace(/\//g, "-").slice(0, 80),
            extension: ".pdf",
            filter: "PDF (*.pdf)",
            save: (path) => hands.exportPdf(Places.url(path), title),
        }, win);
    }
    // The Print panel, over this window (kit/Printing.qml): the note as a
    // PDF made for the paper chosen there.
    function printOut() {
        if (open === null)
            return;
        const title = Logic.titleOf(open);
        Printing.show({
            title: title,
            make: (file, size) => hands.exportPdf(file, title, size),
            save: () => win.exportPdf(),
        }, win);
    }
    function showSettings() {
        Preferences.show("Notes", "SettingsWindow");
    }

    // What the Format menu, the menu bar and the keys ask of the note.
    function format(what, stay) {
        if (!editable)
            return;
        switch (what) {
        case "bold": hands.setBold(!hands.bold); break;
        case "italic": hands.setItalic(!hands.italic); break;
        case "underline": hands.setUnderline(!hands.underline); break;
        case "strike": hands.setStrike(!hands.strike); break;
        case "quote": hands.setQuote(!hands.quote); break;
        case "checked": hands.setChecked(!hands.checked); break;
        case "in": hands.indent(1); break;
        case "out": hands.indent(-1); break;
        default: hands.setKind(what);
        }
        if (!stay)
            focusNote();
    }
    function clip(what) {
        if (open === null)
            return;
        if (what === "copy")
            hands.copy();
        else if (what === "cut" && editable)
            hands.cut();
        else if (what === "paste" && editable)
            hands.paste();
    }

    // A key that is also a menu item's shortcut is handed to one of the two
    // in turn, the window's own marked ambiguous: either way it runs, once.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const stamp = Date.now();
        if (lastAct.name === name && stamp - lastAct.at < 150)
            return;
        lastAct = { name: name, at: stamp };
        run();
    }
    function takeKeys() {
        if (alert.visible)
            return;
        if (open !== null)
            focusNote();
        else
            focusList();
    }
    function focusNote() {
        if (open !== null)
            pane.edit.forceActiveFocus();
    }
    function focusList() {
        list.take();
    }
    function focusSidebar() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }
    // The sidebar's keys.
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))
            return;
        const at = side.findIndex(entry => entry.key === folder);
        switch (event.key) {
        case Qt.Key_Up: chooseFolder(side[Math.max(0, at - 1)].key); break;
        case Qt.Key_Down: chooseFolder(side[Math.min(side.length - 1, at + 1)].key); break;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            focusList();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (at >= 0 && !side[at].fixed)
                renaming = folder;
            break;
        case Qt.Key_Backspace:
        case Qt.Key_Delete:
            deleteFolder(folder);
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
    // It opens where it was last, as large (../kit/placing.h).
    property string frameName: "main"
    title: "Notes"

    readonly property Appearance appearance: Appearance {}
    MenuBar { notes: win }
    Editor {
        id: hands
        document: pane.edit.textDocument
        monoFamily: Theme.monoFont
        cursorPosition: pane.edit.cursorPosition
        selectionStart: pane.edit.selectionStart
        selectionEnd: pane.edit.selectionEnd
        onEdited: {
            if (win.editable) {
                win.dirty = true;
                saver.restart();
            }
            if (win.finding)
                pane.recount();
        }
    }
    // A note is written a moment after the typing stops.
    Timer {
        id: saver
        interval: 500
        onTriggered: if (win.dirty) win.save()
    }
    Timer {
        interval: 30000
        repeat: true
        running: win.visible
        onTriggered: win.now = Date.now()
    }
    Connections {
        target: Store
        function onChanged() {
            win.sync();
        }
    }
    // What is kept from one launch to the next.
    Settings {
        id: kept
        category: "window"
        property bool sidebar: true
        property string folder: "Notes"
        property bool pinnedShut: false
    }
    property bool ready: false
    onSidebarShownChanged: if (ready) kept.sidebar = sidebarShown
    onClosing: leave()

    Component.onCompleted: {
        sidebarShown = kept.sidebar;
        pinnedShut = kept.pinnedShut;
        folderNames = Array.from(Store.folders());
        folder = kept.folder === Logic.everything || folderNames.includes(kept.folder) ? kept.folder : Logic.home;
        load();
        if (!side.some(entry => entry.key === folder))
            folder = Logic.home;
        ready = true;
        settle();
        takeKeys();
        if (App.show === "format")
            formatShown = true;
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win);
        }
    }

    component Key: Shortcut {
        id: key
        property string name
        property var run
        onActivated: win.act(name, run)
        onActivatedAmbiguously: win.act(name, run)
    }
    Key { sequences: ["Ctrl+N", "Meta+N"]; name: "new"; run: win.newNote }
    Key { sequences: ["Ctrl+Shift+N", "Meta+Shift+N"]; name: "newFolder"; run: win.newFolder }
    Key { sequences: ["Ctrl+W", "Meta+W"]; name: "close"; run: win.close }
    Key { sequences: ["Ctrl+P", "Meta+P"]; name: "print"; run: win.printOut }
    Key { sequences: ["Ctrl+M", "Meta+M"]; name: "minimize"; run: win.showMinimized }
    Key { sequences: ["Ctrl+Q", "Meta+Q"]; name: "quit"; run: () => { win.leave(); Qt.quit(); } }
    Key { sequences: ["Ctrl+,", "Meta+,"]; name: "settings"; run: win.showSettings }
    Key { sequences: ["Ctrl+Alt+F", "Meta+Alt+F"]; name: "search"; run: win.search }
    Key { sequences: ["Ctrl+Alt+S", "Meta+Alt+S"]; name: "folders"; run: () => win.sidebarShown = !win.sidebarShown }
    Key { sequences: ["Ctrl+F", "Meta+F"]; name: "find"; run: () => win.find(false) }
    Key { sequences: ["Ctrl+Shift+F", "Meta+Shift+F"]; name: "replace"; run: () => win.find(true) }
    Key { sequences: ["Ctrl+G", "Meta+G"]; name: "findNext"; run: () => win.findNext(1) }
    Key { sequences: ["Ctrl+Shift+G", "Meta+Shift+G"]; name: "findPrevious"; run: () => win.findNext(-1) }
    Key { sequences: ["Ctrl+E", "Meta+E"]; name: "findSelection"; run: win.findSelection }
    Key { sequences: ["Ctrl+J", "Meta+J"]; name: "jump"; run: win.jump }
    Key { sequences: ["Ctrl+Shift+T", "Meta+Shift+T"]; name: "title"; run: () => win.format("title", false) }
    Key { sequences: ["Ctrl+Shift+H", "Meta+Shift+H"]; name: "heading"; run: () => win.format("heading", false) }
    Key { sequences: ["Ctrl+Shift+J", "Meta+Shift+J"]; name: "subheading"; run: () => win.format("subheading", false) }
    Key { sequences: ["Ctrl+Shift+B", "Meta+Shift+B"]; name: "body"; run: () => win.format("body", false) }
    Key { sequences: ["Ctrl+Shift+M", "Meta+Shift+M"]; name: "mono"; run: () => win.format("mono", false) }
    Key { sequences: ["Ctrl+Shift+7", "Ctrl+&", "Meta+Shift+7", "Meta+&"]; name: "bullet"; run: () => win.format("bullet", false) }
    Key { sequences: ["Ctrl+Shift+8", "Ctrl+*", "Meta+Shift+8", "Meta+*"]; name: "dash"; run: () => win.format("dash", false) }
    Key { sequences: ["Ctrl+Shift+9", "Ctrl+(", "Meta+Shift+9", "Meta+("]; name: "number"; run: () => win.format("number", false) }
    Key { sequences: ["Ctrl+Shift+L", "Meta+Shift+L"]; name: "check"; run: () => win.format("check", false) }
    Key { sequences: ["Ctrl+Shift+U", "Meta+Shift+U"]; name: "checked"; run: () => win.format("checked", false) }
    Key { sequences: ["Ctrl+'", "Meta+'"]; name: "quote"; run: () => win.format("quote", false) }
    Key { sequences: ["Ctrl+B", "Meta+B"]; name: "bold"; run: () => win.format("bold", false) }
    Key { sequences: ["Ctrl+I", "Meta+I"]; name: "italic"; run: () => win.format("italic", false) }
    Key { sequences: ["Ctrl+U", "Meta+U"]; name: "underline"; run: () => win.format("underline", false) }
    // (⌘] and ⌘[ come from the session's keyboard as Forward and Back.)
    Key { sequences: ["Ctrl+]", "Meta+]", "Alt+Right"]; name: "in"; run: () => win.format("in", false) }
    Key { sequences: ["Ctrl+[", "Meta+[", "Alt+Left"]; name: "out"; run: () => win.format("out", false) }

    Item {
        id: frame
        anchors.fill: parent

        Item {
            id: keys
            Keys.onPressed: (event) => win.keyPressed(event)
        }

        Sidebar {
            id: sidebar
            visible: win.sidebarShown
            height: parent.height
            window: win
        }

        // Under the bar, beside the sidebar: the list and the note, cut to
        // the window's bottom corners (not when drawn off-screen, where a
        // mask draws nothing: a grab's are square).
        Item {
            id: body
            x: win.listX
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

            NoteList {
                id: list
                width: Look.listWidth
                height: parent.height
                window: win
            }
            Rectangle {
                x: Look.listWidth
                width: 1
                height: parent.height
                color: Look.divider
            }
            NotePane {
                id: pane
                x: Look.listWidth + 1
                width: parent.width - x
                height: parent.height
                window: win
                hands: hands
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

        // The bar's ground over the list and over the note; the window
        // moves by it, and two clicks zoom it.
        Rectangle {
            x: win.listX
            width: Look.listWidth
            height: Look.toolbar
            topLeftRadius: win.sidebarShown ? 0 : win.corner
            color: Look.listBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onDoubleTapped: win.toggleZoom() }
        }
        Rectangle {
            x: win.noteX - 1
            width: 1
            height: Look.toolbar
            color: Look.divider
        }
        Rectangle {
            x: win.noteX
            width: parent.width - x
            height: Look.toolbar
            topRightRadius: win.corner
            color: Look.noteBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onDoubleTapped: win.toggleZoom() }
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

        FormatMenu {
            anchors.fill: parent
            window: win
            hands: hands
            center: toolbar.formatCenter
        }

        // The note being dragged: its name on a card beside the pointer
        // (below and right of it: what is under the pointer stays seen).
        Rectangle {
            visible: win.dragged !== ""
            x: Math.max(4, Math.min(frame.width - width - 4, win.dragAt.x + 14))
            y: Math.max(4, Math.min(frame.height - height - 4, win.dragAt.y + 12))
            width: Math.min(220, ghost.implicitWidth + 28)
            height: 30
            radius: 8
            color: Look.chosenNoteQuiet
            opacity: 0.9
            border.width: 0.5
            border.color: Look.rim
            Label {
                id: ghost
                x: 14
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: win.rowOf(win.dragged)?.title ?? ""
                font.weight: 700
                color: Look.text
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
}
