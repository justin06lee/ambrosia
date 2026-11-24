import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia
import "emoji.js" as Emoji

// The emoji picker, as ⌃⌘Space shows on a Mac: a field to search by, the
// emoji in their groups under the ones used lately, and a strip of the
// groups to jump by. The arrows move, Return or a click puts the chosen one
// into the app in front (through the session's input method, input/: no
// clipboard), Escape empties the field and then closes.
Item {
    id: panel

    readonly property Region blurArea: Region { item: panel; radius: Theme.radius.panel }
    readonly property var size: Theme.size.emoji
    property alias query: field.text
    // The chosen emoji, as its place in `flat`.
    property int current: 0
    // Where the pointer last was over the grid, while open.
    property var pointer: undefined

    // Every emoji, read from emoji.js the first time this opens: a list of
    // { title, glyph, items }, an item { emoji, name, key, words }.
    property var groups: []
    readonly property var glyphs: ["face", "paw", "cup", "ball", "car", "bulb", "heart", "flag"]
    function load() {
        if (groups.length > 0) return;
        groups = Emoji.groups.map((group, at) => ({
            title: group[0],
            glyph: glyphs[at],
            items: group[1].split("\n").map(line => {
                const parts = line.split("\t");
                // `key` is the name as it is searched: a flag's has capitals.
                return { emoji: parts[0], name: parts[1], key: parts[1].toLowerCase(), words: parts[2] ?? "" };
            }),
        }));
    }

    // The ones chosen lately, newest first, kept between logins. Until
    // there are enough of them, a few that most people start with.
    readonly property var starters: ["😀", "😂", "🥰", "😎", "🤔", "😭", "👍", "🙏", "👏", "🎉", "❤️", "🔥", "✨", "✅", "👀", "💯", "🙌", "😅"]
    FileView {
        path: Quickshell.statePath("emoji.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: kept
            property list<string> recent: []
        }
    }
    function remember(emoji) {
        kept.recent = [emoji].concat(kept.recent.filter(e => e !== emoji)).slice(0, size.recent);
    }

    // What shows: the groups, or what the field finds. `sections` is
    // { title, glyph, items }; `rows` what the list draws, a heading or one
    // line of the grid; `flat` every emoji showing, in order, each knowing
    // its row and column.
    readonly property string wanted: query.trim().toLowerCase()
    readonly property var sections: {
        if (groups.length === 0) return [];
        if (wanted !== "") return [{ title: "", glyph: "", items: find(wanted) }];
        const byEmoji = {};
        for (const group of groups)
            for (const item of group.items) byEmoji[item.emoji] = item;
        const lately = kept.recent.concat(starters.filter(e => !kept.recent.includes(e)))
            .slice(0, 2 * size.columns).map(e => byEmoji[e]).filter(item => item);
        return [{ title: "Frequently Used", glyph: "clock", items: lately }].concat(groups);
    }
    property var rows: []
    property var flat: []
    // The row each section starts at.
    property var starts: []
    onSectionsChanged: {
        const rows = [], flat = [], starts = [];
        sections.forEach((section, at) => {
            starts.push(rows.length);
            if (section.title !== "") rows.push({ heading: section.title, section: at, cells: [] });
            for (let i = 0; i < section.items.length; i += size.columns) {
                const cells = section.items.slice(i, i + size.columns).map((item, column) => {
                    const cell = { emoji: item.emoji, name: item.name, index: flat.length, row: rows.length, column: column };
                    flat.push(cell);
                    return cell;
                });
                rows.push({ heading: "", section: at, cells: cells });
            }
        });
        panel.flat = flat;
        panel.starts = starts;
        panel.rows = rows;
        current = 0;
        list.positionViewAtBeginning();
    }

    // The emoji a query finds, best first: the name itself, a whole word of
    // the name, a name that starts with it, a word of the name that does,
    // then the same for the words it is found by. Every word typed has to
    // find it.
    function find(q) {
        const parts = q.split(/\s+/).filter(part => part !== "");
        const found = [];
        for (const group of groups) {
            for (const item of group.items) {
                const names = item.key.split(/[\s:,-]+/);
                const words = item.words.split(" ");
                let total = 0;
                for (const part of parts) {
                    let score = 0;
                    if (item.key === part) score = 7;
                    else if (names.includes(part)) score = 6;
                    else if (item.key.startsWith(part)) score = 5;
                    else if (names.some(word => word.startsWith(part))) score = 4;
                    else if (words.includes(part)) score = 3;
                    else if (words.some(word => word.startsWith(part))) score = 2;
                    if (score === 0) {
                        total = 0;
                        break;
                    }
                    total += score;
                }
                if (total > 0) found.push({ item: item, score: total, at: found.length });
            }
        }
        found.sort((a, b) => b.score - a.score || a.at - b.at);
        return found.slice(0, 20 * size.columns).map(entry => entry.item);
    }

    function move(dx, dy) {
        const cell = flat[current];
        if (!cell) return;
        let next = current;
        if (dx !== 0) {
            next = Math.max(0, Math.min(flat.length - 1, current + dx));
        } else {
            // The line of the grid above or below, past any heading.
            let row = cell.row + dy;
            while (rows[row] && rows[row].cells.length === 0) row += dy;
            if (!rows[row]) return;
            const cells = rows[row].cells;
            next = cells[Math.min(cell.column, cells.length - 1)].index;
        }
        current = next;
        list.positionViewAtIndex(flat[next].row, ListView.Contain);
    }
    function accept() {
        const cell = flat[current];
        if (cell) choose(cell.emoji);
    }
    // Into the app in front, once this has closed and the app's field has
    // the keyboard again; where nothing takes text, onto the clipboard.
    function choose(emoji) {
        remember(emoji);
        Popups.close();
        typist.emoji = emoji;
        typist.running = true;
    }
    Process {
        id: typist
        property string emoji: ""
        command: ["/usr/lib/ambrosia/ambrosia-input", "type", emoji]
        onExited: code => {
            if (code !== 0) Quickshell.clipboardText = emoji;
        }
    }
    function jump(section) {
        if (starts[section] === undefined) return;
        list.positionViewAtIndex(starts[section], ListView.Beginning);
        const first = rows.slice(starts[section]).find(row => row.cells.length > 0);
        if (first) current = first.cells[0].index;
    }

    onVisibleChanged: {
        if (!visible) return;
        load();
        field.text = "";
        current = 0;
        pointer = undefined;
        list.positionViewAtBeginning();
        field.forceActiveFocus();
        // A read-only field hides its caret unless told.
        field.cursorVisible = true;
    }

    width: size.columns * size.cell + 2 * size.padding
    height: size.padding + size.field + Theme.space.s2 + list.height + 1 + size.bar

    Glass {
        anchors.fill: parent
        material: "thick"
        radius: Theme.radius.panel
        shadow: Theme.color.shadow.window
    }

    MouseArea {
        anchors.fill: parent
        onPressed: field.forceActiveFocus()
    }

    // The field.
    Rectangle {
        id: well
        x: panel.size.padding
        y: panel.size.padding
        width: parent.width - 2 * panel.size.padding
        height: panel.size.field
        radius: height / 2
        color: Theme.color.fill.secondary

        Icon {
            id: magnifier
            x: Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 15
            color: Theme.color.label.secondary
        }

        TextInput {
            id: field
            anchors { left: magnifier.right; right: parent.right; leftMargin: Theme.space.s1_5; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.body.size
            color: Theme.color.label.primary
            selectionColor: Theme.accent.highlight
            clip: true
            focus: panel.visible
            // Not a field as the input method sees one: while the picker
            // has the keyboard, the session's input method must have no
            // field to write to, or the choice would be typed here as this
            // closes (ambrosia-input writes to the field that is active).
            // Read-only is how Qt is told that; the keys are put in by hand.
            readOnly: true

            Keys.onPressed: event => {
                const command = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
                switch (event.key) {
                case Qt.Key_Backspace:
                case Qt.Key_Delete:
                    if (command) text = "";
                    else if (selectedText !== "") remove(selectionStart, selectionEnd);
                    else if (cursorPosition > 0) remove(cursorPosition - 1, cursorPosition);
                    break;
                case Qt.Key_Escape:
                    if (text !== "") text = "";
                    else Popups.close();
                    break;
                case Qt.Key_Left:
                    panel.move(-1, 0);
                    break;
                case Qt.Key_Right:
                    panel.move(1, 0);
                    break;
                case Qt.Key_Up:
                    panel.move(0, -1);
                    break;
                case Qt.Key_Down:
                    panel.move(0, 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    panel.accept();
                    break;
                default:
                    if (event.matches(StandardKey.Paste)) {
                        write(Quickshell.clipboardText.split("\n")[0]);
                        break;
                    }
                    // A letter, a digit, a space: anything that prints.
                    if (command || (event.modifiers & Qt.AltModifier) || event.text === "" || event.text.charCodeAt(0) < 32 || event.text.charCodeAt(0) === 127)
                        return;
                    write(event.text);
                }
                event.accepted = true;
            }
            function write(letters) {
                if (selectedText !== "") remove(selectionStart, selectionEnd);
                insert(cursorPosition, letters);
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: "Search Emoji"
                color: Theme.color.label.tertiary
            }
        }
    }

    // The grid: a list of its lines, so only the ones in view are drawn.
    ListView {
        id: list
        anchors { top: well.bottom; topMargin: Theme.space.s2 }
        x: panel.size.padding
        width: panel.size.columns * panel.size.cell
        height: panel.size.rows * panel.size.cell
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: panel.rows
        // The group the top line belongs to (the strip marks it).
        readonly property int section: (contentY, panel.rows[Math.max(0, indexAt(0, contentY + 1))]?.section ?? 0)

        delegate: Item {
            id: line
            required property var modelData
            width: list.width
            height: modelData.heading !== "" ? panel.size.heading : panel.size.cell

            Label {
                visible: line.modelData.heading !== ""
                x: Theme.space.s1
                anchors { bottom: parent.bottom; bottomMargin: Theme.space.s1 }
                text: line.modelData.heading.toUpperCase()
                style: Theme.text.caption
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
                color: Theme.color.label.secondary
            }

            Row {
                Repeater {
                    model: line.modelData.cells

                    Item {
                        id: cell
                        required property var modelData
                        readonly property bool chosen: modelData.index === panel.current
                        width: panel.size.cell
                        height: panel.size.cell

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Theme.radius.control
                            color: Theme.color.fill.primary
                            visible: cell.chosen
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.emoji
                            font.family: "Noto Color Emoji"
                            font.pixelSize: panel.size.glyph
                            renderType: Text.QtRendering
                        }
                        // The pointer chooses only by moving: a cell that
                        // scrolls under a resting pointer isn't chosen.
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            function point() {
                                const at = mapToItem(null, mouseX, mouseY);
                                const moved = panel.pointer !== undefined && (at.x !== panel.pointer.x || at.y !== panel.pointer.y);
                                panel.pointer = at;
                                if (moved) panel.current = cell.modelData.index;
                            }
                            onEntered: point()
                            onPositionChanged: point()
                            onClicked: panel.choose(cell.modelData.emoji)
                        }
                    }
                }
            }
        }

        Label {
            visible: panel.rows.length === 0 && panel.groups.length > 0
            anchors.centerIn: parent
            text: "No Emoji Found"
            color: Theme.color.label.secondary
        }
    }

    Rectangle {
        id: rule
        anchors.top: list.bottom
        width: parent.width
        height: 1
        color: Theme.color.separator
    }

    // The groups: a press brings one to the top.
    Row {
        id: strip
        anchors { top: rule.bottom; horizontalCenter: parent.horizontalCenter }
        height: panel.size.bar
        opacity: panel.wanted === "" ? 1 : 0.35

        Repeater {
            model: panel.wanted === "" ? panel.sections : panel.sections.length > 0 ? [{ glyph: "clock" }].concat(panel.groups) : []

            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool here: panel.wanted === "" && list.section === index
                width: list.width / 9
                height: strip.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: Theme.radius.control
                    color: Theme.color.fill.secondary
                    visible: press.containsMouse && panel.wanted === ""
                }
                Icon {
                    anchors.centerIn: parent
                    name: tab.modelData.glyph
                    size: 18
                    color: tab.here ? Theme.accent.bg : Theme.color.label.secondary
                }
                MouseArea {
                    id: press
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: panel.wanted === ""
                    onClicked: panel.jump(tab.index)
                }
            }
        }
    }
}
