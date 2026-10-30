import QtQuick
import Ambrosia
import Settings

// Wi-Fi's Advanced…, as System Settings shows it: Show legacy networks and
// options (WEP and WPA networks in the list, and in Other…), the card's own
// address, and every network saved here in a table, each with its ⋯ menu.
// Left out: Require administrator authorization to change networks or to
// turn Wi-Fi on or off (NetworkManager's polkit rules, which only root can
// write).
Sheet {
    id: sheet

    signal settingsOf(string uuid)
    signal forget(string uuid, string ssid)

    function show() {
        open = true;
    }

    sheetWidth: 470

    Box {
        width: parent.width
        FormRow {
            label: qsTr("Show legacy networks and options")
            Switch {
                checked: WiFi.showLegacy
                onToggled: WiFi.showLegacy = !WiFi.showLegacy
            }
        }
    }
    Box {
        width: parent.width
        visible: WiFi.address !== ""
        FormRow {
            label: qsTr("Wi‑Fi MAC address")
            value: WiFi.address
        }
    }

    SectionHeading {
        width: parent.width
        visible: WiFi.saved.length > 0
        text: qsTr("Known Networks")
    }
    // The networks saved here: a header of Network Name and Security Type,
    // then a row each on alternating fills.
    Rectangle {
        id: table
        visible: WiFi.saved.length > 0
        width: parent.width
        height: Look.tableHeader + WiFi.saved.length * Look.tableRow
        radius: Look.boxRadius
        color: Look.box
        Accessible.role: Accessible.Table

        Rectangle {
            width: parent.width
            height: Look.tableHeader - 1
            topLeftRadius: Look.boxRadius
            topRightRadius: Look.boxRadius
            color: Look.tableFill
        }
        Rectangle {
            y: Look.tableHeader - 1
            width: parent.width
            height: 1
            color: Look.tableRule
        }
        Repeater {
            model: [qsTr("Network Name"), qsTr("Security Type")]
            Label {
                required property int index
                required property string modelData
                x: index === 0 ? 9 : 202.5
                y: (Look.tableHeader - 1 - height) / 2
                text: modelData
                style: Theme.text.caption
            }
        }
        Repeater {
            model: WiFi.saved
            Rectangle {
                id: entry
                required property int index
                required property var modelData
                readonly property bool last: index === WiFi.saved.length - 1
                y: Look.tableHeader + index * Look.tableRow
                width: table.width
                height: Look.tableRow
                color: index % 2 ? Look.tableFill : "transparent"
                bottomLeftRadius: last ? Look.boxRadius : 0
                bottomRightRadius: last ? Look.boxRadius : 0
                Accessible.role: Accessible.Row
                Accessible.name: modelData.ssid

                Glyph {
                    visible: entry.modelData.secure
                    x: 10
                    y: 5.5
                    name: "lock"
                    size: 13
                }
                Label {
                    x: 31
                    width: 192 - x - 6
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: entry.modelData.ssid
                }
                Label {
                    x: 204
                    width: 386 - x - 6
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: ({
                        none: qsTr("None"), owe: qsTr("Enhanced Open"), wep: qsTr("WEP"),
                        "dynamic-wep": qsTr("Dynamic WEP"), wpa1: qsTr("WPA Personal"),
                        wpa: qsTr("WPA2/WPA3 Personal"), sae: qsTr("WPA3 Personal"),
                        enterprise: qsTr("WPA2/WPA3 Enterprise"), enterprise3: qsTr("WPA3 Enterprise"),
                    })[entry.modelData.security] ?? ""
                }
                Glyph {
                    id: moreButton
                    x: 408.25 - size / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: "more"
                    size: 13.4
                    Accessible.role: Accessible.ButtonMenu
                    Accessible.name: qsTr("Show Detail")
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            menu.network = entry.modelData;
                            menu.autoJoin = WiFi.details(entry.modelData.uuid).autoJoin ?? false;
                            menu.openUnder(moreButton);
                        }
                    }
                }
            }
        }
    }

    // A saved network's ⋯, as on the pane's own rows.
    PopupMenu {
        id: menu
        property var network: ({})
        property bool autoJoin
        items: [
            { text: qsTr("Auto-Join"), value: "autoJoin" },
            {},
            { text: qsTr("Copy Password"), value: "copy", enabled: menu.network.secure ?? false },
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
                sheet.settingsOf(network.uuid);
            else
                sheet.forget(network.uuid, network.ssid);
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
    onAccepted: close()
}
