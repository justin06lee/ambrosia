import QtQuick
import Ambrosia
import "../../../session/plasma-shell/org.ambrosia.desktop/contents/lockscreen"

// The lock screen where KDE's locker isn't: LockScreen.qml as it is, with
// stand-ins for what the locker hands it (an authenticator that never
// answers, an account's name, no picture of its own, and a wallpaper item,
// which the locker would draw from kscreenlockerrc). The time is the Mac's
// own.
Item {
    id: sheet

    width: 1440
    height: 900

    readonly property string kscreenlocker_userName: "Ada Lovelace"
    readonly property string kscreenlocker_userImage: ""
    readonly property Item wallpaper: picture

    QtObject {
        id: authenticator
        readonly property bool unlocked: false
        readonly property bool hadPrompt: false
        signal promptForSecretChanged()
        signal failed(int kind)
        signal succeeded()
        function startAuthenticating() {}
        function stopAuthenticating() {}
        function respond(password) {}
    }

    Image {
        id: picture
        anchors.fill: parent
        source: "../../../out/build/qmlshot/wallpapers/" + (shotDark ? "nectar-night.png" : "nectar-day.png")
        fillMode: Image.PreserveAspectCrop
    }

    LockScreen {
        anchors.fill: parent
        focus: true
        // The session's colors, which the locker has from kdeglobals.
        night: shotDark
    }
}
