import QtQuick
import Ambrosia
import Settings

// Bluetooth, as System Settings lays it out: the pane's own box (its icon,
// name, what it does and its switch) with how others see this computer
// under it, discoverable while the pane is open; then the devices paired
// with it, and those in range, each connected or disconnected where
// pointed. All of it BlueZ's (src/bluetooth.cpp); pairing codes come from
// the session's agent (bluedevil). Left out: the help button and Learn
// more…. Not yet: a device's ⓘ (rename, forget).
Page {
    id: page

    Component.onCompleted: Bluetooth.watching = Qt.binding(() => page.visible && Bluetooth.enabled)
    Component.onDestruction: Bluetooth.watching = false

    function toggle(device) {
        if (device.connected)
            Bluetooth.disconnectDevice(device.address);
        else
            Bluetooth.connectDevice(device.address);
    }

    Box {
        Item {
            width: parent.width
            height: 68
            PaneIcon {
                x: 11
                y: 12
                size: 26
                glyph: "bluetooth"
                tint: "blue"
            }
            Label {
                x: 48
                y: 10
                text: qsTr("Bluetooth")
                font.weight: 600
            }
            Label {
                x: 48
                y: 28
                width: 328
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 15
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: qsTr("Connect to accessories you can use for activities such as streaming music, typing, and gaming.")
            }
            Switch {
                x: parent.width - Look.boxPadding - width
                y: 9
                large: true
                animated: Bluetooth.ready
                enabled: !Bluetooth.blocked
                checked: Bluetooth.enabled
                onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                Accessible.name: qsTr("Bluetooth")
            }
        }
        Item {
            width: parent.width
            height: note.height + 20
            visible: Bluetooth.enabled
            Label {
                id: note
                x: Look.boxPadding
                y: 10
                width: 407
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 15
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: qsTr("This computer is discoverable as “%1” while Bluetooth Settings is open.").arg(Bluetooth.name)
            }
        }
    }

    SectionHeading {
        visible: myDevices.visible
        text: qsTr("My Devices")
    }
    Box {
        id: myDevices
        visible: Bluetooth.enabled && Bluetooth.devices.length > 0
        Repeater {
            model: Bluetooth.devices
            DeviceRow {
                required property var modelData
                device: modelData
                paired: true
                onToggle: page.toggle(modelData)
                onInfo: {
                    deviceSheet.device = Bluetooth.details(modelData.address);
                    deviceSheet.open = true;
                }
            }
        }
    }

    SectionHeading {
        visible: Bluetooth.enabled
        text: qsTr("Nearby Devices")
        Spinner {
            x: parent.width - 10 - width
            anchors.bottom: parent.bottom
            running: Bluetooth.discovering
        }
    }
    Box {
        visible: Bluetooth.enabled
        Item {
            width: parent.width
            height: 36
            visible: Bluetooth.nearby.length === 0
            Label {
                anchors.centerIn: parent
                color: Theme.color.label.secondary
                text: qsTr("Searching…")
            }
        }
        Repeater {
            model: Bluetooth.nearby
            DeviceRow {
                required property var modelData
                device: modelData
                onToggle: page.toggle(modelData)
            }
        }
    }

    // A paired device's sheet: its name (typed over, it's renamed), what it
    // is and its version; forget it, connect or disconnect it.
    Sheet {
        id: deviceSheet
        property var device: ({})
        settings: page.settings
        onAccepted: close()

        Box {
            width: parent.width
            FormRow {
                label: qsTr("Name")
                NameField {
                    width: 300
                    value: deviceSheet.device.name ?? ""
                    onCommitted: (text) => Bluetooth.rename(deviceSheet.device.address, text)
                }
            }
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Device Type")
                value: ({
                    headphones: qsTr("Headphones"), speaker: qsTr("Speaker"), gamepad: qsTr("Gamepad"),
                    keyboard: qsTr("Keyboard"), mouse: qsTr("Mouse"), phone: qsTr("Phone"),
                    computer: qsTr("Computer"), watch: qsTr("Watch"),
                })[deviceSheet.device.kind] ?? qsTr("Device")
            }
            FormRow {
                visible: (deviceSheet.device.battery ?? -1) >= 0
                label: qsTr("Battery")
                value: (deviceSheet.device.battery ?? 0) + "%"
            }
            FormRow {
                visible: (deviceSheet.device.version ?? "") !== ""
                label: qsTr("Version")
                value: deviceSheet.device.version ?? ""
            }
        }

        leading: [
            PushButton {
                text: qsTr("Forget This Device…")
                onClicked: {
                    forgetSheet.device = deviceSheet.device;
                    deviceSheet.close();
                    forgetSheet.open = true;
                }
            },
            PushButton {
                readonly property bool connected: (Bluetooth.devices.find(d => d.address === deviceSheet.device.address) ?? {}).connected ?? false
                text: connected ? qsTr("Disconnect") : qsTr("Connect")
                onClicked: connected ? Bluetooth.disconnectDevice(deviceSheet.device.address)
                    : Bluetooth.connectDevice(deviceSheet.device.address)
            }
        ]
        trailing: PushButton {
            text: qsTr("Done")
            primary: true
            onClicked: deviceSheet.close()
        }
    }
    // Forgetting asks first: the device has to be paired again to be used.
    Sheet {
        id: forgetSheet
        property var device: ({})
        settings: page.settings
        sheetWidth: 400
        onAccepted: {
            Bluetooth.forget(device.address);
            close();
        }

        Label {
            width: parent.width
            text: qsTr("Forget “%1”?").arg(forgetSheet.device.name ?? "")
            style: Theme.text.headline
            wrapMode: Text.Wrap
        }
        Label {
            width: parent.width
            text: qsTr("You'll need to pair it again to use it with this computer.")
            color: Theme.color.label.secondary
            wrapMode: Text.Wrap
        }

        trailing: [
            PushButton {
                text: qsTr("Cancel")
                onClicked: forgetSheet.close()
            },
            PushButton {
                text: qsTr("Forget Device")
                primary: true
                onClicked: forgetSheet.accepted()
            }
        ]
    }
}
