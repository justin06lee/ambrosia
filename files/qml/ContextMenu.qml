import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import Files

// Finder's shortcut menu (a right-click, or a Control-click): the commands
// for what was clicked, drawn in the window as the pop-up menus are, since
// its row of tag colors is more than the shell's menus draw. Rows are
// {text, run, enabled}, {separator: true}, or {tags: true}: Finder's colors,
// each a click to give the tag to everything selected or take it from all;
// pointed at, it shows which it does. A row may have a `submenu` (rows, or
// a function giving them: another of these opens beside it), an `icon` (an
// icon theme name: Open With's apps) or `checked` (Sort By's mark).
Controls.Popup {
    id: menu

    property var items: []
    property int lit: -1
    // The items the tag row acts on, and the tags they all have.
    property var urls: []
    property var common: []
    // With colorOf set, the tag row picks one color (the sidebar's tag
    // menu): the one checked, and chosen(color) on a click.
    property string colorOf: ""
    signal colorChosen(string color)
    readonly property var colors: ["red", "orange", "yellow", "green", "blue", "purple", "gray"]
    readonly property var colored: Tags.all.filter(tag => tag.color !== "").slice(0, 7)
    property string hint: ""
    // Rows with a mark or an icon push every row's words right, as a Mac's.
    readonly property bool marks: items.some(item => item.icon !== undefined || item.checked !== undefined)

    // Submenus. `above` is the menu this one hangs off; `below` the one
    // open beside row `belowRow` of this. A submenu says why it closed:
    // "ran" (a row was chosen: everything closes), "left" (Escape or ←:
    // back to this menu), "above" (this menu closed it), or "" (a press
    // somewhere else: this one closes too unless the pointer is on it).
    property var above: null
    property var below: null
    property int belowRow: -1
    property string why: ""
    readonly property bool pointed: over.hovered
    // Whether the lit row was reached by the arrows: a submenu then waits
    // for →, and takes the keys only when entered that way.
    property bool byKeys: false

    // How tall these rows make it: known at once, where the layout's own
    // height is still the last menu's when a new one is placed.
    readonly property real tall: 2 * padding + items.reduce((sum, item) =>
        sum + (item.separator ? 11 : item.tags ? Finder.contextTagRow : Finder.menuRow), 0)
    // Where it was asked to be; placed again once it has its width.
    property var asked: ({})
    function place() {
        const root = parent;
        if (asked.beside) {
            menu.x = asked.right + implicitWidth + 4 <= root.width ? asked.right : Math.max(4, asked.left - implicitWidth);
            menu.y = Math.max(4, Math.min(asked.y, root.height - tall - 4));
        } else {
            menu.x = Math.max(4, Math.min(asked.x, root.width - implicitWidth - 4));
            menu.y = asked.y + tall + 4 <= root.height ? asked.y : Math.max(4, asked.y - tall);
        }
    }
    function openAt(x, y) {
        common = urls.length > 0 ? Tags.common(urls) : [];
        lit = -1;
        hint = "";
        asked = { x: x, y: y };
        place();
        open();
        Qt.callLater(place);
    }
    // Beside a row of the menu above: to its right, or to its left where
    // the window ends first.
    function openBeside(right, left, y) {
        common = [];
        lit = -1;
        hint = "";
        why = "";
        asked = { beside: true, right: right, left: left, y: y };
        place();
        open();
        Qt.callLater(place);
    }
    function run(i) {
        const item = items[i];
        if (!item || item.separator || item.tags || item.enabled === false)
            return;
        if (item.submenu) {
            openSub(i, false);
            return;
        }
        why = "ran";
        close();
        item.run();
    }
    function openSub(i, byKey) {
        if (belowRow === i && below?.opened) {
            if (byKey) {
                below.forceActiveFocus();
                below.step(1);
            }
            return;
        }
        closeSub();
        if (!below)
            below = Qt.createComponent("ContextMenu.qml").createObject(menu.parent, { above: menu });
        const item = items[i];
        below.urls = [];
        below.colorOf = "";
        below.items = typeof item.submenu === "function" ? item.submenu() : item.submenu;
        const row = repeater.itemAt(i);
        const at = row.mapToItem(menu.parent, 0, 0);
        belowRow = i;
        below.openBeside(menu.x + menu.width - 3, menu.x + 3, at.y - below.padding);
        if (byKey) {
            below.forceActiveFocus();
            below.step(1);
        }
    }
    function closeSub() {
        if (below?.opened) {
            below.why = "above";
            below.close();
        }
        belowRow = -1;
    }
    function subClosed(reason) {
        if (reason === "above")
            return;
        belowRow = -1;
        if (reason === "ran" || (reason === "" && !pointed)) {
            why = "ran";
            close();
        } else {
            rows.forceActiveFocus();
        }
    }
    // The pointer on a row with a submenu opens it after a moment; off it,
    // the submenu stays a little longer, so the pointer can cross other
    // rows on its way there.
    onLitChanged: {
        if (byKeys) {
            wait.stop();
            if (belowRow >= 0 && belowRow !== lit)
                closeSub();
            return;
        }
        const item = items[lit];
        wait.interval = belowRow >= 0 && belowRow !== lit ? 280 : 100;
        if ((item && item.submenu) || belowRow >= 0)
            wait.restart();
    }
    Timer {
        id: wait
        onTriggered: {
            if (!menu.opened)
                return;
            if (menu.below?.opened && menu.below.pointed) {
                menu.lit = menu.belowRow;
                return;
            }
            const item = menu.items[menu.lit];
            if (item && item.submenu && item.enabled !== false)
                menu.openSub(menu.lit, false);
            else if (menu.belowRow >= 0 && menu.lit !== menu.belowRow)
                menu.closeSub();
        }
    }
    onAboutToHide: {
        wait.stop();
        closeSub();
    }
    onClosed: {
        if (above)
            above.subClosed(why);
        why = "";
    }
    function step(by) {
        byKeys = true;
        let i = lit;
        for (let k = 0; k < items.length; ++k) {
            i = (i + by + items.length) % items.length;
            const item = items[i];
            if (!item.separator && !item.tags && item.enabled !== false) {
                lit = i;
                return;
            }
        }
    }

    parent: Controls.Overlay.overlay
    padding: 5
    // A submenu takes the keys only when → enters it (openSub).
    focus: above === null
    // With a submenu open a press on it is a press outside this one: the
    // submenu says what became of it (subClosed).
    closePolicy: belowRow >= 0 ? Controls.Popup.NoAutoClose
        : above ? Controls.Popup.CloseOnPressOutside
        : Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    implicitWidth: Math.max(Finder.contextMenuWidth, rows.implicitWidth + 2 * padding)

    background: Rectangle {
        radius: 8
        color: Finder.menu
        border.width: 0.5
        border.color: Finder.menuRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.5 : 0.2
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            blurMax: 24
        }
    }

    contentItem: Column {
        id: rows
        focus: true
        Keys.onUpPressed: menu.step(-1)
        Keys.onDownPressed: menu.step(1)
        Keys.onReturnPressed: menu.run(menu.lit)
        Keys.onEnterPressed: menu.run(menu.lit)
        Keys.onSpacePressed: menu.run(menu.lit)
        Keys.onRightPressed: {
            if (menu.items[menu.lit]?.submenu && menu.items[menu.lit].enabled !== false)
                menu.openSub(menu.lit, true);
        }
        Keys.onLeftPressed: {
            if (menu.above) {
                menu.why = "left";
                menu.close();
            }
        }
        Keys.onEscapePressed: (event) => {
            if (menu.above) {
                menu.why = "left";
                menu.close();
            } else if (menu.belowRow >= 0) {
                menu.closeSub();
            } else {
                event.accepted = false;
            }
        }

        HoverHandler {
            id: over
        }

        Repeater {
            id: repeater
            model: menu.items
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool separator: modelData.separator === true
                readonly property bool tagRow: modelData.tags === true
                readonly property bool lit: !separator && !tagRow && menu.lit === index
                readonly property bool usable: !separator && !tagRow && modelData.enabled !== false
                width: menu.availableWidth
                implicitWidth: tagRow ? dots.implicitWidth + 24 : label.x + label.implicitWidth + (modelData.submenu ? 34 : 26)
                height: separator ? 11 : tagRow ? Finder.contextTagRow : Finder.menuRow

                Rectangle {
                    visible: row.separator
                    anchors.centerIn: parent
                    width: parent.width - 18
                    height: 1
                    color: Finder.menuRule
                }
                Rectangle {
                    visible: row.lit
                    anchors.fill: parent
                    radius: 5
                    color: Theme.accent.bg
                }
                Glyph {
                    visible: row.modelData.checked === true
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 13
                    color: label.color
                }
                Image {
                    visible: (row.modelData.icon ?? "") !== ""
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    source: visible ? "image://icon/" + row.modelData.icon : ""
                }
                Label {
                    id: label
                    visible: !row.separator && !row.tagRow
                    x: menu.marks ? 31 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text ?? ""
                    color: row.lit ? Theme.accent.fg : row.usable ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                Glyph {
                    visible: row.modelData.submenu !== undefined
                    x: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    name: "pathSeparator"
                    size: 12
                    color: row.lit ? Theme.accent.fg : Theme.color.label.secondary
                }
                HoverHandler {
                    enabled: row.usable
                    onHoveredChanged: {
                        if (hovered) {
                            menu.byKeys = false;
                            menu.lit = row.index;
                        }
                    }
                }
                TapHandler {
                    enabled: row.usable
                    onTapped: menu.run(row.index)
                }

                // Finder's colors, then under them what a click would do.
                Row {
                    id: dots
                    visible: row.tagRow
                    x: 12
                    y: 5
                    spacing: Finder.contextTagGap
                    Repeater {
                        model: menu.colorOf !== "" ? menu.colors : menu.colored
                        Item {
                            id: dot
                            required property var modelData
                            readonly property string color_: menu.colorOf !== "" ? modelData : modelData.color
                            readonly property string name: menu.colorOf !== "" ? "" : modelData.name
                            readonly property bool has: menu.colorOf !== "" ? Tags.colorOf(menu.colorOf) === color_ : menu.common.indexOf(name) >= 0
                            width: Finder.contextTagDot
                            height: width
                            Rectangle {
                                anchors.centerIn: parent
                                width: hover.hovered ? parent.width + 4 : parent.width
                                height: width
                                radius: width / 2
                                color: Finder.tagFill[dot.color_]
                                border.width: 1
                                border.color: Finder.tagRim[dot.color_]
                                Behavior on width { NumberAnimation { duration: 80 } }
                            }
                            Glyph {
                                visible: hover.hovered || dot.has
                                anchors.centerIn: parent
                                name: dot.has && (hover.hovered || menu.colorOf !== "") ? (menu.colorOf !== "" ? "check" : "close") : "plus"
                                size: 11
                                color: "white"
                            }
                            HoverHandler {
                                id: hover
                                onHoveredChanged: {
                                    if (hovered)
                                        menu.lit = -1;
                                    if (hovered)
                                        menu.hint = menu.colorOf !== "" ? dot.color_.charAt(0).toUpperCase() + dot.color_.slice(1)
                                            : (dot.has ? "Remove Tag “" : "Add Tag “") + dot.name + "”";
                                    else if (menu.hint !== "")
                                        menu.hint = "";
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    menu.close();
                                    if (menu.colorOf !== "")
                                        menu.colorChosen(dot.color_);
                                    else
                                        Tags.toggle(menu.urls, dot.name);
                                }
                            }
                        }
                    }
                }
                Label {
                    visible: row.tagRow
                    x: 14
                    y: dots.y + Finder.contextTagDot + 5
                    style: Theme.text.caption
                    text: menu.hint
                    color: Theme.color.label.secondary
                }
            }
        }
    }
}
