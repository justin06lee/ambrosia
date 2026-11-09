import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import Files

// Tags… from the shortcut menu: Finder's tag popover. The tags every item
// has are tokens in a field; typing a name and Return gives it to all (a
// new tag joins the sidebar), ⌫ in the empty field takes the last away, and
// the tags they don't all have are listed under it, a click to add one.
Controls.Popup {
    id: editor

    property var urls: []
    property var common: []
    function refresh() { common = urls.length > 0 ? Tags.common(urls) : []; }
    function openAt(x, y) {
        refresh();
        input.text = "";
        const root = parent;
        editor.x = Math.max(4, Math.min(x, root.width - width - 4));
        editor.y = y + implicitHeight + 4 <= root.height ? y : Math.max(4, y - implicitHeight);
        open();
        input.forceActiveFocus();
    }
    function add(name) {
        if (name.trim() === "")
            return;
        Tags.add(urls, name);
        refresh();
    }

    Connections {
        target: Tags
        function onChanged() { if (editor.opened) editor.refresh(); }
    }

    parent: Controls.Overlay.overlay
    width: 260
    padding: 10
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

    background: Rectangle {
        radius: 10
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
        spacing: 8
        Rectangle {
            width: editor.availableWidth
            height: Math.max(26, tokens.implicitHeight + 8)
            radius: 6
            color: Finder.searchFill
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.accent.bg, 0.6) : Finder.capsuleRim
            TapHandler { onTapped: input.forceActiveFocus() }
            Flow {
                id: tokens
                x: 5
                y: 4
                width: parent.width - 10
                spacing: 3
                Repeater {
                    model: editor.common
                    Rectangle {
                        id: token
                        required property string modelData
                        readonly property string color_: Tags.colorOf(modelData)
                        width: tokenText.implicitWidth + 10
                        height: 18
                        radius: 3
                        color: Finder.tagToken(color_)
                        Label {
                            id: tokenText
                            anchors.centerIn: parent
                            text: token.modelData
                            color: Finder.tagTokenText(token.color_)
                        }
                    }
                }
                TextInput {
                    id: input
                    width: Math.max(60, contentWidth + 8)
                    height: 18
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: Theme.color.label.primary
                    selectionColor: Theme.accent.bg
                    selectedTextColor: Theme.accent.fg
                    Keys.onReturnPressed: {
                        editor.add(text);
                        text = "";
                    }
                    Keys.onEnterPressed: Keys.returnPressed(event)
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Backspace && text === "" && editor.common.length > 0) {
                            Tags.remove(editor.urls, editor.common[editor.common.length - 1]);
                            editor.refresh();
                            event.accepted = true;
                        }
                    }
                    Label {
                        visible: editor.common.length === 0 && input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Add Tags…"
                        color: Theme.color.label.tertiary
                    }
                }
            }
        }
        // The tags not on every item yet, those matching what's typed.
        Column {
            width: editor.availableWidth
            Repeater {
                model: Tags.all.filter(tag => editor.common.indexOf(tag.name) < 0
                    && tag.name.toLowerCase().indexOf(input.text.trim().toLowerCase()) >= 0)
                Item {
                    id: choice
                    required property var modelData
                    width: parent.width
                    height: Finder.menuRow
                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: pick.hovered
                        color: Theme.accent.bg
                    }
                    Rectangle {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: choice.modelData.color !== "" ? Finder.tagFill[choice.modelData.color] : "transparent"
                        border.width: 1
                        border.color: choice.modelData.color !== "" ? Finder.tagRim[choice.modelData.color] : Theme.color.label.tertiary
                    }
                    Label {
                        x: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: choice.modelData.name
                        color: pick.hovered ? Theme.accent.fg : Theme.color.label.primary
                    }
                    HoverHandler { id: pick }
                    TapHandler {
                        onTapped: {
                            editor.add(choice.modelData.name);
                            input.text = "";
                        }
                    }
                }
            }
        }
    }
}
