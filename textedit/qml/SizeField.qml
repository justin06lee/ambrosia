import QtQuick
import Ambrosia
import TextEditor

// The format bar's font size: a field to type a size into (Return sets
// it) and a button beside it that drops the usual sizes.
Rectangle {
    id: field

    property real size: 12
    property real menuHeight: 420
    readonly property bool editing: input.activeFocus
    signal chosen(real size)
    // Typing is over: the keys go back to the text.
    signal done()

    function show(value) {
        return Math.abs(value - Math.round(value)) < 0.005 ? String(Math.round(value)) : String(Math.round(value * 10) / 10);
    }

    height: Look.control
    radius: Look.controlRadius
    color: Look.field
    onSizeChanged: if (!input.activeFocus) input.text = show(size)

    MouseArea {
        width: drop.x
        height: parent.height
        cursorShape: Qt.IBeamCursor
        onPressed: input.forceActiveFocus()
    }
    TextInput {
        id: input
        x: 7
        width: 20
        anchors.verticalCenter: parent.verticalCenter
        text: field.show(field.size)
        font.family: Theme.uiFont
        font.pixelSize: 12
        color: Look.controlText
        selectionColor: Theme.accent.highlight
        selectedTextColor: Look.controlText
        renderType: Text.NativeRendering
        selectByMouse: true
        clip: true
        validator: DoubleValidator { bottom: 1; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
        onActiveFocusChanged: activeFocus ? selectAll() : text = field.show(field.size)
        onAccepted: {
            const value = Number(text.replace(",", "."));
            if (value >= 1)
                field.chosen(value);
            field.done();
        }
        Keys.onEscapePressed: field.done()
    }
    Rectangle {
        id: drop
        x: parent.width - width - 4
        y: 2
        width: 19.5
        height: parent.height - 4
        radius: 4
        color: area.pressed || menu.visible ? Look.controlPressed : Look.fieldButton
        Glyph {
            anchors.centerIn: parent
            name: "chevronDown"
            size: 12
            color: Look.glyph
        }
        MouseArea {
            id: area
            anchors.fill: parent
            onPressed: menu.visible ? menu.close() : menu.openUnder(field)
        }
    }
    PopupMenu {
        id: menu
        items: [9, 10, 11, 12, 13, 14, 18, 24, 36, 48, 64, 72, 96, 144, 288].map(size => ({ text: String(size), value: size }))
        current: field.size
        minimumWidth: 80
        maximumHeight: field.menuHeight
        onChosen: (value) => field.chosen(value)
    }
}
