import QtQuick
import Ambrosia
import Settings

// Not a pane: every control of a page laid out as System Settings' Sound
// lays them out, for side-by-sides with it (--pane controls). Nothing here
// changes the system; the panes that use these controls do.
Page {
    id: page

    property string alert: "sonar"
    property string device: "speakers"
    property real alertVolume: 1
    property real volume: 0.19
    property real balance: 0.5
    property var switches: ({ startup: true, interface: true, feedback: false })
    property string side: "output"

    SectionHeading { first: true; text: "Sound Effects" }
    Box {
        FormRow {
            label: "Alert sound"
            PopUpButton {
                items: [{ text: "Boop", value: "boop" }, { text: "Breeze", value: "breeze" }, { text: "Sonar", value: "sonar" }]
                current: page.alert
                onChosen: (value) => page.alert = value
            }
        }
        FormRow {
            label: "Play sound effects through"
            PopUpButton {
                items: [{ text: "Selected Sound Output Device", value: "selected" }, { text: "Speakers", value: "speakers" }]
                current: page.device
                onChosen: (value) => page.device = value
            }
        }
        FormRow {
            label: "Alert volume"
            Slider {
                minGlyph: "volumeLow"
                maxGlyph: "volumeHigh"
                value: page.alertVolume
                onMoved: (value) => page.alertVolume = value
            }
        }
        Repeater {
            model: [["startup", "Play sound on startup"], ["interface", "Play user interface sound effects"],
                    ["feedback", "Play feedback when volume is changed"]]
            FormRow {
                required property var modelData
                label: modelData[1]
                Switch {
                    checked: page.switches[modelData[0]]
                    onToggled: {
                        const next = Object.assign({}, page.switches);
                        next[modelData[0]] = !next[modelData[0]];
                        page.switches = next;
                    }
                }
            }
        }
    }

    SectionHeading { text: "Output & Input" }
    Box {
        Item {
            width: parent.width
            height: Look.controlRow + 4
            Segmented {
                x: Look.boxPadding
                y: Look.boxPadding
                items: [{ text: "Output", value: "output" }, { text: "Input", value: "input" }]
                current: page.side
                onChosen: (value) => page.side = value
            }
        }
    }
    Box {
        FormRow {
            label: "Output volume"
            Slider {
                minGlyph: "volumeLow"
                maxGlyph: "volumeHigh"
                value: page.volume
                onMoved: (value) => page.volume = value
            }
        }
        FormRow {
            label: "Balance"
            Slider {
                ticks: 3
                value: page.balance
                onMoved: (value) => page.balance = value
            }
        }
    }

    Item {
        width: Look.boxWidth
        height: Look.help + Look.helpGap - Look.boxGap
        HelpButton {
            x: parent.width - width
            y: parent.height - height
        }
    }
}
