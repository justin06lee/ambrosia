import QtQuick
import Ambrosia
import Settings

// Notifications, as System Settings lays it out: what banners show, and each
// app that has sent one, the shell keeping the list. An app's row has its own
// switch, as allowing it is all there is to say: the shell's banners have no
// styles, badges or sounds to set. Left out: Notification Center and its
// heading (we have only banners), When Unlocked and the sleeping, locked and
// mirroring options (the lock screen shows none), Learn more… and the help
// button.
Page {
    id: page

    readonly property var apps: (Preferences.all.notificationApps ?? []).map(each => {
        const parts = each.split("\t");
        return { name: parts[0], icon: parts[1] ?? "" };
    }).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var off: Preferences.all.notificationsOff ?? []

    Box {
        Item {
            width: parent.width
            height: 65
            PaneIcon {
                x: 10
                y: 10
                size: 28
                glyph: "notifications"
                tint: "red"
            }
            Label {
                x: 48
                y: 10
                text: qsTr("Notifications")
                font.weight: 600
            }
            Label {
                x: 48
                y: 27.5
                width: parent.width - x - 20
                style: Theme.text.caption
                color: Theme.color.label.secondary
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 14
                text: qsTr("Customize what notifications show, and which apps can send them.")
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Show previews")
            PopUpButton {
                items: [
                    { text: qsTr("Always"), value: true },
                    { text: qsTr("Never"), value: false },
                ]
                current: Preferences.all.notificationPreviews ?? true
                onChosen: (value) => Preferences.set("notificationPreviews", value)
            }
        }
    }

    SectionHeading { text: qsTr("Application Notifications") }
    Box {
        Item {
            visible: page.apps.length === 0
            width: parent.width
            height: 52
            Label {
                x: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.color.label.secondary
                text: qsTr("Apps appear here once they've sent a notification.")
            }
        }
        Repeater {
            model: page.apps
            Item {
                id: row
                required property var modelData
                readonly property bool allowed: !page.off.includes(modelData.name)
                width: parent.width
                height: 52
                Image {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    sourceSize: Qt.size(64, 64)
                    source: "image://icon/" + (row.modelData.icon || "application-x-executable")
                }
                Column {
                    x: 50
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: row.modelData.name }
                    Label {
                        text: row.allowed ? qsTr("Banners") : qsTr("Off")
                        style: Theme.text.caption
                        color: Theme.color.label.secondary
                    }
                }
                Switch {
                    x: parent.width - Look.boxPadding - width
                    anchors.verticalCenter: parent.verticalCenter
                    checked: row.allowed
                    onToggled: Preferences.set("notificationsOff", row.allowed
                        ? page.off.concat([row.modelData.name])
                        : page.off.filter(each => each !== row.modelData.name))
                }
            }
        }
    }
}
