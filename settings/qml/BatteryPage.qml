import QtQuick
import Ambrosia
import Settings

// Battery, or Energy where there's none. With a battery: Low Power Mode for
// each power source, the battery's health and charge limit (UPower), its
// level over the last day, and Options…; without: Low Power Mode, and
// whether the computer sleeps on its own with the display off. Left out:
// Screen On Usage and the last 10 days (nothing records them), Wake for
// network access, starting up after a power failure, Power Nap, UPS options
// (nothing of ours does them) and the help button.
Page {
    id: page

    Component.onCompleted: {
        Power.read();
        samples = Power.history(24);
    }
    property var samples: []
    Timer {
        interval: 60000
        repeat: true
        running: Power.hasBattery
        onTriggered: page.samples = Power.history(24)
    }
    readonly property string health: Power.capacity < 0 ? "" : Power.capacity < 80 ? qsTr("Service Recommended") : qsTr("Normal")
    // What it's doing, as the line over the chart says it.
    readonly property string status: Power.state === "charging" ? qsTr("Charging, %1%").arg(Power.percentage)
        : Power.state === "full" ? qsTr("Fully charged")
        : Power.state === "pending" && Power.chargeLimit ? qsTr("Charged to %1% Limit").arg(Power.chargeLimitPercent)
        : Power.state === "pending" ? qsTr("Not charging, %1%").arg(Power.percentage)
        : qsTr("%1%").arg(Power.percentage)

    // Energy
    Box {
        visible: !Power.hasBattery
        FormRow {
            visible: Power.lowPowerAvailable
            label: qsTr("Low Power Mode")
            Switch {
                checked: Power.lowPower
                onToggled: Power.lowPower = !checked
            }
        }
        FormRow {
            visible: Power.canSleep
            label: qsTr("Prevent automatic sleeping when the display is off")
            Switch {
                checked: Power.preventSleep
                onToggled: Power.preventSleep = !checked
            }
        }
    }

    // Battery
    Box {
        visible: Power.hasBattery && Power.lowPowerAvailable
        FormRow {
            label: qsTr("Low Power Mode")
            PopUpButton {
                items: [
                    { text: qsTr("Never"), value: "never" },
                    { text: qsTr("Always"), value: "always" },
                    { text: qsTr("Only on Battery"), value: "battery" },
                    { text: qsTr("Only on Power Adapter"), value: "adapter" },
                ]
                current: Power.lowPowerMode
                onChosen: (value) => Power.lowPowerMode = value
            }
        }
    }
    Box {
        visible: Power.hasBattery
        FormRow {
            visible: page.health !== ""
            label: qsTr("Battery Health")
            Row {
                spacing: 10
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.health
                    color: Theme.color.label.secondary
                }
                InfoButton { onClicked: healthSheet.open = true }
            }
        }
        FormRow {
            visible: Power.chargeLimitSupported
            label: qsTr("Charging")
            InfoButton { onClicked: chargingSheet.open = true }
        }
    }
    Box {
        visible: Power.hasBattery
        Column {
            x: Look.boxPadding
            width: parent.width - 2 * Look.boxPadding
            topPadding: Look.boxPadding
            bottomPadding: Look.boxPadding
            spacing: 12
            Label { text: page.status }
            Label {
                text: qsTr("Battery Level")
                font.weight: 600
            }
            BatteryChart {
                width: parent.width
                samples: page.samples
            }
        }
    }
    Item {
        visible: Power.hasBattery
        width: parent.width
        height: Look.popupHeight
        PushButton {
            anchors.right: parent.right
            text: qsTr("Options…")
            onClicked: optionsSheet.open = true
        }
    }

    Sheet {
        id: healthSheet
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: close()
        Label {
            text: qsTr("Battery Health")
            font.weight: 600
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Battery Condition")
                value: page.health
            }
            FormRow {
                label: qsTr("Maximum Capacity")
                value: Power.capacity >= 0 ? qsTr("%1%").arg(Power.capacity) : ""
            }
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            style: Theme.text.caption
            color: Theme.color.label.secondary
            text: qsTr("Maximum capacity measures the battery's charge against when it was new. Lower capacity may mean less time between charges.")
        }
        trailing: [
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: healthSheet.accepted()
            }
        ]
    }

    Sheet {
        id: chargingSheet
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: close()
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Charge Limit")
                description: qsTr("Your computer will charge to a %1% limit. Stopping short of full helps the battery last longer.").arg(Power.chargeLimitPercent)
                Switch {
                    checked: Power.chargeLimit
                    onToggled: Power.chargeLimit = !checked
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: chargingSheet.accepted()
            }
        ]
    }

    Sheet {
        id: optionsSheet
        settings: page.settings
        sheetWidth: 490
        below: 24
        onAccepted: close()
        Box {
            width: parent.width
            FormRow {
                visible: Power.canSleep
                label: qsTr("Prevent automatic sleeping on power adapter when the display is off")
                Switch {
                    checked: Power.preventSleep
                    onToggled: Power.preventSleep = !checked
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: optionsSheet.accepted()
            }
        ]
    }
}
