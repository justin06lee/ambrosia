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
// pointed at, it shows which it does.
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

    function openAt(x, y) {
        common = urls.length > 0 ? Tags.common(urls) : [];
        lit = -1;
        hint = "";
        const root = parent;
        menu.x = Math.max(4, Math.min(x, root.width - implicitWidth - 4));
        menu.y = y + implicitHeight + 4 <= root.height ? y : Math.max(4, y - implicitHeight);
        open();
    }
    function run(i) {
        const item = items[i];
        if (!item || item.separator || item.tags || item.enabled === false)
            return;
        close();
        item.run();
    }
    function step(by) {
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
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
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

        Repeater {
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
                implicitWidth: tagRow ? dots.implicitWidth + 24 : label.implicitWidth + 40
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
                Label {
                    id: label
                    visible: !row.separator && !row.tagRow
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text ?? ""
                    color: row.lit ? Theme.accent.fg : row.usable ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                HoverHandler {
                    enabled: row.usable
                    onHoveredChanged: if (hovered) menu.lit = row.index
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
