import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Ambrosia

// Ambrosia's login screen, in the manner of a Mac's: the desktop picture,
// the date and time at the top, and near the bottom the account's picture,
// its name and a password field; Sleep, Restart and Shut Down under them.
// Every size and color is a design token (the Ambrosia Theme module); SDDM
// loads this once per screen and hands it `sddm`, `userModel`,
// `sessionModel`, `keyboard` and `config` (theme.conf).
Item {
    id: root

    width: 1920
    height: 1200

    // Night from six to six, unless theme.conf says which.
    property date now: new Date()
    readonly property string appearance: config.appearance || "auto"
    readonly property bool night: appearance === "dark"
        || (appearance !== "light" && (now.getHours() < 6 || now.getHours() >= 18))
    Binding { target: Theme; property: "dark"; value: root.night }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // The tokens are a Mac's points; a login screen is seen whole, so they
    // grow with the screen.
    readonly property real u: Math.max(1, height / 900)
    readonly property color ink: Theme.color.label.primary
    readonly property color faint: Theme.color.label.secondary
    readonly property color glass: Theme.color.material.thin.tint
    readonly property color rim: Theme.color.glass.rim

    // Who is logging in, and into what: the last of each to start with.
    property int userIndex: Math.max(0, userModel.lastIndex)
    property string userName: userModel.lastUser
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string sessionName: ""
    property bool busy: false

    function login() {
        if (busy || !userName) return;
        busy = true;
        sddm.login(userName, password.text, sessionIndex);
    }
    function choose(index) {
        if (busy || index < 0 || index >= users.count) return;
        userIndex = index;
        password.text = "";
        password.forceActiveFocus();
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            password.text = "";
            shake.restart();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            leave.start();
        }
    }

    component Glyph: Shape {
        id: glyph
        property string path
        property color color: root.ink
        property real size: 24 * root.u
        width: size
        height: size
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: glyph.color
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            scale: Qt.size(glyph.size / 24, glyph.size / 24)
            PathSvg { path: glyph.path }
        }
    }

    // A round glass button with its name under it.
    component PowerButton: Item {
        id: button
        property string name
        property string path
        signal pressed()
        width: 64 * root.u
        height: disc.height + 6 * root.u + caption.height
        opacity: enabled ? 1 : 0.4

        Rectangle {
            id: disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.size.control.large * root.u
            height: width
            radius: width / 2
            color: root.glass
            border.width: 1
            border.color: root.rim
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.ink
                opacity: area.pressed ? 0.16 : area.containsMouse ? 0.08 : 0
            }
            Glyph {
                anchors.centerIn: parent
                size: 20 * root.u
                path: button.path
            }
        }
        Text {
            id: caption
            anchors.top: disc.bottom
            anchors.topMargin: 6 * root.u
            anchors.horizontalCenter: parent.horizontalCenter
            text: button.name
            color: root.faint
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.caption.size * root.u
            font.weight: Theme.text.caption.weight
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.pressed()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.night ? "#1a1430" : "#f7e9d2"
    }
    Image {
        id: picture
        anchors.fill: parent
        source: config.background
            || "/usr/share/ambrosia/wallpapers/" + (root.night ? "nectar-night.png" : "nectar-day.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.slow } }
    }

    Item {
        id: content
        anchors.fill: parent

        // The date over the time.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.085
            spacing: -4 * root.u

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "dddd, MMMM d")
                color: root.ink
                opacity: 0.8
                font.family: Theme.uiFont
                font.pixelSize: 22 * root.u
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // The locale's own clock, 12 or 24 hours, without its AM or PM.
                text: {
                    const locale = Qt.locale();
                    return root.now.toLocaleTimeString(locale, Locale.ShortFormat)
                        .replace(locale.amText, "").replace(locale.pmText, "").trim();
                }
                color: root.ink
                opacity: 0.72
                font.family: Theme.uiFont
                font.pixelSize: 112 * root.u
                font.weight: Font.Bold
                font.letterSpacing: -3 * root.u
                font.features: { "tnum": 1 }
            }
        }

        // The accounts, the chosen one larger; its password field under them.
        Column {
            id: account
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: power.top
            anchors.bottomMargin: root.height * 0.07
            spacing: Theme.space.s3 * root.u

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space.s8 * root.u

                Repeater {
                    id: users
                    model: userModel

                    Item {
                        id: person
                        required property int index
                        required property string name
                        required property string realName
                        required property string icon
                        readonly property bool chosen: index === root.userIndex
                        readonly property string shown: realName || name
                        // SDDM's stand-in for an account without a picture.
                        readonly property bool faceless: icon === "" || icon.endsWith("/faces/.face.icon")
                        readonly property real side: (chosen ? 64 : 44) * root.u
                        onChosenChanged: if (chosen) root.userName = name
                        Component.onCompleted: if (chosen) root.userName = name

                        width: Math.max(side, label.implicitWidth)
                        height: 64 * root.u + Theme.space.s2 * root.u + label.height
                        opacity: chosen ? 1 : 0.7

                        Rectangle {
                            id: face
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: label.top
                            anchors.bottomMargin: Theme.space.s2 * root.u
                            width: person.side
                            height: person.side
                            radius: width / 2
                            color: root.glass
                            border.width: 1
                            border.color: root.rim
                            Behavior on width { NumberAnimation { duration: Theme.fade.base; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                visible: person.faceless || photo.status !== Image.Ready
                                text: person.shown.split(/\s+/).slice(0, 2).map(word => word.charAt(0).toUpperCase()).join("")
                                color: root.ink
                                font.family: Theme.uiFont
                                font.pixelSize: parent.width * 0.38
                                font.weight: Font.DemiBold
                            }
                            Image {
                                id: photo
                                anchors.fill: parent
                                anchors.margins: 1
                                source: person.faceless ? "" : person.icon
                                sourceSize: Qt.size(128 * root.u, 128 * root.u)
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                            }
                            Rectangle {
                                id: round
                                anchors.fill: photo
                                radius: width / 2
                                visible: false
                                layer.enabled: true
                            }
                            MultiEffect {
                                anchors.fill: photo
                                visible: !person.faceless && photo.status === Image.Ready
                                source: photo
                                maskEnabled: true
                                maskSource: round
                            }
                        }
                        Text {
                            id: label
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: person.shown
                            color: root.ink
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.text.title3.size * root.u
                            font.weight: person.chosen ? Theme.text.title3.weight : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.choose(person.index)
                        }
                    }
                }
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 200 * root.u
                height: Theme.size.control.regular * root.u + 2
                radius: height / 2
                color: root.glass
                border.width: 1
                border.color: root.rim
                opacity: root.busy ? 0.6 : 1

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: nudge; property: "x"; to: -10 * root.u; duration: 50 }
                    NumberAnimation { target: nudge; property: "x"; to: 9 * root.u; duration: 70 }
                    NumberAnimation { target: nudge; property: "x"; to: -6 * root.u; duration: 70 }
                    NumberAnimation { target: nudge; property: "x"; to: 4 * root.u; duration: 70 }
                    NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
                }
                transform: Translate { id: nudge }

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.s3 * root.u
                    anchors.rightMargin: (caps.visible || go.visible ? 30 : 12) * root.u
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    focus: true
                    enabled: !root.busy
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.ink
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: root.ink
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.text.body.size * root.u
                    onAccepted: root.login()
                    Keys.onLeftPressed: event => {
                        if (text === "" && users.count > 1) root.choose(root.userIndex - 1);
                        else event.accepted = false;
                    }
                    Keys.onRightPressed: event => {
                        if (text === "" && users.count > 1) root.choose(root.userIndex + 1);
                        else event.accepted = false;
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: password.text === ""
                        text: "Enter Password"
                        color: root.faint
                        font: password.font
                    }
                }
                // Caps Lock is on.
                Glyph {
                    id: caps
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    visible: keyboard.capsLock && !go.visible
                    size: 16 * root.u
                    color: root.faint
                    path: "M12 4.5 5 12h4v3.5h6V12h4zM9 18.5h6"
                }
                Rectangle {
                    id: go
                    anchors.right: parent.right
                    anchors.rightMargin: 4 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    visible: password.text !== ""
                    width: parent.height - 8 * root.u
                    height: width
                    radius: width / 2
                    color: Qt.alpha(root.ink, goArea.pressed ? 0.3 : 0.16)
                    Glyph {
                        anchors.centerIn: parent
                        size: 14 * root.u
                        path: "M5 12h13.5M13 6.5l5.5 5.5-5.5 5.5"
                    }
                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        onClicked: root.login()
                    }
                }
            }
        }

        Row {
            id: power
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.height * 0.05
            spacing: Theme.space.s4 * root.u

            PowerButton {
                name: "Sleep"
                path: "M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"
                enabled: sddm.canSuspend
                onPressed: sddm.suspend()
            }
            PowerButton {
                name: "Restart"
                path: "M6 6.5v5h5M6.6 11A7 7 0 1 1 5 13.5"
                enabled: sddm.canReboot
                onPressed: sddm.reboot()
            }
            PowerButton {
                name: "Shut Down"
                path: "M12 3.5v8M7.2 6.3a7.5 7.5 0 1 0 9.6 0"
                enabled: sddm.canPowerOff
                onPressed: sddm.powerOff()
            }
        }

        // What to log into, when there is more than Ambrosia: click for the next.
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.s4 * root.u
            visible: sessions.count > 1
            text: root.sessionName
            color: root.faint
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.body.size * root.u
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.space.s2 * root.u
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
            }
        }
        Repeater {
            id: sessions
            model: sessionModel
            Item {
                required property int index
                required property string name
                readonly property bool chosen: index === root.sessionIndex
                onChosenChanged: if (chosen) root.sessionName = name
                Component.onCompleted: if (chosen) root.sessionName = name
            }
        }
    }

    // Logged in: the screen clears for the desktop.
    NumberAnimation {
        id: leave
        target: content
        property: "opacity"
        to: 0
        duration: Theme.fade.base
    }

    Component.onCompleted: password.forceActiveFocus()
}
