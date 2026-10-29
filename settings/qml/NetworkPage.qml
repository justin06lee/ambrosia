import QtQuick
import Ambrosia
import Settings

// Network, as System Settings lays it out: the services connected, the
// VPNs, then Other Services. No Firewall row: Ambrosia ships no firewall
// (docs/settings/PLAN.md). The ⋯ menu (add a service, its order) waits on
// the Mac's to be captured.
Page {
    id: page

    Box {
        visible: Network.connected.length > 0
        Repeater {
            model: Network.connected
            ServiceRow {
                required property var modelData
                settings: page.settings
                service: modelData
            }
        }
    }
    Box {
        visible: Network.vpn.state !== undefined
        ServiceRow {
            settings: page.settings
            service: ({ name: qsTr("VPN"), kind: "vpn", state: Network.vpn.state ?? "" })
        }
    }

    SectionHeading {
        visible: othersBox.visible
        first: Network.connected.length === 0 && Network.vpn.state === undefined
        text: qsTr("Other Services")
    }
    Box {
        id: othersBox
        visible: Network.others.length > 0
        Repeater {
            model: Network.others
            ServiceRow {
                required property var modelData
                settings: page.settings
                service: modelData
            }
        }
    }
}
