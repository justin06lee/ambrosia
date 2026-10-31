import QtQuick
import Ambrosia
import Settings

// General › Date & Time, on timedated. Left out: choosing the time server
// (timesyncd's config, a root file; the source only shows), setting the zone
// from location (nothing on our side finds it; the zone's chosen from a list
// rather than the Mac's map), and the help button.
Page {
    id: page

    property var now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: page.now = new Date()
    }
    Component.onCompleted: DateTime.read()

    Box {
        FormRow {
            label: qsTr("Set time and date automatically")
            Switch {
                checked: DateTime.automatic
                onToggled: DateTime.setAutomatic(!checked)
            }
        }
        FormRow {
            visible: DateTime.automatic && DateTime.source !== ""
            label: qsTr("Source")
            value: DateTime.source
        }
    }
    Box {
        FormRow {
            label: qsTr("Date and time")
            Row {
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.color.label.secondary
                    text: Qt.formatDateTime(page.now, (Preferences.all.clock24 ?? false) ? "MMM d, yyyy 'at' HH:mm:ss" : "MMM d, yyyy 'at' h:mm:ss AP")
                }
                PushButton {
                    visible: !DateTime.automatic
                    text: qsTr("Set…")
                    onClicked: {
                        clock.value = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss");
                        clockSheet.open = true;
                    }
                }
            }
        }
        FormRow {
            label: qsTr("24-hour time")
            Switch {
                checked: Preferences.all.clock24 ?? false
                onToggled: Preferences.set("clock24", !checked)
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Time zone")
            Row {
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.color.label.secondary
                    text: DateTime.zoneName
                }
                PushButton {
                    text: qsTr("Set…")
                    onClicked: zones.open = true
                }
            }
        }
        FormRow {
            label: qsTr("Closest city")
            value: DateTime.city
        }
    }

    ChooserSheet {
        id: zones
        settings: page.settings
        title: qsTr("Select a time zone")
        items: DateTime.zones
        onPicked: (value) => DateTime.setZone(value)
    }

    Sheet {
        id: clockSheet
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            if (DateTime.setTime(clock.text))
                close();
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Date and time")
                NameField {
                    id: clock
                    width: 170
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 80
                onClicked: clockSheet.close()
            },
            PushButton {
                text: qsTr("Set")
                primary: true
                minimumWidth: 80
                onClicked: clockSheet.accepted()
            }
        ]
    }
}
