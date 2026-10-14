import Quickshell
import QtQuick
import Ambrosia

// "Are you sure…?" before something that can't be undone, like restarting,
// or a question with a secret for an answer, like a Wi-Fi password. Return
// accepts and Escape cancels.
Item {
    id: dialog

    // { title, text, accept: button label, password: bool, action: function },
    // where action is given the password when there is one.
    property var confirmation: null
    readonly property Region blurArea: Region { item: dialog; radius: Theme.radius.panel }

    function accept() {
        const action = confirmation?.action;
        const answer = password.text;
        Popups.close();
        action?.(answer);
    }

    onVisibleChanged: {
        password.text = "";
        if (visible && confirmation?.password) Qt.callLater(() => password.forceActiveFocus());
    }

    width: 280
    height: content.implicitHeight + 2 * Theme.space.s5

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.thick.tint
        radius: Theme.radius.panel
        shadow: Theme.color.shadow.window
    }

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content
        x: Theme.space.s5
        y: Theme.space.s5
        width: parent.width - 2 * Theme.space.s5
        spacing: Theme.space.s3

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "bowl"
            size: 48
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: dialog.confirmation?.title ?? ""
            style: Theme.text.headline
        }

        Label {
            width: parent.width
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: dialog.confirmation?.text ?? ""
            style: Theme.text.callout
            color: Theme.color.label.secondary
        }

        Rectangle {
            visible: dialog.confirmation?.password === true
            width: parent.width
            height: Theme.size.control.regular
            radius: Theme.radius.control
            color: Theme.color.bg.control
            border.width: password.activeFocus ? Theme.size.focusRing.width : 1
            border.color: password.activeFocus ? Theme.accent.highlight : Theme.color.border

            TextInput {
                id: password
                anchors { fill: parent; leftMargin: Theme.space.s2; rightMargin: Theme.space.s2 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                font.family: Theme.uiFont
                font.pixelSize: Theme.text.body.size
                color: Theme.color.label.primary
                selectionColor: Theme.accent.highlight
                clip: true
                onAccepted: dialog.accept()
                Keys.onEscapePressed: Popups.close()
            }
        }

        Row {
            width: parent.width
            spacing: Theme.space.s2
            topPadding: Theme.space.s1

            PushButton {
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                onClicked: Popups.close()
            }
            PushButton {
                width: (parent.width - parent.spacing) / 2
                text: dialog.confirmation?.accept ?? "OK"
                primary: true
                onClicked: dialog.accept()
            }
        }
    }
}
