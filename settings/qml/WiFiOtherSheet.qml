import QtQuick
import Ambrosia
import Settings

// Wi-Fi's Other…, as System Settings shows it: a network added by its name
// and security, with its password; OK saves it and joins it
// (WiFi.addNetwork), and it stays saved if it isn't in range. Other…
// offers all its security types whatever Advanced…'s Show legacy networks
// switch says; the switch only affects which networks are listed.
Sheet {
    id: sheet

    property string security: "wpa"
    property bool showPassword: false
    readonly property bool enterprise: ["dynamic-wep", "wpa-wpa2-enterprise", "enterprise", "enterprise3"].includes(security)
    readonly property bool needsPassword: security !== "none"
    // WPA's passwords run 8 to 63 characters; none typed, the system asks.
    readonly property bool ready: nameField.text !== ""
        && (!["wpa-wpa2", "wpa", "sae"].includes(security) || passwordField.text === "" || passwordField.text.length >= 8)

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
    // The room under the box, as the Mac leaves it for each kind.
    below: security === "none" ? 68.5 : enterprise ? 20.5 : security === "wep" ? 20 : 24
    onAccepted: {
        if (!ready)
            return;
        WiFi.addNetwork(nameField.text, security, needsPassword ? passwordField.text : "", enterprise ? userField.text : "");
        close();
    }

    Box {
        width: parent.width
        // Rows at the Mac's heights.
        Item {
            width: parent.width
            height: 66
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
            height: 36
            label: qsTr("Network Name")
            NameField {
                id: nameField
                width: 236
                ring: false
                activeFocusOnTab: true
                Accessible.name: qsTr("Network Name")
            }
        }
        FormRow {
            height: 37.5
            label: qsTr("Security")
            PopUpButton {
                items: [
                    { text: qsTr("None"), value: "none" },
                    {},
                    { text: qsTr("WEP"), value: "wep" },
                    { text: qsTr("WPA/WPA2 Personal"), value: "wpa-wpa2" },
                    { text: qsTr("WPA2/WPA3 Personal"), value: "wpa" },
                    { text: qsTr("WPA3 Personal"), value: "sae" },
                    {},
                    { text: qsTr("Dynamic WEP"), value: "dynamic-wep" },
                    { text: qsTr("WPA/WPA2 Enterprise"), value: "wpa-wpa2-enterprise" },
                    { text: qsTr("WPA2 Enterprise"), value: "enterprise" },
                    { text: qsTr("WPA3 Enterprise"), value: "enterprise3" },
                ]
                current: sheet.security
                onChosen: (value) => sheet.security = value
            }
        }
        FormRow {
            height: 37
            visible: sheet.enterprise
            label: qsTr("Mode")
            PopUpButton {
                items: [{ text: qsTr("Automatic"), value: "automatic" }]
                current: "automatic"
            }
        }
        FormRow {
            height: 36
            visible: sheet.enterprise
            label: qsTr("Username")
            NameField {
                id: userField
                width: 260
                ring: false
                activeFocusOnTab: true
                Accessible.name: qsTr("Username")
            }
        }
        FormRow {
            height: 36
            visible: sheet.needsPassword
            label: qsTr("Password")
            NameField {
                id: passwordField
                width: 268
                ring: false
                activeFocusOnTab: true
                echoMode: sheet.showPassword && !sheet.enterprise ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                Accessible.name: qsTr("Password")
            }
        }
        FormRow {
            height: 36.5
            visible: sheet.needsPassword && !sheet.enterprise
            label: qsTr("Show password")
            Switch {
                checked: sheet.showPassword
                onToggled: sheet.showPassword = !sheet.showPassword
            }
        }
    }

    trailing: [
        PushButton {
            id: cancelButton
            text: qsTr("Cancel")
            onClicked: sheet.close()
        },
        PushButton {
            text: qsTr("OK")
            minimumWidth: cancelButton.implicitWidth
            primary: true
            enabled: sheet.ready
            onClicked: sheet.accepted()
        }
    ]
}
