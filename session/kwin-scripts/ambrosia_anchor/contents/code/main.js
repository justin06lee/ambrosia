// A window that changes its own size keeps its top left corner.
//
// KWin grows a window that resizes itself around its middle (a Wayland
// app cannot say where it wants to be). A Mac's grows down and to the
// right: a Settings window changing tabs keeps its title bar where it is.
// This puts the corner back as the size changes, in the same pass, so
// nothing is seen to jump.
//
// Only for windows nobody else can resize (their smallest and largest
// sizes are the same): any change of size is then the app's own, never a
// tile, a zoom or a drag at an edge. A window that would reach under the
// Dock or off the screen is moved up or left to fit, as on a Mac.

function anchor(window) {
    if (!window.normalWindow && !window.dialog && !window.utility) return;
    window.frameGeometryChanged.connect((old) => {
        const now = window.frameGeometry;
        if (old.width < 1 || old.height < 1) return; // just placed
        if (now.width === old.width && now.height === old.height) return;
        if (window.resizeable || window.move || window.resize || window.fullScreen) return;
        const area = workspace.clientArea(KWin.PlacementArea, window);
        let x = old.x;
        let y = old.y;
        if (x + now.width > area.x + area.width) x = Math.max(area.x, area.x + area.width - now.width);
        if (y + now.height > area.y + area.height) y = Math.max(area.y, area.y + area.height - now.height);
        if (x === now.x && y === now.y) return;
        window.frameGeometry = { x: x, y: y, width: now.width, height: now.height };
    });
}

workspace.windowList().forEach(anchor);
workspace.windowAdded.connect(anchor);
