// KWin's own Show Desktop (Super+D with the Linux-first keyboard, an app or
// a panel asking for it) hides everything that isn't a desktop or a dock to
// KWin, and the shell's wallpaper and menu bar are neither: the screen goes
// black but for the Dock. Show Desktop here is the windows effect's
// (session/kwin-effects/ambrosia_windows): the windows slide off and the
// shell stays. So the moment KWin's switches on it is switched off again,
// and ours is asked for in its place.
//
// A script isn't told that Show Desktop changed, only each window that it
// was hidden by it or shown again. KWin's is never left on, so the first
// window to say so means it has just been switched on. KWin says it from
// the middle of its pass over the windows: nothing is done until that pass
// is over.
let ours = false;
const after = new QTimer();
after.singleShot = true;
after.interval = 0;
after.timeout.connect(() => {
    ours = true;
    workspace.slotToggleShowDesktop();
    ours = false;
    callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component",
        "invokeShortcut", "Ambrosia Show Desktop");
});

function watch(window) {
    window.hiddenByShowDesktopChanged.connect(() => {
        if (!ours && !after.active) {
            after.start();
        }
    });
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
