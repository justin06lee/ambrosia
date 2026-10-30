import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings

// A switch, 36 × 16: on, the track takes the accent color and the knob (a
// 20 × 12 capsule, 2 in from the track's edge) slides to the right. It says
// it was toggled; whoever owns the setting sets `checked`.
Item {
    id: control

    property bool checked
    // A pane's own switch, by its name at the top (Wi-Fi, Bluetooth): 44 × 20.
    property bool large: false
    // Slides when it changes; off while what it shows is still being read.
    property bool animated: true
    signal toggled()

    implicitWidth: large ? Look.switchLargeWidth : Look.switchWidth
    implicitHeight: large ? Look.switchLargeHeight : Look.switchHeight
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Keys.onSpacePressed: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        // Under a sheet (disabled there), gray; a sheet's own keeps the accent.
        color: !control.checked ? Look.switchOff : !control.enabled && control.Window.window?.underSheet ? Look.switchInactive : Theme.accent.bg
        Behavior on color { enabled: control.animated; ColorAnimation { duration: Theme.fade.fast } }
    }
    Rectangle {
        y: 2
        x: control.checked ? control.width - width - 2 : 2
        width: control.large ? Look.switchLargeKnob : Look.switchKnob
        height: control.height - 4
        radius: height / 2
        color: Look.knob
        Behavior on x { enabled: control.animated; NumberAnimation { duration: Theme.spring.snappy.duration; easing.type: Easing.OutCubic } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.18
            shadowBlur: 0.2
            shadowVerticalOffset: 0.5
            blurMax: 4
        }
    }
    TapHandler { onTapped: control.toggled() }
}
