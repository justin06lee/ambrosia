import QtQuick
import Ambrosia
import Settings

// Accessibility, as macOS 26 lists it: the sections that have something
// here to act on (Access), each row opening its page. Left out: VoiceOver
// and the spoken features (no screen reader is installed), Hover Text,
// captions, Voice and Switch Control, Speech, Siri and the shortcut.
Page {
    id: page

    readonly property var sections: [
        { name: qsTr("Vision"), rows: [
            { id: "zoom", name: qsTr("Zoom"), glyph: "search", tint: "black" },
            { id: "display", name: qsTr("Display"), glyph: "displays", tint: "blue" },
            { id: "motion", name: qsTr("Motion"), glyph: "play", tint: "green" },
        ] },
        { name: qsTr("Hearing"), rows: [
            { id: "audio", name: qsTr("Audio"), glyph: "sound", tint: "red" },
        ] },
        { name: qsTr("Motor"), rows: [
            { id: "keyboard", name: qsTr("Keyboard"), glyph: "keyboard", tint: "gray" },
            { id: "pointer", name: qsTr("Pointer Control"), glyph: "mouse", tint: "blue" },
        ] },
    ]

    Box {
        Item {
            width: parent.width
            height: 66
            PaneIcon {
                x: Look.boxPadding
                y: Look.boxPadding
                glyph: "accessibility"
                tint: "blue"
                size: 28
            }
            Column {
                x: 48
                y: Look.boxPadding
                width: parent.width - x - Look.boxPadding
                spacing: 2
                Label {
                    text: qsTr("Accessibility")
                    font.weight: 600
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 14
                    text: qsTr("Personalize this computer in ways that work best for you, with accessibility features for vision, hearing and motor.")
                }
            }
        }
    }
    Repeater {
        model: page.sections
        Column {
            id: section
            required property var modelData
            width: Look.boxWidth
            spacing: 0
            SectionHeading {
                text: section.modelData.name
            }
            Item { width: 1; height: 10 }
            Box {
                Repeater {
                    model: section.modelData.rows
                    Item {
                        id: row
                        required property var modelData
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
                        Glyph {
                            x: row.width - Look.chevronRight - width + 3
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevronRight"
                            size: 12
                            color: Theme.color.label.tertiary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.settings.choose("accessibility-options?" + row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
