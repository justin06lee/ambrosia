import QtQuick
import Ambrosia
import Settings

// A network service, as System Settings' Network lists them: its icon, its
// name, a dot and whether it's connected under it, and a chevron. Wi-Fi
// opens its own pane; the rest open KDE's connection editor until their
// pages are built.
Item {
    id: row

    required property var settings
    // {name, kind, state}, as Network gives them.
    required property var service

    readonly property var look: ({
        wifi: { glyph: "wifi", tint: "blue" },
        ethernet: { glyph: "ethernet", tint: "gray" },
        bluetooth: { glyph: "bluetooth", tint: "blue" },
        modem: { glyph: "cellular", tint: "green" },
        vpn: { glyph: "network", tint: "blue" },
    })[service.kind] ?? { glyph: "ethernet", tint: "gray" }

    width: parent ? parent.width : Look.boxWidth
    height: 52

    PaneIcon {
        x: 11
        y: 12
        size: 26
        glyph: row.look.glyph
        tint: row.look.tint
    }
    Label {
        x: 48.5
        y: 10
        width: chevron.x - x - 8
        text: row.service.name
        elide: Text.ElideRight
    }
    Rectangle {
        x: 49.25
        y: 30.75
        width: 8
        height: 8
        radius: 4
        color: row.service.state === "connected" ? Look.connected
            : row.service.state === "connecting" ? Look.connecting : Look.notConnected
    }
    Label {
        x: 62
        y: 27.5
        color: Theme.color.label.secondary
        text: ({
            connected: qsTr("Connected"),
            connecting: qsTr("Connecting…"),
            off: qsTr("Off"),
        })[row.service.state] ?? qsTr("Not connected")
    }
    Glyph {
        id: chevron
        x: row.width - Look.chevronRight - width + 3
        anchors.verticalCenter: parent.verticalCenter
        name: "chevronRight"
        size: 12
        color: Theme.color.label.tertiary
    }
    TapHandler {
        onTapped: row.service.kind === "wifi" ? row.settings.choose("wifi") : App.openModule("kcm_networkmanagement")
    }
}
