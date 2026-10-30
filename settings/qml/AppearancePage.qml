import QtQuick
import Ambrosia
import Settings

// Appearance, as System Settings lays it out: Auto, Light or Dark; the accent;
// what a click in a scroll bar does. Auto follows KDE's night-time service, in
// the shell. Left out: Liquid Glass, Multicolor, Icon & widget style and the
// text highlight color (nothing on our side to act on them); folder color,
// sidebar icon size, window tint and Show scroll bars (not yet in our apps),
// and the help button.
Page {
    id: page

    Box {
        Item {
            width: parent.width
            height: 86
            Label {
                x: Look.boxPadding
                y: Look.boxPadding
                text: qsTr("Appearance")
            }
            Row {
                x: 212
                y: 10
                spacing: 8
                Repeater {
                    model: [
                        { mode: "auto", text: qsTr("Auto") },
                        { mode: "light", text: qsTr("Light") },
                        { mode: "dark", text: qsTr("Dark") },
                    ]
                    AppearanceTile {
                        required property var modelData
                        mode: modelData.mode
                        text: modelData.text
                        chosen: Preferences.appearance === modelData.mode
                        onClicked: Preferences.appearance = modelData.mode
                    }
                }
            }
        }
    }

    SectionHeading { text: qsTr("Theme") }
    Box {
        Item {
            width: parent.width
            height: 61
            Label {
                x: Look.boxPadding
                y: Look.boxPadding
                text: qsTr("Color")
            }
            Row {
                x: 170
                y: 6
                Repeater {
                    model: [
                        { id: "blue", name: qsTr("Blue") },
                        { id: "purple", name: qsTr("Purple") },
                        { id: "pink", name: qsTr("Pink") },
                        { id: "red", name: qsTr("Red") },
                        { id: "orange", name: qsTr("Orange") },
                        { id: "honey", name: qsTr("Yellow") },
                        { id: "green", name: qsTr("Green") },
                        { id: "graphite", name: qsTr("Graphite") },
                    ]
                    Item {
                        id: swatch
                        required property var modelData
                        readonly property bool chosen: Preferences.accent === modelData.id
                        readonly property color face: Theme.color.accents[modelData.id].bg
                        width: 36
                        height: 32
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.name
                        Accessible.checked: chosen
                        Rectangle {
                            x: 2
                            y: 4
                            width: 24
                            height: 24
                            radius: 12
                            color: swatch.face
                        }
                        Rectangle {
                            visible: swatch.chosen
                            x: -1
                            y: 1
                            width: 30
                            height: 30
                            radius: 15
                            color: "transparent"
                            border.width: 2
                            border.color: swatch.face
                        }
                        Label {
                            visible: swatch.chosen
                            x: 14 - width / 2
                            y: 31
                            text: swatch.modelData.name
                            style: Theme.text.caption
                            color: Theme.color.label.secondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Preferences.accent = swatch.modelData.id
                        }
                    }
                }
            }
        }
    }

    SectionHeading { text: qsTr("Windows") }
    Box {
        Column {
            x: Look.boxPadding
            topPadding: Look.boxPadding
            bottomPadding: 8
            Label {
                height: 22
                text: qsTr("Click in the scroll bar to")
            }
            RadioRow {
                text: qsTr("Jump to the next page")
                checked: !Preferences.jumpToClick
                onClicked: Preferences.jumpToClick = false
            }
            RadioRow {
                text: qsTr("Jump to the spot that's clicked")
                checked: Preferences.jumpToClick
                onClicked: Preferences.jumpToClick = true
            }
        }
    }
}
