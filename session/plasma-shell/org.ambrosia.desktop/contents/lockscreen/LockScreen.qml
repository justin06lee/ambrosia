import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import Ambrosia

// Ambrosia's lock screen: the login screen's own picture (Login.qml is the
// SDDM theme's Main.qml) for the one account, over the user's desktop
// picture, which KDE's locker draws behind this from kscreenlockerrc (the
// shell keeps that in step with its own; shell/Wallpaper.qml).
//
// KDE's locker (kscreenlocker_greet) loads this from the Plasma shell
// package the session names (/etc/xdg/ambrosia/plasmashellrc) and hands it
// `authenticator`, `kscreenlocker_userName`, `kscreenlocker_userImage` and
// `wallpaper`. A file here that doesn't load makes it fall back to its
// built-in screen; one that loads and doesn't unlock keeps its user out,
// so the talk with PAM below is as Plasma's own lock screen has it, and
// `loginctl unlock-session` from a console always lets in.
//
// To look at it without locking:
//   /usr/lib/kscreenlocker_greet --testing --shell org.ambrosia.desktop
Item {
    id: lock

    // What the locker looks for on this item.
    property bool viewVisible: false
    property bool locked: false

    // PAM has asked for the password and waits for it.
    property bool asked: false
    // A password typed before PAM asked: given as soon as it does.
    property string pending: ""
    property bool held: false
    // Let in without a password being asked (an account with none): Return
    // or the arrow leaves.
    property bool open: false

    function answer(password) {
        if (open) {
            Qt.quit();
        } else if (asked) {
            asked = false;
            authenticator.respond(password);
        } else {
            pending = password;
            held = true;
            authenticator.startAuthenticating();
        }
    }

    implicitWidth: 800
    implicitHeight: 600

    Connections {
        target: authenticator

        function onPromptForSecretChanged() {
            if (lock.held) {
                const password = lock.pending;
                lock.pending = "";
                lock.held = false;
                authenticator.respond(password);
            } else {
                lock.asked = true;
            }
        }
        // `kind` is 0 for the password, something else for a fingerprint
        // reader and the like, which fail on their own.
        function onFailed(kind) {
            if (kind != 0) return;
            lock.asked = false;
            lock.held = false;
            lock.pending = "";
            sddm.loginFailed();
            authenticator.startAuthenticating();
        }
        function onSucceeded() {
            // Ends what is still asking, so nothing times out behind us.
            authenticator.stopAuthenticating();
            if (authenticator.hadPrompt) {
                sddm.loginSucceeded();
                Qt.quit();
            } else {
                lock.open = true;
            }
        }
    }

    // PAM is kept asking for as long as the screen is locked, so a
    // password typed at any time has someone to go to.
    Timer {
        interval: 1000
        running: !authenticator.unlocked
        repeat: true
        triggeredOnStart: true
        onTriggered: authenticator.startAuthenticating()
    }

    // The locker draws the picture kscreenlockerrc names under this item;
    // when it has none to draw, ours.
    // The locker's colors are the session's: dark when its window color is.
    SystemPalette { id: system }
    property bool night: system.window.hslLightness < 0.5
    Image {
        anchors.fill: parent
        visible: typeof wallpaper === "undefined" || !wallpaper
        source: visible ? "/usr/share/ambrosia/wallpapers/" + (lock.night ? "nectar-night.png" : "nectar-day.png") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // What SDDM hands its theme, as the locker has it.
    QtObject {
        id: sddm
        readonly property bool canSuspend: false
        readonly property bool canReboot: false
        readonly property bool canPowerOff: false
        signal loginFailed()
        signal loginSucceeded()
        function login(user, password, session) {
            lock.answer(password);
        }
        function suspend() {}
        function reboot() {}
        function powerOff() {}
    }
    ListModel {
        id: userModel
        readonly property int lastIndex: 0
        readonly property string lastUser: kscreenlocker_userName
        Component.onCompleted: append({
            name: kscreenlocker_userName,
            realName: kscreenlocker_userName,
            icon: kscreenlocker_userImage === "" ? ""
                : "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/"),
        })
    }
    ListModel {
        id: sessionModel
        readonly property int lastIndex: 0
    }
    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }
    QtObject {
        id: keyboard
        readonly property bool capsLock: capsLockState.locked
    }
    QtObject {
        id: config
        readonly property string appearance: lock.night ? "dark" : "light"
        readonly property string background: ""
    }

    Login {
        anchors.fill: parent
        focus: true
        lockScreen: true
    }
}
