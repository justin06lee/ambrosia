import QtQuick
import Ambrosia
import Settings

// Users & Groups: everyone with an account here (AccountsService), each with
// a sheet for their picture, name and whether they administer the computer,
// and Add User…. Changing someone else asks for an administrator's password
// (polkit). Left out: the Guest User, groups, automatic login (SDDM's, which
// only root may change) and network account servers.
Page {
    id: page

    Component.onCompleted: Accounts.read()

    // The user whose sheet is open.
    property var shown: null
    readonly property var current: shown ? Accounts.users.find(user => user.path === shown.path) ?? shown : null
    function nameOf(user) {
        return user.fullName !== "" ? user.fullName : user.name;
    }

    Box {
        Repeater {
            model: Accounts.users
            Item {
                id: row
                required property var modelData
                width: parent ? parent.width : Look.boxWidth
                height: 52
                UserPicture {
                    x: Look.boxPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    source: row.modelData.icon
                }
                Column {
                    x: 50
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Label { text: page.nameOf(row.modelData) }
                    Label {
                        text: row.modelData.admin ? qsTr("Admin") : qsTr("Standard")
                        style: Theme.text.caption
                        color: Theme.color.label.secondary
                    }
                }
                InfoButton {
                    x: row.width - Look.boxPadding - width - 2
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        page.shown = row.modelData;
                        fullNameField.text = page.nameOf(row.modelData);
                        userSheet.open = true;
                    }
                }
            }
        }
    }
    Item {
        width: parent.width
        height: Look.popupHeight
        PushButton {
            anchors.right: parent.right
            text: qsTr("Add User…")
            onClicked: addSheet.show()
        }
    }

    // A user's sheet: picture, full name, admin; Delete User… for anyone but you.
    Sheet {
        id: userSheet
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: {
            if (page.current && fullNameField.text.trim() !== "" && fullNameField.text !== page.nameOf(page.current))
                Accounts.setFullName(page.current.path, fullNameField.text);
            close();
        }
        Row {
            spacing: 14
            Item {
                width: 64
                height: 64
                UserPicture {
                    anchors.fill: parent
                    source: page.current?.icon ?? ""
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: pictureSheet.open = true
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label {
                    text: page.current ? page.nameOf(page.current) : ""
                    style: Theme.text.title3
                }
                Label {
                    text: page.current?.name ?? ""
                    color: Theme.color.label.secondary
                }
            }
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Full name")
                NameField {
                    id: fullNameField
                    width: 220
                    ring: false
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Full name")
                }
            }
            FormRow {
                label: qsTr("Allow this user to administer this computer")
                Switch {
                    // You can't stop being the last administrator.
                    enabled: !(page.current?.me && page.current?.admin && Accounts.admins < 2)
                    opacity: enabled ? 1 : 0.5
                    checked: page.current?.admin ?? false
                    onToggled: Accounts.setAdmin(page.current.path, !checked)
                }
            }
        }
        leading: [
            PushButton {
                visible: !(page.current?.me ?? true)
                text: qsTr("Delete User…")
                onClicked: {
                    removeHome.checked = false;
                    deleteSheet.open = true;
                }
            }
        ]
        trailing: [
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: userSheet.accepted()
            }
        ]
    }

    // The system's pictures to choose from.
    Sheet {
        id: pictureSheet
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: close()
        Label {
            text: qsTr("Choose a picture")
            font.weight: 600
        }
        Grid {
            columns: 6
            spacing: 12
            Repeater {
                model: Accounts.pictures
                Item {
                    required property string modelData
                    width: 52
                    height: 52
                    UserPicture {
                        anchors.fill: parent
                        source: parent.modelData
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.accent.bg
                        visible: area.containsMouse
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Accounts.setPicture(page.current.path, parent.modelData);
                            pictureSheet.close();
                        }
                    }
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                onClicked: pictureSheet.close()
            }
        ]
    }

    Sheet {
        id: deleteSheet
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            Accounts.deleteUser(page.current.uid, removeHome.checked);
            close();
            userSheet.close();
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            font.weight: 600
            text: qsTr("Delete the user “%1”?").arg(page.current ? page.nameOf(page.current) : "")
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.color.label.secondary
            text: qsTr("They won't be able to log in to this computer any more.")
        }
        CheckBox {
            id: removeHome
            text: qsTr("Delete their home folder too")
            onToggled: checked = !checked
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 88
                onClicked: deleteSheet.close()
            },
            PushButton {
                text: qsTr("Delete User")
                primary: true
                minimumWidth: 88
                onClicked: deleteSheet.accepted()
            }
        ]
    }

    Sheet {
        id: addSheet
        settings: page.settings
        sheetWidth: 460
        below: 24

        property string problem: ""
        property bool adding: false
        // The account name follows the full name until it's typed in.
        property bool nameTyped: false
        readonly property string nameProblem: Accounts.nameProblem(nameField.text)
        readonly property bool ready: fullField.text.trim() !== "" && nameField.text !== "" && nameProblem === ""
            && passwordField.text !== "" && passwordField.text === verifyNew.text && !adding
        function show() {
            fullField.text = "";
            nameField.text = "";
            passwordField.text = "";
            verifyNew.text = "";
            adminNew.checked = false;
            nameTyped = false;
            problem = "";
            open = true;
            fullField.forceActiveFocus();
        }
        onAccepted: {
            if (!ready)
                return;
            adding = true;
            problem = "";
            Accounts.createUser(fullField.text.trim(), nameField.text, passwordField.text, adminNew.checked);
        }
        Connections {
            target: Accounts
            function onCreateDone(ok, message) {
                addSheet.adding = false;
                if (ok)
                    addSheet.close();
                else
                    addSheet.problem = message;
            }
        }

        Label {
            text: qsTr("New User")
            font.weight: 600
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Full name")
                NameField {
                    id: fullField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Full name")
                    onTextChanged: if (!addSheet.nameTyped) nameField.text = Accounts.suggestName(text)
                }
            }
            FormRow {
                label: qsTr("Account name")
                description: addSheet.nameProblem !== "" ? addSheet.nameProblem : qsTr("This will be the name of the home folder.")
                NameField {
                    id: nameField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Account name")
                    onTextEdited: addSheet.nameTyped = true
                }
            }
            FormRow {
                label: qsTr("Password")
                NameField {
                    id: passwordField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    Accessible.name: qsTr("Password")
                }
            }
            FormRow {
                label: qsTr("Verify")
                NameField {
                    id: verifyNew
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    Accessible.name: qsTr("Verify")
                }
            }
            FormRow {
                label: qsTr("Allow this user to administer this computer")
                Switch {
                    id: adminNew
                    onToggled: checked = !checked
                }
            }
        }
        Label {
            width: parent.width
            visible: addSheet.problem !== "" || (verifyNew.text !== "" && verifyNew.text !== passwordField.text)
            wrapMode: Text.WordWrap
            style: Theme.text.caption
            color: Theme.color.palette.red
            text: addSheet.problem !== "" ? addSheet.problem : qsTr("The passwords don't match.")
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                enabled: !addSheet.adding
                onClicked: addSheet.close()
            },
            PushButton {
                text: qsTr("Create User")
                primary: true
                enabled: addSheet.ready
                onClicked: addSheet.accepted()
            }
        ]
    }
}
