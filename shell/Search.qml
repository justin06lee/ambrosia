import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import Ambrosia

// Search (Super+Space, or the magnifier in the menu bar): type to find an
// app, one of System Settings' panes, a file or a folder, or a sum to work
// out; arrows to choose, Return to open it (a sum's answer is copied;
// ⌘Return shows a file in its folder), Escape or a click outside to close. Settings' Spotlight pane says which
// kinds show. It covers the screen while open so the click outside lands here.
PanelWindow {
    id: search

    // The screen this window was made for (its live `screen` changes as it
    // maps and unmaps, which would loop through `visible`).
    required property ShellScreen home
    readonly property bool open: Popups.searchOpen && Popups.searchScreen === home
    property string query: ""
    property int current: 0
    // Where the pointer last was over the rows, while open.
    property var pointer: undefined
    readonly property int rowHeight: Theme.size.row.large
    readonly property int maxRows: 8

    // System Settings' panes, found by name like apps (the names Settings'
    // sidebar shows; a pane this computer lacks just opens Settings).
    readonly property var panes: [
        ["wifi", "Wi‑Fi", "wireless network internet"], ["bluetooth", "Bluetooth", "devices pair"],
        ["network", "Network", "ethernet vpn"], ["battery", "Battery", "energy power low power mode"],
        ["general", "General", ""], ["about", "About", "name version serial"],
        ["softwareupdate", "Software Update", "updates upgrade"], ["storage", "Storage", "disk space"],
        ["datetime", "Date & Time", "clock time zone"], ["language", "Language & Region", "locale formats"],
        ["loginitems", "Login Items", "startup autostart"], ["sharing", "Sharing", "remote login ssh"],
        ["accessibility", "Accessibility", "zoom color filters sticky keys"], ["appearance", "Appearance", "dark light accent"],
        ["dock", "Desktop & Dock", "magnification hot corners"], ["displays", "Displays", "resolution scale night shift brightness"],
        ["menubar", "Menu Bar", "clock control center"], ["wallpaper", "Wallpaper", "background picture"],
        ["notifications", "Notifications", "banners"], ["sound", "Sound", "volume output input alert"],
        ["focus", "Focus", "do not disturb"], ["lockscreen", "Lock Screen", "screen saver sleep"],
        ["privacy", "Privacy & Security", "camera microphone"], ["password", "Login Password", "change password"],
        ["users", "Users & Groups", "accounts"], ["keyboard", "Keyboard", "key repeat shortcuts input sources"],
        ["mouse", "Mouse", "tracking speed scrolling"], ["trackpad", "Trackpad", "tap to click"],
        ["printers", "Printers & Scanners", "print paper"],
    ]

    // How well a query matches: 3 the name starts with it, 2 a word does, 1
    // it's somewhere in the name or keywords, 0 not at all.
    function score(q, name, words) {
        if (name.startsWith(q)) return 3;
        if (words.some(w => w.split(/[\s&_.()\[\]-]+/).some(part => part.startsWith(q)))) return 2;
        return words.some(w => w.includes(q)) ? 1 : 0;
    }

    // Files and folders by name, from Files' index (Files runs from login
    // with every visible name in the home in memory, so an answer takes a few
    // milliseconds): asked a moment after the typing pauses, from two
    // letters on. Each is {path, dir, thumb}, thumb the picture the
    // thumbnail cache already has of it.
    property var files: []
    readonly property string wanted: fold(query.trim())
    readonly property bool wantsFiles: wanted.length >= 2 && !(Settings.searchOff.includes("files") && Settings.searchOff.includes("folders"))
    onWantedChanged: {
        if (wantsFiles) pause.restart();
        else files = [];
    }
    // Lower case without accents, as the index folds names.
    function fold(text) {
        return text.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    }
    // A folder as the line under a name gives it: "Documents › Taxes".
    readonly property string homeDir: Quickshell.env("HOME") ?? ""
    function where(folder) {
        if (folder === homeDir) return homeDir.slice(homeDir.lastIndexOf("/") + 1);
        return (folder.startsWith(homeDir + "/") ? folder.slice(homeDir.length + 1) : folder).split("/").join(" › ");
    }
    function find() {
        if (finder.running || !wantsFiles) return; // one at a time; it asks again when it's back
        finder.asked = wanted;
        finder.running = true;
    }
    Timer {
        id: pause
        interval: 40
        onTriggered: search.find()
    }
    Process {
        id: finder
        property string asked: ""
        command: ["busctl", "--user", "--auto-start=no", "--timeout=2", "--json=short", "call", "org.ambrosia.files", "/org/ambrosia/files",
            "org.ambrosia.Files", "Find", "si", asked, "12"]
        stdout: StdioCollector {
            onStreamFinished: {
                let found = [];
                try {
                    // Two strings each: the path (a folder's ends in a slash), its thumbnail.
                    const items = JSON.parse(text).data[0];
                    for (let i = 0; i + 1 < items.length; i += 2)
                        found.push({ path: items[i].replace(/\/$/, ""), dir: items[i].endsWith("/"), thumb: items[i + 1] });
                } catch (error) {
                    // Files isn't running, or is an older one: no files then.
                }
                if (search.wantsFiles) search.files = found;
            }
        }
        onExited: if (asked !== search.wanted) search.find()
    }

    // Arithmetic typed into the field, worked out: numbers with + - * / % ^
    // and brackets (× ÷ x too). Undefined unless it's a whole sum.
    function calculate(text) {
        const src = text.replace(/[×x]/g, "*").replace(/÷/g, "/").replace(/[\s,]/g, "");
        if (!/^[-+(.\d]/.test(src) || !/\d[-+*/%^]+[-+(.\d]/.test(src) || /[^-+*/%^().\d]/.test(src)) return undefined;
        let at = 0;
        const peek = () => src[at];
        function primary() {
            if (peek() === "(") {
                at++;
                const value = sum();
                if (peek() !== ")") throw 0;
                at++;
                return value;
            }
            const match = /^(\d+\.?\d*|\.\d+)/.exec(src.slice(at));
            if (!match) throw 0;
            at += match[0].length;
            return parseFloat(match[0]);
        }
        function unary() {
            if (peek() === "-") { at++; return -unary(); }
            if (peek() === "+") { at++; return unary(); }
            const base = primary();
            if (peek() === "^") { at++; return Math.pow(base, unary()); }
            return base;
        }
        function product() {
            let value = unary();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = src[at++], right = unary();
                value = op === "*" ? value * right : op === "/" ? value / right : value % right;
            }
            return value;
        }
        function sum() {
            let value = product();
            while (peek() === "+" || peek() === "-") {
                const op = src[at++], right = product();
                value = op === "+" ? value + right : value - right;
            }
            return value;
        }
        try {
            const value = sum();
            if (at !== src.length || !isFinite(value)) return undefined;
            return String(parseFloat(value.toPrecision(12)));
        } catch (e) {
            return undefined;
        }
    }

    // What the query finds, best first: a sum's answer, then apps,
    // Settings' panes and files by how well their names match (an app before
    // a pane before a file that match as well; files keep the order Files
    // gave them, at most six). Each is {name, detail, icon, open()}, with
    // picture where a file has a thumbnail.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        const off = Settings.searchOff;
        const found = [];
        const answer = off.includes("calculator") ? undefined : calculate(q);
        if (answer !== undefined)
            found.push({ name: answer, detail: query.trim() + " =", icon: "accessories-calculator", rank: 9, open: () => { Quickshell.clipboardText = answer; } });
        for (const entry of off.includes("apps") ? [] : DesktopEntries.applications.values) {
            if (entry.noDisplay) continue;
            const name = entry.name.toLowerCase();
            const rank = score(q, name, [name, entry.genericName.toLowerCase()].concat(entry.keywords.map(k => k.toLowerCase())));
            if (rank > 0)
                found.push({ name: entry.name, detail: entry.genericName || entry.comment, icon: entry.icon, rank: rank + 0.5, open: () => Session.launch(entry.id) });
        }
        for (const [id, title, keywords] of off.includes("settings") ? [] : panes) {
            const name = title.toLowerCase().replace("‑", "-");
            const rank = score(q, name, [name].concat(keywords.split(" ")));
            if (rank > 0)
                found.push({ name: title, detail: "System Settings", icon: "org.ambrosia.settings", rank, open: () => Session.settings(id) });
        }
        // The last answer's files that still match what's typed now, so they
        // narrow with each letter until the next answer comes.
        const words = wanted.split(/\s+/);
        let shown = 0;
        for (const file of files) {
            const name = file.path.slice(file.path.lastIndexOf("/") + 1), folded = fold(name);
            if (shown === 6 || off.includes(file.dir ? "folders" : "files") || !words.every(word => folded.includes(word))) continue;
            found.push({ name, detail: where(file.path.slice(0, file.path.lastIndexOf("/"))), picture: file.thumb, path: file.path,
                icon: file.dir ? "ambrosia-folder" : "ambrosia-document", fallback: file.dir ? "folder" : "text-x-generic",
                rank: Math.max(1, score(wanted, folded, [folded])) - 0.25 - shown++ / 1000, open: () => Session.open(file.path) });
        }
        found.sort((a, b) => b.rank - a.rank || a.name.localeCompare(b.name));
        return found.slice(0, maxRows);
    }

    // reveal: show a file in its folder instead of opening it (⌘Return).
    function launch(result, reveal) {
        if (!result) return;
        Popups.searchOpen = false;
        if (reveal && result.path) Session.reveal(result.path);
        else result.open();
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambrosia-search"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: panel; radius: Theme.radius.panel }

    onOpenChanged: {
        query = "";
        field.text = "";
        files = [];
        current = 0;
        pointer = undefined;
        if (open) field.forceActiveFocus();
    }
    onResultsChanged: current = 0

    MouseArea {
        anchors.fill: parent
        onPressed: Popups.searchOpen = false
    }

    Item {
        id: panel
        x: (parent.width - width) / 2
        y: parent.height * 0.22
        width: 640
        height: fieldRow.height + (search.results.length > 0 ? list.height + 1 + 2 * Theme.space.s1_5 : 0)

        Glass {
            anchors.fill: parent
            tint: Theme.color.material.thick.tint
            radius: Theme.radius.panel
            shadow: Theme.color.shadow.window
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: fieldRow
            width: parent.width
            height: 52

            Icon {
                id: magnifier
                x: Theme.space.s4
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 22
                color: Theme.color.label.secondary
            }

            TextInput {
                id: field
                anchors { left: magnifier.right; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                font.family: Theme.uiFont
                font.pixelSize: Theme.text.title2.size + 3
                font.weight: Font.Normal
                color: Theme.color.label.primary
                selectionColor: Theme.accent.highlight
                clip: true
                focus: search.open
                onTextChanged: search.query = text

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        Popups.searchOpen = false;
                        break;
                    case Qt.Key_Down:
                        search.current = Math.min(search.current + 1, search.results.length - 1);
                        break;
                    case Qt.Key_Up:
                        search.current = Math.max(search.current - 1, 0);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        search.launch(search.results[search.current], event.modifiers & (Qt.ControlModifier | Qt.MetaModifier));
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Search"
                    font.pixelSize: field.font.pixelSize
                    font.weight: Font.Normal
                    color: Theme.color.label.tertiary
                }
            }
        }

        Rectangle {
            visible: search.results.length > 0
            anchors.top: fieldRow.bottom
            width: parent.width
            height: 1
            color: Theme.color.separator
        }

        Column {
            id: list
            anchors { top: fieldRow.bottom; topMargin: 1 + Theme.space.s1_5; left: parent.left; right: parent.right; leftMargin: Theme.space.s1_5; rightMargin: Theme.space.s1_5 }

            Repeater {
                model: search.results

                Item {
                    id: result
                    required property var modelData
                    required property int index
                    readonly property bool highlighted: search.current === index
                    width: list.width
                    height: search.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.control
                        color: Theme.accent.bg
                        visible: result.highlighted
                    }

                    IconImage {
                        id: appIcon
                        x: Theme.space.s2
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        source: result.modelData.picture ? "file://" + result.modelData.picture
                            : Quickshell.iconPath(result.modelData.icon, result.modelData.fallback
                                ?? (result.modelData.icon === "accessories-calculator" ? "accessories-calculator-symbolic" : "application-x-executable"))
                    }

                    Column {
                        anchors { left: appIcon.right; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }

                        Label {
                            width: parent.width
                            text: result.modelData.name
                            style: Theme.text.body
                            color: result.highlighted ? Theme.accent.fg : Theme.color.label.primary
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: result.modelData.detail
                            style: Theme.text.caption
                            color: result.highlighted ? Theme.accent.fg : Theme.color.label.secondary
                            opacity: result.highlighted ? 0.8 : 1
                            elide: Text.ElideRight
                        }
                    }

                    // The pointer chooses a row only by moving: a row that
                    // comes up under a resting pointer isn't chosen, or
                    // Return would open it instead of the best match.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        function point() {
                            const at = mapToItem(null, mouseX, mouseY);
                            const moved = search.pointer !== undefined && (at.x !== search.pointer.x || at.y !== search.pointer.y);
                            search.pointer = at;
                            if (moved) search.current = result.index;
                        }
                        onEntered: point()
                        onPositionChanged: point()
                        onClicked: search.launch(result.modelData)
                    }
                }
            }
        }
    }
}
