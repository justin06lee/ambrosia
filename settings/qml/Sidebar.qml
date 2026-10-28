import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings

// The floating sidebar (macOS 26's System Settings): an inset, rounded
// glass panel holding the traffic lights, the search field and the panes
// in their groups. A click shows a pane, or opens the KDE module standing
// in for one we haven't built.
Item {
    id: sidebar

    required property var settings
    readonly property alias search: search
    // Positions inside the panel, from the window's.
    readonly property int inset: Look.sidebarInset

    Rectangle {
        anchors.fill: parent
        radius: Look.sidebarRadius
        color: Look.sidebar
        border.width: 0.5
        border.color: Look.sidebarRim
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
        x: Look.lightsX - sidebar.inset
        y: Look.lightsY - sidebar.inset
        window: sidebar.settings
    }

    SearchField {
        id: search
        x: Look.searchX - sidebar.inset
        y: Look.searchY - sidebar.inset
        onAccepted: {
            const first = Panes.listed(text)[0]?.[0];
            if (first)
                sidebar.settings.choose(first.id);
        }
    }

    Flickable {
        id: list
        y: Look.listTop - sidebar.inset
        width: parent.width
        height: parent.height - y
        contentHeight: groups.implicitHeight + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: groups
            width: parent.width
            spacing: Look.groupGap

            Repeater {
                model: Panes.listed(search.text)
                Column {
                    id: group
                    required property var modelData
                    width: groups.width

                    Repeater {
                        model: group.modelData
                        Item {
                            id: row
                            required property var modelData
                            readonly property bool current: sidebar.settings.sidebarPane === modelData.id
                            readonly property bool lit: current && sidebar.settings.looksActive
                            width: group.width
                            height: Look.row

                            Rectangle {
                                x: Look.rowX - sidebar.inset
                                width: Look.rowWidth
                                height: parent.height
                                radius: Look.rowRadius
                                visible: row.current
                                color: row.lit ? Theme.accent.bg : Look.selectionInactive
                            }
                            PaneIcon {
                                x: Look.rowIconX - sidebar.inset
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: row.modelData.glyph
                                tint: row.modelData.tint
                            }
                            Label {
                                x: Look.rowLabelX - sidebar.inset
                                width: Look.rowX - sidebar.inset + Look.rowWidth - x - 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name
                                elide: Text.ElideRight
                                color: row.lit ? Theme.accent.fg : Theme.color.label.primary
                            }
                            TapHandler {
                                onTapped: sidebar.settings.choose(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
