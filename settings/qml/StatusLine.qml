import QtQuick
import Ambrosia
import Settings

// A service's state under its name: a dot, and what it's doing in caption text.
Item {
    id: line

    property string state

    implicitWidth: 12.5 + label.implicitWidth
    implicitHeight: label.implicitHeight

    Rectangle {
        y: 2
        width: 8.25
        height: 8.25
        radius: 4.125
        color: line.state === "connected" ? Look.connected
            : line.state === "connecting" ? Look.connecting : Look.notConnected
    }
    Label {
        id: label
        x: 12.5
        style: Theme.text.caption
        color: Theme.color.label.secondary
        text: ({
            connected: qsTr("Connected"),
            connecting: qsTr("Connecting…"),
            off: qsTr("Off"),
            inactive: qsTr("Inactive"),
            unconfigured: qsTr("Not configured"),
        })[line.state] ?? qsTr("Not connected")
    }
}
