import QtQuick
import Ambrosia
import Settings

// Displays' Advanced…, as System Settings shows it. Link to Mac or iPad is
// Apple's and left out, which leaves this one switch.
Sheet {
    id: sheet

    sheetWidth: 470
    onAccepted: close()

    Box {
        width: parent.width
        FormRow {
            height: 36.5
            label: qsTr("Show resolutions as list")
            Switch {
                checked: Displays.showAsList
                onToggled: Displays.showAsList = !Displays.showAsList
            }
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
}
