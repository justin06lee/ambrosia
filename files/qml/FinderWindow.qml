import QtQuick
import QtQuick.Window
import Ambrosia
import Files

// One Finder window: the floating sidebar, the toolbar, the folder in the
// chosen view and the path bar, on a frameless window that draws its own
// corners (KWin draws the shadow; App.decorate asks for it).
Window {
    id: win

    required property url startUrl
    property url url: startUrl
    property string view: "list"
    property bool first: false
    // The Columns view's first column. Going somewhere (the sidebar, Back,
    // the path bar) starts the columns there; moving through them doesn't.
    property url columnRoot: startUrl
    onViewChanged: {
        if (view === "column")
            columnRoot = url;
        galleryKeep();
    }
    // View > Show Preview: the pane on the gallery's right, and the Columns
    // view's last column for a file. The pane hides when the window is too
    // narrow for it.
    property bool showPreview: true
    // The preview's Information with Show More open, for every item after.
    property bool previewMore: false
    readonly property bool previewShown: view === "gallery" && showPreview
        && main.width - Finder.previewPane >= Finder.previewPaneMinContent

    // Back and forward, as Finder keeps them per window.
    property var history: [startUrl]
    property int historyIndex: 0
    readonly property bool canGoBack: historyIndex > 0
    readonly property bool canGoForward: historyIndex < history.length - 1

    // Tabs, as Finder's (File ▸ New Tab, ⌘T; TabBar.qml). The window shows
    // one tab, and what it shows is live in the window's own properties;
    // `tabs` holds every tab as it was left ({ key, url, view, history,
    // historyIndex, columnRoot, name, picked }), the one in front put
    // right when another is shown. The bar shows with two tabs or more,
    // or when View ▸ Show Tab Bar says so.
    property var tabs: []
    property int tabAt: 0
    property int tabKeys: 0
    property bool tabBarAlways: false
    readonly property bool tabBarShown: !isPanel && (tabs.length > 1 || tabBarAlways)
    // View ▸ Hide Sidebar, every window's (a panel keeps its): the lights
    // then stand in the toolbar's place and the toolbar starts after them.
    readonly property bool sidebarShown: Prefs.sidebar || isPanel
    // The bars along the bottom, which View shows and hides for every
    // window: the path bar, and under it the status bar (a window only: a
    // panel has its buttons there). A search shows the path bar whatever
    // View says, for where the item found is, as Finder's does.
    readonly property bool pathBarShown: (Prefs.pathBar && !isPanel) || searching
    readonly property bool statusBarShown: Prefs.statusBar && !isPanel
    readonly property int footer: (pathBarShown ? Finder.pathBar : 0) + (statusBarShown ? Finder.statusBar : 0)
    readonly property int tabStrip: tabBarShown ? Finder.tabStrip : 0
    readonly property var tabNames: tabs.map((each, at) => at === tabAt ? placeName : each.name)
    function tabState() {
        return { key: tabs[tabAt]?.key ?? ++tabKeys, url: url, view: view, history: history, historyIndex: historyIndex,
                 columnRoot: columnRoot, name: placeName, picked: selectedUrls() };
    }
    function tabUrl(at) {
        return at === tabAt ? url : tabs[at].url;
    }
    // Every tab as it is now.
    function tabsNow() {
        const all = tabs.slice();
        all[tabAt] = tabState();
        return all;
    }
    function takeTab(tab) {
        if (lookOpen)
            closeLook();
        searchShown(tab.url);
        clearSelection();
        editing = "";
        pending = null;
        history = tab.history;
        historyIndex = tab.historyIndex;
        galleryAt = 0;
        url = tab.url;
        view = tab.view;
        columnRoot = tab.columnRoot;
        if (tab.picked.length > 0)
            selectWhenShown(tab.picked, false);
        focusResults();
    }
    function showTab(at) {
        if (at < 0 || at >= tabs.length || at === tabAt)
            return;
        if (renaming)
            editor?.commit();
        springEnd();
        const all = tabsNow();
        tabs = all;
        tabAt = at;
        takeTab(all[at]);
    }
    function stepTab(by) {
        if (tabs.length > 1)
            showTab((tabAt + by + tabs.length) % tabs.length);
    }
    // A new tab after the one in front, on a folder (none: where new
    // windows start), shown as this one is.
    function newTab(target) {
        if (isPanel)
            return;
        if (renaming)
            editor?.commit();
        springEnd();
        const to = target ? Qt.url(target.toString()) : Prefs.newWindowUrl;
        const all = tabsNow();
        all.splice(tabAt + 1, 0, { key: ++tabKeys, url: to, view: view, history: [to], historyIndex: 0, columnRoot: to, name: "", picked: [] });
        tabs = all;
        tabAt += 1;
        takeTab(all[tabAt]);
    }
    // The last tab's end is the window's.
    function closeTab(at) {
        if (at < 0 || at >= tabs.length)
            return;
        if (tabs.length <= 1) {
            close();
            return;
        }
        const all = tabsNow();
        all.splice(at, 1);
        if (at === tabAt) {
            tabs = all;
            tabAt = Math.min(at, all.length - 1);
            takeTab(all[tabAt]);
        } else {
            if (at < tabAt)
                tabAt -= 1;
            tabs = all;
        }
    }
    function closeOtherTabs(at) {
        if (at !== tabAt)
            showTab(at);
        tabs = [tabState()];
        tabAt = 0;
    }
    function moveTab(from, to) {
        if (from === to || from < 0 || to < 0 || from >= tabs.length || to >= tabs.length)
            return;
        const all = tabsNow();
        const key = all[tabAt].key;
        all.splice(to, 0, all.splice(from, 1)[0]);
        tabs = all;
        tabAt = all.findIndex(each => each.key === key);
    }
    function tabToWindow(at) {
        if (tabs.length < 2)
            return;
        App.openWindow(tabUrl(at));
        closeTab(at);
    }
    function tabMenu(at, x, y) {
        shortcuts.urls = [];
        shortcuts.colorOf = "";
        shortcuts.items = [
            { text: "New Tab", run: () => newTab() },
            { text: "Close Tab", run: () => closeTab(at) },
            { text: "Close Other Tabs", enabled: tabs.length > 1, run: () => closeOtherTabs(at) },
            { text: "Move Tab to New Window", enabled: tabs.length > 1, run: () => tabToWindow(at) },
        ];
        shortcuts.openAt(x, y);
    }
    // The selection: rows → true, the row keys act on, and where a Shift
    // range starts.
    property var selected: ({})
    property int current: -1
    property int anchor: -1
    readonly property int selectedCount: Object.keys(selected).length
    // The selection's items by URL, for views showing other models' rows.
    readonly property var selectedSet: {
        const set = {};
        for (const row of Object.keys(selected))
            set[folder.urlAt(Number(row)).toString()] = true;
        return set;
    }
    readonly property bool hasSelection: selectedCount > 0
    // The item shown large (the gallery, the preview pane): the one the keys
    // act on, or else the first selected; and its roles (name, kind,
    // sizeText, …), read again whenever the selection is set again.
    readonly property int shownRow: selected[current] ? current : hasSelection ? Number(Object.keys(selected)[0]) : -1
    readonly property var shownInfo: shownRow >= 0 && selected ? folder.infoAt(shownRow) : ({})
    // Where New Folder, Paste and renaming work: folders on this computer.
    readonly property bool local: url.toString().startsWith("file:")
    readonly property bool inTrash: url.toString().startsWith("trash:")
    // Applications lists what is installed: nothing there goes to the Trash.
    readonly property bool inApplications: url.toString().startsWith("applications:")
    // Items on this computer, in a folder or found by a search.
    readonly property bool localItems: local || searching

    // Search (⌘F, the toolbar's field): what's typed, the token a
    // suggestion made of it, where it looks and the Kind criterion. While
    // there's something to look for the window shows a search: URL, in one
    // place in the history, just after the folder it started in; with
    // nothing typed it shows that folder again.
    property bool searchOpen: false
    property string searchText: ""
    property var searchToken: null // {mode: "name" or "content", text}
    property string searchScope: "computer"
    property string searchKind: "any"
    property url searchFolder: startUrl
    readonly property bool searching: url.toString().startsWith("search:")
    readonly property bool tagShown: url.toString().startsWith("search:?tag=")
    readonly property bool scopeBarShown: searching && !tagShown
    property bool keepSearch: false
    function openSearch() {
        if (!searchOpen) {
            if (!scopeBarShown) {
                searchFolder = local ? url : Places.place("home");
                // Files' Settings: where a search looks first.
                searchScope = local ? Prefs.startScope() : "computer";
            }
            searchOpen = true;
        }
        toolbar.focusSearch();
    }
    function searchTarget() {
        const words = ((searchToken ? searchToken.text + " " : "") + searchText).trim();
        if (words === "")
            return "";
        let target = "search:?q=" + encodeURIComponent(words);
        if (searchScope === "folder" && searchFolder.toString().startsWith("file:"))
            target += "&in=" + encodeURIComponent(searchFolder.toString());
        if (searchToken)
            target += "&mode=" + searchToken.mode;
        if (searchKind !== "any")
            target += "&kind=" + searchKind;
        return target;
    }
    function backToFolder() {
        keepSearch = true;
        if (canGoBack && history[historyIndex - 1].toString() === searchFolder.toString())
            back();
        else
            replaceWith(searchFolder);
        keepSearch = false;
    }
    function updateSearch() {
        const target = searchTarget();
        if (target === "") {
            if (scopeBarShown)
                backToFolder();
        } else if (scopeBarShown) {
            replaceWith(Qt.url(target));
        } else {
            keepSearch = true;
            go(target);
            keepSearch = false;
        }
    }
    // Shows target in this place in the history.
    function replaceWith(target) {
        if (target.toString() === url.toString())
            return;
        clearSelection();
        editing = "";
        pending = null;
        const h = history.slice();
        h[historyIndex] = target;
        history = h;
        columnRoot = target;
        galleryAt = 0;
        url = target;
    }
    function typeSearch(text) {
        searchText = text;
        updateSearch();
    }
    function chooseSearchToken(mode) {
        searchToken = { mode: mode, text: searchText.trim() };
        searchText = "";
        updateSearch();
    }
    function removeSearchToken() {
        searchToken = null;
        updateSearch();
    }
    function setSearchScope(scope) {
        searchScope = scope;
        Prefs.usedScope(scope);
        updateSearch();
    }
    function setSearchKind(kind) {
        searchKind = kind;
        updateSearch();
    }
    function closeSearch() {
        const shown = scopeBarShown;
        searchOpen = false;
        searchText = "";
        searchToken = null;
        searchKind = "any";
        if (shown)
            backToFolder();
        focusResults();
    }
    function focusResults() {
        pane.forceActiveFocus();
    }
    // Going back or forward to a search puts it back in the field; going
    // anywhere else ends the search.
    function searchShown(target) {
        if (keepSearch)
            return;
        const s = target.toString();
        if (s.startsWith("search:") && !s.startsWith("search:?tag=")) {
            const params = {};
            for (const part of s.slice(s.indexOf("?") + 1).split("&")) {
                const eq = part.indexOf("=");
                if (eq > 0)
                    params[part.slice(0, eq)] = decodeURIComponent(part.slice(eq + 1));
            }
            searchOpen = true;
            searchToken = params.mode ? { mode: params.mode, text: params.q ?? "" } : null;
            searchText = params.mode ? "" : (params.q ?? "");
            searchScope = params["in"] ? "folder" : "computer";
            if (params["in"])
                searchFolder = Qt.url(params["in"]);
            searchKind = params.kind ?? "any";
        } else {
            searchOpen = false;
            searchText = "";
            searchToken = null;
            searchKind = "any";
        }
    }

    readonly property alias model: folder

    // Another app's Open or Save panel (the desktop portal's file chooser,
    // files/src/portal.h): the same window with Cancel and a button that
    // chooses under the folder, a name field over it when saving, and no
    // traffic lights or menus of Files' own. null in a Finder window.
    // {kind: "open" | "folder" | "save" | "saveFiles", title, accept,
    // multiple, name, filters: [{text, value, globs, mimes}], filter}.
    property var panel: null
    readonly property bool isPanel: panel !== null
    readonly property string panelKind: panel?.kind ?? ""
    property int panelFilter: panel?.filter ?? -1
    property string panelName: panel?.name ?? ""
    // The choice: the items' URLs, and the filter that was showing.
    signal panelAccepted(var urls, int filter)
    // What can't be chosen is dimmed, as on a Mac: when opening, a file
    // the app's filter leaves out; when saving or choosing a folder, every
    // file.
    function dimmed(name, isDir) {
        if (!isPanel || isDir)
            return false;
        if (panelKind !== "open")
            return true;
        const filter = panel.filters[panelFilter];
        return filter !== undefined && !App.accepts(name, filter.globs, filter.mimes);
    }
    // One folder selected: the button goes into it when opening files.
    readonly property bool panelOnFolder: selectedCount === 1 && shownRow >= 0 && folder.isDirAt(shownRow)
    readonly property string panelVerb: !isPanel ? "" : panelKind === "open" && panelOnFolder ? "Open" : panel.accept
    readonly property bool panelCanChoose: {
        if (!isPanel)
            return false;
        if (panelKind === "save")
            return local && panelName.trim() !== "" && panelName.indexOf("/") < 0;
        if (panelKind !== "open")
            return local && (!hasSelection || panelOnFolder);
        if (!hasSelection || (selectedCount > 1 && !panel.multiple))
            return false;
        if (panelOnFolder)
            return true;
        for (const row of Object.keys(selected))
            if (folder.isDirAt(Number(row)) || dimmed(folder.nameAt(Number(row)), false))
                return false;
        return true;
    }
    function panelChoose() {
        if (!panelCanChoose || panelAlert.visible)
            return;
        if (panelKind === "save") {
            const name = panelName.trim();
            const target = Qt.url(url.toString().replace(/\/+$/, "") + "/" + encodeURIComponent(name));
            if (App.exists(target))
                panelAlert.ask(name, folder.name);
            else
                panelAccepted([target], panelFilter);
        } else if (panelKind === "open" && panelOnFolder) {
            open(shownRow);
        } else if (panelKind === "open") {
            panelAccepted(selectedUrls(), panelFilter);
        } else {
            panelAccepted([panelOnFolder ? folder.urlAt(shownRow) : url], panelFilter);
        }
    }
    // The keyboard goes back to a save's name, or to the folder.
    function panelFocus() {
        if (nameRow.item)
            nameRow.item.focusField();
        else
            focusResults();
    }
    // A file clicked while saving lends its name, as on a Mac.
    onSelectedChanged: {
        if (panelKind === "save" && selectedCount === 1 && shownRow >= 0 && !folder.isDirAt(shownRow))
            panelName = folder.nameAt(shownRow);
    }

    // A window keeps its active look while one of its menus is open, as on
    // a Mac: the menu bar's menu takes the keyboard, so Qt calls the window
    // inactive. The count clears whenever the window has the keyboard again.
    // (--active draws the first window active, for grabs.)
    property int menusOpen: 0
    // Something of Ambrosia's own is open over the screen (the app menu,
    // the control center): its menu bar says so through the menu named for
    // the app (MenuBar.qml). Yes or no, not a count: a missed word from
    // the bar must not leave the window lit for good.
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || (quickLook.item?.active ?? false) || (first && App.active)
    onActiveChanged: if (active) menusOpen = 0
    readonly property var window: win

    width: 920
    height: 580
    minimumWidth: Finder.minWidth
    minimumHeight: Finder.minHeight
    visible: true
    color: "transparent"
    flags: (isPanel ? Qt.Dialog : Qt.Window) | Qt.FramelessWindowHint
    // Another disk's own folder goes by the disk's name (its folder's is
    // the label, or a string of digits when it has none).
    readonly property var volume: Places.sections.length > 0 && local ? Places.volumeOf(url) : ({})
    // The folder's name, which the toolbar shows; a panel's window goes by
    // what the app called it ("Open", "Save As").
    readonly property string placeName: volume.url !== undefined && volume.url.toString().replace(/\/+$/, "") === url.toString().replace(/\/+$/, "") ? volume.name : folder.name
    title: isPanel && panel.title !== "" ? panel.title : placeName

    readonly property Appearance appearance: Appearance {}

    function go(target) {
        const next = typeof target === "string" ? Qt.url(target) : target;
        if (next.toString() === url.toString())
            return;
        history = history.slice(0, historyIndex + 1).concat([next]);
        historyIndex = history.length - 1;
        show_(next, "");
    }
    function back() {
        if (!canGoBack)
            return;
        const from = url;
        historyIndex -= 1;
        show_(history[historyIndex], from);
    }
    function forward() {
        if (!canGoForward)
            return;
        historyIndex += 1;
        show_(history[historyIndex], "");
    }
    function up() {
        const s = url.toString().replace(/\/+$/, "");
        const cut = s.lastIndexOf("/");
        if (cut < 0 || s.endsWith(":") || s === "file://")
            return;
        // Coming up out of a folder selects it, as Finder does.
        reselect = decodeURIComponent(s.slice(cut + 1));
        go(cut <= 7 && s.startsWith("file://") ? "file:///" : s.slice(0, cut));
    }
    function parentOf(target) {
        const s = target.toString().replace(/\/+$/, "");
        const cut = s.lastIndexOf("/");
        return cut <= 7 && s.startsWith("file://") ? "file:///" : s.slice(0, cut);
    }
    property string reselect: ""
    function show_(target, from) {
        searchShown(target);
        clearSelection();
        editing = "";
        pending = null;
        if (from !== "" && from.toString().startsWith(target.toString()))
            reselect = decodeURIComponent(from.toString().slice(target.toString().replace(/\/+$/, "").length + 1)).split("/")[0];
        columnRoot = target;
        galleryAt = 0;
        url = target;
        if (!folder.loading && reselect === "")
            galleryKeep(); // a folder already read shows at once
    }
    // The Columns view: the window moves to a folder one of its columns
    // shows, and selects item there (or, with first, its first item; or
    // nothing). The columns stay, and so does the place in the history.
    property bool selectFirst: false
    function browse(target, item, first) {
        const next = typeof target === "string" ? Qt.url(target) : target;
        // The folder can show (and select its first item) inside the move.
        const wantFirst = first === true;
        selectFirst = wantFirst;
        if (next.toString() !== url.toString()) {
            clearSelection();
            editing = "";
            pending = null;
            const h = history.slice();
            h[historyIndex] = next;
            history = h;
            url = next;
        }
        if (item)
            selectWhenShown([item], false);
        else if (!wantFirst)
            clearSelection();
        else if (selectFirst && !folder.loading && folder.count > 0)
            firstShown();
    }
    // The gallery always shows an item: when the one it showed goes, the
    // one now in its place; in a folder just shown, the first.
    property int galleryAt: 0
    onCurrentChanged: if (current >= 0) galleryAt = current
    function galleryKeep() {
        if (view === "gallery" && !hasSelection && !pending && folder.count > 0)
            select(Math.min(galleryAt, folder.count - 1), false, false);
    }
    function firstShown() {
        selectFirst = false;
        if (folder.count > 0)
            select(0, false, false);
    }
    // Into the folder selected, or out to the one around this one.
    function columnInto() {
        if (selectedCount === 1 && current >= 0 && folder.isDirAt(current))
            browse(folder.urlAt(current), null, true);
    }
    function columnOut() {
        if (url.toString().replace(/\/+$/, "") !== columnRoot.toString().replace(/\/+$/, ""))
            browse(parentOf(url), url);
    }

    // The Go menu's places, by name.
    function goPlace(name) {
        go(Places.place(name));
    }
    // A disk was ejected: a window showing it goes home.
    Connections {
        target: Places
        function onEjected(volume) {
            const root = volume.toString().replace(/\/+$/, "");
            const at = (win.searching ? win.searchFolder : win.url).toString();
            if (at === root || at.startsWith(root + "/")) {
                if (win.searchOpen)
                    win.closeSearch();
                win.goPlace("home");
            }
        }
    }

    function clearSelection() {
        selected = {};
        current = -1;
        anchor = -1;
    }
    function select(row, extend, toggle) {
        if (row < 0 || row >= folder.count)
            return;
        let next = {};
        if (toggle) {
            next = Object.assign({}, selected);
            if (next[row])
                delete next[row];
            else
                next[row] = true;
            anchor = row;
        } else if (extend && anchor >= 0) {
            for (let i = Math.min(anchor, row); i <= Math.max(anchor, row); ++i)
                next[i] = true;
        } else {
            next[row] = true;
            anchor = row;
        }
        selected = next;
        current = row;
        pane.item.positionAt(row);
    }
    function click(row, modifiers) {
        // A panel that takes one item selects one; a dimmed file, none.
        const many = !isPanel || panel.multiple;
        if (isPanel && panelKind === "open" && row >= 0 && row < folder.count && dimmed(folder.nameAt(row), folder.isDirAt(row)))
            return;
        select(row, many && (modifiers & Qt.ShiftModifier), many && (modifiers & Qt.ControlModifier));
    }
    // With Command held a folder opens in a new tab, as in Finder.
    function open(row, modifiers) {
        const target = folder.urlAt(row);
        if (folder.isDirAt(row) && !isPanel && ((modifiers ?? 0) & (Qt.ControlModifier | Qt.MetaModifier)))
            newTab(target);
        else if (folder.isDirAt(row) && view === "column")
            browse(target, null, true);
        else if (folder.isDirAt(row))
            go(target);
        else if (isPanel)
            panelChoose(); // a double click chooses, if it can be chosen
        else if (App.expands(target))
            run(FileOps.expand([target]), { select: true }); // an archive: what it holds appears beside it, selected
        else
            App.openFile(target);
    }
    function openSelection() {
        for (const row of Object.keys(selected))
            open(Number(row));
    }
    // The selection's items, in row order.
    function selectedUrls() {
        return Object.keys(selected).map(Number).sort((a, b) => a - b).map(row => folder.urlAt(row));
    }

    // File operations (FileOps, through KIO, undoable). What one of them
    // makes in this folder is selected once the folder shows it: its reread
    // can come before the operation ends, or after.
    property var started: ({}) // FileOps id → {select, edit}
    function run(id, then) {
        if (id >= 0)
            started[id] = then ?? {};
    }
    Connections {
        target: FileOps
        function onFinished(id, urls, ok) {
            const then = win.started[id];
            if (then === undefined)
                return;
            delete win.started[id];
            if (ok && then.select && urls.length > 0)
                win.selectWhenShown(Array.from(urls), then.edit === true);
        }
    }
    property var pending: null
    function selectWhenShown(urls, edit) {
        pending = { urls: urls, edit: edit, until: Date.now() + 3000 };
        selectPending();
    }
    function selectPending() {
        if (!pending)
            return;
        const rows = folder.rowsOf(pending.urls).filter(row => row >= 0);
        if (rows.length < pending.urls.length && Date.now() < pending.until)
            return;
        const p = pending;
        pending = null;
        if (rows.length === 0)
            return;
        const next = {};
        for (const row of rows)
            next[row] = true;
        selected = next;
        current = rows[0];
        anchor = rows[0];
        pane.item.positionAt(rows[0]);
        if (p.edit)
            beginRename(rows[0]);
    }

    function newFolder() {
        if (local)
            run(FileOps.newFolder(url), { select: true, edit: true });
    }
    function duplicate() {
        if (hasSelection && local)
            run(FileOps.duplicate(selectedUrls()), { select: true });
    }
    function makeAlias() {
        if (hasSelection && local)
            run(FileOps.makeAlias(selectedUrls()), { select: true });
    }
    function compress() {
        if (hasSelection && local)
            run(FileOps.compress(selectedUrls()), { select: true });
    }
    // Finder's Sort By: names and kinds from A, dates and sizes from the
    // newest and the largest.
    readonly property var sortings: [["name", "Name"], ["kind", "Kind"], ["date", "Date Modified"], ["size", "Size"]]
    function sortBy(column) {
        model.ascending = column === "name" || column === "kind";
        model.sortColumn = column;
    }
    // Open With's rows: the app that opens it anyway first, then the
    // others, then KDE's window for any app at all.
    function openWithEntries() {
        const urls = selectedUrls();
        const apps = App.appsFor(urls[0]);
        const row = (app, first) => ({ text: app.name + (first ? " (default)" : ""), icon: app.icon, run: () => App.openWith(urls, app.id) });
        const rows = apps.length > 0 ? [row(apps[0], true)] : [];
        if (apps.length > 1)
            rows.push({ separator: true }, ...apps.slice(1).map(app => row(app, false)));
        if (rows.length > 0)
            rows.push({ separator: true });
        rows.push({ text: "Other…", icon: "", run: () => App.openWith(urls, "") });
        return rows;
    }
    function trashSelection() {
        if (!hasSelection || inApplications)
            return;
        run(inTrash ? FileOps.putBack(selectedUrls()) : FileOps.trash(selectedUrls()));
    }
    function copySelection() {
        if (hasSelection)
            FileOps.copyToClipboard(selectedUrls());
    }
    function paste(move) {
        if (local)
            run(FileOps.paste(url, move), { select: true });
    }

    // Renaming in place: the item whose name is being edited, and its field.
    property url editing: ""
    property var editor: null
    property bool editingFolder: false
    readonly property bool renaming: editing.toString() !== ""
    function beginRename(row) {
        if (row < 0 || !folder.urlAt(row).toString().startsWith("file:"))
            return;
        select(row, false, false);
        editingFolder = folder.isDirAt(row);
        editing = folder.urlAt(row);
    }
    function renameSelection() {
        if (selectedCount === 1)
            beginRename(Number(Object.keys(selected)[0]));
    }
    // The field is done: text is the new name, or undefined to keep the old.
    function endRename(text) {
        const target = editing;
        editing = "";
        pane.forceActiveFocus();
        if (text === undefined)
            return;
        const rename = (name) => run(FileOps.rename(target, name), { select: true });
        // A document's extension says what opens it: Finder asks before one
        // changes, comes or goes (Files' Settings can turn the asking off),
        // and its default keeps the old one under the new name.
        const extension = (name) => {
            const dot = name.lastIndexOf(".");
            return dot > 0 && dot < name.length - 1 && !/\s/.test(name.slice(dot)) ? name.slice(dot) : "";
        };
        const old = decodeURIComponent(target.toString().replace(/\/$/, "").split("/").pop());
        const from = extension(old), to = extension(text);
        if (editingFolder || !Prefs.warnExtension || from.toLowerCase() === to.toLowerCase()) {
            rename(text);
            return;
        }
        const kept = text.slice(0, text.length - to.length) + from;
        const keep = () => { if (kept !== old) rename(kept); };
        const detail = "If you make this change, your document may open in a different application.";
        if (from === "")
            panelAlert.question("Are you sure you want to add the extension “" + to + "” to the end of the name?", detail,
                                "Add", () => rename(text), "Don’t Add", keep);
        else if (to === "")
            panelAlert.question("Are you sure you want to remove the extension “" + from + "”?", detail,
                                "Remove", () => rename(text), "Keep " + from, keep);
        else
            panelAlert.question("Are you sure you want to change the extension from “" + from + "” to “" + to + "”?", detail,
                                "Use " + to, () => rename(text), "Keep " + from, keep);
    }

    // Dragging items out: a real drag (text/uri-list) that this and other
    // windows, other apps and the Dock's Trash take; whoever takes it does
    // the work.
    property bool dragging: false
    property var dragUrls: []
    Item {
        id: dragItem
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.mimeData: ({ "text/uri-list": win.dragUrls.map(u => u.toString()).join("\r\n") })
        Drag.imageSourceSize: Qt.size(48, 48)
        Drag.onDragFinished: win.dragging = false
    }
    function startDrag(row) {
        if (!selected[row])
            select(row, false, false);
        dragUrls = selectedUrls();
        dragItem.Drag.imageSource = "qrc:/qt/qml/Files/art/" + (folder.isDirAt(row) ? "folder" : "document") + ".svg";
        dragging = true;
        dragItem.Drag.active = true;
    }
    // Items dropped on a folder (dir): moved within a disk, copied across
    // disks or with Option held, as Finder does; on the Trash, trashed.
    // Returns the action taken, for the drag's source.
    function dropOn(urls, dir) {
        urls = Array.from(urls);
        if (urls.length === 0)
            return Qt.IgnoreAction;
        if (dir.toString().startsWith("trash:")) {
            run(FileOps.trash(urls));
            return Qt.MoveAction;
        }
        const copy = (App.modifiers() & Qt.AltModifier) || !FileOps.dropMoves(urls, dir);
        // Items dropped in the folder they're in stay where they are.
        if (!copy) {
            const into = dir.toString().replace(/\/+$/, "");
            urls = urls.filter(u => parentOf(u).replace(/\/+$/, "") !== into);
            if (urls.length === 0)
                return Qt.IgnoreAction;
        }
        const here = dir.toString() === url.toString();
        run(copy ? FileOps.copy(urls, dir) : FileOps.move(urls, dir), { select: here && !springOrigin });
        Qt.callLater(springEnd);
        return copy ? Qt.CopyAction : Qt.MoveAction;
    }

    // Spring-loaded folders, as Finder's: a drag held over a folder (a row,
    // an icon, a place in the sidebar, a folder in the path bar) for a
    // moment makes it blink twice and open in this window, and so on down;
    // once the drag is dropped, leaves the window or is given up, the
    // window is back where the drag found it, its history too.
    property var springOrigin: null
    property string springTarget: ""
    // The blink: the folder under the drag is unlit while this is set.
    property bool springDim: false
    // What takes drops tells where the drag rests: a folder's URL, or "".
    function springOver(target) {
        const to = target ? target.toString() : "";
        springLeave.stop();
        if (to === springTarget)
            return;
        springTarget = to;
        springBlink.stop();
        springDim = false;
        if (to !== "" && to.replace(/\/+$/, "") !== url.toString().replace(/\/+$/, ""))
            springWait.restart();
        else
            springWait.stop();
    }
    // The drag left something that takes drops: unless it comes to rest on
    // another in a moment, it has left the window.
    function springLeft() {
        springOver("");
        if (springOrigin)
            springLeave.restart();
    }
    function springOpen() {
        const to = springTarget;
        springDim = false;
        if (to === "")
            return;
        if (!springOrigin)
            springOrigin = { history: history.slice(), index: historyIndex, root: columnRoot };
        // In columns a folder under the first column opens as the next
        // column, as a click on it would; anything else goes there.
        const root = columnRoot.toString().replace(/\/+$/, "");
        if (view === "column" && !searching && to.startsWith(root + "/"))
            browse(to, null, false);
        else
            go(to);
    }
    function springEnd() {
        springWait.stop();
        springBlink.stop();
        springLeave.stop();
        springDim = false;
        springTarget = "";
        if (!springOrigin)
            return;
        const origin = springOrigin;
        springOrigin = null;
        const from = url;
        history = origin.history;
        historyIndex = origin.index;
        if (history[historyIndex].toString() !== from.toString())
            show_(history[historyIndex], "");
        columnRoot = origin.root;
    }
    onDraggingChanged: if (!dragging) Qt.callLater(springEnd)
    Timer {
        id: springWait
        interval: Finder.springDelay
        onTriggered: springBlink.restart()
    }
    Timer {
        id: springLeave
        interval: 250
        onTriggered: win.springEnd()
    }
    SequentialAnimation {
        id: springBlink
        PropertyAction { target: win; property: "springDim"; value: true }
        PauseAnimation { duration: Finder.springBlink }
        PropertyAction { target: win; property: "springDim"; value: false }
        PauseAnimation { duration: Finder.springBlink }
        PropertyAction { target: win; property: "springDim"; value: true }
        PauseAnimation { duration: Finder.springBlink }
        ScriptAction { script: win.springOpen() }
    }

    // Files' own menus, in a Finder window: a panel belongs to another app.
    Loader {
        active: !win.isPanel
        sourceComponent: Component { MenuBar { finder: win } }
    }

    // Quick Look (Space, ⌘Y): its panel shows the item selected while it's
    // open, and closes when nothing is.
    property bool lookOpen: false
    function toggleLook() {
        if (lookOpen)
            closeLook();
        else if (hasSelection)
            lookOpen = true;
    }
    function closeLook() {
        if (!lookOpen)
            return;
        lookOpen = false;
        win.requestActivate();
    }
    onHasSelectionChanged: if (!hasSelection) Qt.callLater(() => { if (!win.hasSelection) win.lookOpen = false; })
    Loader {
        id: quickLook
        active: win.lookOpen
        sourceComponent: Component {
            QuickLook {
                finder: win
                transientParent: win
                onClosing: win.lookOpen = false
            }
        }
    }
    // The shortcut menu (a right-click): on an item, for the selection (the
    // item selected first if it wasn't); elsewhere, for the folder. x and y
    // are in the window.
    function contextMenu(row, x, y) {
        if (row >= 0 && !selected[row])
            select(row, false, false);
        else if (row < 0)
            clearSelection();
        const one = selectedCount === 1 ? folder.nameAt(shownRow) : "";
        const items = row < 0 ? [
            { text: "New Folder", enabled: local, run: () => newFolder() },
            { separator: true },
            { text: "Get Info", run: () => getInfo() },
            { separator: true },
            { text: FileOps.clipboardCount > 1 ? "Paste " + FileOps.clipboardCount + " Items" : "Paste Item",
              enabled: FileOps.clipboardCount > 0 && local, run: () => paste(false) },
            { separator: true },
            { text: "Sort By", enabled: !searching, submenu: () => sortings.map(([column, title]) =>
                ({ text: title, checked: model.sortColumn === column, run: () => sortBy(column) })) },
        ] : [
            { text: "Open", run: () => openSelection() },
        ].concat(selectedCount === 1 && !isPanel && folder.isDirAt(shownRow) ? [
            { text: "Open in New Tab", run: () => newTab(folder.urlAt(shownRow)) },
        ] : [], [
            { text: "Open With", enabled: !inTrash, submenu: () => openWithEntries() },
            { separator: true },
            { text: inTrash ? "Put Back" : "Move to Trash", enabled: !inApplications, run: () => trashSelection() },
            { separator: true },
            { text: "Get Info", run: () => getInfo() },
            { text: "Rename", enabled: selectedCount === 1 && localItems, run: () => renameSelection() },
            { text: one !== "" ? "Compress “" + one + "”" : "Compress " + selectedCount + " Items", enabled: local && localItems && !inTrash, run: () => compress() },
            { text: "Duplicate", enabled: local, run: () => duplicate() },
            { text: "Make Alias", enabled: local && localItems && !inTrash, run: () => makeAlias() },
            { text: one !== "" ? "Quick Look “" + one + "”" : "Quick Look " + selectedCount + " Items", run: () => { if (!lookOpen) toggleLook(); } },
            { separator: true },
            { text: one !== "" ? "Copy “" + one + "”" : "Copy " + selectedCount + " Items", run: () => copySelection() },
        ].concat(localItems ? [
            { separator: true },
            { tags: true },
            { text: "Tags…", run: () => { tagEditor.urls = selectedUrls(); tagEditor.openAt(x, y); } },
        ] : []));
        shortcuts.urls = row >= 0 ? selectedUrls() : [];
        shortcuts.colorOf = "";
        shortcuts.items = items;
        shortcuts.openAt(x, y);
    }
    // A sidebar tag's menu: its color (Finder's tag color editor).
    // and, as Finder's, its name and its end.
    property string tagRenaming: ""
    function tagMenu(name, x, y) {
        shortcuts.urls = [];
        shortcuts.colorOf = name;
        shortcuts.items = [
            { text: "Rename “" + name + "”", run: () => tagRenaming = name },
            { text: "Delete Tag “" + name + "”…", run: () => panelAlert.question(
                "Are you sure you want to delete the tag “" + name + "”?",
                "Deleting a tag removes it from every item it is attached to.", "Delete Tag",
                () => { if (tagShown && url.toString().indexOf(encodeURIComponent(name)) >= 0) goPlace("home"); Tags.removeTag(name); }) },
            { separator: true },
            { tags: true },
        ];
        shortcuts.openAt(x, y);
    }
    ContextMenu {
        id: shortcuts
        onColorChosen: (color) => Tags.setColor(colorOf, color)
        onClosed: win.requestActivate()
    }
    TagEditor {
        id: tagEditor
    }

    // Get Info (⌘I): a window for each item selected, or for this folder.
    function getInfo() {
        for (const target of hasSelection ? selectedUrls() : [url])
            App.openInfo(target);
    }

    // Runs a command once per key press: the menu bar's shortcut and the
    // window's key handler can both see the same press.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        if (renaming) {
            // ⌘⌫ deletes a word in the name field; it never trashes then.
            if (name === "trash")
                return;
            editor?.commit();
        }
        run();
    }
    function selectAll() {
        const all = {};
        for (let i = 0; i < folder.count; ++i)
            all[i] = true;
        selected = all;
    }

    FolderModel {
        id: folder
        url: win.url
        onLoaded: {
            if (win.reselect !== "") {
                const row = indexOf(win.reselect);
                win.reselect = "";
                if (row >= 0)
                    win.select(row, false, false);
            }
            win.selectPending();
            if (win.selectFirst && !win.hasSelection)
                win.firstShown();
            win.galleryKeep();
            if (!win.shownOnce) {
                win.shownOnce = true;
                if (win.first) {
                    win.pendingExpand = App.expand;
                    win.expandPending();
                    if (App.select !== "")
                        win.select(indexOf(App.select), false, false);
                }
                App.shown(win, loadMs, firstMs);
            }
        }
    }
    property bool shownOnce: false

    // --expand: opens the given folders in place as their rows appear.
    property var pendingExpand: []
    function expandPending() {
        const base = folder.url.toString().replace(/\/+$/, "");
        const left = [];
        for (const path of pendingExpand) {
            let row = -1;
            for (let i = 0; i < folder.count && row < 0; ++i)
                if (decodeURIComponent(folder.urlAt(i).toString()) === decodeURIComponent(base + "/" + path))
                    row = i;
            if (row >= 0)
                folder.setExpanded(row, true, false);
            else
                left.push(path);
        }
        pendingExpand = left;
    }

    // Rows coming and going above the selection (a folder opening in place)
    // move it with its items.
    function shiftRows(first, count) {
        const move = (row) => row >= first ? (count < 0 && row < first - count ? -1 : row + count) : row;
        const next = {};
        for (const key of Object.keys(selected)) {
            const row = move(Number(key));
            if (row >= 0)
                next[row] = true;
        }
        selected = next;
        current = current < 0 ? -1 : move(current);
        anchor = anchor < 0 ? -1 : move(anchor);
    }
    // A reset (a reread changed too much to line up) keeps the selection
    // by its items.
    property var keepSelected: []
    Connections {
        target: folder
        function onRowsInserted(parent, first, last) {
            win.shiftRows(first, last - first + 1);
            if (win.pendingExpand.length > 0)
                Qt.callLater(win.expandPending);
            if (win.pending)
                Qt.callLater(win.selectPending);
        }
        function onRowsRemoved(parent, first, last) {
            win.shiftRows(first, -(last - first + 1));
            Qt.callLater(win.galleryKeep);
        }
        function onModelAboutToBeReset() { win.keepSelected = win.selectedUrls(); }
        function onModelReset() {
            const urls = win.keepSelected;
            win.keepSelected = [];
            win.clearSelection();
            Qt.callLater(win.galleryKeep);
            if (urls.length === 0)
                return;
            const next = {};
            for (const row of folder.rowsOf(urls))
                if (row >= 0)
                    next[row] = true;
            win.selected = next;
            const rows = Object.keys(next).map(Number);
            if (rows.length > 0)
                win.current = win.anchor = Math.min(...rows);
        }
    }

    onVisibleChanged: if (visible) App.decorate(win, Finder.windowRadius)
    Component.onCompleted: {
        tabs = [tabState()];
        if (visible)
            App.decorate(win, Finder.windowRadius);
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Finder.windowRadius
        // Under the sidebar's glass the window is open to the desktop,
        // unless columns have scrolled in under it.
        readonly property bool glassy: sidebar.item?.glassy ?? false
        color: glassy ? "transparent" : Finder.content
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

        Backing {
            visible: frame.glassy
            anchors.fill: parent
            color: Finder.content
            radius: Finder.windowRadius
            hole: Qt.rect(sidebar.x, sidebar.y, sidebar.width, sidebar.height)
            holeRadius: Finder.sidebarRadius
            open: !(pane.item?.underSidebar ?? false)
        }

        Keys.onPressed: (event) => win.keyPressed(event)

        // Under everything that takes drops: a drag anywhere else in the
        // window (the toolbar, beside the columns) is still in the window,
        // which is how a sprung folder knows the drag hasn't left. Nothing
        // can be dropped on it.
        DropArea {
            anchors.fill: parent
            z: -1
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                drag.accept(Qt.IgnoreAction);
                win.springOver("");
            }
            onPositionChanged: (drag) => drag.accept(Qt.IgnoreAction)
            onExited: win.springLeft()
            onDropped: (drop) => {
                drop.accepted = false;
                Qt.callLater(win.springEnd);
            }
        }

        // What Finder's status bar says, for screen readers, and for
        // files/bench/probe.py, which times every app by when it says it.
        Accessible.role: Accessible.Pane
        Accessible.name: folder.loading ? "" : folder.count.toLocaleString(Qt.locale("en_US"), "f", 0) + " items"

        // The window moves by its toolbar's empty space.
        DragHandler {
            target: null
            onActiveChanged: if (active) win.startSystemMove()
        }

        // The sidebar: the floating inset glass panel (macOS 26's Finder)
        // or, with --sidebar flush, the flush one along the window's edge, a
        // stub for now. Both take the window and fill this space, over
        // what scrolls under them.
        Loader {
            id: sidebar
            readonly property bool flush: App.sidebar === "flush"
            active: win.sidebarShown
            visible: win.sidebarShown
            z: 1
            x: flush ? 0 : Finder.sidebarInset
            y: x
            width: flush ? Finder.sidebarInset + Finder.sidebarWidth : Finder.sidebarWidth
            height: parent.height - 2 * y
            sourceComponent: flush ? flushSidebar : floatingSidebar
        }
        Component {
            id: floatingSidebar
            Sidebar { finder: win }
        }
        Component {
            id: flushSidebar
            SidebarFlush { finder: win }
        }

        TrafficLights {
            id: bareLights
            visible: !win.sidebarShown
            z: 1
            x: Finder.lightsX
            y: Finder.lightsY
            window: win.window
        }

        Item {
            id: main
            x: win.sidebarShown ? sidebar.x + sidebar.width : 0
            // A panel keeps a row over the folder for a save's name, and a
            // bar of buttons under it.
            y: win.panelKind === "save" ? Finder.panelName : 0
            width: parent.width - x
            height: parent.height - y - (win.isPanel ? Finder.panelBar : 0)

            Loader {
                id: pane
                anchors.fill: parent
                anchors.bottomMargin: win.footer
                anchors.rightMargin: win.previewShown ? Finder.previewPane : 0
                // The scope bar's rows push the view down (its top stays
                // under the toolbar's glass otherwise).
                anchors.topMargin: (win.scopeBarShown ? 2 * Finder.scopeRow : 0) + win.tabStrip
                focus: true
                // Search results have no columns: the list instead, as in Finder.
                sourceComponent: win.searching && win.view === "column" ? listPane
                    : ({ icon: iconPane, column: columnPane, gallery: galleryPane })[win.view] ?? listPane
            }
            Component {
                id: galleryPane
                GalleryPane { finder: win; focus: true }
            }
            Component {
                id: columnPane
                ColumnPane { finder: win; focus: true; sidebarEdge: main.x }
            }
            Component {
                id: listPane
                ListPane { finder: win; focus: true }
            }
            Component {
                id: iconPane
                IconPane { finder: win; focus: true }
            }

            PreviewPane {
                visible: win.previewShown
                x: parent.width - width
                y: win.tabStrip
                width: Finder.previewPane
                height: parent.height - y
                finder: win
            }

            TabBar {
                visible: win.tabBarShown
                y: Finder.tabTop
                width: parent.width
                finder: win
            }

            ScopeBar {
                visible: win.scopeBarShown
                y: Finder.scopeTop + win.tabStrip
                width: parent.width - (win.previewShown ? Finder.previewPane : 0)
                finder: win
            }

            Toolbar {
                id: toolbar
                x: win.sidebarShown ? Finder.toolbarGap : bareLights.x + bareLights.width + 14
                width: parent.width - x
                finder: win
            }

            Label {
                visible: folder.error !== ""
                anchors.centerIn: pane
                text: folder.error
                color: Theme.color.label.secondary
            }

            PathBar {
                visible: win.pathBarShown
                anchors.bottom: parent.bottom
                anchors.bottomMargin: win.statusBarShown ? Finder.statusBar : 0
                width: parent.width - (win.previewShown ? Finder.previewPane : 0)
                finder: win
            }
            StatusBar {
                visible: win.statusBarShown
                anchors.bottom: parent.bottom
                width: parent.width - (win.previewShown ? Finder.previewPane : 0)
                finder: win
            }
        }

        Loader {
            id: nameRow
            active: win.panelKind === "save"
            x: main.x
            width: main.width
            sourceComponent: Component {
                PanelName {
                    finder: win
                    Component.onCompleted: focusField()
                }
            }
        }
        Loader {
            active: win.isPanel
            x: main.x
            y: parent.height - Finder.panelBar
            width: main.width
            sourceComponent: Component { PanelBar { finder: win } }
        }
        PanelAlert {
            id: panelAlert
            anchors.fill: parent
            z: 2
            finder: win
            onReplaced: win.panelAccepted([Qt.url(win.url.toString().replace(/\/+$/, "") + "/" + encodeURIComponent(name))], win.panelFilter)
        }

        // Resizing by the edges and corners.
        Repeater {
            model: [
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

    // Keyboard, Finder's keys (Ctrl stands for Command, as everywhere in
    // Ambrosia).
    property string typed: ""
    Timer { id: typeReset; interval: 1000; onTriggered: win.typed = "" }

    // On the frame, the focused pane's keys come here unless it took them.
    function keyPressed(event) {
        if (renaming)
            return; // the name field's keys
        // Command is Ctrl (what the Mac-first keyboard gives apps), or
        // Super itself.
        const ctrl = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
        const shift = event.modifiers & Qt.ShiftModifier;
        const alt = event.modifiers & Qt.AltModifier;
        // Type-select: typing a name's start selects it, letters that are
        // shortcuts with Command included (Space stays Quick Look's).
        if (!ctrl && event.text.length === 1 && event.text > " " && event.text !== "\x7f") {
            win.typed += event.text;
            typeReset.restart();
            const row = folder.match(win.typed, 0);
            if (row >= 0)
                win.select(row, false, false);
            event.accepted = true;
            return;
        }
        const columns = win.view === "icon" ? Math.max(1, Math.floor((main.width - Finder.iconLeft) / Finder.iconCell)) : 1;
        switch (event.key) {
        case Qt.Key_Down:
            if (ctrl) win.openSelection();
            else win.select(win.current < 0 ? 0 : Math.min(folder.count - 1, win.current + columns), shift, false);
            break;
        case Qt.Key_Up:
            if (ctrl) win.act("up", win.up);
            else win.select(win.current < 0 ? folder.count - 1 : Math.max(0, win.current - columns), shift, false);
            break;
        case Qt.Key_Right:
            if (win.view === "column") win.columnInto();
            else if (win.view === "icon" || win.view === "gallery") win.select(Math.min(folder.count - 1, win.current + 1), shift, false);
            else if (win.current >= 0) folder.setExpanded(win.current, true, event.modifiers & Qt.AltModifier);
            break;
        case Qt.Key_Left:
            if (win.view === "column") win.columnOut();
            else if (win.view === "icon" || win.view === "gallery") win.select(Math.max(0, win.current - 1), shift, false);
            else if (win.current >= 0 && folder.isExpanded(win.current)) folder.setExpanded(win.current, false, event.modifiers & Qt.AltModifier);
            else if (folder.parentRow(win.current) >= 0) win.select(folder.parentRow(win.current), false, false);
            break;
        case Qt.Key_BracketLeft:
            if (ctrl) win.act("back", win.back);
            break;
        case Qt.Key_BracketRight:
            if (ctrl) win.act("forward", win.forward);
            break;
        case Qt.Key_1:
            if (ctrl) win.act("icons", () => win.view = "icon");
            break;
        case Qt.Key_2:
            if (ctrl) win.act("list", () => win.view = "list");
            break;
        case Qt.Key_3:
            if (ctrl) win.act("columns", () => win.view = "column");
            break;
        case Qt.Key_4:
            if (ctrl) win.act("gallery", () => win.view = "gallery");
            break;
        case Qt.Key_P:
            if (ctrl && shift) win.act("preview", () => win.showPreview = !win.showPreview);
            else if (ctrl && alt) win.act("pathBar", () => Prefs.pathBar = !Prefs.pathBar);
            break;
        case Qt.Key_S:
            // ⌃⌘S on a Mac's keys: Control and Command are both held.
            if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.MetaModifier) && !win.isPanel)
                win.act("sidebar", () => Prefs.sidebar = !Prefs.sidebar);
            break;
        case Qt.Key_Slash:
            if (ctrl && !shift && !alt && !win.isPanel) win.act("statusBar", () => Prefs.statusBar = !Prefs.statusBar);
            break;
        case Qt.Key_O:
            if (ctrl && shift) win.act("documents", () => win.goPlace("documents"));
            else if (ctrl) win.act("open", win.openSelection);
            break;
        case Qt.Key_F:
            if (ctrl && shift) win.act("recents", () => win.goPlace("recents"));
            else if (ctrl) win.act("find", win.openSearch);
            break;
        case Qt.Key_D:
            if (ctrl && shift) win.act("desktop", () => win.goPlace("desktop"));
            else if (ctrl) win.act("duplicate", win.duplicate);
            break;
        case Qt.Key_L:
            if (ctrl && alt) win.act("downloads", () => win.goPlace("downloads"));
            break;
        case Qt.Key_H:
            if (ctrl && shift) win.act("home", () => win.goPlace("home"));
            break;
        case Qt.Key_C:
            if (ctrl && shift) win.act("computer", () => win.goPlace("computer"));
            else if (ctrl) win.act("copy", win.copySelection);
            break;
        case Qt.Key_V:
            if (ctrl && alt) win.act("moveHere", () => win.paste(true));
            else if (ctrl) win.act("paste", () => win.paste(false));
            break;
        case Qt.Key_Z:
            if (ctrl && shift) win.act("redo", FileOps.redo);
            else if (ctrl) win.act("undo", FileOps.undo);
            break;
        case Qt.Key_N:
            if (ctrl && shift) win.act("newFolder", win.newFolder);
            else if (ctrl && !win.isPanel) win.act("new", () => App.openWindow(Prefs.newWindowUrl));
            break;
        case Qt.Key_Comma:
            if (ctrl && !win.isPanel) win.act("settings", () => Preferences.show("Files", "SettingsWindow"));
            else return;
            break;
        case Qt.Key_Backspace:
            if (ctrl && shift) win.act("emptyTrash", FileOps.emptyTrash);
            else if (ctrl) win.act("trash", win.trashSelection);
            else return;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (ctrl) win.act("open", win.openSelection);
            else if (win.isPanel) win.act("choose", win.panelChoose);
            else win.act("rename", win.renameSelection);
            break;
        case Qt.Key_W:
            if (ctrl && shift) win.act("closeWindow", win.close);
            else if (ctrl) win.act("close", () => win.closeTab(win.tabAt));
            break;
        case Qt.Key_T:
            if (ctrl && shift && !win.isPanel) win.act("tabBar", () => win.tabBarAlways = !win.tabBarAlways);
            else if (ctrl) win.act("newTab", () => win.newTab());
            break;
        // ⌃Tab and ⇧⌃Tab, and ⇧⌘] and ⇧⌘[ (which arrive as Ctrl+Page Down
        // and Up): the tab after, the tab before.
        case Qt.Key_Tab:
            if (ctrl) win.act("nextTab", () => win.stepTab(1));
            else return;
            break;
        case Qt.Key_Backtab:
            if (ctrl) win.act("previousTab", () => win.stepTab(-1));
            else return;
            break;
        case Qt.Key_PageDown:
            if (ctrl) win.act("nextTab", () => win.stepTab(1));
            else return;
            break;
        case Qt.Key_PageUp:
            if (ctrl) win.act("previousTab", () => win.stepTab(-1));
            else return;
            break;
        case Qt.Key_Space:
            if (ctrl) return;
            win.act("look", win.toggleLook);
            break;
        case Qt.Key_Y:
            if (ctrl) win.act("look", win.toggleLook);
            else return;
            break;
        case Qt.Key_I:
            if (ctrl) win.act("info", win.getInfo);
            else return;
            break;
        case Qt.Key_A:
            if (ctrl && shift) win.act("applications", () => win.goPlace("applications"));
            else if (ctrl) win.act("all", win.selectAll);
            break;
        case Qt.Key_Period:
        case Qt.Key_Greater:
            if (ctrl && shift) win.act("hidden", () => folder.showHidden = !folder.showHidden);
            break;
        case Qt.Key_Escape:
            if (win.lookOpen) win.closeLook();
            else if (win.searchOpen && (!win.hasSelection || win.view === "gallery")) win.closeSearch();
            else if (win.isPanel) win.close(); // Cancel
            else if (win.view !== "gallery") win.clearSelection();
            break;
        default:
            return;
        }
        event.accepted = true;
    }
}
