import QtQuick
import org.kde.kwin as KWin
import Ambrosia

// Mission Control: every window of this desktop spread out so each can be
// seen, under a strip of the desktops (a Mac's Spaces), with the menu bar
// and the Dock left where they are. The same spread with one app's windows
// only is a Mac's App Exposé. A click on a window goes to it; Esc, a click
// beside the windows or the key again leaves.
//
// KWin draws nothing else while this is up (a scene effect), so what stays
// on screen is drawn here: MissionScreen.qml, once a screen.
KWin.SceneEffect {
    id: effect

    // "all": this desktop's windows and the desktops' strip. "app": the
    // front app's windows, minimized ones too, on every desktop.
    property string mode: "all"
    // The app whose windows "app" shows, as KWin knows it.
    property string appClass: ""
    // Whether the windows are spread out. Off first, so they fly back, and
    // the effect ends when they have.
    property bool shown: false
    readonly property int duration: (configuration.Duration ?? 0) > 0
        ? configuration.Duration : Theme.exit.smooth.duration

    function show(what) {
        if (visible && shown && mode === what) {
            hide();
            return;
        }
        if (what === "app") {
            const front = KWin.Workspace.activeWindow;
            if (!front || front.skipSwitcher || !(front.normalWindow || front.dialog)) return;
            appClass = front.resourceClass;
        }
        leave.stop();
        mode = what;
        visible = true;
        shown = true;
    }

    function hide() {
        if (!visible) return;
        shown = false;
        leave.restart();
    }

    // Fingers on a trackpad: up for Mission Control, down for the app's
    // windows, and the other way out of either.
    function swipe(up) {
        if (!(visible && shown)) show(up ? "all" : "app");
        else if ((mode === "all") !== up) hide();
    }

    Timer {
        id: leave
        interval: effect.duration
        onTriggered: effect.visible = false
    }

    delegate: MissionScreen { mission: effect }

    // A Mac's ⌃↑ and ⌃↓. Ctrl with an arrow is an app's own here (by word
    // in text), so the keys are chords nothing else has, and the Mac-first
    // keyboard (packaging/keyd) presses them for ⌃↑ and ⌃↓.
    KWin.ShortcutHandler {
        name: "Ambrosia Mission Control"
        text: "Mission Control"
        sequence: "Meta+Ctrl+Alt+Up"
        onActivated: effect.show("all")
    }

    KWin.ShortcutHandler {
        name: "Ambrosia App Windows"
        text: "Application Windows"
        sequence: "Meta+Ctrl+Alt+Down"
        onActivated: effect.show("app")
    }

    // A Mac's four fingers up and down. (KWin's Overview, which has the
    // same gesture, is off in the session's kwinrc.)
    KWin.SwipeGestureHandler {
        direction: KWin.SwipeGestureHandler.Direction.Up
        fingerCount: 4
        onActivated: effect.swipe(true)
    }

    KWin.SwipeGestureHandler {
        direction: KWin.SwipeGestureHandler.Direction.Down
        fingerCount: 4
        onActivated: effect.swipe(false)
    }
}
