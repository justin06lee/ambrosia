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
}
