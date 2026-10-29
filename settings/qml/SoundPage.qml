import QtQuick
import Ambrosia
import Settings

// Sound, as System Settings lays it out: alerts (their sound theme, device
// and volume) and the volume-change feedback; then Output & Input, the
// devices in a table, and the chosen one's volume, mute and balance, or its
// volume and level. Everything is the system's own (src/sound.cpp:
// PipeWire through its PulseAudio server, KDE's sound theme, plasma-pa).
// Left out: the startup chime and interface sounds, which Linux hasn't.
Page {
    id: page

    property string side: "output"

    // A level in decibels, -60 to 0, across the meter.
    function loudness(peak) {
        return peak <= 0.001 ? 0 : Math.max(0, Math.min(1, 1 + Math.log10(peak) * 20 / 60));
    }

    // Opened as sound?input or sound?output, that side is shown.
    function reveal(anchor) {
        if (anchor === "input" || anchor === "output")
            side = anchor;
    }
    Connections {
        target: page.settings
        function onAnchorChanged() { page.reveal(page.settings.anchor); }
    }

    Component.onCompleted: {
        reveal(settings.anchor);
        Sound.monitoring = Qt.binding(() => page.side === "input" && page.visible);
    }
    Component.onDestruction: Sound.monitoring = false

    SectionHeading { first: true; text: qsTr("Sound Effects") }
    Box {
        FormRow {
            label: qsTr("Alert sound")
            firstLine: Look.popupHeight
            enabled: Sound.themes.length > 0
            Row {
                spacing: 9
                PopUpButton {
                    anchors.verticalCenter: parent.verticalCenter
                    items: Sound.themes.map(theme => ({ text: theme.title, value: theme.name }))
                    current: Sound.theme
                    onChosen: (value) => Sound.setTheme(value)
                }
                Item {
                    width: 17
                    height: 17
                    anchors.verticalCenter: parent.verticalCenter
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Play sound")
                    Glyph {
                        anchors.centerIn: parent
                        name: "play"
                        size: 17
                        color: Theme.color.label.secondary
                    }
                    TapHandler { onTapped: Sound.playAlert() }
                }
            }
        }
        FormRow {
            label: qsTr("Play sound effects through")
            firstLine: Look.popupHeight
            enabled: Sound.hasAlerts
            PopUpButton {
                items: [{ text: qsTr("Selected Sound Output Device"), value: "" }]
                    .concat(Sound.outputs.map(device => ({ text: device.title, value: device.name })))
                current: Sound.alertDevice
                onChosen: (value) => Sound.setAlertDevice(value)
            }
        }
        FormRow {
            label: qsTr("Alert volume")
            firstLine: Look.sliderKnobHeight
            enabled: Sound.hasAlerts
            Slider {
                minGlyph: "volumeLow"
                maxGlyph: "volumeHigh"
                ticks: 7
                value: Sound.alertVolume
                onMoved: (value) => Sound.setAlertVolume(value)
            }
        }
        FormRow {
            label: qsTr("Play feedback when volume is changed")
            Switch {
                checked: Sound.feedback
                onToggled: Sound.setFeedback(!Sound.feedback)
            }
        }
    }

    SectionHeading { text: qsTr("Output & Input") }
    Box {
        Item {
            width: parent.width
            height: Look.boxPadding + Look.segmented + Look.boxPadding
            Segmented {
                x: Look.boxPadding
                y: Look.boxPadding
                items: [{ text: qsTr("Output"), value: "output" }, { text: qsTr("Input"), value: "input" }]
                current: page.side
                onChosen: (value) => page.side = value
            }
        }
        DeviceTable {
            rows: page.side === "output" ? Sound.outputs : Sound.inputs
            onChosen: (name) => page.side === "output" ? Sound.setDefaultOutput(name) : Sound.setDefaultInput(name)
        }
    }
    Box {
        visible: page.side === "output" && Sound.outputs.length > 0
        FormRow {
            label: qsTr("Output volume")
            firstLine: Look.sliderKnobHeight
            Column {
                spacing: 6
                Slider {
                    minGlyph: "volumeLow"
                    maxGlyph: "volumeHigh"
                    ticks: 7
                    value: Sound.outputVolume
                    onMoved: (value) => Sound.setOutputVolume(value)
                }
                CheckBox {
                    anchors.right: parent.right
                    text: qsTr("Mute")
                    checked: Sound.outputMuted
                    onToggled: Sound.setOutputMuted(!Sound.outputMuted)
                }
            }
        }
        FormRow {
            label: qsTr("Balance")
            firstLine: Look.sliderKnobHeight
            visible: Sound.hasBalance
            Slider {
                trackWidth: 242
                ticks: 3
                captions: [qsTr("Left"), qsTr("Right")]
                value: Sound.balance
                // The middle holds the knob a little, as a detent.
                onMoved: (value) => Sound.setBalance(Math.abs(value - 0.5) < 0.03 ? 0.5 : value)
            }
        }
    }
    Box {
        visible: page.side === "input" && Sound.inputs.length > 0
        FormRow {
            label: qsTr("Input volume")
            firstLine: Look.sliderKnobHeight
            Slider {
                minGlyph: "micQuiet"
                maxGlyph: "mic"
                minSize: 14
                lead: 20
                maxSize: 14
                maxGap: 5
                endPad: 1
                trackWidth: 201
                ticks: 7
                value: Sound.inputVolume
                onMoved: (value) => Sound.setInputVolume(value)
            }
        }
        FormRow {
            label: qsTr("Input level")
            LevelMeter { level: page.loudness(Sound.inputLevel) }
        }
    }
}
