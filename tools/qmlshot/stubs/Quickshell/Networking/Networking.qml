pragma Singleton
import QtQml

// Wi-Fi on and joined to one network, with two more in the air. A sheet can
// change shotNetworks: { name, connected, known, signalStrength, security }.
QtObject {
    id: networking

    property bool wifiEnabled: true
    property var shotNetworks: [
        { name: "Nectar", connected: true, known: true, signalStrength: 0.9, security: 3 },
        { name: "Ambrosia Guest", connected: false, known: false, signalStrength: 0.6, security: 10 },
        { name: "Olympus 5G", connected: false, known: false, signalStrength: 0.4, security: 3 },
    ]
    readonly property QtObject shotWifi: QtObject {
        readonly property int type: 1
        property bool scannerEnabled: false
        readonly property bool connected: networking.shotNetworks.some(network => network.connected)
        readonly property var networks: ({ values: networking.shotNetworks })
    }
    readonly property var devices: ({ values: [shotWifi] })
}
