import QtQuick
import Ambrosia
import Settings

// General › Sharing: Remote Login and the local hostname. Turning Remote Login
// off asks first, as it can cut off whoever's connected. Left out: File, Media,
// Screen, Printer, Internet and Bluetooth Sharing, Content Caching and Remote
// Management and Application Scripting, which have nothing on our side yet, and
// the help button.
Page {
    id: page

    Component.onCompleted: Sharing.read()

    SectionHeading {
        first: true
        text: qsTr("Advanced")
    }
    Box {
        FormRow {
            visible: Sharing.remoteLoginAvailable
            label: qsTr("Remote Login")
            description: qsTr("Log in to this computer from another: ssh %1@%2.local").arg(Sharing.user).arg(Sharing.hostname)
            Switch {
                checked: Sharing.remoteLogin
                onToggled: {
                    if (checked)
                        stopConfirm.open = true;
                    else
                        Sharing.setRemoteLogin(true);
                }
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Local hostname")
            description: qsTr("Computers on your local network can access your computer at this address.")
            Row {
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.color.label.secondary
                    text: Sharing.hostname + ".local"
                }
                PushButton {
                    text: qsTr("Edit…")
                    onClicked: {
                        name.value = Sharing.hostname;
                        name.text = Sharing.hostname;
                        hostSheet.open = true;
                    }
                }
            }
        }
    }

    Sheet {
        id: stopConfirm
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            close();
            Sharing.setRemoteLogin(false);
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            font.weight: 600
            text: qsTr("Turn off Remote Login?")
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.color.label.secondary
            text: qsTr("Anyone connected over SSH, and anyone relying on it to reach this computer, will be cut off.")
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 88
                onClicked: stopConfirm.close()
            },
            PushButton {
                text: qsTr("Turn Off")
                primary: true
                minimumWidth: 88
                onClicked: stopConfirm.accepted()
            }
        ]
    }

    Sheet {
        id: hostSheet
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            Sharing.setHostname(name.text);
            close();
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Local hostname")
                NameField {
                    id: name
                    width: 180
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 80
                onClicked: hostSheet.close()
            },
            PushButton {
                text: qsTr("OK")
                primary: true
                minimumWidth: 80
                onClicked: hostSheet.accepted()
            }
        ]
    }
}
