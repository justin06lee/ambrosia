import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Ambrosia

// A new account's first minutes, as a Mac's setup ends: a welcome, then
// Choose Your Look (light, dark or auto, each as a small picture of the
// desktop; the choice takes at once, behind the panel too). It covers the
// first screen, the desktop blurred behind it, until it is done; an account
// sees it once (Settings.welcome, set when the shell finds no settings at
// all), and `ambrosia welcome` shows it again. Return continues, the arrows
// choose a look, Escape goes back a page.
PanelWindow {
    id: welcome

    // The screen this window was made for.
    required property ShellScreen home
    readonly property bool open: Popups.welcomeOpen
    // 0 the welcome, 1 the look.
    property int page: 0
    readonly property var looks: [
        { key: "light", name: "Light" },
        { key: "dark", name: "Dark" },
        { key: "auto", name: "Auto" },
    ]
    readonly property QtObject size: Theme.size.welcome
    // Installed beside the shell; AMBROSIA_WALLPAPERS points a dev checkout elsewhere.
    readonly property string pictures: "file://" + (Quickshell.env("AMBROSIA_WALLPAPERS") || Quickshell.shellDir + "/../wallpapers")

    function choose(look) {
        if (look === "auto")
            Settings.appearance = "auto";
        else
            Appearance.setDark(look === "dark");
    }
    function step(by) {
        const at = looks.findIndex(look => look.key === Settings.appearance);
        choose(looks[Math.max(0, Math.min(looks.length - 1, at + by))].key);
    }
    function next() {
        if (page === 0) {
            page = 1;
            return;
        }
        Settings.welcome = false;
        Popups.welcomeOpen = false;
    }

    // The settings are read a moment after the shell starts.
    function greet() {
        if (Settings.loaded && Settings.welcome)
            Popups.welcomeOpen = true;
    }
    Component.onCompleted: greet()
    Connections {
        target: Settings
        function onLoadedChanged() { welcome.greet(); }
    }
    onOpenChanged: {
        if (!open) return;
        page = 0;
        keys.forceActiveFocus();
    }

    screen: home
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambrosia-welcome"
    WlrLayershell.keyboardFocus: open && asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: veil }

    // KWin hands a layer surface the keyboard when it starts to ask for it,
    // not for as long as it asks: a window that opens while this is up
    // takes the keyboard away. So when it goes, this stops asking for a
    // moment and asks again. Quickshell sends what a window asks for with
    // the window's next frame, so each change has to draw one (`redrawn`).
    property bool asking: true
    readonly property bool hasKeyboard: veil.Window.active
    onHasKeyboardChanged: {
        if (open && asking && !hasKeyboard) {
            asking = false;
            askAgain.start();
        }
    }
    Timer {
        id: askAgain
        interval: 80
        onTriggered: welcome.asking = true
    }

    // The desktop behind, blurred by the compositor and quietened.
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.color.material.thin.tint
        opacity: welcome.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }

        // Something that changes with `asking`, so that a frame is drawn.
        Rectangle {
            id: redrawn
            width: 1
            height: 1
            color: welcome.asking ? "#01000000" : "#02000000"
        }

        // Nothing under it takes a click while it is up.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: welcome.open
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    welcome.next();
                    break;
                case Qt.Key_Left:
                    if (welcome.page === 1) welcome.step(-1);
                    break;
                case Qt.Key_Right:
                    if (welcome.page === 1) welcome.step(1);
                    break;
                case Qt.Key_Escape:
                    if (welcome.page === 1) welcome.page = 0;
                    break;
                }
                event.accepted = true;
            }
        }

        Item {
            id: panel
            anchors.centerIn: parent
            width: welcome.size.width
            height: welcome.size.height
            scale: welcome.open ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: Theme.fade.base; easing.type: Easing.OutCubic } }

            Glass {
                anchors.fill: parent
                tint: Theme.color.material.thick.tint
                radius: Theme.radius.panel
                shadow: Theme.color.shadow.window
            }

            // The welcome.
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.space.s6
                width: parent.width - 2 * welcome.size.padding
                spacing: Theme.space.s4
                opacity: welcome.page === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "bowl"
                    size: welcome.size.mark
                    color: Theme.color.label.primary
                }
                Item { width: 1; height: Theme.space.s2 }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome to Ambrosia"
                    style: Theme.text.largeTitle
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "One choice to make, and it’s yours. Anything here can be changed later in System Settings."
                    color: Theme.color.label.secondary
                }
            }

            // Choose Your Look.
            Column {
                anchors { top: parent.top; topMargin: welcome.size.padding + Theme.space.s4; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 2 * welcome.size.padding
                spacing: Theme.space.s2
                opacity: welcome.page === 1 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Choose Your Look"
                    style: Theme.text.largeTitle
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Select an appearance and see how the Dock, menus, buttons and windows adjust."
                    color: Theme.color.label.secondary
                }
                Item { width: 1; height: Theme.space.s10 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: welcome.size.lookGap

                    Repeater {
                        model: welcome.looks

                        Item {
                            id: look
                            required property var modelData
                            readonly property bool chosen: Settings.appearance === modelData.key
                            readonly property int room: welcome.size.ring + welcome.size.ringGap

                            width: welcome.size.lookWidth + 2 * room
                            height: picture.height + 2 * room + Theme.space.s2 + name.height

                            // The ring round the chosen one.
                            Rectangle {
                                width: parent.width
                                height: picture.height + 2 * look.room
                                radius: Theme.radius.card + look.room
                                color: "transparent"
                                border.width: welcome.size.ring
                                border.color: Theme.accent.bg
                                visible: look.chosen
                            }
                            Item {
                                id: picture
                                x: look.room
                                y: look.room
                                width: welcome.size.lookWidth
                                height: welcome.size.lookHeight

                                // Auto is both: light on the left, dark on the right.
                                Mini {
                                    width: look.modelData.key === "auto" ? parent.width / 2 : parent.width
                                    full: parent.width
                                    night: look.modelData.key === "dark"
                                }
                                Mini {
                                    visible: look.modelData.key === "auto"
                                    x: parent.width / 2
                                    width: parent.width / 2
                                    full: parent.width
                                    night: true
                                }
                            }
                            Label {
                                id: name
                                anchors { top: picture.bottom; topMargin: look.room + Theme.space.s2; horizontalCenter: parent.horizontalCenter }
                                text: look.modelData.name
                                font.weight: look.chosen ? Font.DemiBold : Theme.text.body.weight
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: welcome.choose(look.modelData.key)
                            }
                        }
                    }
                }
            }

            PushButton {
                anchors { left: parent.left; bottom: parent.bottom; margins: Theme.space.s6 }
                text: "Back"
                visible: welcome.page === 1
                onClicked: welcome.page = 0
            }
            PushButton {
                anchors { right: parent.right; bottom: parent.bottom; margins: Theme.space.s6 }
                text: "Continue"
                primary: true
                onClicked: welcome.next()
            }
        }
    }

    // A small picture of the desktop in one look: its wallpaper, the menu
    // bar, a window with a sidebar, the Dock. `width` may be a part of it
    // (Auto shows half of each); `full` is the whole picture's width.
    component Mini: Item {
        id: mini

        property bool night
        property real full: width
        readonly property QtObject look: night ? Theme.darkColors : Theme.lightColors

        height: parent.height
        clip: true

        ClippingRectangle {
            // The whole picture, of which this may show the left or the right part.
            x: -mini.x
            width: mini.full
            height: mini.height
            radius: Theme.radius.card
            color: mini.look.bg.window

            Image {
                anchors.fill: parent
                source: welcome.pictures + (mini.night ? "/nectar-night.png" : "/nectar-day.png")
                sourceSize.width: 2 * mini.full
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // The menu bar.
            Rectangle {
                width: parent.width
                height: Math.round(parent.height * 0.07)
                color: Qt.alpha(mini.look.bg.window, 0.6)
            }
            // A window: a sidebar, its lights, a default button.
            Rectangle {
                x: Math.round(parent.width * 0.2)
                y: Math.round(parent.height * 0.2)
                width: Math.round(parent.width * 0.6)
                height: Math.round(parent.height * 0.5)
                radius: Theme.radius.minimum
                color: mini.look.bg.window
                border.width: 1
                border.color: mini.look.separator
                clip: true

                Rectangle {
                    width: Math.round(parent.width * 0.3)
                    height: parent.height
                    color: mini.look.bg.sidebar
                }
                Row {
                    x: 5
                    y: 5
                    spacing: 3
                    Repeater {
                        model: [Theme.windowControls.close, Theme.windowControls.minimize, Theme.windowControls.zoom]
                        Rectangle {
                            required property color modelData
                            width: 5
                            height: 5
                            radius: 2.5
                            color: modelData
                        }
                    }
                }
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                    width: 22
                    height: 8
                    radius: 3
                    color: mini.look.accents[Settings.accent].bg
                }
            }
            // The Dock.
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                width: Math.round(parent.width * 0.42)
                height: Math.round(parent.height * 0.11)
                radius: height / 3
                color: Qt.alpha(mini.look.bg.window, 0.7)
            }
        }
    }
}
