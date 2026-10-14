import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import Ambrosia

// The control center: one capsule module per control, on a grid of
// size.controlCenter.unit cells, floating on a pure blur with no panel.
// Opening and closing follow choreography.controlCenter: the modules fade in
// together and the on-states light up a beat later; closing drops the
// on-states first, then fades the modules.
Item {
    id: cc

    property bool open: false
    // Up while open and while fading out.
    readonly property bool shown: open || fade.running || modules.opacity > 0
    readonly property Region blurArea: Region { item: cc; radius: Theme.radius.controlCenter }

    readonly property int unit: Theme.size.controlCenter.unit
    readonly property int gap: Theme.size.controlCenter.gap
    readonly property int pad: Theme.size.controlCenter.padding
    readonly property int rowCount: Brightness.available ? 6 : 5
    // Lit on-states; off while closing and until a beat after opening.
    property bool lit: false

    width: 4 * unit + 3 * gap + 2 * pad
    height: rowCount * unit + (rowCount - 1) * gap + 2 * pad
    visible: shown

    function cell(column, row) {
        return Qt.point(pad + column * (unit + gap), pad + row * (unit + gap));
    }
    function span(cells) {
        return cells * unit + (cells - 1) * gap;
    }

    onOpenChanged: {
        lit = false;
        if (open) {
            Brightness.refresh();
            lightUp.restart();
        }
    }
    Timer {
        id: lightUp
        interval: Theme.choreography.controlCenter.lightUpDelay
        onTriggered: cc.lit = true
    }

    // Clicks between modules land here, not on the Overlay behind.
    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: modules
        anchors.fill: parent
        opacity: cc.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: cc.open ? Theme.choreography.controlCenter.fadeIn : Theme.choreography.controlCenter.fadeOut
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [...Theme.fade.curve, 1, 1]
            }
        }

        // Wi-Fi
        Pill {
            position: cc.cell(0, 0)
            icon: "wifi"
            title: "Wi-Fi"
            on: Networking.wifiEnabled
            readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
            readonly property var network: device?.networks.values.find(n => n.connected) ?? null
            detail: !Networking.wifiEnabled ? "Off" : network ? network.name : "Not Connected"
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            onOpened: {
                Popups.close();
                Session.settings("kcm_networkmanagement");
            }
        }

        // Bluetooth
        Pill {
            position: cc.cell(0, 1)
            icon: "bluetooth"
            title: "Bluetooth"
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var device: Bluetooth.devices.values.find(d => d.connected) ?? null
            on: adapter?.enabled ?? false
            enabled: adapter !== null
            detail: !adapter ? "Unavailable" : !adapter.enabled ? "Off" : device ? device.name : "On"
            onToggled: adapter.enabled = !adapter.enabled
            onOpened: {
                Popups.close();
                Session.settings("kcm_bluetooth");
            }
        }

        // Now Playing
        Module {
            id: nowPlaying
            readonly property point position: cc.cell(2, 0)
            readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
            x: position.x
            y: position.y
            width: cc.span(2)
            height: cc.span(2)

            Rectangle {
                id: art
                x: Theme.space.s4
                y: Theme.space.s4
                width: 36
                height: 36
                radius: Theme.radius.control
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.color.palette.yellow }
                    GradientStop { position: 0.55; color: Theme.color.palette.orange }
                    GradientStop { position: 1; color: Theme.color.palette.pink }
                }

                Image {
                    anchors.fill: parent
                    source: nowPlaying.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                }
            }

            Column {
                anchors { left: parent.left; right: parent.right; bottom: transport.top; margins: Theme.space.s4; bottomMargin: Theme.space.s2 }

                Label {
                    width: parent.width
                    text: nowPlaying.player?.trackTitle || "Not Playing"
                    style: Theme.text.headline
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: nowPlaying.player?.trackArtist ?? ""
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                    elide: Text.ElideRight
                }
            }

            Row {
                id: transport
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s4; bottomMargin: Theme.space.s3 }
                spacing: (width - 20 - 26 - 20) / 2
                enabled: nowPlaying.player !== null

                Transport { icon: "back"; size: 20; enabled: nowPlaying.player?.canGoPrevious ?? false; onClicked: nowPlaying.player.previous() }
                Transport {
                    icon: nowPlaying.player?.isPlaying ? "pause" : "play"
                    size: 26
                    enabled: nowPlaying.player?.canTogglePlaying ?? false
                    onClicked: nowPlaying.player.togglePlaying()
                }
                Transport { icon: "forward"; size: 20; enabled: nowPlaying.player?.canGoNext ?? false; onClicked: nowPlaying.player.next() }
            }
        }

        // Focus: Do Not Disturb holds notification banners back.
        Pill {
            position: cc.cell(0, 2)
            icon: "moon"
            title: "Focus"
            detail: on ? "Do Not Disturb" : ""
            on: Settings.doNotDisturb
            onToggled: Settings.doNotDisturb = !Settings.doNotDisturb
            onOpened: Settings.doNotDisturb = !Settings.doNotDisturb
        }

        Circle {
            position: cc.cell(2, 2)
            icon: "nightlight"
            on: Appearance.nightLight
            onToggled: Appearance.setNightLight(!Appearance.nightLight)
        }

        Circle {
            position: cc.cell(3, 2)
            icon: "contrast"
            on: Settings.dark
            onToggled: Appearance.setDark(!Settings.dark)
        }

        // Display brightness, when the display can be dimmed.
        Bar {
            visible: Brightness.available
            position: cc.cell(0, 3)
            title: "Display"
            value: Brightness.value
            lowIcon: "sun"
            highIcon: "sun"
            onMoved: value => Brightness.set(value)
        }

        // Sound
        Bar {
            id: sound
            readonly property var sink: Pipewire.defaultAudioSink
            position: cc.cell(0, Brightness.available ? 4 : 3)
            title: "Sound"
            enabled: !!sink?.audio
            value: sink?.audio?.muted ? 0 : (sink?.audio?.volume ?? 0)
            lowIcon: sink?.audio?.muted ? "speakerOff" : "speaker"
            onMoved: value => {
                sink.audio.muted = false;
                sink.audio.volume = value;
            }
            onLowIconClicked: sink.audio.muted = !sink.audio.muted

            PwObjectTracker { objects: [sound.sink] }
        }

        // Accent
        Module {
            readonly property point position: cc.cell(0, Brightness.available ? 5 : 4)
            x: position.x
            y: position.y
            width: cc.span(4)
            height: cc.unit

            Label {
                x: Theme.space.s4
                y: Theme.space.s2
                text: "Accent"
                style: Theme.text.headline
            }

            Row {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s4; bottomMargin: Theme.space.s2 + 2 }
                spacing: (width - 8 * 20) / 7

                Repeater {
                    model: ["blue", "purple", "pink", "red", "orange", "honey", "green", "graphite"]

                    Item {
                        id: swatch
                        required property string modelData
                        readonly property bool chosen: Settings.accent === modelData
                        width: 20
                        height: 20

                        Rectangle {
                            anchors.centerIn: parent
                            visible: swatch.chosen
                            width: 28
                            height: 28
                            radius: 14
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.color.accents[swatch.modelData].bg
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Theme.color.accents[swatch.modelData].bg
                            border.width: 0.5
                            border.color: Qt.rgba(0, 0, 0, 0.15)
                            scale: swatchArea.containsMouse ? 1.1 : 1
                            Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                        }
                        MouseArea {
                            id: swatchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Appearance.setAccent(swatch.modelData)
                        }
                    }
                }
            }
        }
    }

    // A module: a capsule of thin glass with a lit rim.
    component Module: Rectangle {
        radius: Theme.radius.module
        color: Theme.color.material.thin.tint
        border.width: 1
        border.color: Theme.color.glass.rim
    }

    // A round toggle: on is a solid circle, accent with a white glyph in light
    // mode, white with an accent glyph in dark.
    component Toggle: Rectangle {
        id: toggle
        property string icon
        property bool on
        property real glyph: 18
        signal clicked

        readonly property bool showOn: on && cc.lit
        width: Theme.size.controlCenter.toggle
        height: width
        radius: width / 2
        color: showOn ? (Theme.dark ? Theme.color.label.primary : Theme.accent.bg) : Theme.color.fill.primary
        scale: toggleArea.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: cc.lit ? Theme.choreography.controlCenter.lightUp : 0 } }
        Behavior on scale { SpringAnimation { spring: 8; damping: 0.5 } }

        Icon {
            anchors.centerIn: parent
            name: toggle.icon
            size: toggle.glyph
            color: toggle.showOn ? (Theme.dark ? Theme.accent.bg : Theme.accent.fg) : Theme.color.label.primary
        }
        MouseArea {
            id: toggleArea
            anchors.fill: parent
            onClicked: toggle.clicked()
        }
    }

    // Toggle, title and detail on a two-cell capsule. The toggle switches it;
    // the rest of the capsule opens its settings.
    component Pill: Module {
        id: pill
        property point position
        property string icon
        property string title
        property string detail
        property bool on
        signal toggled
        signal opened

        x: position.x
        y: position.y
        width: cc.span(2)
        height: cc.unit
        opacity: enabled ? 1 : 0.5

        MouseArea {
            anchors.fill: parent
            onClicked: pill.opened()
        }
        Toggle {
            id: pillToggle
            x: Theme.space.s3
            anchors.verticalCenter: parent.verticalCenter
            icon: pill.icon
            on: pill.on
            onClicked: pill.toggled()
        }
        Column {
            anchors { left: pillToggle.right; right: parent.right; leftMargin: Theme.space.s2; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

            Label {
                width: parent.width
                text: pill.title
                style: Theme.text.headline
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: pill.detail
                style: Theme.text.caption
                color: Theme.color.label.secondary
                elide: Text.ElideRight
            }
        }
    }

    // A one-cell round control.
    component Circle: Toggle {
        property point position
        signal toggled
        x: position.x
        y: position.y
        width: cc.unit
        glyph: 22
        onClicked: toggled()
    }

    component Transport: Item {
        id: transportButton
        property string icon
        property real size
        signal clicked
        width: size
        height: size
        opacity: enabled ? 1 : 0.4
        scale: transportArea.pressed ? 0.9 : 1
        Behavior on scale { SpringAnimation { spring: 8; damping: 0.5 } }

        Icon {
            anchors.centerIn: parent
            name: transportButton.icon
            size: transportButton.size
            color: transportArea.containsMouse ? Theme.color.label.primary : Theme.color.label.secondary
        }
        MouseArea {
            id: transportArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: transportButton.clicked()
        }
    }

    // A titled slider across the grid. Drag or click the track to set it.
    component Bar: Module {
        id: barModule
        property point position
        property string title
        property real value
        property string lowIcon
        property string highIcon
        signal moved(real value)
        signal lowIconClicked

        x: position.x
        y: position.y
        width: cc.span(4)
        height: cc.unit
        opacity: enabled ? 1 : 0.5

        Label {
            x: Theme.space.s4
            y: Theme.space.s2
            text: barModule.title
            style: Theme.text.headline
        }

        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s4; bottomMargin: Theme.space.s3 }
            spacing: Theme.space.s2

            Icon {
                id: low
                anchors.verticalCenter: parent.verticalCenter
                name: barModule.lowIcon
                size: barModule.highIcon ? 13 : 16

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: barModule.lowIconClicked()
                }
            }

            Item {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - low.width - (high.visible ? high.width : 0) - parent.spacing * (high.visible ? 2 : 1)
                height: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.size.controlCenter.track
                    radius: height / 2
                    color: Theme.color.fill.primary

                    Rectangle {
                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, barModule.value)))
                        height: parent.height
                        radius: height / 2
                        color: Theme.color.label.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    preventStealing: true
                    function set(mouseX) {
                        barModule.moved(Math.max(0, Math.min(1, mouseX / track.width)));
                    }
                    onPressed: mouse => set(mouse.x)
                    onPositionChanged: mouse => set(mouse.x)
                }
            }

            Icon {
                id: high
                visible: barModule.highIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: barModule.highIcon
                size: 19
            }
        }
    }
}
