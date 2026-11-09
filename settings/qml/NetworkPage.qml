import QtQuick
import Ambrosia
import Settings

// Network, as System Settings lays it out: the services connected, the
// VPNs, then Other Services. No Firewall row: Ambrosia ships no firewall
// (docs/settings/PLAN.md). The ⋯ menu's Add Service… and Add VPN Configuration
// open KDE's connection editor. Left out of it: Manage Virtual Interfaces…,
// Set Service Order… and Locations (nothing on our side acts on them yet).
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
    Item {
        width: Look.boxWidth
        height: Look.popupHeight + Look.boxGap
        MoreButton {
            id: moreButton
            x: parent.width - width
            y: Look.boxGap
            onClicked: moreMenu.openUnder(moreButton)
        }
    }
    PopupMenu {
        id: moreMenu
        items: [
            { text: qsTr("Add Service…"), value: "add" },
            { text: qsTr("Add VPN Configuration…"), value: "vpn" },
        ]
        onChosen: App.openModule("kcm_networkmanagement")
    }
}
