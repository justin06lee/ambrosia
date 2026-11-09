import QtQuick
import Ambrosia
import Settings

// Focus, as System Settings lays it out, with the one we have, on a switch
// rather than a page of its own as it has nothing else to set; Control
// Center's Focus is the same setting. Left out: Reduce Interruptions, Sleep,
// Add Focus…, Share across devices, Focus status and the help button.
Page {
    id: page

    Box {
        Item {
            width: parent.width
            height: 52
            PaneIcon {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                size: 28
                glyph: "focus"
                tint: "indigo"
            }
            Column {
                x: 48
                anchors.verticalCenter: parent.verticalCenter
                Label { text: qsTr("Do Not Disturb") }
                Label {
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    text: qsTr("Holds back notifications, except urgent ones.")
                }
            }
            Switch {
                x: parent.width - Look.boxPadding - width
                anchors.verticalCenter: parent.verticalCenter
                checked: Preferences.all.doNotDisturb ?? false
                onToggled: Preferences.set("doNotDisturb", !checked)
            }
        }
    }
}
