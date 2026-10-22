import QtQuick
import Ambrosia

// An item's tags, a token each, then a field for another, as Get Info and
// the preview show them: Return adds what is typed (a new tag joins the
// sidebar), ⌫ in the empty field takes the last away.
Rectangle {
    id: field

    required property var item // an ItemInfo
    // Get Info rules the field's edge while it is empty or typed in; the
    // preview's is only its fill.
    property bool ruled: true
    // Where the tokens and the typing start, and how big "Add Tags…" is.
    property real inset: 4
    property real textTop: 9
    property int placeholderSize: 13
    property color placeholderColor: Theme.color.label.secondary

    color: "transparent"
    border.width: ruled ? 1 : 0
    border.color: field.item.tags.length === 0 || tagInput.activeFocus ? Finder.infoRule : "transparent"
    TapHandler { onTapped: tagInput.forceActiveFocus() }

    Flow {
        x: field.inset
        y: field.item.tags.length > 0 ? 2 : field.textTop
        width: parent.width - 2 * field.inset
        spacing: 2
        Repeater {
            model: field.item.tags
            Rectangle {
                id: token
                required property string modelData
                readonly property string color_: Tags.colorOf(modelData)
                width: tokenText.implicitWidth + 9
                height: 14
                radius: 2
                color: Finder.tagToken(color_)
                Label {
                    id: tokenText
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    text: token.modelData
                    color: Finder.tagTokenText(token.color_)
                }
            }
        }
        TextInput {
            id: tagInput
            width: Math.max(80, contentWidth + 8)
            height: 14
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            readOnly: !field.item.url.toString().startsWith("file:")
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.color.label.primary
            selectionColor: Theme.accent.bg
            selectedTextColor: Theme.accent.fg
            renderType: Text.NativeRendering
            Keys.onReturnPressed: {
                if (text.trim() !== "")
                    Tags.add([field.item.url], text);
                text = "";
            }
            Keys.onEnterPressed: Keys.returnPressed(event)
            Keys.onEscapePressed: {
                text = "";
                focus = false;
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Backspace && text === "" && field.item.tags.length > 0) {
                    Tags.remove([field.item.url], field.item.tags[field.item.tags.length - 1]);
                    event.accepted = true;
                }
            }
            Label {
                visible: field.item.tags.length === 0 && tagInput.text === ""
                x: -1
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: field.placeholderSize
                text: "Add Tags…"
                color: field.placeholderColor
            }
        }
    }
}
