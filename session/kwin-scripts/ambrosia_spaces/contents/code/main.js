// A window made full screen gets a Space of its own.
//
// On a Mac the green light (or a film going full screen) doesn't cover
// the desktop: the window leaves it for a Space made for it, to the right
// of the desktops, which ⌃← and ⌃→ and Mission Control's strip reach like
// any other, and which is gone again when the window leaves full screen
// or closes. KWin's full screen is a window over the others on the same
// desktop. This makes the Space: a desktop named for the app, at the end
// of the row, with the window moved onto it and shown; and unmakes it,
// the window back on the desktop it came from.
//
// A window of another app that opens while a full-screen Space is shown
// would land on it, under or over the full-screen one: it is sent to the
// desktop the full-screen window came from instead, and that desktop
// shown, as a Mac does. The app's own windows (a dialog, a panel) stay
// with it.
//
// KWin keeps its desktops in kwinrc, so a Space still there when the
// session ends would be an empty desktop named "Preview" at the next
// login: ours carry a mark in their names (a zero-width space at the
// end, which nothing draws) and any found with no full-screen window as
// the script starts are removed.

const mark = "​";
// The window's id → { space, from, everywhere }.
const spaces = new Map();

function appName(window) {
    // "Notes.txt — TextEdit": the part an app puts last is its name.
    const caption = String(window.caption || "");
    const cut = Math.max(caption.lastIndexOf(" — "), caption.lastIndexOf(" – "), caption.lastIndexOf(" - "));
    const name = cut >= 0 ? caption.slice(cut + 3) : caption;
    return (name || String(window.resourceClass || "Full Screen")).trim();
}

function spaceOf(desktop) {
    for (const [id, space] of spaces) {
        if (space.space === desktop) return space;
    }
    return null;
}

function enter(window) {
    const id = String(window.internalId);
    if (spaces.has(id) || !window.normalWindow) return;
    const everywhere = window.onAllDesktops;
    const from = !everywhere && window.desktops.length > 0 ? window.desktops[0] : workspace.currentDesktop;
    // Full screen on a Space already: nothing to make.
    if (spaceOf(from)) return;
    // On one of ours that this run of the script didn't make (the script
    // started again with the window up): it is the window's own still.
    if (String(from.name).endsWith(mark)) {
        spaces.set(id, { space: from, from: workspace.desktops[0], everywhere: false, window: window });
        return;
    }
    const at = workspace.desktops.length;
    workspace.createDesktop(at, appName(window) + mark);
    const space = workspace.desktops[at];
    if (!space) return;
    spaces.set(id, { space: space, from: from, everywhere: everywhere, window: window });
    window.desktops = [space];
    workspace.currentDesktop = space;
}

function leave(window) {
    const id = String(window.internalId);
    const space = spaces.get(id);
    if (!space) return;
    spaces.delete(id);
    const all = workspace.desktops;
    const back = all.indexOf(space.from) >= 0 ? space.from : all[0];
    if (all.indexOf(space.space) < 0) return; // taken away in Mission Control
    // Whatever else is on it (the app's dialogs) goes back too.
    for (const other of workspace.windowList()) {
        if (other.deleted || other.onAllDesktops) continue;
        if (other.desktops.indexOf(space.space) >= 0)
            other.desktops = other === window && space.everywhere ? [] : [back];
    }
    if (workspace.currentDesktop === space.space)
        workspace.currentDesktop = back;
    workspace.removeDesktop(space.space);
}

// Once KWin is done with what it was doing: a window moved to another
// desktop from inside its own change to full screen was left a menu
// bar's height down.
function later(what) {
    const timer = new QTimer();
    timer.singleShot = true;
    timer.timeout.connect(() => {
        what();
        timer.destroy();
    });
    timer.start(0);
}

function fits(window) {
    const area = workspace.clientArea(KWin.FullScreenArea, window);
    const now = window.frameGeometry;
    return now.x === area.x && now.y === area.y && now.width === area.width && now.height === area.height;
}

function sameApp(one, other) {
    return one.pid === other.pid || (one.resourceClass !== "" && String(one.resourceClass) === String(other.resourceClass));
}

function watch(window) {
    if (!window.normalWindow) return;
    window.fullScreenChanged.connect(() => later(() => {
        if (window.deleted) return;
        if (window.fullScreen) enter(window);
        else leave(window);
    }));
    // A full-screen window stays the screen's size and place. Showing its
    // Space leaves it a menu bar's height down: for a moment nothing is in
    // front, the bar is back with its strip of the screen kept clear, and
    // KWin moves a window at the screen's top out from under it.
    window.frameGeometryChanged.connect(() => {
        if (!window.fullScreen || window.deleted || fits(window)) return;
        later(() => {
            if (window.fullScreen && !window.deleted && !fits(window))
                window.frameGeometry = workspace.clientArea(KWin.FullScreenArea, window);
        });
    });
    if (window.fullScreen) {
        enter(window);
        return;
    }
    // Opened while a full-screen Space is shown, and not that app's: to
    // the desktop the Space was made from.
    const shown = spaceOf(workspace.currentDesktop);
    if (shown && !window.onAllDesktops && !sameApp(window, shown.window) && window.desktops.indexOf(shown.space) >= 0) {
        const all = workspace.desktops;
        const back = all.indexOf(shown.from) >= 0 ? shown.from : all[0];
        window.desktops = [back];
        workspace.currentDesktop = back;
        workspace.activeWindow = window;
    }
}

workspace.windowList().forEach(watch);
// Left over from a session that ended with one up: a Space of ours that
// no full-screen window has.
for (const desktop of workspace.desktops.slice()) {
    if (String(desktop.name).endsWith(mark) && !spaceOf(desktop) && workspace.desktops.length > 1)
        workspace.removeDesktop(desktop);
}
workspace.windowAdded.connect(watch);
workspace.windowRemoved.connect(leave);
