import QtQuick
import Ambrosia
import Settings

// One of Privacy & Security's lists (privacy-apps?camera): the apps that
// asked, each with its switch. A screen share an app was let start again is
// only forgotten when switched off; it asks the next time.
Page {
    id: page

    readonly property string kind: settings.anchor
    readonly property var apps: Privacy.apps[kind] ?? []
    readonly property string lead: ({
        camera: qsTr("Allow the apps below to access your camera."),
        microphone: qsTr("Allow the apps below to access your microphone."),
        screen: qsTr("Allow the apps below to record the content of your screen and audio, even while using other apps."),
    })[kind] ?? ""

    Component.onCompleted: Privacy.read()

    Box {
        Item {
            width: parent.width
            height: lead.implicitHeight + 2 * Look.boxPadding
            Label {
                id: lead
                x: Look.boxPadding
                y: Look.boxPadding
                width: parent.width - 2 * Look.boxPadding
                wrapMode: Text.WordWrap
                text: page.lead
            }
        }
        Item {
            visible: page.apps.length === 0
            width: parent.width
            height: Look.textRow
            Label {
                anchors.centerIn: parent
                color: Theme.color.label.secondary
                text: qsTr("No Items")
            }
        }
        Repeater {
            model: page.apps
            Item {
                id: row
                required property var modelData
                width: parent ? parent.width : Look.boxWidth
                height: Look.navRow
                Image {
                    x: Look.navIconX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    sourceSize: Qt.size(44, 44)
                    source: "image://icon/" + (row.modelData.icon || "application-x-executable")
                }
                Label {
                    x: Look.navLabelX
                    width: toggle.x - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    elide: Text.ElideRight
                }
                Switch {
                    id: toggle
                    x: row.width - Look.boxPadding - width
                    anchors.verticalCenter: parent.verticalCenter
                    checked: row.modelData.allowed
                    onToggled: Privacy.setAllowed(row.modelData.kind, row.modelData.app, !checked)
                }
            }
        }
    }
}
