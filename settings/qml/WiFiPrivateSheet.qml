import QtQuick
import Ambrosia
import Settings

// An other network's ⋯, as System Settings shows it: the private address to
// join it with, kept until it is joined (WiFi.setPrivateAddressFor). On a
// Mac that's Fixed until changed; here Off, as joining without it does.
Sheet {
    id: sheet

    property string ssid
    property string mode: "off"

    function show(ssid) {
        sheet.ssid = ssid;
        mode = WiFi.privateAddressFor(ssid);
        open = true;
    }

    sheetWidth: 470
    onAccepted: {
        WiFi.setPrivateAddressFor(ssid, mode);
        close();
    }

    Box {
        width: parent.width
        FormRow {
            label: qsTr("Private Wi‑Fi address")
            description: qsTr("Using a private address helps reduce tracking of your computer by Wi‑Fi network operators. A fixed private address allows this network to track this computer, but helps reduce tracking across other networks.")
            firstLine: Look.popupHeight
            PopUpButton {
                items: [
                    { text: qsTr("Off"), value: "off" },
                    { text: qsTr("Fixed"), value: "fixed" },
                    { text: qsTr("Rotating"), value: "rotating" },
                ]
                current: sheet.mode
                onChosen: (value) => sheet.mode = value
            }
        }
        // A private address is known once joined with it.
        FormRow {
            visible: sheet.mode === "off"
            label: qsTr("Wi‑Fi address")
            value: WiFi.address
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
            onClicked: sheet.accepted()
        }
    ]
}
