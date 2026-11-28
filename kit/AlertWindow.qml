import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Ambrosia

// An alert, as a Mac raises one, for an app of ours to ask or tell with
// where it has no window to say it on (kit/alert.h raises it, from C++). Measured from
// macOS 27's in Dark (2026-11-28, an alert of a program of our own shown
// behind everything; the icon's place from Disk Utility's): a card 260
// wide with corners of 20; the app's icon 64 across at 19, 19; the words
// 218 wide from 21, 99 down (19 with no icon): what it says in bold, more
// about it 8 under that, both 13; a password's field 228 by 24, 14 under
// the words; the buttons 28 tall 15 under that and 16 from the foot, one
// 228 wide or two of 110, 8 apart, the one Return presses at the right.
// The card draws its own shadow inside a window larger than it, so an app
// needs nothing else to show one.
//
// `buttons` is [{ text, role, primary, cancel }] (OK alone when none is
// given): Return presses the primary one, Escape the one marked cancel.
// `answered` says which, and what was typed when `secret` asked for a
// password. Whoever made the window takes it away once it has answered
// (kit/alert.h).
Window {
    id: alert

    // The app's icon by its name in the Ambrosia icon theme, or none.
    property string icon
    property string heading
    property string detail
    property var buttons: []
    property bool secret: false
    signal answered(string role, string typed)

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property color ground: dark ? "#2f2e2c" : "#f1f1f1"
    readonly property color field: dark ? "#1a1919" : "#ffffff"
    readonly property color fieldRim: dark ? "#373634" : "#c8c8c8"
    readonly property color push: dark ? "#3f3e3c" : "#ffffff"
    readonly property color ink: colors.label.primary
    readonly property var shown: buttons.length > 0 ? buttons : [{ text: "OK", role: "ok", primary: true, cancel: true }]

    // Room round the card for its shadow.
    readonly property int aside: 44
    readonly property int above: 26
    readonly property int below: 62

    property bool said: false
    function answer(role) {
        if (said)
            return;
        said = true;
        const typed = input.text;
        hide();
        answered(role, typed);
    }
    function accept() {
        const button = shown.find(each => each.primary) ?? shown[shown.length - 1];
        if (secret && input.text === "" && !button.cancel)
            return;
        answer(button.role);
    }
    function cancel() {
        const button = shown.find(each => each.cancel);
        if (button)
            answer(button.role);
    }
    // Closed from outside (the session ending): as Escape, and with no
    // button for that, as nothing chosen.
    function dismiss() {
        answer(shown.find(each => each.cancel)?.role ?? "");
    }

    title: "​"
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: transientParent ? Qt.WindowModal : Qt.NonModal
    readonly property int wide: 260 + 2 * aside
    readonly property int tall: Math.ceil(card.height) + above + below
    width: wide
    height: tall
    minimumWidth: wide
    maximumWidth: wide
    minimumHeight: tall
    maximumHeight: tall
    color: "transparent"
    onClosing: if (!said) dismiss()
    onVisibleChanged: if (visible) (secret ? input : keys).forceActiveFocus()

    component Words: Text {
        width: 218
        wrapMode: Text.Wrap
        color: alert.ink
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    Rectangle {
        id: card
        x: alert.aside
        y: alert.above
        width: 260
        height: column.y + column.height + 16
        radius: 20
        color: alert.ground
        border.width: 0.5
        border.color: alert.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            shadowBlur: 1
            shadowVerticalOffset: 10
            blurMax: 44
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                const command = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    alert.accept();
                else if (event.key === Qt.Key_Escape || (command && event.key === Qt.Key_Period))
                    alert.cancel();
                else if (!command)
                    return;
                // ⌘W and the rest are not the window's under it while this asks.
                event.accepted = true;
            }
            Keys.onShortcutOverride: (event) => event.accepted = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0
                && (event.key === Qt.Key_W || event.key === Qt.Key_Period)

            Image {
                visible: alert.icon !== ""
                x: 19
                y: 19
                width: 64
                height: 64
                sourceSize: Qt.size(128, 128)
                source: alert.icon ? "file:///usr/share/icons/Ambrosia/apps/scalable/" + alert.icon + ".svg" : ""
            }
            Column {
                id: column
                x: 21
                y: alert.icon !== "" ? 99 : 19
                width: 218
                Words { text: alert.heading; font.weight: 700 }
                Item { visible: alert.detail !== ""; width: 1; height: 8 }
                Words { visible: alert.detail !== ""; text: alert.detail }
                Item { visible: alert.secret; width: 1; height: 14 }
                Rectangle {
                    visible: alert.secret
                    x: -5
                    width: 228
                    height: 24
                    radius: 6
                    color: alert.field
                    border.width: input.activeFocus && alert.active ? 2.5 : 0.5
                    border.color: input.activeFocus && alert.active ? Theme.accent.bg : alert.fieldRim
                    TextInput {
                        id: input
                        x: 7
                        width: parent.width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        echoMode: TextInput.Password
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        color: alert.ink
                        selectionColor: Theme.accent.highlight
                        selectedTextColor: alert.ink
                        renderType: Text.NativeRendering
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Password"
                        Keys.onReturnPressed: alert.accept()
                        Keys.onEnterPressed: alert.accept()
                        Keys.onEscapePressed: alert.cancel()
                    }
                }
                Item { width: 1; height: 15 }
                Row {
                    x: -5
                    spacing: 8
                    Repeater {
                        model: alert.shown.length
                        Rectangle {
                            id: button
                            required property int index
                            readonly property var told: alert.shown[index]
                            readonly property bool lit: !!told.primary && alert.active
                            width: alert.shown.length === 1 ? 228 : (228 - 8 * (alert.shown.length - 1)) / alert.shown.length
                            height: 28
                            radius: 14
                            color: lit ? Theme.accent.bg : alert.push
                            border.width: alert.dark || lit ? 0 : 0.5
                            border.color: alert.fieldRim
                            Accessible.role: Accessible.Button
                            Accessible.name: told.text
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: area.pressed
                                color: alert.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
                            }
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: button.told.text
                                color: button.lit ? Theme.accent.fg : alert.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }
                            MouseArea { id: area; anchors.fill: parent; onClicked: alert.answer(button.told.role) }
                        }
                    }
                }
            }
        }
    }
}
