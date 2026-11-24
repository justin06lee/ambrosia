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
    if (window.ambrosiaLeaving) {
        left(window);
        return;
    }
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

// It rides on a window that stays drawn for that long: none of `leaving`.
function quietStart(time, leaving) {
    const on = effects.stackingOrder.find(window =>
        window.visible && !window.deleted && !(leaving || []).includes(window));
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

// `into` is the list that remembers them: Hide's, or Show Desktop's.
function putAway(windows, into) {
    busy = true;
    quietly(() => {
        for (const window of windows) {
            if (window.minimized) {
                continue;
            }
            window.minimized = true;
            if (window.minimized) {
                (into || hidden).push(window);
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
    // Show Desktop is over once anything comes forward.
    if (aside.length > 0) {
        showWindows(window);
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
    aside = aside.filter(other => other != window);
    if (window.ambrosiaLeaving) {
        left(window);
    }
});

// Show Desktop, as a Mac's thumb and three fingers spread (and its F11):
// every window on this desktop slides off past the edge nearest it, and
// the same way back when asked again or when any window is brought
// forward. Once off the screen they are put away as Hide puts them (to
// KWin, minimized), so the desktop under them can be used; KWin's own Show
// Desktop would put the shell's wallpaper and menu bar aside too.
const slideTime = animationTime(350);
// The windows put aside, and those still on their way out.
let aside = [];
let leaving = [];

// How far `window` has to go to be off its screen, past the nearest edge.
function wayOut(window) {
    const frame = window.geometry;
    const screen = window.screen ? window.screen.geometry : effects.virtualScreenGeometry;
    const room = 48;
    const x = frame.x + frame.width / 2 - (screen.x + screen.width / 2);
    const y = frame.y + frame.height / 2 - (screen.y + screen.height / 2);
    if (Math.abs(x) / screen.width >= Math.abs(y) / screen.height) {
        return x >= 0 ? { x: screen.x + screen.width - frame.x + room, y: 0 }
            : { x: -(frame.x + frame.width - screen.x) - room, y: 0 };
    }
    return y >= 0 ? { x: 0, y: screen.y + screen.height - frame.y + room }
        : { x: 0, y: -(frame.y + frame.height - screen.y) - room };
}

function showDesktop() {
    if (leaving.length > 0 || aside.length > 0 || effects.hasActiveFullScreenEffect) {
        return;
    }
    const windows = effects.stackingOrder.filter(window =>
        hides(window) && window.visible && !window.minimized && window.onCurrentDesktop);
    if (windows.length == 0) {
        return;
    }
    // The screen is this effect's until a little after the slide, so that
    // putting the windows away at its end plays no Genie.
    quietStart(slideTime + 250, windows);
    for (const window of windows) {
        stop(window);
        const way = wayOut(window);
        window.ambrosiaWay = way;
        // Held where it ends, off the screen, until the window is brought
        // back; the second animation is only there to say when the slide
        // is over (a held one never ends).
        window.ambrosiaHeld = set({
            window: window,
            // A window closed meanwhile just goes: kept alive by this, it
            // would never be let go of.
            keepAlive: false,
            curve: QEasingCurve.InOutCubic,
            duration: slideTime,
            animations: [{ type: Effect.Translation, to: { value1: way.x, value2: way.y } }],
        });
        window.ambrosiaLeaving = animate({
            window: window,
            keepAlive: false,
            duration: slideTime,
            animations: [{ type: Effect.Opacity, from: 1, to: 1 }],
        });
        leaving.push(window);
    }
}

// `window` is off the screen; the last one out puts them all away. KWin
// says an animation ended from the middle of its own pass over them, so
// nothing here may start or cancel one (it crashed KWin when it did): the
// windows are only minimized, and what holds them is cancelled when they
// are brought back.
function left(window) {
    delete window.ambrosiaLeaving;
    if (leaving.some(other => other.ambrosiaLeaving && !other.deleted)) {
        return;
    }
    const gone = leaving.filter(other => !other.deleted);
    leaving = [];
    busy = true;
    for (const other of gone) {
        other.minimized = true;
        if (other.minimized) {
            aside.push(other);
        }
    }
    busy = false;
}

// Back the way they went, `front` (if any) on top.
function showWindows(front) {
    if (leaving.length > 0) {
        return;
    }
    const back = aside.filter(window => !window.deleted);
    aside = [];
    if (back.length == 0) {
        return;
    }
    busy = true;
    for (const window of back) {
        if (window.ambrosiaHeld) {
            cancel(window.ambrosiaHeld);
            delete window.ambrosiaHeld;
        }
    }
    quietly(() => {
        for (const window of back) {
            window.minimized = false;
        }
    });
    for (const window of back) {
        const way = window.ambrosiaWay;
        delete window.ambrosiaWay;
        if (way) {
            animate({
                window: window,
                curve: QEasingCurve.InOutCubic,
                duration: slideTime,
                animations: [{ type: Effect.Translation, from: { value1: way.x, value2: way.y }, to: { value1: 0, value2: 0 } }],
            });
        }
        effects.activeWindow = window;
    }
    if (front) {
        effects.activeWindow = front;
    }
    busy = false;
}

// The toggle has a key; the other two are what the trackpad's spread and
// pinch run (the Mission Control effect hears the fingers and presses
// these by name).
registerShortcut("Ambrosia Show Desktop", "Show the Desktop, or the Windows Again", "Meta+Ctrl+Alt+D", () => {
    if (aside.length > 0) {
        showWindows(null);
    } else {
        showDesktop();
    }
});
registerShortcut("Ambrosia Windows Aside", "Show the Desktop", "", showDesktop);
registerShortcut("Ambrosia Windows Back", "Bring the Windows Back from Show Desktop", "", () => showWindows(null));
