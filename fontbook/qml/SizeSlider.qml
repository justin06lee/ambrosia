import QtQuick
import Ambrosia
import FontBook

// How large the fonts are shown: a small A, a track 68.5 long with a knob
// 16 by 12, a large A. A press on either A steps a tenth; the knob follows
// the pointer.
Item {
    id: slider

    required property Window window
    // 0 to 1.
    property real value: 0.5
    signal moved(real value)

    readonly property real trackX: 26.5
    readonly property real trackWidth: 68.5
    readonly property real knobWidth: 16
    readonly property color ink: window.looksActive ? Look.glyph : Look.glyphInactive

    width: 117
    height: Look.control

    function set(to) {
        slider.moved(Math.max(0, Math.min(1, to)));
    }

    Label {
        x: 10.5
        anchors.verticalCenter: parent.verticalCenter
        text: "A"
        font.pixelSize: 9
        font.weight: 600
        color: slider.ink
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: slider.set(slider.value - 0.1) }
    }
    Rectangle {
        x: slider.trackX
        anchors.verticalCenter: parent.verticalCenter
        width: slider.trackWidth
        height: 4
        radius: 2
        color: Look.track
        Rectangle {
            width: knob.x - slider.trackX + slider.knobWidth / 2
            height: parent.height
            radius: 2
            color: slider.window.looksActive ? Look.trackFilledActive : Look.trackFilled
        }
    }
    Rectangle {
        id: knob
        x: slider.trackX + slider.value * (slider.trackWidth - slider.knobWidth)
        anchors.verticalCenter: parent.verticalCenter
        width: slider.knobWidth
        height: 12
        radius: 6
        color: Look.knob
        border.width: Look.dark ? 0 : 0.5
        border.color: "#30000000"
    }
    MouseArea {
        x: slider.trackX - 4
        width: slider.trackWidth + 8
        height: parent.height
        function at(mouseX) {
            slider.set((mouseX - 4 - slider.knobWidth / 2) / (slider.trackWidth - slider.knobWidth));
        }
        onPressed: (mouse) => at(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) at(mouse.x); }
    }
    Label {
        x: 101
        anchors.verticalCenter: parent.verticalCenter
        text: "A"
        font.pixelSize: 13
        font.weight: 600
        color: slider.ink
        MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: slider.set(slider.value + 0.1) }
    }
}
