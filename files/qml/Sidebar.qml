import QtQuick
import QtQuick.Effects
import Ambrosia
import Files

// The floating sidebar: an inset, rounded glass panel holding the traffic
// lights and Finder's sections (the top items, Favorites, Locations, Tags).
Item {
    id: sidebar

    required property var finder

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Finder.sidebarRadius
        color: Finder.sidebar
        border.width: 0.5
        border.color: Finder.sidebarRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.4 : 0.09
            shadowBlur: 0.5
            shadowVerticalOffset: 1
            blurMax: 24
        }
    }

    TrafficLights {
        x: Finder.lightsX - Finder.sidebarInset
        y: Finder.lightsY - Finder.sidebarInset
        window: sidebar.finder.window
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: Finder.sidebarFirstRow
        contentHeight: sections.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sections
            width: parent.width
            spacing: Finder.sidebarGap

            Repeater {
                model: Places.sections
                Column {
                    id: section
                    required property var modelData
                    width: sections.width

                    Label {
                        visible: section.modelData.title !== ""
                        x: Finder.sidebarIconX - 5
                        height: Finder.sidebarHeader
                        verticalAlignment: Text.AlignVCenter
                        text: section.modelData.title
                        style: Theme.text.caption
                        font.weight: 600
                        color: Theme.color.label.secondary
                    }
                    Repeater {
                        model: section.modelData.items
                        Item {
                            id: row
                            required property var modelData
                            readonly property bool current: modelData.url !== undefined
                                && sidebar.finder.url.toString() === modelData.url.toString()
                            width: section.width
                            height: Finder.sidebarRow

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 2
                                anchors.bottomMargin: 2
                                radius: 8
                                color: Theme.color.fill.secondary
                                visible: row.current
                            }
                            Glyph {
                                visible: row.modelData.glyph !== undefined
                                x: Finder.sidebarIconX - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.glyph ?? ""
                                size: Finder.sidebarGlyph
                                color: Theme.color.label.secondary
                            }
                            Rectangle {
                                // A tag's color dot.
                                visible: row.modelData.color !== undefined
                                x: Finder.sidebarIconX - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 6
                                color: row.modelData.color ? Theme.color.palette[row.modelData.color] : "transparent"
                            }
                            Label {
                                x: Finder.sidebarLabelX - Finder.sidebarInset + 8
                                width: parent.width - x - 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name
                                elide: Text.ElideRight
                            }
                            TapHandler {
                                onTapped: if (row.modelData.url !== undefined) sidebar.finder.go(row.modelData.url)
                            }
                        }
                    }
                }
            }
        }
    }
}
