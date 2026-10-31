import QtQuick
import Ambrosia
import Settings

// General › Software Update, on PackageKit: what's waiting, Update Now (asking
// first, then polkit) and Check Now. Opening it reads the package lists as they
// stand. Left out: Upgrade Tonight, Automatic Updates (a rolling system is
// updated when you choose) and Beta Updates (no such channel), and the help
// button. Check Now is ours: the Mac checks as the page opens.
Page {
    id: page

    readonly property int count: Updates.packages.length
    readonly property bool busy: ["reading", "checking", "installing"].includes(Updates.state)
    Component.onCompleted: Updates.read()

    Box {
        Item {
            width: parent.width
            height: 56
            Column {
                x: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * x - 220
                spacing: 2
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    font.weight: page.count > 0 && !page.busy ? 600 : 400
                    text: Updates.state === "reading" || Updates.state === "idle" ? qsTr("Reading the package lists…")
                        : Updates.state === "checking" ? qsTr("Checking for updates…")
                        : Updates.state === "installing" ? qsTr("Installing updates… %1%").arg(Updates.percent)
                        : Updates.state === "failed" ? qsTr("Couldn't check for updates.")
                        : page.count === 1 ? qsTr("1 update available")
                        : page.count > 1 ? qsTr("%1 updates available").arg(page.count)
                        : qsTr("%1 is up to date").arg(About.systemName)
                }
                Label {
                    visible: text !== ""
                    width: parent.width
                    elide: Text.ElideRight
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    text: Updates.state === "failed" ? Updates.error : ""
                }
            }
            Row {
                x: parent.width - Look.boxPadding - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                PushButton {
                    text: qsTr("Check Now")
                    enabled: !page.busy
                    onClicked: Updates.check()
                }
                PushButton {
                    visible: page.count > 0
                    text: qsTr("Update Now")
                    enabled: !page.busy
                    onClicked: confirm.open = true
                }
            }
        }
        FormRow {
            label: qsTr("Installed")
            value: About.systemVersion ? About.systemName + " " + About.systemVersion : About.systemName
        }
    }

    Box {
        visible: page.count > 0
        Repeater {
            model: Updates.packages.slice(0, 200)
            FormRow {
                required property var modelData
                height: 28
                label: modelData.name
                value: modelData.version
            }
        }
    }

    Sheet {
        id: confirm
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            close();
            Updates.install();
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            font.weight: 600
            text: page.count === 1 ? qsTr("Install 1 update?") : qsTr("Install %1 updates?").arg(page.count)
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.color.label.secondary
            text: qsTr("This updates the whole system. Some apps may need to restart afterwards.")
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 88
                onClicked: confirm.close()
            },
            PushButton {
                text: qsTr("Update Now")
                primary: true
                minimumWidth: 88
                onClicked: confirm.accepted()
            }
        ]
    }
}
