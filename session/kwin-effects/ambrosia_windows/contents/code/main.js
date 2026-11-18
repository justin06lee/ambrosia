"use strict";

// How a window opens and closes in Ambrosia, as a Mac's does: it swells into
// place from a little smaller while it fades in, and when it is closed it is
// simply gone, so nothing here answers a window closing. This stands in for
// KWin's own Scale, which shrinks a closing window away (the session's
// kwinrc switches that off and this on).

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
