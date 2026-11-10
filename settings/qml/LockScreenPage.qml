import QtQuick
import Ambrosia
import Settings

// Lock Screen: when the display turns off (PowerDevil), and when a password
// is needed after it does (kscreenlocker). Left out: the user's name and
// photo, password hints and a message on the lock screen (the lock screen
// shows the name and photo always, and has neither of the others), the
// login window's options (SDDM's, which only root may change), Accessibility
// Options… and the help button.
Page {
    id: page

    Component.onCompleted: Power.read()

    // Idle times, as the Mac offers them; one set some other way is offered too.
    function offItems(current) {
        const items = [
            { text: qsTr("For 1 minute"), value: 60 },
            { text: qsTr("For 2 minutes"), value: 120 },
            { text: qsTr("For 3 minutes"), value: 180 },
            { text: qsTr("For 5 minutes"), value: 300 },
            { text: qsTr("For 10 minutes"), value: 600 },
            { text: qsTr("For 20 minutes"), value: 1200 },
            { text: qsTr("For 30 minutes"), value: 1800 },
            { text: qsTr("For 1 hour"), value: 3600 },
            { text: qsTr("For 1 hour, 30 minutes"), value: 5400 },
            { text: qsTr("For 2 hours"), value: 7200 },
            { text: qsTr("For 2 hours, 30 minutes"), value: 9000 },
            { text: qsTr("For 3 hours"), value: 10800 },
            { text: qsTr("Never"), value: 0 },
        ];
        if (!items.some(item => item.value === current))
            items.splice(items.findIndex(item => item.value === 0 || item.value > current), 0,
                         { text: current % 60 === 0 ? qsTr("For %n minute(s)", "", current / 60) : qsTr("For %n second(s)", "", current), value: current });
        return items;
    }
    readonly property var waitItems: [
        { text: qsTr("Immediately"), value: 0 },
        { text: qsTr("After 5 seconds"), value: 5 },
        { text: qsTr("After 1 minute"), value: 60 },
        { text: qsTr("After 5 minutes"), value: 300 },
        { text: qsTr("After 15 minutes"), value: 900 },
        { text: qsTr("After 1 hour"), value: 3600 },
        { text: qsTr("After 4 hours"), value: 14400 },
        { text: qsTr("After 8 hours"), value: 28800 },
        { text: qsTr("Never"), value: -1 },
    ]
    readonly property string warning: "⚠️ " + qsTr("Never letting your display turn off may shorten its lifespan and increase energy usage.")

    Box {
        FormRow {
            visible: Power.hasBattery
            firstLine: Look.popupHeight
            label: qsTr("Turn display off on battery when inactive")
            description: Power.displayOffBattery === 0 ? page.warning : ""
            PopUpButton {
                items: page.offItems(Power.displayOffBattery)
                current: Power.displayOffBattery
                onChosen: (value) => Power.setDisplayOff("Battery", value)
            }
        }
        FormRow {
            firstLine: Look.popupHeight
            label: Power.hasBattery ? qsTr("Turn display off on power adapter when inactive") : qsTr("Turn display off when inactive")
            description: Power.displayOffAdapter === 0 ? page.warning : ""
            PopUpButton {
                items: page.offItems(Power.displayOffAdapter)
                current: Power.displayOffAdapter
                onChosen: (value) => Power.setDisplayOff("AC", value)
            }
        }
        FormRow {
            label: qsTr("Require password after display is turned off")
            PopUpButton {
                items: page.waitItems
                current: page.waitItems.some(item => item.value === Power.requirePasswordAfter)
                    ? Power.requirePasswordAfter
                    : page.waitItems.reduce((best, item) => item.value >= 0 && Math.abs(item.value - Power.requirePasswordAfter) < Math.abs(best - Power.requirePasswordAfter) ? item.value : best, 0)
                onChosen: (value) => Power.requirePasswordAfter = value
            }
        }
    }
}
