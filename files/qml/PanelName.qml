import QtQuick
import Ambrosia

// Over a Save panel's folder: the name the file will have. It opens with
// the suggested name selected up to its extension; Return saves, Escape
// cancels, and the arrows still move through the folder under it.
Item {
    id: row

    required property var finder // the FinderWindow, a Save panel

    height: Finder.panelName
    function focusField() {
        input.forceActiveFocus();
        const dot = input.text.lastIndexOf(".");
        input.select(0, dot > 0 ? dot : input.text.length);
    }

    Label {
        id: caption
        anchors.right: field.left
        anchors.rightMargin: 8
        anchors.verticalCenter: field.verticalCenter
        text: "Save As:"
        color: Theme.color.label.primary
    }
    Rectangle {
        id: field
        x: Math.round((parent.width - width + caption.implicitWidth + 8) / 2)
        y: parent.height - height - 4
        width: Math.min(320, parent.width - caption.implicitWidth - 48)
        height: 24
        radius: 5
        color: Theme.dark ? "#1affffff" : "#ffffff"
        border.width: input.activeFocus ? 0 : 0.5
        border.color: Theme.dark ? "#33ffffff" : "#33000000"

        // The focus ring, outside the field.
        Rectangle {
            visible: input.activeFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.accent.highlight
        }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: row.finder.panelName
            onTextEdited: row.finder.panelName = text
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.body.size
            font.letterSpacing: Theme.text.body.tracking
            color: Theme.color.label.primary
            selectionColor: Theme.accent.highlight
            selectedTextColor: Theme.color.label.primary
            selectByMouse: true
            renderType: Text.NativeRendering
            Accessible.role: Accessible.EditableText
            Accessible.name: "Save As"

            Keys.onReturnPressed: row.finder.panelChoose()
            Keys.onEnterPressed: row.finder.panelChoose()
        }
    }
}
