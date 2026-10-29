import QtQuick
import Ambrosia
import Settings

// Wi-Fi, as System Settings lays it out: the pane's own box (its icon,
// name, what it does and its switch) with the network in use under it;
// then the known networks in range and the others, each with its lock and
// signal, a Connect button where pointed. All of it NetworkManager's
// (src/wifi.cpp). Left out: Personal Hotspots and asking to join
// hotspots (an iPhone's), the help button and its Learn More. Not yet:
// Details…, a network's ⋯ menu, Other… and Advanced….
Page {
    id: page

    Component.onCompleted: WiFi.watching = Qt.binding(() => page.visible && WiFi.enabled)
    Component.onDestruction: WiFi.watching = false

    function connect(network) {
        WiFi.join(network.ssid);
    }

    Box {
        Item {
            width: parent.width
            height: 66
            PaneIcon {
                x: 11
                y: 12
                size: 26
                glyph: "wifi"
                tint: "blue"
            }
            Label {
                x: 48
                y: 10
                text: qsTr("Wi‑Fi")
                font.weight: 600
            }
            Label {
                x: 48
                y: 28
                width: 342
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 14
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: qsTr("Set up Wi‑Fi to wirelessly connect your computer to the internet. Turn on Wi‑Fi, then choose a network to join.")
            }
            Switch {
                x: parent.width - Look.boxPadding - width
                y: 9
                large: true
                enabled: !WiFi.blocked
                checked: WiFi.enabled
                onToggled: WiFi.setEnabled(!WiFi.enabled)
                Accessible.name: qsTr("Wi‑Fi")
            }
        }
        // The network in use.
        Item {
            width: parent.width
            height: 52
            visible: WiFi.enabled && WiFi.current.ssid !== undefined
            Label {
                x: Look.boxPadding
                y: 10
                width: 300
                elide: Text.ElideRight
                text: WiFi.current.ssid ?? ""
            }
            Rectangle {
                x: 12.5
                y: 33
                width: 6
                height: 6
                radius: 3
                color: WiFi.current.state === "connected" ? Look.connected : Theme.color.label.tertiary
            }
            Label {
                x: 21
                y: 28
                color: Theme.color.label.secondary
                text: WiFi.current.state === "connected" ? qsTr("Connected") : qsTr("Connecting…")
            }
            NetworkSignal {
                x: 318
                y: 16.3
                pitch: 25
                secure: WiFi.current.secure ?? false
                bars: WiFi.current.bars ?? 3
            }
        }
    }

    SectionHeading {
        visible: knownBox.visible
        text: WiFi.known.length === 1 ? qsTr("Known Network") : qsTr("Known Networks")
    }
    Box {
        id: knownBox
        visible: WiFi.enabled && WiFi.known.length > 0
        Repeater {
            model: WiFi.known
            NetworkRow {
                required property var modelData
                network: modelData
                known: true
                onConnect: page.connect(modelData)
            }
        }
    }

    SectionHeading {
        visible: WiFi.enabled
        text: qsTr("Other Networks")
        Spinner {
            x: parent.width - 12 - width
            anchors.bottom: parent.bottom
            running: WiFi.scanning
        }
    }
    Box {
        visible: WiFi.enabled && WiFi.others.length > 0
        Repeater {
            model: WiFi.others
            NetworkRow {
                required property var modelData
                network: modelData
                onConnect: page.connect(modelData)
            }
        }
    }
}
