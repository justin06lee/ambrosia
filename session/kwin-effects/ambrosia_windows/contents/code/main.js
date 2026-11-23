"use strict";

// How a window opens and closes in Ambrosia, as a Mac's does: it swells into
// place from a little smaller while it fades in, and when it is closed it is
// simply gone, so nothing here answers a window closing. This stands in for
// KWin's own Scale, which shrinks a closing window away (the session's
// kwinrc switches that off and this on).
//
// It also hides apps (⌘H, ⌥⌘H, the app menu's Hide rows): see the end.

// The size a window starts at. By eye: there is no recording of a Mac to
// measure yet.
const startScale = 0.9;
// The snappy spring's settling time, in ms (design/tokens.ts, spring.snappy).
// "Duration" in kwinrc's [Effect-ambrosia_windows] overrides it (it is
// declared in ../config/main.xml, without which KWin reads no setting): slow
// it down to look at the motion.
const snappy = 290;
let openTime = animationTime(snappy);

function readConfig() {
    openTime = animationTime(effect.readConfig("Duration", 0) || snappy);
}

// The logout prompt and the splash screen have effects of their own, and
// Spectacle's region picker must cover the screen at once.
const others = ["ksmserver ksmserver", "ksmserver-logout-greeter ksmserver-logout-greeter", "ksplashqml ksplashqml"];

// An app's windows and dialogs: not menus, tooltips, the shell's own
// surfaces, the lock screen, or anything KWin doesn't manage.
function opens(window) {
    if (others.includes(window.windowClass)) {
        return false;
    }
    if (window.windowClass == "spectacle org.kde.spectacle" && window.tag == "region-editor") {
        return false;
    }
    if (window.popupWindow || window.lockScreen || window.outline || !window.managed) {
        return false;
    }
    return window.normalWindow || window.dialog;
}

// What is behind a see-through window stays blurred while the window is
// drawn smaller than it is.
function hold(window, on) {
    window.setData(Effect.WindowForceBlurRole, on ? true : null);
    window.setData(Effect.WindowForceBackgroundContrastRole, on ? true : null);
}

function stop(window) {
    if (window.ambrosiaOpening) {
        cancel(window.ambrosiaOpening);
        delete window.ambrosiaOpening;
        hold(window, false);
    }
}

effects.windowAdded.connect(window => {
    if (effects.hasActiveFullScreenEffect || !opens(window) || !window.visible) {
        return;
    }
    if (effect.isGrabbed(window, Effect.WindowAddedGrabRole)) {
        return;
    }
    hold(window, true);
    window.ambrosiaOpening = animate({
        window: window,
        curve: QEasingCurve.OutQuart,
        duration: openTime,
        animations: [
            { type: Effect.Scale, from: startScale },
            { type: Effect.Opacity, from: 0 },
        ],
    });
});

// Another effect has taken the window's arrival for itself.
effects.windowDataChanged.connect((window, role) => {
    if (role == Effect.WindowAddedGrabRole && effect.isGrabbed(window, role)) {
        stop(window);
    }
});

effect.animationEnded.connect(window => {
    delete window.ambrosiaOpening;
    hold(window, false);
});
effect.configChanged.connect(readConfig);
readConfig();

// Hiding an app, as ⌘H does on a Mac: its windows are put away at once, with
// no motion, and are all back at once when the app is next brought forward
// (from the Dock, ⌘Tab, or by itself). To KWin they are minimized, so the
// Dock and ⌘Tab still list the app. The actions go by these names in KWin's
// own shortcuts (System Settings lists them); the shell's menus run them by
// name, and the Mac-first keyboard sends the first two chords for ⌘H and
// ⌥⌘H (packaging/keyd).

// The windows Hide put away, until their app is shown again.
let hidden = [];
// Set while this puts windows away or brings them back itself.
let busy = false;

// An app is the class of its windows: its id on Wayland.
function appOf(window) {
    return window.windowClass.split(" ").pop();
}

// The windows an app is hidden by: not the shell's own, which no switcher
// lists either.
function hides(window) {
    return window.managed && !window.deleted && !window.skipSwitcher
        && (window.normalWindow || window.dialog);
}

// KWin's Genie (and Scale) play for every window put away or brought back,
// except while some effect has the whole screen. So this one takes it, for
// as long as `change` runs or for `time` ms; meanwhile whatever is blurred
// stays blurred, which it otherwise wouldn't under such an effect.
let quiet = null;
let quietOn = null;

function quietStart(time) {
    const on = effects.stackingOrder.find(window => window.visible && !window.deleted);
    if (quiet || !on) {
        return false;
    }
    effects.stackingOrder.forEach(window => hold(window, true));
    quietOn = on;
    quiet = animate({
        window: on,
        duration: time,
        fullScreen: true,
        animations: [{ type: Effect.Opacity, from: 1, to: 1 }],
    });
    return true;
}

function quietEnded() {
    quiet = quietOn = null;
    effects.stackingOrder.forEach(window => {
        if (!window.ambrosiaOpening) {
            hold(window, false);
        }
    });
}

// KWin doesn't say which animation ended, only that this effect no longer
// has the screen.
effect.isActiveFullScreenEffectChanged.connect(() => {
    if (quiet && !effect.isActiveFullScreenEffect) {
        quietEnded();
    }
});

function quietly(change) {
    // Ended here, not by the clock: a window put away is no longer drawn,
    // and an animation on one never ends.
    const mine = quietStart(1000);
    change();
    if (mine) {
        cancel(quiet);
        quietEnded();
    }
}

function forget() {
    hidden = hidden.filter(window => !window.deleted && window.minimized);
}

function putAway(windows) {
    busy = true;
    quietly(() => {
        for (const window of windows) {
            if (window.minimized) {
                continue;
            }
            window.minimized = true;
            if (window.minimized) {
                hidden.push(window);
            }
        }
    });
    busy = false;
}

// Brings them back, in front of everything, `front` (if any) on top.
function bringBack(windows, front) {
    busy = true;
    quietly(() => {
        for (const window of windows) {
            window.minimized = false;
        }
    });
    hidden = hidden.filter(window => !windows.includes(window));
    for (const window of windows) {
        effects.activeWindow = window;
    }
    if (front) {
        effects.activeWindow = front;
    }
    busy = false;
}

registerShortcut("Ambrosia Hide App", "Hide the App in Front", "Meta+Ctrl+Alt+H", () => {
    const front = effects.activeWindow;
    if (!front || !hides(front)) {
        return;
    }
    const app = appOf(front);
    putAway(effects.stackingOrder.filter(window => hides(window) && appOf(window) == app));
});

registerShortcut("Ambrosia Hide Others", "Hide Every App but the One in Front", "Meta+Ctrl+Alt+Shift+H", () => {
    const front = effects.activeWindow;
    const app = front && hides(front) ? appOf(front) : "";
    putAway(effects.stackingOrder.filter(window => hides(window) && appOf(window) != app));
});

registerShortcut("Ambrosia Show All", "Show Every Hidden App", "", () => {
    forget();
    const front = effects.activeWindow;
    bringBack(hidden.slice(), front && hides(front) ? front : null);
});

// The shell runs this just before it brings a hidden app forward itself (a
// click in the Dock): for a moment windows come back with no motion.
registerShortcut("Ambrosia Show Without Motion", "Bring the Next Windows Back at Once", "", () => {
    quietStart(300);
});

// ⌘Tab brings its window forward the moment it closes.
effects.tabBoxClosed.connect(() => {
    forget();
    if (hidden.length > 0) {
        quietStart(150);
    }
});

// One window of a hidden app has come forward: the rest come with it.
effects.windowActivated.connect(window => {
    if (busy || !window || !hides(window)) {
        return;
    }
    forget();
    const app = appOf(window);
    const rest = hidden.filter(other => appOf(other) == app);
    if (rest.length > 0) {
        bringBack(rest, window);
    }
});

effects.windowDeleted.connect(window => {
    // An animation goes with its window, without a word.
    if (window == quietOn) {
        quietEnded();
    }
    hidden = hidden.filter(other => other != window);
});
