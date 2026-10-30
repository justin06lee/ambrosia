import QtQuick
import Ambrosia
import Settings

// A list typed into (Wi-Fi's DNS servers and search domains), as System
// Settings draws it: 24-tall rows in a box four rows tall, and under them a
// bar with + (a new row, typed into at once) and − (the chosen row). While
// it's empty, what the network gives (`fallback`) shows in gray.
Item {
    id: list

    property var items: []
    property var fallback: []
    signal edited(var items)

    property int chosen: -1
    property bool adding: false

    width: parent ? parent.width : Look.boxWidth
    height: Look.editListRows * Look.editListRow + Look.editListBar

    function remove() {
        if (chosen < 0)
            return;
        const next = items.slice();
        next.splice(chosen, 1);
        chosen = -1;
        edited(next);
    }

    Rectangle {
        anchors.fill: parent
        radius: Look.boxRadius
        color: Look.box
    }
    Flickable {
        id: rows
        width: parent.width
        height: Look.editListRows * Look.editListRow
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: column
            width: rows.width
            Repeater {
                model: list.items.length > 0 ? list.items : list.fallback
                Rectangle {
                    required property string modelData
                    required property int index
                    width: column.width
                    height: Look.editListRow
                    color: list.chosen === index && list.items.length > 0 ? Theme.accent.bg : "transparent"
                    Label {
                        x: Look.boxPadding
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * x
                        elide: Text.ElideRight
                        text: parent.modelData
                        color: list.items.length === 0 ? Theme.color.label.secondary
                            : list.chosen === parent.index ? Theme.accent.fg : Theme.color.label.primary
                    }
                    TapHandler {
                        enabled: list.items.length > 0
                        onTapped: list.chosen = parent.index
                    }
                }
            }
            // The row being added.
            Item {
                width: column.width
                height: Look.editListRow
                visible: list.adding
                TextInput {
                    id: input
                    // Return ends the row, not the sheet: it's claimed
                    // before the sheet's shortcut sees it.
                    Keys.onShortcutOverride: (event) => event.accepted = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape
                    Keys.onReturnPressed: focus = false
                    Keys.onEnterPressed: focus = false
                    x: Look.boxPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.text.body.size
                    color: Theme.color.label.primary
                    selectionColor: Theme.accent.highlight
                    renderType: Text.NativeRendering
                    clip: true
                    onEditingFinished: {
                        if (!list.adding)
                            return;
                        list.adding = false;
                        const value = text.trim();
                        text = "";
                        if (value !== "")
                            list.edited(list.items.concat([value]));
                    }
                    Keys.onEscapePressed: {
                        list.adding = false;
                        text = "";
                        focus = false;
                    }
                }
            }
        }
    }
    Rectangle {
        y: rows.height
        width: parent.width
        height: 1
        color: Look.hairline
    }
    // + and −, 9.5 glyphs 25 apart.
    Row {
        x: 4
        y: rows.height + 1
        height: Look.editListBar - 1
        Repeater {
            model: [
                { glyph: "+", act: () => { list.adding = true; list.chosen = -1; input.forceActiveFocus(); }, usable: true },
                { glyph: "−", act: () => list.remove(), usable: list.chosen >= 0 },
            ]
            Item {
                required property var modelData
                width: 25
                height: parent.height
                Label {
                    anchors.centerIn: parent
                    text: parent.modelData.glyph
                    color: parent.modelData.usable ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                TapHandler {
                    enabled: parent.modelData.usable
                    onTapped: parent.modelData.act()
                }
            }
        }
    }
}
