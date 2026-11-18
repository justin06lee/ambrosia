pragma Singleton
import QtQml

// An adapter that is on, with nothing paired. A sheet can put devices in
// shotDevices: { name, connected, … }.
QtObject {
    property var shotDevices: []
    readonly property QtObject defaultAdapter: QtObject {
        property bool enabled: true
        property bool discovering: false
        property string name: "shot"
    }
    readonly property var devices: ({ values: shotDevices })
}
