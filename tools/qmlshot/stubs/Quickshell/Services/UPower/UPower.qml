pragma Singleton
import QtQml

// A laptop on its battery, most of the way full.
QtObject {
    readonly property bool onBattery: true
    readonly property QtObject displayDevice: QtObject {
        property bool isLaptopBattery: true
        property bool ready: true
        property real percentage: 0.82
        property int state: 2
    }
}
