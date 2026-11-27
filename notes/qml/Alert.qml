import QtQuick
import QtQuick.Effects
import Ambrosia
import Notes

// The window asking before something is lost, or saying what went wrong:
// the window dims and a card asks, its buttons one under another as macOS
// 26 stacks three. Return presses the first, Escape the one marked
// `cancel`.
Rectangle {
    id: alert

    required property var window
    property string title
    property string detail
    // [{ text, role, primary, cancel }]
    property var buttons: []
    property var then: null

    function ask(title, detail, buttons, then) {
        alert.title = title;
        alert.detail = detail;
        alert.buttons = buttons;
        alert.then = then;
        visible = true;
        card.forceActiveFocus();
    }
    function answer(role) {
        const then = alert.then;
        alert.then = null;
        visible = false;
        window.takeKeys();
        if (then)
            then(role);
    }

    visible: false
    radius: window.corner
    color: Theme.dark ? "#66000000" : "#33000000"
    // Nothing under the card takes a click while it asks.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onWheel: (wheel) => wheel.accepted = true }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 260
        height: column.height + 36
        radius: 20
        color: Theme.dark ? "#2e2e2b" : "#f6f6f6"
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.3
            shadowBlur: 1
            shadowVerticalOffset: 8
            blurMax: 48
        }
        Keys.onReturnPressed: alert.answer(alert.buttons[0].role)
        Keys.onEnterPressed: alert.answer(alert.buttons[0].role)
        Keys.onEscapePressed: {
            const cancel = alert.buttons.find(button => button.cancel);
            if (cancel)
                alert.answer(cancel.role);
        }
        Keys.onPressed: (event) => {
            // Command-D and Command-Delete: the one that throws away.
            const discard = alert.buttons.find(button => button.discard);
            if (discard && (event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_D || event.key === Qt.Key_Backspace)) {
                alert.answer(discard.role);
                event.accepted = true;
            }
        }

        Column {
            id: column
            x: 18
            y: 18
            width: parent.width - 36
            spacing: 8
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: alert.title
                style: Theme.text.headline
            }
            Label {
                width: parent.width
                visible: alert.detail !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: alert.detail
                style: Theme.text.caption
            }
            Item { width: 1; height: 4 }
            Repeater {
                model: alert.buttons
                PushButton {
                    required property var modelData
                    width: column.width
                    height: 28
                    text: modelData.text
                    primary: !!modelData.primary
                    onClicked: alert.answer(modelData.role)
                }
            }
        }
    }
}
