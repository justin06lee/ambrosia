import QtQuick
import Ambrosia
import Settings

// Spotlight, as System Settings lays it out, for our Search (Super+Space):
// which kinds of result it shows. The shell keeps the kinds turned off
// (settings.json's searchOff) and goes by them from the next letter typed.
// Left out: what Search doesn't have (related content, quick keys, a
// history, the clipboard, other apps' content, iPhone apps, menu items),
// Files' sheet of file kinds, Search Privacy… and the help button.
Page {
    id: page

    readonly property var off: Preferences.all.searchOff ?? []
    function allow(kind, on) {
        Preferences.set("searchOff", on ? off.filter(each => each !== kind) : off.concat([kind]));
    }

    Box {
        Item {
            width: parent.width
            height: about.height + 2 * Look.boxPadding
            PaneIcon {
                x: Look.boxPadding
                y: Look.boxPadding
                glyph: "spotlight"
                tint: "blue"
                size: 28
            }
            Column {
                id: about
                x: 48
                y: Look.boxPadding
                width: parent.width - x - Look.boxPadding
                spacing: 2
                Label {
                    text: qsTr("Spotlight")
                    font.weight: 600
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 14
                    text: qsTr("Spotlight helps you quickly find things on this computer: apps, settings, files and folders, and the answers to sums.")
                }
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Results from Apps")
            description: qsTr("Allows content from apps to appear in Spotlight.")
        }
        Repeater {
            model: [
                { kind: "calculator", name: qsTr("Calculator"), icon: "accessories-calculator" },
                { kind: "settings", name: qsTr("System Settings"), icon: "org.ambrosia.settings" },
            ]
            Item {
                id: app
                required property var modelData
                width: parent.width
                height: 41
                Image {
                    x: Look.boxPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    sourceSize: Qt.size(40, 40)
                    source: "image://icon/" + app.modelData.icon
                }
                Label {
                    x: 38
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.modelData.name
                }
                Switch {
                    x: parent.width - Look.boxPadding - width
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !page.off.includes(app.modelData.kind)
                    onToggled: page.allow(app.modelData.kind, !checked)
                }
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Results from System")
            description: qsTr("Allows items to appear in Spotlight.")
        }
        Repeater {
            model: [
                { kind: "apps", name: qsTr("Apps") },
                { kind: "files", name: qsTr("Files") },
                { kind: "folders", name: qsTr("Folders") },
            ]
            FormRow {
                id: kind
                required property var modelData
                label: modelData.name
                Switch {
                    checked: !page.off.includes(kind.modelData.kind)
                    onToggled: page.allow(kind.modelData.kind, !checked)
                }
            }
        }
    }
}
