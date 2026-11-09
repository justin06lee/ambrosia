import QtQuick
import Ambrosia
import Settings

// Keyboard: how keys repeat, in the Mac's steps (KWin's kcminputrc), the
// backlight where the keyboard has one (UPower), Keyboard Shortcuts… and the
// input sources, whose Edit… open KDE's modules until ours are built. Left
// out: brightness in low light, the backlight's timeout, the 🌐 key,
// keyboard navigation (each app's own), Text Replacements…, Dictation and
// Set Up Keyboard… (nothing here does them) and the help button.
Page {
    id: page

    Component.onCompleted: Keyboard.read()

    Box {
        Item {
            width: parent.width
            height: 75
            Column {
                x: Look.boxPadding
                y: Look.boxPadding
                spacing: 6
                Label { text: qsTr("Key repeat rate") }
                Slider {
                    trackWidth: 210
                    ticks: 8
                    snaps: true
                    captions: [qsTr("Off"), qsTr("Fast")]
                    value: Keyboard.repeatStep / 7
                    onMoved: (value) => Keyboard.repeatStep = Math.round(value * 7)
                }
            }
            Column {
                x: 240
                y: Look.boxPadding
                spacing: 6
                Label { text: qsTr("Delay until repeat") }
                Slider {
                    trackWidth: 210
                    ticks: 6
                    snaps: true
                    captions: [qsTr("Long"), qsTr("Short")]
                    value: Keyboard.delayStep / 5
                    onMoved: (value) => Keyboard.delayStep = Math.round(value * 5)
                }
            }
        }
    }
    Box {
        FormRow {
            visible: Keyboard.backlight
            label: qsTr("Keyboard brightness")
            Slider {
                trackWidth: 188
                minGlyph: "sunLow"
                maxGlyph: "sunHigh"
                value: Keyboard.brightness
                onMoved: (value) => Keyboard.brightness = value
            }
        }
        Item {
            visible: App.hasModule("kcm_keys")
            width: parent.width
            height: 44
            PushButton {
                anchors.right: parent.right
                anchors.rightMargin: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Keyboard Shortcuts…")
                onClicked: App.openModule("kcm_keys")
            }
        }
    }

    SectionHeading {
        text: qsTr("Text Input")
    }
    Box {
        FormRow {
            label: qsTr("Input Sources")
            Row {
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.color.label.secondary
                    text: Keyboard.inputSources
                }
                PushButton {
                    visible: App.hasModule("kcm_keyboard")
                    text: qsTr("Edit…")
                    onClicked: App.openModule("kcm_keyboard")
                }
            }
        }
    }
}
