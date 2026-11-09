import QtQuick
import Ambrosia
import Settings

// A Wi-Fi network in a list, as System Settings has it: its name, with
// room before it for the check by the one in use; a lock if it takes a
// password and its signal at the right; pointed at, a Connect button left
// of them, and its ⋯ right of them. Known networks' rows are 40 tall,
// others' 44.
Item {
    id: row

    required property var network
    property bool known: false
    signal connect()
    signal more(Item button)

    width: parent ? parent.width : Look.boxWidth
    height: known ? 40 : 44
    Accessible.role: Accessible.ListItem
    Accessible.name: network.ssid

    HoverHandler { id: hover }

    Glyph {
        visible: row.network.current
        x: 18.2
        y: (row.height - 16) / 2 + 0.5
        name: "tick"
        size: 16
    }
    Label {
        x: 41
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
    Glyph {
        id: moreButton
        x: 421.5 - (size - 17) / 2
        anchors.verticalCenter: parent.verticalCenter
        name: "more"
        size: 18.7
        color: Theme.color.label.secondary
        Accessible.role: Accessible.ButtonMenu
        Accessible.name: qsTr("Show Detail")
        MouseArea { anchors.fill: parent; onClicked: row.more(moreButton) }
    }
}
