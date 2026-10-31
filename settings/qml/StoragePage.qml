import QtQuick
import Ambrosia
import Settings

// General › Storage: the disk's use, what takes it, sized in the background at
// the lowest priority while the page shows. Left out: All Volumes…, iCloud and
// the other Recommendations, each row's ⓘ, Apple's other categories, and the
// help button. Empty Trash Automatically is KDE's own setting, after 30 days.
Page {
    id: page

    readonly property var colors: [Theme.color.palette.red, Theme.color.palette.orange, Theme.color.palette.yellow, Theme.color.label.tertiary]
    Component.onCompleted: Storage.start()
    Component.onDestruction: Storage.stop()

    Box {
        Item {
            width: parent.width
            height: 78
            Label {
                x: Look.boxPadding
                y: 12
                text: Storage.volume
            }
            Label {
                x: parent.width - Look.boxPadding - width
                y: 12
                text: Storage.usedText
                color: Theme.color.label.secondary
            }
            Rectangle {
                id: bar
                x: Look.boxPadding
                y: 36
                width: parent.width - 2 * x
                height: 14
                radius: 4
                color: Look.track
                Row {
                    Repeater {
                        model: Storage.categories
                        Rectangle {
                            required property var modelData
                            required property int index
                            visible: modelData.bytes > 0
                            width: Math.max(2, bar.width * modelData.bytes / Storage.total)
                            height: bar.height
                            topLeftRadius: index === 0 ? bar.radius : 0
                            bottomLeftRadius: index === 0 ? bar.radius : 0
                            color: page.colors[index]
                        }
                    }
                }
            }
            Row {
                x: Look.boxPadding
                y: 56
                spacing: 12
                Repeater {
                    model: Storage.categories
                    Row {
                        required property var modelData
                        required property int index
                        spacing: 4
                        Rectangle {
                            y: 4
                            width: 7
                            height: 7
                            radius: 3.5
                            color: page.colors[parent.index]
                        }
                        Label {
                            text: parent.modelData.name
                            style: Theme.text.caption
                            color: Theme.color.label.secondary
                        }
                    }
                }
            }
        }
    }

    SectionHeading { text: qsTr("Recommendations") }
    Box {
        FormRow {
            label: qsTr("Empty Trash Automatically")
            description: qsTr("Erase items that have been in the Trash for more than 30 days.")
            Switch {
                checked: Storage.emptyTrash
                onToggled: Storage.emptyTrash = !Storage.emptyTrash
            }
        }
    }

    Box {
        Repeater {
            model: Storage.categories
            FormRow {
                required property var modelData
                label: modelData.name
                value: modelData.text
            }
        }
    }
}
