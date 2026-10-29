import QtQuick
import Ambrosia
import Settings

// A Wi-Fi network in a list, as System Settings has it: its name (a check
// before it for the one in use, among known networks), a lock if it takes
// a password and its signal at the right; pointed at, a Connect button
// left of them. Known networks' rows are 37 tall, others' 45.
Item {
    id: row

    required property var network
    property bool known: false
    signal connect()

    width: parent ? parent.width : Look.boxWidth
    height: known ? Look.textRow + 1 : 45
    Accessible.role: Accessible.ListItem
    Accessible.name: network.ssid

    HoverHandler { id: hover }

    Glyph {
        visible: row.network.current
        x: 18.2
        y: (row.height - 16) / 2 + 0.2
        name: "tick"
        size: 16
    }
    Label {
        x: row.known ? 41 : 21
        anchors.verticalCenter: parent.verticalCenter
        width: connectButton.x - x - 8
        text: row.network.ssid
        elide: Text.ElideRight
    }
    PushButton {
        id: connectButton
        x: 291
        anchors.verticalCenter: parent.verticalCenter
        width: 76
        visible: hover.hovered && !row.network.current
        text: qsTr("Connect")
        onClicked: row.connect()
    }
    NetworkSignal {
        x: 374
        anchors.verticalCenter: parent.verticalCenter
        secure: row.network.secure
        bars: row.network.bars
    }
}
