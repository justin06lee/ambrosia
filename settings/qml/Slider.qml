import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings

// A slider, 200 wide unless told otherwise: a 6 point track filled in the
// accent color up to a 20 × 16 white knob; tick marks under it, glyphs at
// its ends (Sound's speakers) and captions under them (Balance's Left and
// Right). `value` runs from 0 to 1; dragging or clicking says where it
// moved, and whoever owns the setting sets it. The knob stops only on the
// ticks if it `snaps`.
Item {
    id: slider

    property real value: 0
    property int ticks: 0
    property bool snaps: false
    property real trackWidth: Look.sliderWidth
    property var captions: [] // [under the start, under the end]
    property string minGlyph
    property string maxGlyph
    signal moved(real value)

    readonly property real lead: minGlyph !== "" ? 20 : 0
    implicitWidth: lead + trackWidth + (maxGlyph !== "" ? 23 : 0)
    implicitHeight: captions.length > 0 ? 31 : ticks > 0 ? 24 : Look.sliderKnobHeight
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Slider

    Glyph {
        visible: slider.minGlyph !== ""
        y: (Look.sliderKnobHeight - height) / 2
        name: slider.minGlyph
        size: 13
        color: Theme.color.label.secondary
    }
    Item {
        id: groove
        x: slider.lead
        width: slider.trackWidth
        height: Look.sliderKnobHeight

        Rectangle {
            y: (parent.height - height) / 2
            width: parent.width
            height: Look.sliderTrack
            radius: height / 2
            color: Look.track
        }
        Rectangle {
            y: (parent.height - height) / 2
            width: knob.x + knob.width / 2
            height: Look.sliderTrack
            radius: height / 2
            color: Theme.accent.bg
        }
        Repeater {
            model: slider.ticks
            Rectangle {
                required property int index
                x: Look.sliderKnobWidth / 2 + index * (groove.width - Look.sliderKnobWidth) / Math.max(1, slider.ticks - 1) - width / 2
                y: groove.height + 3
                width: 1.5
                height: 4
                radius: 0.75
                color: Theme.color.label.tertiary
            }
        }
        Rectangle {
            id: knob
            x: Math.max(0, Math.min(1, slider.value)) * (groove.width - width)
            width: Look.sliderKnobWidth
            height: Look.sliderKnobHeight
            radius: height / 2
            color: "white"
            border.width: 0.5
            border.color: "#1a000000"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.22
                shadowBlur: 0.25
                shadowVerticalOffset: 0.5
                blurMax: 6
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            function place(mx) {
                let v = (mx - 4 - Look.sliderKnobWidth / 2) / (groove.width - Look.sliderKnobWidth);
                v = Math.max(0, Math.min(1, v));
                if (slider.snaps && slider.ticks > 1)
                    v = Math.round(v * (slider.ticks - 1)) / (slider.ticks - 1);
                slider.moved(v);
            }
            onPressed: (mouse) => place(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) place(mouse.x); }
        }
    }
    Glyph {
        visible: slider.maxGlyph !== ""
        x: groove.x + groove.width + 6
        y: (Look.sliderKnobHeight - height) / 2
        name: slider.maxGlyph
        size: 17
        color: Theme.color.label.secondary
    }
    Repeater {
        model: slider.captions
        Label {
            required property int index
            required property string modelData
            x: index === 0 ? groove.x : groove.x + groove.width - width
            y: Look.sliderKnobHeight + 1
            text: modelData
            style: Theme.text.caption
        }
    }
}
