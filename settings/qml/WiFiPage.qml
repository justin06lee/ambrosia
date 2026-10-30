import QtQuick
import Ambrosia
import Settings

// Wi-Fi, as System Settings lays it out: the pane's own box (its icon,
// name, what it does and its switch) with the network in use under it;
// then the known networks in range and the others, each with its lock and
// signal, a Connect button where pointed; Details… on the one in use and a
// known one's ⋯ menu open its settings (WiFiDetailsSheet); Other… adds a
// network by name (WiFiOtherSheet), Advanced… lists every one saved
// (WiFiAdvancedSheet). All of it NetworkManager's (src/wifi.cpp). Left out:
// Personal Hotspots and asking to join hotspots (an iPhone's), asking to
// join networks (NetworkManager never asks), the help button and its Learn
// More. Not yet: other networks' ⋯ menu.
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
            height: 65.5
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
        // The network in use, laid from the top.
        Item {
            width: parent.width
            height: 54
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
                y: 31
                width: 10
                height: 10
                radius: 5
                color: WiFi.current.state === "connected" ? Look.connected : Theme.color.label.tertiary
            }
            Label {
                x: 28.5
                y: 28
                color: Theme.color.label.secondary
                text: WiFi.current.state === "connected" ? qsTr("Connected") : qsTr("Connecting…")
            }
            NetworkSignal {
                x: 318
                y: 15
                pitch: 25
                secure: WiFi.current.secure ?? false
                bars: WiFi.current.bars ?? 3
            }
            PushButton {
                x: parent.width - Look.boxPadding - width
                y: 10
                width: 76
                text: qsTr("Details…")
                onClicked: detailsSheet.show(WiFi.current.uuid)
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
                onMore: (button) => {
                    knownMenu.network = modelData;
                    knownMenu.autoJoin = WiFi.details(modelData.uuid).autoJoin ?? false;
                    knownMenu.openUnder(button);
                }
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
    Item {
        width: Look.boxWidth
        height: Look.popupHeight
        visible: WiFi.enabled
        PushButton {
            x: parent.width - width
            text: qsTr("Other…")
            onClicked: otherSheet.show()
        }
    }
    // 20 under what's above, as the page's foot.
    Item {
        width: Look.boxWidth
        height: Look.popupHeight + Look.boxGap
        visible: WiFi.available
        PushButton {
            x: parent.width - width
            y: Look.boxGap
            text: qsTr("Advanced…")
            onClicked: advancedSheet.show()
        }
    }

    // A known network's ⋯: Auto-Join, Copy Password, Network Settings…
    // (its Details… sheet) and Forget This Network….
    PopupMenu {
        id: knownMenu
        property var network: ({})
        property bool autoJoin
        items: [
            { text: qsTr("Auto-Join"), value: "autoJoin" },
            {},
            { text: qsTr("Copy Password"), value: "copy", enabled: knownMenu.network.secure ?? false },
            { text: qsTr("Network Settings…"), value: "settings" },
            {},
            { text: qsTr("Forget This Network…"), value: "forget" },
        ]
        current: autoJoin ? "autoJoin" : undefined
        onChosen: (value) => {
            if (value === "autoJoin")
                WiFi.applyDetails(network.uuid, { autoJoin: !autoJoin });
            else if (value === "copy")
                WiFi.copyPassword(network.uuid);
            else if (value === "settings")
                detailsSheet.show(network.uuid);
            else
                page.askForget(network.uuid, network.ssid);
        }
    }

    function askForget(uuid, ssid) {
        forgetSheet.uuid = uuid;
        forgetSheet.ssid = ssid;
        forgetSheet.open = true;
    }

    WiFiOtherSheet {
        id: otherSheet
        settings: page.settings
    }
    WiFiAdvancedSheet {
        id: advancedSheet
        settings: page.settings
        onForget: (uuid, ssid) => page.askForget(uuid, ssid)
    }
    WiFiDetailsSheet {
        id: detailsSheet
        settings: page.settings
        onForget: (uuid, ssid) => page.askForget(uuid, ssid)
    }
    // Forgetting asks first: the password has to be typed again to join.
    Sheet {
        id: forgetSheet
        property string uuid
        property string ssid
        settings: page.settings
        sheetWidth: 400
        onAccepted: {
            WiFi.forget(uuid);
            close();
        }

        Label {
            width: parent.width
            text: qsTr("Forget “%1”?").arg(forgetSheet.ssid)
            style: Theme.text.headline
            wrapMode: Text.Wrap
        }
        Label {
            width: parent.width
            text: qsTr("This computer will no longer join this Wi‑Fi network on its own.")
            color: Theme.color.label.secondary
            wrapMode: Text.Wrap
        }

        trailing: [
            PushButton {
                text: qsTr("Cancel")
                onClicked: forgetSheet.close()
            },
            PushButton {
                text: qsTr("Forget")
                primary: true
                onClicked: forgetSheet.accepted()
            }
        ]
    }
}
