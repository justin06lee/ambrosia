import QtQuick
import Ambrosia
import Settings

// A Bluetooth device in a list, as System Settings has it: what it is, its
// name and, for one paired with this computer, whether it's connected;
// pointed at, Connect or Disconnect, and a spinner while it pairs or
// connects; a paired one's ⓘ opens its sheet. Paired devices' rows are 57
// tall, nearby ones' 44.
Item {
    id: row

    required property var device
    property bool paired: false
    signal toggle()
    signal info()

    width: parent ? parent.width : Look.boxWidth
    height: paired ? 57 : 44
    Accessible.role: Accessible.ListItem
    Accessible.name: device.name

    HoverHandler { id: hover }

    Glyph {
        x: 9
        y: (row.height - size) / 2 + 0.5
        name: row.device.kind
        size: 30
        color: Theme.color.label.secondary
    }
    Label {
        x: 48
        y: row.paired ? 14 : (row.height - height) / 2
        width: button.x - x - 8
        elide: Text.ElideRight
        text: row.device.name
    }
    Label {
        visible: row.paired
        x: 48
        y: 32
        style: Theme.text.callout
        color: Theme.color.label.secondary
        text: row.device.busy ? qsTr("Connecting…") : row.device.connected ? qsTr("Connected") : qsTr("Not Connected")
    }
    // Paired rows keep their controls on the name's line, as the ⓘ is.
    PushButton {
        id: button
        x: 422.5 - width
        y: row.paired ? 10.25 : (row.height - height) / 2
        visible: hover.hovered && !row.device.busy
        text: row.device.connected ? qsTr("Disconnect") : qsTr("Connect")
        onClicked: row.toggle()
    }
    Glyph {
        visible: row.paired
        x: 431.5 - (size - 17) / 2
        y: 13.5 - (size - 17) / 2
        name: "info"
        size: 18.7
        color: Theme.color.label.secondary
        TapHandler { onTapped: row.info() }
    }
    Spinner {
        x: 422.5 - width
        y: row.paired ? 14.25 : (row.height - height) / 2
        running: row.device.busy
    }
}
