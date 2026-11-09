import QtQuick
import Ambrosia
import Settings

// Network's VPN, as System Settings has it: each VPN NetworkManager holds with
// its state and switch; ⓘ and + open KDE's connection editor, which knows every
// VPN's own settings. Left out: About VPNs & Privacy… (Apple's text), how long
// it's been connected (NetworkManager doesn't say) and the help button.
Page {
    id: page

    Box {
        visible: Network.vpns.length > 0
        Repeater {
            model: Network.vpns
            Item {
                id: vpn
                required property var modelData
                width: parent.width
                height: 52
                PaneIcon {
                    x: 11
                    y: 12
                    size: 26
                    glyph: "network"
                    tint: "blue"
                }
                Label {
                    x: 48.5
                    y: 10.5
                    width: toggle.x - x - 8
                    text: vpn.modelData.name
                    elide: Text.ElideRight
                }
                StatusLine {
                    x: 49
                    y: 28.5
                    state: vpn.modelData.state
                }
                Switch {
                    id: toggle
                    x: info.x - width - 10
                    anchors.verticalCenter: parent.verticalCenter
                    checked: vpn.modelData.state !== "disconnected"
                    onToggled: Network.setVpnActive(vpn.modelData.uuid, !checked)
                    Accessible.name: vpn.modelData.name
                }
                Glyph {
                    id: info
                    x: parent.width - 11 - width
                    anchors.verticalCenter: parent.verticalCenter
                    name: "info"
                    size: 17
                    color: Theme.color.label.secondary
                    MouseArea { anchors.fill: parent; onClicked: App.openModule("kcm_networkmanagement") }
                }
            }
        }
    }
    Item {
        width: Look.boxWidth
        height: Look.popupHeight + Look.boxGap
        PushButton {
            x: parent.width - width
            y: Look.boxGap
            text: qsTr("Add VPN…")
            onClicked: App.openModule("kcm_networkmanagement")
        }
    }
}
