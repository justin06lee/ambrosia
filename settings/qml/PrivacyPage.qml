import QtQuick
import Ambrosia
import Settings

// Privacy & Security: the apps allowed to use the camera, the microphone and
// the screen (the desktop portal's permission store), each opening its
// list, and whether the system disk is encrypted. Left out: Location
// Services (no location service here), the data kinds Linux keeps no
// permission for (Calendars, Contacts, Files & Folders, Photos…), Full Disk
// Access and the other kinds no app asks for here, Apple's reports and
// advertising, where apps may come from, Lockdown Mode, accessories,
// Advanced… and the help button.
Page {
    id: page

    Component.onCompleted: Privacy.read()

    readonly property var kinds: [
        { id: "camera", name: qsTr("Camera"), glyph: "camera", tint: "gray" },
        { id: "microphone", name: qsTr("Microphone"), glyph: "microphone", tint: "orange" },
        { id: "screen", name: qsTr("Screen & System Audio Recording"), glyph: "screenRecording", tint: "red" },
    ]

    Box {
        Item {
            width: parent.width
            height: 66
            PaneIcon {
                x: Look.boxPadding
                y: Look.boxPadding
                glyph: "privacy"
                tint: "blue"
                size: 28
            }
            Column {
                x: 48
                y: Look.boxPadding
                width: parent.width - x - Look.boxPadding
                spacing: 2
                Label {
                    text: qsTr("Privacy")
                    font.weight: 600
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 14
                    text: qsTr("Control which apps can use your camera and microphone, and record your screen.")
                }
            }
        }
    }
    Box {
        Repeater {
            model: page.kinds
            Item {
                id: row
                required property var modelData
                readonly property int count: (Privacy.apps[modelData.id] ?? []).filter(app => app.allowed).length
                width: parent ? parent.width : Look.boxWidth
                height: Look.navRow
                PaneIcon {
                    x: Look.navIconX
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: row.modelData.glyph
                    tint: row.modelData.tint
                }
                Label {
                    x: Look.navLabelX
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                }
                Label {
                    anchors.right: chevron.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.color.label.secondary
                    text: row.count
                }
                Glyph {
                    id: chevron
                    x: row.width - Look.chevronRight - width + 3
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevronRight"
                    size: 12
                    color: Theme.color.label.tertiary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: page.settings.choose("privacy-apps?" + row.modelData.id)
                }
            }
        }
    }

    SectionHeading {
        text: qsTr("Security")
    }
    Box {
        FormRow {
            label: qsTr("Disk encryption")
            description: qsTr("Whether the disk this system starts from is encrypted.")
            value: Privacy.diskEncryption === "on" ? qsTr("On") : Privacy.diskEncryption === "off" ? qsTr("Off") : qsTr("Unknown")
        }
    }
}
