import QtQuick
import Ambrosia

// The field an item's name is edited in, over its name. It opens with the
// name selected up to its extension, as Finder's does; Return, Tab or a
// click elsewhere renames, and Esc puts the name back.
Rectangle {
    id: field

    required property var finder
    required property string name
    required property bool isDir
    property QtObject style: Theme.text.body
    property int alignment: TextInput.AlignLeft

    implicitWidth: Math.max(input.contentWidth + 10, 40)
    implicitHeight: input.contentHeight + 4
    radius: 3
    color: Finder.content
    border.width: 1
    border.color: Theme.accent.bg

    property bool done: false
    function commit() {
        if (done)
            return;
        done = true;
        finder.endRename(input.text);
    }
    function cancel() {
        if (done)
            return;
        done = true;
        finder.endRename(undefined);
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: field.alignment
        clip: true
        text: field.name
        font.family: Theme.uiFont
        font.pixelSize: field.style.size
        font.weight: field.style.weight
        font.letterSpacing: field.style.tracking
        color: Theme.color.label.primary
        selectionColor: Theme.accent.bg
        selectedTextColor: Theme.accent.fg
        selectByMouse: true
        renderType: Text.NativeRendering

        Keys.onReturnPressed: field.commit()
        Keys.onEnterPressed: field.commit()
        Keys.onTabPressed: field.commit()
        Keys.onEscapePressed: field.cancel()
        onActiveFocusChanged: if (!activeFocus) field.commit()

        Component.onCompleted: {
            forceActiveFocus();
            const dot = field.isDir ? -1 : text.lastIndexOf(".");
            select(0, dot > 0 ? dot : text.length);
        }
    }

    Component.onCompleted: finder.editor = field
    Component.onDestruction: if (finder.editor === field) finder.editor = null
}
