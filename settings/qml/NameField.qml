import QtQuick
import Ambrosia
import Settings

// A value typed in place, right-aligned (About's Name): a click edits it,
// Return or leaving the field keeps what's typed, Escape puts it back.
TextInput {
    id: field

    property string value
    // Shown, gray, while it's empty (DHCP client ID).
    property string placeholder
    signal committed(string text)

    text: value
    onValueChanged: if (!activeFocus) text = value
    horizontalAlignment: TextInput.AlignRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.text.body.size
    font.letterSpacing: Theme.text.body.tracking
    color: Theme.color.label.primary
    selectionColor: Theme.accent.highlight
    selectedTextColor: Theme.color.label.primary
    renderType: Text.NativeRendering
    selectByMouse: true
    clip: true
    Accessible.role: Accessible.EditableText

    onEditingFinished: {
        if (text !== value)
            committed(text);
        focus = false;
    }
    function revert() {
        text = value;
        focus = false;
    }
    Keys.onEscapePressed: revert()

    Label {
        anchors.right: parent.right
        visible: field.text === "" && !field.activeFocus
        text: field.placeholder
        color: Theme.color.label.tertiary
    }
    // The field it becomes while editing.
    Rectangle {
        z: -1
        visible: field.activeFocus
        x: field.width - Math.min(field.width, field.contentWidth) - 5
        y: -3
        width: Math.min(field.width, field.contentWidth) + 10
        height: field.height + 6
        radius: 5
        color: Theme.dark ? "#1affffff" : "#ffffff"
        border.width: 3
        border.color: Theme.accent.highlight
    }
}
