import QtQuick
import Ambrosia
import Settings

// Menu Bar's Clock Options…: how the clock reads. Our own layout after the
// Mac's, which wasn't photographed.
Sheet {
    id: sheet

    sheetWidth: 470
    below: 24
    onAccepted: close()

    Box {
        width: parent.width
        FormRow {
            label: qsTr("Show date")
            Switch {
                checked: Preferences.all.clockDate ?? true
                onToggled: Preferences.set("clockDate", !checked)
            }
        }
        FormRow {
            label: qsTr("Show the day of the week")
            Switch {
                checked: Preferences.all.clockWeekday ?? true
                onToggled: Preferences.set("clockWeekday", !checked)
            }
        }
    }
    Box {
        width: parent.width
        FormRow {
            label: qsTr("Use a 24-hour clock")
            Switch {
                checked: Preferences.all.clock24 ?? false
                onToggled: Preferences.set("clock24", !checked)
            }
        }
        FormRow {
            label: qsTr("Show AM/PM")
            enabled: !(Preferences.all.clock24 ?? false)
            opacity: enabled ? 1 : 0.45
            Switch {
                checked: Preferences.all.clockAmPm ?? true
                onToggled: Preferences.set("clockAmPm", !checked)
            }
        }
        FormRow {
            label: qsTr("Display the time with seconds")
            Switch {
                checked: Preferences.all.clockSeconds ?? false
                onToggled: Preferences.set("clockSeconds", !checked)
            }
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
}
