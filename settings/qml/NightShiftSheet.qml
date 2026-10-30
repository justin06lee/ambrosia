import QtQuick
import Ambrosia
import Settings

// Displays' Night Shift…, as System Settings shows it, on KWin's Night Light.
// Custom's times are typed: the Mac's own weren't photographed (it would mean
// changing its setting). Left out: the help button.
Sheet {
    id: sheet

    sheetWidth: 470
    below: 24
    onAccepted: close()

    Box {
        width: parent.width
        Label {
            x: Look.boxPadding
            width: parent.width - 2 * Look.boxPadding
            topPadding: 10
            bottomPadding: 5
            wrapMode: Text.WordWrap
            lineHeightMode: Text.FixedHeight
            lineHeight: 15
            color: Theme.color.label.secondary
            text: qsTr("Night Shift automatically shifts the colors of your display to the warmer end of the color spectrum after dark. This may help you get a better night's sleep.")
        }
        FormRow {
            height: 38
            label: qsTr("Schedule")
            PopUpButton {
                items: [
                    { text: qsTr("Off"), value: "off" },
                    { text: qsTr("Custom"), value: "custom" },
                    { text: qsTr("Sunset to Sunrise"), value: "sunset" },
                ]
                current: NightShift.schedule
                onChosen: (value) => NightShift.schedule = value
            }
        }
        FormRow {
            visible: NightShift.schedule === "custom"
            height: 36
            label: qsTr("From")
            NameField {
                width: 60
                value: NightShift.from
                onCommitted: (text) => NightShift.setTimes(text, NightShift.to)
            }
        }
        FormRow {
            visible: NightShift.schedule === "custom"
            height: 36
            label: qsTr("To")
            NameField {
                width: 60
                value: NightShift.to
                onCommitted: (text) => NightShift.setTimes(NightShift.from, text)
            }
        }
        FormRow {
            height: 38
            label: qsTr("Turn on until tomorrow")
            Switch {
                checked: NightShift.manual
                onToggled: NightShift.manual = !NightShift.manual
            }
        }
        FormRow {
            label: qsTr("Color temperature")
            description: qsTr("Warmer settings may affect the appearance of some onscreen motion.")
            firstLine: 16
            Slider {
                trackWidth: 215.5
                ticks: 2
                captions: [qsTr("Less Warm"), qsTr("More Warm")]
                value: NightShift.warmth
                onMoved: (value) => NightShift.warmth = value
            }
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
}
