import QtQuick
import Ambrosia
import TextEditor

// The Find bar, between the bars and the text: what's typed is looked for
// as it is typed, Return goes to the next place (Shift the one before),
// the arrows do the same, Done or Escape puts it away. With Replace
// checked a second row replaces the one found, or all.
Rectangle {
    id: bar

    required property var window
    property alias text: search.value
    property alias replacement: replace.value
    property bool replacing: false
    // How many there are of it; -1 before anything is looked for.
    property int matches: -1
    readonly property bool editing: search.input.activeFocus || replace.input.activeFocus
    signal next(int direction)
    signal replaceOne()
    signal replaceEvery()
    signal done()

    function focusField() {
        search.input.forceActiveFocus();
        search.input.selectAll();
    }

    height: replacing ? 58 : 30
    color: Look.bar

    Rectangle { y: parent.height - 0.5; width: parent.width; height: 0.5; color: Look.barLine }

    component Field: Rectangle {
        id: field
        property alias input: entry
        property alias value: entry.text
        property string hint
        property string glyph
        property string note
        signal accepted(int direction)
        height: 22
        radius: 6
        color: Look.field
        border.width: entry.activeFocus ? 3 : 0.5
        border.color: entry.activeFocus ? Theme.accent.highlight : Look.barLine
        Glyph {
            visible: field.glyph !== ""
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            name: field.glyph
            size: 13
            color: Look.titleNote
        }
        // A click anywhere in the field is a click in its text.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: {
                entry.forceActiveFocus();
                entry.cursorPosition = entry.text.length;
            }
        }
        TextInput {
            id: entry
            x: field.glyph !== "" ? 24 : 8
            width: parent.width - x - 8 - (count.visible ? count.width + 6 : 0)
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.body.size
            color: Look.controlText
            selectionColor: Theme.accent.highlight
            selectedTextColor: Look.controlText
            renderType: Text.NativeRendering
            selectByMouse: true
            clip: true
            Keys.onEscapePressed: bar.done()
            Keys.onReturnPressed: (event) => field.accepted(event.modifiers & Qt.ShiftModifier ? -1 : 1)
            Keys.onEnterPressed: (event) => field.accepted(event.modifiers & Qt.ShiftModifier ? -1 : 1)
        }
        Label {
            x: entry.x
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.text === ""
            text: field.hint
            color: Look.titleNote
        }
        Label {
            id: count
            visible: field.note !== ""
            x: parent.width - width - 8
            anchors.verticalCenter: parent.verticalCenter
            text: field.note
            style: Theme.text.footnote
            color: Look.titleNote
        }
    }

    Field {
        id: search
        x: 8
        y: 4
        width: bar.width - 16 - arrows.width - 6 - doneButton.width - 6 - replaceCheck.width - 10
        hint: "Find"
        glyph: "search"
        note: value === "" || bar.matches < 0 ? "" : bar.matches === 0 ? "Not found" : bar.matches + " found"
        onAccepted: (direction) => bar.next(direction)
    }
    Segments {
        id: arrows
        x: search.x + search.width + 6
        y: 4
        width: 52
        height: 22
        segments: [{ key: "back", glyph: "chevronLeft", on: false }, { key: "on", glyph: "chevronRight", on: false }]
        onTapped: (key) => bar.next(key === "back" ? -1 : 1)
    }
    PushButton {
        id: doneButton
        x: arrows.x + arrows.width + 6
        y: 4
        height: 22
        text: "Done"
        onClicked: bar.done()
    }
    // The Replace check box.
    Item {
        id: replaceCheck
        x: doneButton.x + doneButton.width + 10
        y: 4
        width: box.width + 5 + replaceLabel.implicitWidth
        height: 22
        Rectangle {
            id: box
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 3.5
            color: bar.replacing ? Theme.accent.bg : Look.field
            border.width: bar.replacing ? 0 : 0.5
            border.color: Look.glyphDim
            Glyph {
                visible: bar.replacing
                anchors.centerIn: parent
                name: "check"
                size: 11
                color: Theme.accent.fg
            }
        }
        Label {
            id: replaceLabel
            x: box.width + 5
            anchors.verticalCenter: parent.verticalCenter
            text: "Replace"
            color: Look.controlText
        }
        MouseArea {
            anchors.fill: parent
            onClicked: bar.replacing = !bar.replacing
        }
    }

    Field {
        id: replace
        visible: bar.replacing
        x: 8
        y: 32
        width: search.width
        hint: "Replace"
        onAccepted: bar.replaceOne()
    }
    PushButton {
        id: replaceButton
        visible: bar.replacing
        x: replace.x + replace.width + 6
        y: 32
        height: 22
        text: "Replace"
        enabled: bar.matches > 0
        onClicked: bar.replaceOne()
    }
    PushButton {
        visible: bar.replacing
        x: replaceButton.x + replaceButton.width + 6
        y: 32
        height: 22
        text: "All"
        enabled: bar.matches > 0
        onClicked: bar.replaceEvery()
    }
}
