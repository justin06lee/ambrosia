import QtQuick
import Ambrosia
import Settings

// A network service, as System Settings' Network lists them: its icon, its
// name, a dot and whether it's connected under it, and a chevron. Each opens
// its page: Wi-Fi's pane, the VPNs', or the service's own. Plain, at the top
// of that page, it's only the name and state.
Item {
    id: row

    required property var settings
    // {name, kind, state}, as Network gives them.
    required property var service
    property bool plain: false
    property real topInset: 0

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
        y: 12 + row.topInset
        size: 26
        glyph: row.look.glyph
        tint: row.look.tint
    }
    Label {
        x: 48.5
        y: 10.5 + row.topInset
        width: chevron.x - x - 8
        text: row.service.name
        elide: Text.ElideRight
    }
    StatusLine {
        x: 49
        y: 28.5 + row.topInset
        state: row.service.state ?? ""
    }
    Glyph {
        id: chevron
        visible: !row.plain
        x: row.width - 21
        y: 19.5
        name: "chevronRight"
        size: 14
        color: Theme.color.label.tertiary
    }
    MouseArea {
        visible: !row.plain
        anchors.fill: parent
        onClicked: row.settings.choose(row.service.kind === "wifi" ? "wifi" : row.service.kind === "vpn" ? "network-vpn" : "network-service?" + row.service.id)
    }
}
