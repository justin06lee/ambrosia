import QtQuick
import Ambrosia
import Notes

// The Find bar, over the note (as TextEdit's FindBar.qml; a Mac's was not
// measured: it can't be opened there from behind): what's typed is looked
// for as it is typed, Return goes to the next place (Shift the one
// before), the arrows do the same, Done or Escape puts it away. With
// Replace checked a second row replaces the one found, or all.
Rectangle {
    id: bar

    required property var window
    property alias text: search.value
    property alias replacement: replace.value
    property bool replacing: false
    // How many there are of it; -1 before anything is looked for.
    property int matches: -1
    readonly property bool editing: search.input.activeFocus || replace.input.activeFocus
    readonly property bool can: window.editable
    signal next(int direction)
    signal replaceOne()
    signal replaceEvery()
    signal done()

    function focusField() {
        search.input.forceActiveFocus();
        search.input.selectAll();
    }

    height: replacing && can ? 58 : 30
    color: Look.noteBar

    Rectangle { y: parent.height - 0.5; width: parent.width; height: 0.5; color: Look.hairline }

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
        border.width: entry.activeFocus ? 2.5 : 0.5
        border.color: entry.activeFocus ? Look.tint : Look.rule
        Accessible.role: Accessible.EditableText
        Accessible.name: hint
        Glyph {
            visible: field.glyph !== ""
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            name: field.glyph
            size: 13
            color: Look.note
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
            font.pixelSize: 13
            color: Look.text
            selectionColor: Look.selection
            selectedTextColor: Look.text
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
            color: Look.faint
        }
        Label {
            id: count
            visible: field.note !== ""
            x: parent.width - width - 8
            anchors.verticalCenter: parent.verticalCenter
            text: field.note
            style: Theme.text.footnote
            color: Look.note
        }
    }

    // One of the two arrows: half of a rounded pair.
    component Arrow: Rectangle {
        id: arrow
        property string glyph
        property string name
        signal tapped()
        width: 26
        height: 22
        color: press.pressed ? (Look.dark ? "#26ffffff" : "#d3d3d3") : (Look.dark ? "#13ffffff" : "#e4e4e4")
        opacity: enabled ? 1 : 0.45
        Accessible.role: Accessible.Button
        Accessible.name: name
        Glyph {
            anchors.centerIn: parent
            name: arrow.glyph
            size: 12
            color: Look.text
        }
        MouseArea {
            id: press
            anchors.fill: parent
            onClicked: arrow.tapped()
        }
    }

    Field {
        id: search
        x: 8
        y: 4
        width: bar.width - 16 - arrows.width - 6 - doneButton.width - 6 - (replaceCheck.visible ? replaceCheck.width + 10 : 0)
        hint: "Find"
        glyph: "search"
        note: value === "" || bar.matches < 0 ? "" : bar.matches === 0 ? "Not found" : bar.matches + " found"
        onAccepted: (direction) => bar.next(direction)
    }
    Row {
        id: arrows
        x: search.x + search.width + 6
        y: 4
        spacing: 1
        Arrow {
            glyph: "chevronLeft"
            name: "Previous"
            topLeftRadius: 6
            bottomLeftRadius: 6
            enabled: bar.matches > 0
            onTapped: bar.next(-1)
        }
        Arrow {
            glyph: "chevronRight"
            name: "Next"
            topRightRadius: 6
            bottomRightRadius: 6
            enabled: bar.matches > 0
            onTapped: bar.next(1)
        }
    }
    PushButton {
        id: doneButton
        x: arrows.x + arrows.width + 6
        y: 4
        height: 22
        text: "Done"
        onClicked: bar.done()
    }
    // The Replace check box (not over a note that can't be changed).
    Item {
        id: replaceCheck
        visible: bar.can
        x: doneButton.x + doneButton.width + 10
        y: 4
        width: box.width + 5 + replaceLabel.implicitWidth
        height: 22
        Accessible.role: Accessible.CheckBox
        Accessible.name: "Replace"
        Rectangle {
            id: box
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 3.5
            color: bar.replacing ? Look.tint : Look.field
            border.width: bar.replacing ? 0 : 0.5
            border.color: Look.ring
            Glyph {
                visible: bar.replacing
                anchors.centerIn: parent
                name: "check"
                size: 11
                weight: 2.6
                color: Look.dark ? "#1c1c1c" : "#ffffff"
            }
        }
        Label {
            id: replaceLabel
            x: box.width + 5
            anchors.verticalCenter: parent.verticalCenter
            text: "Replace"
            color: Look.text
        }
        MouseArea {
            anchors.fill: parent
            onClicked: bar.replacing = !bar.replacing
        }
    }

    Field {
        id: replace
        visible: bar.replacing && bar.can
        x: 8
        y: 32
        width: search.width
        hint: "Replace"
        onAccepted: bar.replaceOne()
    }
    PushButton {
        id: replaceButton
        visible: replace.visible
        x: replace.x + replace.width + 6
        y: 32
        height: 22
        text: "Replace"
        enabled: bar.matches > 0
        onClicked: bar.replaceOne()
    }
    PushButton {
        visible: replace.visible
        x: replaceButton.x + replaceButton.width + 6
        y: 32
        height: 22
        text: "All"
        enabled: bar.matches > 0
        onClicked: bar.replaceEvery()
    }
}
