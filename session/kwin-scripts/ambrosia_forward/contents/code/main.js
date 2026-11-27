// A window its own app asks to bring forward comes forward, while that
// app is the one in front.
//
// An app may only bring a window of its forward with the keyboard's
// leave: a key just pressed in it. Chosen from Ambrosia's menu bar, an
// action reaches the app with no key at all (the bar had the keyboard),
// so KWin refuses, and marks the window as wanting attention instead.
// On a Mac, Settings… chosen while the Settings window is behind a
// document brings it forward. This lets the refusal through when the
// asking window belongs to the app whose window is active: an app in the
// background still can't take the screen.

function watch(window) {
    window.demandsAttentionChanged.connect(() => {
        if (!window.demandsAttention) return;
        const front = workspace.activeWindow;
        if (!front || front === window || front.pid !== window.pid) return;
        workspace.activeWindow = window;
    });
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
