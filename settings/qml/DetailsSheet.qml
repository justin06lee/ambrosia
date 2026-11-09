import QtQuick
import Ambrosia
import Settings

// A Details… sheet, Wi-Fi's (a known network's Network Settings…) or a network
// service's, as System Settings shows it: a sidebar of the network, TCP/IP,
// DNS and Hardware; what's changed kept until OK (source.applyDetails), Cancel
// dropping it.
// Left out: WINS (Windows file sharing's), 802.1X (the Mac takes only
// Apple's configuration profiles there), Proxies (apps don't read
// NetworkManager's), Limit IP address tracking (Apple's own) and Renew DHCP
// Lease (NetworkManager renews only by joining again).
Sheet {
    id: sheet

    // WiFi or Network: where details and applyDetails are.
    property var source: WiFi
    readonly property bool wifi: source === WiFi
    property string glyph: "wifi"
    property string tint: "blue"
    // What the sidebar calls it, if not the network's own name.
    property string name
    property string uuid
    property var details: ({})
    property var changes: ({})
    property string page: "network"
    readonly property var shown: Object.assign({}, details, changes)
    readonly property bool inUse: details.ip !== undefined
    signal forget(string uuid, string ssid)

    function show(uuid) {
        sheet.uuid = uuid;
        details = source.details(uuid);
        changes = {};
        page = "network";
        open = true;
    }
    function change(key, value) {
        const next = Object.assign({}, changes);
        next[key] = value;
        changes = next;
    }
    function chooseIpv4(method) {
        change("ipv4Method", method);
        // Manually starts from the address in use, as on a Mac.
        if (method === "manual" && !shown.manualIp) {
            change("manualIp", details.ip ?? "");
            change("manualSubnet", details.subnet ?? "255.255.255.0");
            change("manualRouter", details.router ?? "");
        }
    }

    sheetWidth: 670
    pageX: 208
    bodyHeight: 360
    onAccepted: {
        source.applyDetails(uuid, changes);
        close();
    }
    Connections {
        target: sheet.source
        function onDetailsChanged() {
            if (sheet.open)
                sheet.details = sheet.source.details(sheet.uuid);
        }
    }

    side: Column {
        x: 10
        y: 10
        width: parent.width - 20
        Repeater {
            model: [
                { id: "network" },
                { id: "tcpip", name: qsTr("TCP/IP") },
                { id: "dns", name: qsTr("DNS") },
                { id: "hardware", name: qsTr("Hardware") },
            ]
            Rectangle {
                id: entry
                required property var modelData
                readonly property bool network: modelData.id === "network"
                readonly property bool chosen: sheet.page === modelData.id
                width: parent.width
                height: network ? 47.5 : Look.row
                radius: Look.rowRadius
                color: chosen ? Theme.accent.bg : "transparent"
                PaneIcon {
                    visible: entry.network
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: 28
                    glyph: sheet.glyph
                    tint: sheet.tint
                }
                Label {
                    x: entry.network ? 40 : 6
                    y: entry.network ? 8 : (parent.height - height) / 2
                    width: parent.width - x - 6
                    elide: Text.ElideRight
                    text: entry.network ? (sheet.name || (sheet.shown.ssid ?? "")) : entry.modelData.name
                    font.weight: entry.network ? 600 : 400
                    color: entry.chosen ? Theme.accent.fg : Theme.color.label.primary
                }
                Rectangle {
                    visible: entry.network
                    x: 41
                    y: 29
                    width: 8.5
                    height: width
                    radius: width / 2
                    color: sheet.inUse ? Look.connected : Theme.color.label.tertiary
                }
                Label {
                    visible: entry.network
                    x: 53.5
                    y: 25.5
                    style: Theme.text.caption
                    text: sheet.inUse ? qsTr("Connected") : qsTr("Not Connected")
                    color: entry.chosen ? Theme.accent.fg : Theme.color.label.secondary
                }
                MouseArea { anchors.fill: parent; onClicked: sheet.page = entry.modelData.id }
            }
        }
    }

    // The network's own page.
    Box {
        visible: sheet.page === "network" && sheet.wifi
        width: parent.width
        FormRow {
            label: qsTr("Automatically join this network")
            Switch {
                checked: sheet.shown.autoJoin ?? false
                onToggled: sheet.change("autoJoin", !checked)
            }
        }
    }
    Box {
        visible: sheet.page === "network" && sheet.wifi
        width: parent.width
        FormRow {
            label: qsTr("Private Wi‑Fi address")
            description: qsTr("Using a private address helps reduce tracking of your computer by Wi‑Fi network operators. A fixed private address allows this network to track this computer, but helps reduce tracking across other networks.")
            firstLine: Look.popupHeight
            PopUpButton {
                items: [
                    { text: qsTr("Off"), value: "off" },
                    { text: qsTr("Fixed"), value: "fixed" },
                    { text: qsTr("Rotating"), value: "rotating" },
                ]
                current: sheet.shown.privateAddress
                onChosen: (value) => sheet.change("privateAddress", value)
            }
        }
        // A private address is known once joined with it.
        FormRow {
            visible: sheet.inUse || sheet.shown.privateAddress === "off"
            label: qsTr("Wi‑Fi address")
            value: (sheet.inUse ? sheet.details.address : sheet.details.mac) ?? ""
        }
    }
    // A service's: its name, which the list and its page go by.
    Box {
        visible: sheet.page === "network" && !sheet.wifi
        width: parent.width
        FormRow {
            label: qsTr("Name")
            NameField {
                width: 350
                ring: false
                value: sheet.name
                onCommitted: (text) => sheet.change("name", text)
            }
        }
    }
    Box {
        visible: sheet.page === "network" && sheet.wifi
        width: parent.width
        FormRow {
            label: qsTr("Low data mode")
            description: qsTr("Low data mode helps reduce your computer's data usage over specific Wi‑Fi networks you select.")
            firstLine: Look.switchHeight
            Switch {
                checked: sheet.shown.lowData ?? false
                onToggled: sheet.change("lowData", !checked)
            }
        }
    }
    Box {
        visible: sheet.page === "network" && sheet.wifi && sheet.inUse
        width: parent.width
        FormRow { label: qsTr("IP address"); value: sheet.details.ip ?? "" }
        FormRow {
            visible: (sheet.details.router ?? "") !== ""
            label: qsTr("Router")
            value: sheet.details.router ?? ""
        }
    }

    // TCP/IP.
    Box {
        visible: sheet.page === "tcpip"
        width: parent.width
        FormRow {
            label: qsTr("Configure IPv4")
            PopUpButton {
                items: [
                    { text: qsTr("Using DHCP"), value: "dhcp" },
                    { text: qsTr("Manually"), value: "manual" },
                    { text: qsTr("Off"), value: "off" },
                ]
                current: sheet.shown.ipv4Method
                onChosen: (value) => sheet.chooseIpv4(value)
            }
        }
        Repeater {
            model: [
                { label: qsTr("IP address"), key: "manualIp", now: "ip" },
                { label: qsTr("Subnet mask"), key: "manualSubnet", now: "subnet" },
                { label: qsTr("Router"), key: "manualRouter", now: "router" },
            ]
            FormRow {
                id: addressRow
                required property var modelData
                readonly property bool manual: sheet.shown.ipv4Method === "manual"
                visible: manual || sheet.shown.ipv4Method === "dhcp" && (sheet.details[modelData.now] ?? "") !== ""
                label: modelData.label
                value: manual ? "" : (sheet.details[modelData.now] ?? "")
                NameField {
                    visible: addressRow.manual
                    width: 200
                    value: sheet.shown[addressRow.modelData.key] ?? ""
                    onCommitted: (text) => sheet.change(addressRow.modelData.key, text)
                }
            }
        }
    }
    Box {
        visible: sheet.page === "tcpip" && sheet.shown.ipv4Method === "dhcp"
        width: parent.width
        FormRow {
            label: qsTr("DHCP client ID (if required)")
            NameField {
                width: 210
                placeholder: qsTr("DHCP client ID")
                value: sheet.shown.clientId ?? ""
                onCommitted: (text) => sheet.change("clientId", text)
            }
        }
    }
    Box {
        visible: sheet.page === "tcpip"
        width: parent.width
        FormRow {
            label: qsTr("Configure IPv6")
            PopUpButton {
                items: [
                    { text: qsTr("Automatically"), value: "auto" },
                    { text: qsTr("Link-local only"), value: "link-local" },
                    { text: qsTr("Off"), value: "off" },
                ]
                current: sheet.shown.ipv6Method
                onChosen: (value) => sheet.change("ipv6Method", value)
            }
        }
        FormRow {
            visible: sheet.inUse && (sheet.details.ipv6Router ?? "") !== ""
            label: qsTr("Router")
            value: sheet.details.ipv6Router ?? ""
        }
    }
    Box {
        visible: sheet.page === "tcpip" && (sheet.details.ipv6 ?? []).length > 0
        width: parent.width
        FormRow { label: qsTr("IPv6 address"); value: qsTr("Prefix length") }
        Repeater {
            model: sheet.details.ipv6 ?? []
            FormRow {
                required property var modelData
                label: modelData.address
                value: modelData.prefix
            }
        }
    }

    // DNS: servers and search domains typed in replace the network's own.
    Repeater {
        model: [
            { title: qsTr("DNS Servers"), caption: qsTr("IP addresses"), key: "dnsServers", now: "dns" },
            { title: qsTr("Search Domains"), caption: "", key: "searchDomains", now: "domains" },
        ]
        Column {
            id: dnsPart
            required property var modelData
            visible: sheet.page === "dns"
            width: parent.width
            spacing: 6
            Column {
                x: Look.boxPadding
                Label { text: dnsPart.modelData.title; font.weight: 600 }
                Label {
                    visible: dnsPart.modelData.caption !== ""
                    text: dnsPart.modelData.caption
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                }
            }
            EditList {
                items: sheet.shown[dnsPart.modelData.key] ?? []
                fallback: sheet.details[dnsPart.modelData.now] ?? []
                onEdited: (items) => sheet.change(dnsPart.modelData.key, items)
            }
        }
    }

    // Hardware: its own address, and the MTU, standard or typed.
    Box {
        visible: sheet.page === "hardware"
        width: parent.width
        FormRow { label: qsTr("MAC address"); value: sheet.details.mac ?? "" }
        FormRow {
            label: qsTr("MTU")
            PopUpButton {
                items: [
                    { text: qsTr("Standard (1500)"), value: "standard" },
                    { text: qsTr("Custom"), value: "custom" },
                ]
                current: (sheet.shown.mtu ?? 0) > 0 ? "custom" : "standard"
                onChosen: (value) => sheet.change("mtu", value === "custom" ? 1500 : 0)
            }
        }
        FormRow {
            visible: (sheet.shown.mtu ?? 0) > 0
            label: qsTr("Custom MTU")
            NameField {
                id: mtuField
                width: 100
                value: String(sheet.shown.mtu ?? "")
                onCommitted: (typed) => {
                    const mtu = parseInt(typed);
                    if (mtu >= 576 && mtu <= 9000)
                        sheet.change("mtu", mtu);
                    else
                        mtuField.text = mtuField.value;
                }
            }
        }
    }

    leading: PushButton {
        visible: sheet.wifi
        text: qsTr("Forget This Network…")
        onClicked: {
            sheet.close();
            sheet.forget(sheet.uuid, sheet.shown.ssid ?? "");
        }
    }
    trailing: [
        PushButton {
            id: cancelButton
            text: qsTr("Cancel")
            onClicked: sheet.close()
        },
        PushButton {
            text: qsTr("OK")
            minimumWidth: cancelButton.implicitWidth
            primary: true
            onClicked: sheet.accepted()
        },
    ]
}
