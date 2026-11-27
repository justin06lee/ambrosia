import QtQuick
import QtQuick.Effects
import Ambrosia
import Notes

// The Format menu that hangs from Aa, as Notes draws it (Look.qml): bold,
// italic, underline and strikethrough in a row, then the kinds a paragraph
// can be, each written as it will look, the current one checked; under a
// rule, Block Quote. A click outside or Escape shuts it. The highlighter
// and its colors are not here: nothing behind them yet.
Item {
    id: menu

    required property var window
    required property var hands
    // The middle of the button it hangs from.
    property real center: 0
    readonly property var kinds: [
        { kind: "title", text: "Title", size: 21, weight: 800 },
        { kind: "heading", text: "Heading", size: 16.5, weight: 700 },
        { kind: "subheading", text: "Subheading", size: 14, weight: 700 },
        { kind: "body", text: "Body", size: 14, weight: 400 },
        { kind: "mono", text: "Monostyled", size: 13, weight: 400, mono: true },
        { kind: "bullet", text: "• Bulleted List", size: 14, weight: 400 },
        { kind: "dash", text: "– Dashed List", size: 14, weight: 400 },
        { kind: "number", text: "1. Numbered List", size: 14, weight: 400 },
    ]
    readonly property real quoteY: Look.formatFirst + kinds.length * Look.formatPitch + 12.5

    visible: window.formatShown
    onVisibleChanged: if (visible) card.forceActiveFocus()

    // Anything else clicked: shut.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.window.formatShown = false
    }

    Rectangle {
        id: card
        x: Math.max(8, Math.min(menu.width - width - 8, menu.center - width / 2))
        y: Look.toolbar + 2
        width: Look.formatWidth
        height: menu.quoteY + 18
        radius: Look.formatRadius
        color: Look.menuFill
        border.width: 0.5
        border.color: Look.menuRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.3
            shadowBlur: 1
            shadowVerticalOffset: 6
            blurMax: 40
        }
        Keys.onEscapePressed: {
            menu.window.formatShown = false;
            menu.window.focusNote();
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // B I U S.
        Repeater {
            model: [
                { what: "bold", text: "B", on: menu.hands.bold },
                { what: "italic", text: "I", on: menu.hands.italic },
                { what: "underline", text: "U", on: menu.hands.underline },
                { what: "strike", text: "S", on: menu.hands.strike },
            ]
            Item {
                id: letter
                required property var modelData
                required property int index
                x: Look.formatMarkX + index * Look.formatMarkPitch - width / 2
                y: Look.formatMarkY - height / 2
                width: 26
                height: 26
                Accessible.role: Accessible.Button
                Accessible.name: modelData.what
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Look.menuLit
                    visible: letter.modelData.on || area.pressed
                }
                Label {
                    anchors.centerIn: parent
                    text: letter.modelData.text
                    font.pixelSize: 16
                    font.weight: letter.modelData.what === "bold" ? 800 : 500
                    font.italic: letter.modelData.what === "italic"
                    font.underline: letter.modelData.what === "underline"
                    font.strikeout: letter.modelData.what === "strike"
                    color: letter.modelData.on ? Look.tint : Look.title
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    onClicked: menu.window.format(letter.modelData.what, true)
                }
            }
        }
        Rectangle {
            x: 13
            y: Look.formatRule
            width: parent.width - 26
            height: 0.5
            color: Look.dark ? "#3affffff" : "#26000000"
        }

        Repeater {
            model: menu.kinds
            Item {
                id: line
                required property var modelData
                required property int index
                readonly property bool current: menu.hands.kind === modelData.kind
                x: 5
                y: Look.formatFirst + index * Look.formatPitch - height / 2
                width: card.width - 10
                height: 28
                Accessible.role: Accessible.MenuItem
                Accessible.name: modelData.text
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Look.menuLit
                    visible: over.hovered
                }
                HoverHandler { id: over }
                Glyph {
                    visible: line.current
                    x: Look.formatCheckX - 5 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 14
                    weight: 2.4
                    color: Look.title
                }
                Label {
                    x: Look.formatTextX - 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.text
                    font.family: line.modelData.mono ? Theme.monoFont : Theme.uiFont
                    font.pixelSize: line.modelData.size
                    font.weight: line.modelData.weight
                    color: Look.title
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        menu.window.formatShown = false;
                        menu.window.format(line.modelData.kind, false);
                    }
                }
            }
        }
        Rectangle {
            x: 13
            y: Look.formatFirst + (menu.kinds.length - 1) * Look.formatPitch + 21
            width: parent.width - 26
            height: 0.5
            color: Look.dark ? "#3affffff" : "#26000000"
        }
        Item {
            id: quoted
            x: 5
            y: menu.quoteY - height / 2
            width: card.width - 10
            height: 28
            Accessible.role: Accessible.MenuItem
            Accessible.name: "Block Quote"
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Look.menuLit
                visible: overQuote.hovered
            }
            HoverHandler { id: overQuote }
            Glyph {
                visible: menu.hands.quote
                x: Look.formatCheckX - 5 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 14
                weight: 2.4
                color: Look.title
            }
            Rectangle {
                x: Look.formatTextX - 5
                anchors.verticalCenter: parent.verticalCenter
                width: 2.5
                height: 15
                radius: 1.25
                color: Look.subtitle
            }
            Label {
                x: Look.formatTextX + 4
                anchors.verticalCenter: parent.verticalCenter
                text: "Block Quote"
                font.pixelSize: 14
                font.weight: 500
                color: Look.title
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    menu.window.formatShown = false;
                    menu.window.format("quote", false);
                }
            }
        }
    }
}
