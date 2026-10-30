import QtQuick
import Ambrosia
import Settings

// Wi-Fi's Other…, as System Settings shows it: a network added by its name
// and security, with its password; OK saves it and joins it
// (WiFi.addNetwork), and it stays saved if it isn't in range. Old kinds of
// security (WEP, WPA) are offered only with Advanced…'s Show legacy
// networks and options.
Sheet {
    id: sheet

    property string security: "wpa"
    property bool showPassword: false
    readonly property bool enterprise: security === "enterprise"
    readonly property bool needsPassword: security !== "none"
    // WPA's passwords run 8 to 63 characters; none typed, the system asks.
    readonly property bool ready: nameField.text !== ""
        && (!["wpa", "wpa1", "sae"].includes(security) || passwordField.text === "" || passwordField.text.length >= 8)

    function show() {
        nameField.text = "";
        userField.text = "";
        passwordField.text = "";
        security = "wpa";
        showPassword = false;
        open = true;
        nameField.forceActiveFocus();
    }

    sheetWidth: 400
    onAccepted: {
        if (!ready)
            return;
        WiFi.addNetwork(nameField.text, security, needsPassword ? passwordField.text : "", enterprise ? userField.text : "");
        close();
    }

    Box {
        width: parent.width
        Item {
            width: parent.width
            height: 65.5
            PaneIcon {
                x: 11
                y: 12
                size: 26
                glyph: "wifi"
                tint: "blue"
            }
            Label {
                x: 48
                y: 10
                text: qsTr("Add a Wi‑Fi Network Profile")
                font.weight: 600
            }
            Label {
                x: 48
                y: 28
                width: parent.width - x - 20
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 14
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: qsTr("Enter the name and the security type of the profile you want to add.")
            }
        }
        FormRow {
            label: qsTr("Network Name")
            NameField {
                id: nameField
                width: 250
                ring: false
                activeFocusOnTab: true
                Accessible.name: qsTr("Network Name")
            }
        }
        FormRow {
            label: qsTr("Security")
            PopUpButton {
                items: [
                    { text: qsTr("None"), value: "none" },
                    { text: qsTr("WPA2/WPA3 Personal"), value: "wpa" },
                    { text: qsTr("WPA3 Personal"), value: "sae" },
                    { text: qsTr("WPA2/WPA3 Enterprise"), value: "enterprise" },
                ].concat(WiFi.showLegacy ? [
                    {},
                    { text: qsTr("WEP"), value: "wep" },
                    { text: qsTr("WPA Personal"), value: "wpa1" },
                ] : [])
                current: sheet.security
                onChosen: (value) => sheet.security = value
            }
        }
        FormRow {
            visible: sheet.enterprise
            label: qsTr("Username")
            NameField {
                id: userField
                width: 250
                ring: false
                activeFocusOnTab: true
                Accessible.name: qsTr("Username")
            }
        }
        FormRow {
            visible: sheet.needsPassword
            label: qsTr("Password")
            NameField {
                id: passwordField
                width: 280
                ring: false
                activeFocusOnTab: true
                echoMode: sheet.showPassword ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                Accessible.name: qsTr("Password")
            }
        }
        FormRow {
            visible: sheet.needsPassword
            label: qsTr("Show password")
            Switch {
                checked: sheet.showPassword
                onToggled: sheet.showPassword = !sheet.showPassword
            }
        }
    }

    trailing: [
        PushButton {
            text: qsTr("Cancel")
            onClicked: sheet.close()
        },
        PushButton {
            text: qsTr("OK")
            primary: true
            enabled: sheet.ready
            onClicked: sheet.accepted()
        }
    ]
}
