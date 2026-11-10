import QtQuick
import Ambrosia
import Settings

// Login Password: changing yours, the old one checked by PAM through passwd.
// Left out: a password hint (Linux keeps none) and the help button; Touch
// ID, as there's no fingerprint stack yet.
Page {
    id: page

    SectionHeading {
        first: true
        text: qsTr("Password")
    }
    Box {
        FormRow {
            height: 44
            label: Accounts.passwordSet ? qsTr("A login password has been set for this user.") : qsTr("No login password has been set for this user.")
            PushButton {
                text: Accounts.passwordSet ? qsTr("Change…") : qsTr("Set…")
                onClicked: changeSheet.show()
            }
        }
    }

    Sheet {
        id: changeSheet
        settings: page.settings
        sheetWidth: 440
        below: 24

        // Why the last try didn't take, shown under the fields.
        property string problem: ""
        readonly property bool ready: (!Accounts.passwordSet || oldField.text !== "") && newField.text !== ""
            && newField.text === verifyField.text && !Accounts.changingPassword
        function show() {
            oldField.text = "";
            newField.text = "";
            verifyField.text = "";
            problem = "";
            open = true;
            (Accounts.passwordSet ? oldField : newField).forceActiveFocus();
        }
        onAccepted: {
            if (!ready)
                return;
            problem = "";
            Accounts.changePassword(oldField.text, newField.text);
        }
        Connections {
            target: Accounts
            function onPasswordDone(ok, message) {
                if (!changeSheet.open)
                    return;
                if (ok) {
                    changeSheet.close();
                    return;
                }
                if (message === "old") {
                    changeSheet.problem = qsTr("The old password is incorrect.");
                    oldField.text = "";
                    oldField.forceActiveFocus();
                } else {
                    changeSheet.problem = message;
                    newField.text = "";
                    verifyField.text = "";
                    newField.forceActiveFocus();
                }
            }
        }

        Label {
            text: qsTr("Change Password")
            font.weight: 600
        }
        Box {
            width: parent.width
            FormRow {
                visible: Accounts.passwordSet
                label: qsTr("Old Password")
                NameField {
                    id: oldField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    Accessible.name: qsTr("Old password")
                }
            }
            FormRow {
                label: qsTr("New Password")
                NameField {
                    id: newField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    Accessible.name: qsTr("New password")
                }
            }
            FormRow {
                label: qsTr("Verify")
                NameField {
                    id: verifyField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    Accessible.name: qsTr("Verify")
                }
            }
        }
        Label {
            width: parent.width
            visible: changeSheet.problem !== "" || (verifyField.text !== "" && verifyField.text !== newField.text)
            wrapMode: Text.WordWrap
            style: Theme.text.caption
            color: Theme.color.palette.red
            text: changeSheet.problem !== "" ? changeSheet.problem : qsTr("The passwords don't match.")
        }
        leading: [
            Spinner {
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                running: Accounts.changingPassword
                visible: running
            }
        ]
        trailing: [
            PushButton {
                id: cancelPassword
                text: qsTr("Cancel")
                enabled: !Accounts.changingPassword
                onClicked: changeSheet.close()
            },
            PushButton {
                text: qsTr("Change Password")
                primary: true
                enabled: changeSheet.ready
                onClicked: changeSheet.accepted()
            }
        ]
    }
}
