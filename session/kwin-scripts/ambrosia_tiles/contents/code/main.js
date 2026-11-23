// A window tiled to half or a quarter of the screen (dragged to an edge, or
// by a key or the green button's menu) keeps a margin from the screen's
// edges and from the tile beside it, as a Mac's tiled windows do, and lands
// where the preview showed it (session/kwin-outline, which is drawn as far
// inside the place).
//
// KWin gives each of its halves and quarters a padding of nothing; a tile
// takes all of its padding at a screen's edge and half of it beside another
// tile. A layout the user drew themselves (KWin's tile editor) comes with a
// padding of its own, which is left alone.
const margin = readConfig("Margin", 8);

function pad(window) {
    const tile = window.tile;
    if (tile && tile.padding === 0) {
        tile.padding = margin;
    }
}

function watch(window) {
    window.tileChanged.connect(() => pad(window));
    pad(window);
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
