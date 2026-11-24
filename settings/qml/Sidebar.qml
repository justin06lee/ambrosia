import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings
import org.ambrosia.glass

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

    // Glass where the compositor has our effect (org.ambrosia.glass), and
    // see-through only in the window in front, as a Mac's sidebar is: the
    // window leaves a hole under it then (Backing.qml). Solid otherwise.
    readonly property bool glassy: pane.available
    readonly property bool clear: glassy && sidebar.settings.looksActive
    readonly property int room: 24

    // The panel's shadow on the window around it, cut away under the panel
    // itself: glass is only as dark as its tint.
    Item {
        id: cast
        anchors.fill: parent
        anchors.margins: -sidebar.room
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: outline
        }

        Rectangle {
            x: sidebar.room
            y: sidebar.room
            width: sidebar.width
            height: sidebar.height
            radius: Look.sidebarRadius
            color: Look.sidebar
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
    }

    Item {
        id: outline
        anchors.fill: cast
        visible: false
        layer.enabled: true

        Rectangle {
            x: sidebar.room
            y: sidebar.room
            width: sidebar.width
            height: sidebar.height
            radius: Look.sidebarRadius
        }
    }

    GlassPane {
        id: pane
        anchors.fill: parent
        radius: Look.sidebarRadius
        material: "regular"
        visible: panel.color.a < 1
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Look.sidebarRadius
        color: sidebar.clear ? Look.sidebarGlass : Look.sidebar
        border.width: 0.5
        border.color: Look.sidebarRim

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    TrafficLights {
        x: Look.lightsX - sidebar.inset
        y: Look.lightsY - sidebar.inset
        window: sidebar.settings
        closable: !sidebar.settings.underSheet
    }

    SearchField {
        id: search
        x: Look.searchX - sidebar.inset
        y: Look.searchY - sidebar.inset
        enabled: !sidebar.settings.underSheet
        opacity: enabled ? 1 : Look.sheetFadeIcon
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
                            readonly property bool lit: current && sidebar.settings.looksActive && !sidebar.settings.underSheet
                            width: group.width
                            height: Look.row

                            Rectangle {
                                x: Look.rowX - sidebar.inset
                                width: Look.rowWidth
                                height: parent.height
                                radius: Look.rowRadius
                                visible: row.current
                                color: row.lit ? Theme.accent.bg : sidebar.settings.underSheet ? Look.selectionUnderSheet : Look.selectionInactive
                            }
                            PaneIcon {
                                x: Look.rowIconX - sidebar.inset
                                opacity: sidebar.settings.underSheet ? Look.sheetFadeIcon : 1
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
                                opacity: sidebar.settings.underSheet ? Look.sheetFade : 1
                                color: row.lit ? Theme.accent.fg : Theme.color.label.primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !sidebar.settings.underSheet
                                onClicked: sidebar.settings.choose(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
