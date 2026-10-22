import Quickshell
import QtQuick
import Ambrosia

// One open menu: rows on thick glass. Items come either as `entries`, plain
// objects
//   { text, shortcut, enabled, checked, separator, submenu: [...], action }
// or as `handle`, an app's own menu (QsMenuHandle), whose entries carry
// text, enabled, isSeparator, checkState, hasChildren, shortcut (our
// Quickshell build's DBusMenuItem) and triggered().
Item {
    id: menu

    property int depth: 0
    property var entries: []
    property QsMenuHandle handle: null
    // The highlighted row, by mouse or keyboard; -1 for none.
    property int current: -1

    readonly property int padding: Theme.space.s1_5
    readonly property int minWidth: 236

    implicitWidth: Math.max(minWidth, rows.widest + 2 * padding)
    implicitHeight: rows.implicitHeight + 2 * padding
    width: implicitWidth
    height: implicitHeight

    // A shortcut as a Mac menu shows it. Ours come as text; an app's as its
    // DBusMenu key names, a list per key of the sequence, modifiers first
    // ([["Control", "Shift", "S"]]): modifiers as ⌃⌥⇧⌘ in that order, then
    // the key, arrows and editing keys as their symbols.
    readonly property var modifierGlyphs: ({ Control: "⌃", Alt: "⌥", Shift: "⇧", Super: "⌘", Meta: "⌘" })
    readonly property var keyGlyphs: ({
        Up: "↑", Down: "↓", Left: "←", Right: "→", Return: "↩", Enter: "⌤", Tab: "⇥", Backtab: "⇤",
        Backspace: "⌫", Del: "⌦", Delete: "⌦", Esc: "⎋", Escape: "⎋", PgUp: "⇞", PgDown: "⇟",
        Home: "↖", End: "↘", plus: "+", minus: "-"
    })
    function shortcutText(shortcut) {
        if (!shortcut || typeof shortcut === "string") return shortcut ?? "";
        const keys = [];
        for (let i = 0; i < shortcut.length; i++) {
            const names = Array.from(shortcut[i]);
            const mods = ["⌃", "⌥", "⇧", "⌘"].filter(glyph => names.some(name => modifierGlyphs[name] === glyph));
            const key = names.filter(name => !(name in modifierGlyphs) && name !== "Num").pop() ?? "";
            keys.push(mods.join("") + (keyGlyphs[key] ?? (key.length === 1 ? key.toUpperCase() : key)));
        }
        return keys.join(" ");
    }

    // Keyboard: the Overlay forwards keys to the innermost menu.
    function move(step) {
        const count = repeater.count;
        for (let i = 1; i <= count; i++) {
            const next = (current + step * i + count * 2) % count;
            const row = repeater.itemAt(next);
            if (row && !row.separator && row.enabled) {
                current = next;
                return;
            }
        }
    }
    function activateCurrent() {
        repeater.itemAt(current)?.activate();
    }
    function openCurrent() {
        const row = repeater.itemAt(current);
        if (row?.hasSubmenu) row.openSubmenu(true);
        return !!row?.hasSubmenu;
    }

    QsMenuOpener {
        id: opener
        menu: menu.handle
    }

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.thick.tint
        radius: Theme.radius.popover
        shadow: Theme.color.shadow.popover
    }

    // Clicks between rows land on the menu, not on the Overlay behind it.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: rows
        property real widest: 0
        x: menu.padding
        y: menu.padding
        width: menu.width - 2 * menu.padding

        Repeater {
            id: repeater
            model: menu.handle ? opener.children : menu.entries
            onItemAdded: rows.measure()
            onItemRemoved: rows.measure()

            MenuRow {}
        }

        function measure() {
            let widest = 0;
            for (let i = 0; i < repeater.count; i++) widest = Math.max(widest, repeater.itemAt(i)?.implicitWidth ?? 0);
            rows.widest = widest;
            Qt.callLater(rows.tidy);
        }
        // Apps' menus can start or end on a separator, or have two in a row;
        // a menu only draws the ones between items.
        function tidy() {
            let afterItem = false;
            let pending = null;
            for (let i = 0; i < repeater.count; i++) {
                const row = repeater.itemAt(i);
                if (!row) continue;
                if (row.separator) {
                    row.collapsed = true;
                    if (afterItem && !pending) pending = row;
                } else {
                    if (pending) pending.collapsed = false;
                    pending = null;
                    afterItem = true;
                }
            }
        }
    }

    component MenuRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool separator: modelData.isSeparator === true || modelData.separator === true
        readonly property bool hasSubmenu: modelData.hasChildren === true || Array.isArray(modelData.submenu)
        readonly property bool checked: modelData.checked === true || modelData.checkState === Qt.Checked
        readonly property bool highlighted: menu.current === index && enabled && !separator
        property bool collapsed: false

        enabled: modelData.enabled !== false
        visible: !collapsed
        width: rows.width
        height: collapsed ? 0 : separator ? 2 * Theme.space.s1_5 + 1 : Theme.size.row.compact
        implicitWidth: separator ? 0 : 26 + label.implicitWidth + Theme.space.s3
            + (shortcut.text ? Theme.space.s6 + shortcut.implicitWidth : 0)
            + (hasSubmenu ? Theme.space.s6 + 12 : 0)
        onImplicitWidthChanged: rows.measure()

        function activate() {
            if (separator || !enabled) return;
            if (hasSubmenu) {
                openSubmenu(true);
                return;
            }
            // An app's item reaches the app before its menu closes; ours run
            // after, since they may open something else (a confirmation).
            if (typeof modelData.triggered === "function") {
                modelData.triggered();
                Popups.close();
            } else {
                const action = modelData.action;
                Popups.close();
                action?.();
            }
        }
        // From the keyboard, the submenu starts with its first row selected.
        function openSubmenu(fromKeyboard) {
            Popups.openSubmenu(menu.depth, menu.handle ? modelData : modelData.submenu,
                menu.x + menu.width - menu.padding, menu.y + y, fromKeyboard === true);
        }

        Rectangle {
            visible: row.separator
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.space.s3
            width: parent.width - 2 * x
            height: 1
            color: Theme.color.separator
        }

        Rectangle {
            visible: !row.separator
            anchors.fill: parent
            radius: Theme.radius.row
            color: Theme.accent.bg
            opacity: row.highlighted ? 1 : 0
        }

        Icon {
            visible: row.checked
            name: "check"
            size: 14
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            color: label.color
        }

        Label {
            id: label
            visible: !row.separator
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.text ?? ""
            color: !row.enabled ? Theme.color.label.tertiary
                : row.highlighted ? Theme.accent.fg : Theme.color.label.primary
        }

        Label {
            id: shortcut
            visible: !row.separator && text !== ""
            anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            text: menu.shortcutText(row.modelData.shortcut)
            color: row.highlighted ? Theme.accent.fg : Theme.color.label.tertiary
            opacity: row.highlighted ? 0.8 : 1
        }

        Icon {
            visible: row.hasSubmenu
            name: "right"
            size: 12
            anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            color: row.highlighted ? Theme.accent.fg : Theme.color.label.tertiary
        }

        // Takes the press, so it doesn't reach the Overlay's click-outside.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: true
            onEntered: {
                menu.current = row.separator || !row.enabled ? -1 : row.index;
                if (row.hasSubmenu && row.enabled) row.openSubmenu();
                else Popups.closeSubmenus(menu.depth);
            }
            onClicked: row.activate()
        }
    }
}
