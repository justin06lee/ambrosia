import QtQuick
import Ambrosia
import Settings

// Displays, as System Settings lays it out: the displays in a band across
// the top, then the one chosen's scale (Larger Text … More Space),
// brightness where it can be dimmed, color profile, refresh rate and
// rotation. True Tone and the TV's options are Apple's and left out;
// Advanced… and Night Shift… come with their sheets.
Page {
    id: page

    property int chosen: 0
    readonly property var display: Displays.list[Math.min(chosen, Displays.list.length - 1)] ?? null

    // The band: each display's picture and name, the chosen one's in bold.
    Item {
        width: Look.boxWidth
        height: Look.displayBand + Look.boxGap

        Rectangle {
            x: -Look.margin
            width: page.width
            height: Look.displayBand
            color: Look.band
        }
        Rectangle {
            x: -Look.margin
            y: Look.displayBand
            width: page.width
            height: 1
            color: Look.bandRule
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: Displays.list
                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    width: Math.min(304, page.width / Displays.list.length)
                    height: Look.displayBand

                    Image {
                        x: (parent.width - width) / 2
                        y: 8
                        width: 128
                        height: 128
                        sourceSize: Qt.size(256, 256)
                        source: "qrc:/qt/qml/Settings/art/" + (slot.modelData.builtIn ? "laptop" : "desktop") + ".svg"
                    }
                    Label {
                        x: (parent.width - width) / 2
                        y: 124.5
                        text: slot.modelData.name
                        font.weight: slot.index === page.chosen ? 600 : 400
                    }
                    TapHandler {
                        onTapped: page.chosen = slot.index
                    }
                }
            }
        }
    }

    // The scale, as what the display looks like: larger text to more space.
    Box {
        visible: page.display !== null
        Item {
            id: scales
            readonly property var choices: page.display?.scales ?? []
            readonly property real pitch: Math.min(112, 336 / Math.max(1, choices.length - 1))
            width: parent.width
            height: 108

            Repeater {
                model: scales.choices
                Item {
                    id: choice
                    required property var modelData
                    required property int index
                    readonly property bool isDefault: Math.abs(modelData.scale - page.display.defaultScale) < 0.01
                    x: scales.width / 2 + (index - (scales.choices.length - 1) / 2) * scales.pitch - 25
                    y: 19
                    width: 50
                    height: 50

                    ScaleTile {
                        anchors.fill: parent
                        factor: choice.modelData.scale
                        chosen: Math.abs(page.display.scale - choice.modelData.scale) < 0.01
                    }
                    Label {
                        x: (parent.width - width) / 2
                        y: 55
                        style: Theme.text.caption
                        text: choice.isDefault ? qsTr("Default")
                            : choice.index === 0 ? qsTr("Larger Text")
                            : choice.index === scales.choices.length - 1 ? qsTr("More Space") : ""
                        font.weight: choice.isDefault ? 600 : 400
                    }
                    TapHandler {
                        onTapped: Displays.setScale(page.display.id, choice.modelData.scale)
                    }
                }
            }
        }
    }

    Box {
        visible: page.display?.dimmable ?? false
        FormRow {
            height: 39
            label: qsTr("Brightness")
            firstLine: 16
            Slider {
                minGlyph: "sunLow"
                maxGlyph: "sunHigh"
                minSize: 16.5
                maxSize: 18
                value: page.display?.brightness ?? 1
                onMoved: (value) => Displays.setBrightness(page.display.id, value)
            }
        }
    }

    Box {
        visible: page.display !== null
        FormRow {
            height: 37
            label: qsTr("Color profile")
            PopUpButton {
                items: (page.display?.profiles ?? []).map(profile => ({ text: profile.name, value: profile.id }))
                current: page.display?.profile ?? ""
                onChosen: (value) => Displays.setProfile(page.display.id, value)
            }
        }
        FormRow {
            visible: page.display !== null && (!page.display.builtIn || page.display.rates.length > 1)
            height: 37
            label: qsTr("Refresh rate")
            PopUpButton {
                items: (page.display?.rates ?? []).map(rate => ({ text: rate.text, value: rate.id }))
                current: page.display?.rate ?? ""
                onChosen: (value) => Displays.setRate(page.display.id, value)
            }
        }
        FormRow {
            visible: page.display !== null && !page.display.builtIn
            height: 37
            label: qsTr("Rotation")
            PopUpButton {
                items: [
                    { text: qsTr("Standard"), value: "0" },
                    { text: qsTr("90°"), value: "90" },
                    { text: qsTr("180°"), value: "180" },
                    { text: qsTr("270°"), value: "270" },
                ]
                current: page.display?.rotation ?? "0"
                onChosen: (value) => Displays.setRotation(page.display.id, value)
            }
        }
    }
}
