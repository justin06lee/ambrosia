import QtQuick
import ActivityMonitor

// One of the panel's graphs, the newest reading at its right edge and each
// older one a step to the left. "stack": two shares of `most`, the lower one
// (`down`) in its color from the floor and the other on it (the
// processor's system and user load). "area": one number filled under its
// line. "mirror": one number upward from the middle and one downward
// (what comes in and what goes out). A reading is a number, or
// { up, down }. (`most`, not `top`: an item's top is its anchor.)
Canvas {
    id: graph

    property var history: []
    property string kind: "area"
    // The reading that reaches the graph's top (each half's, mirrored).
    property real most: 100
    property color up: Look.blue
    property color down: Look.red
    // How many readings fit across.
    property int across: 60

    onHistoryChanged: requestPaint()
    onKindChanged: requestPaint()
    onMostChanged: requestPaint()
    onUpChanged: requestPaint()
    onDownChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = Math.min(history.length, across);
        const from = history.length - n;
        const w = width, h = height;
        const step = w / (across - 1);
        const x = (i) => w - (n - 1 - i) * step;
        const share = (v) => Math.max(0, Math.min(1, (v > 0 ? v : 0) / (most > 0 ? most : 1)));
        const soft = (color) => Qt.rgba(color.r, color.g, color.b, 0.42);
        // A filled shape between two lines of points, and a line along one.
        const fill = (upper, lower, color) => {
            if (n < 1)
                return;
            ctx.beginPath();
            ctx.moveTo(x(0), lower(0));
            for (let i = 0; i < n; ++i)
                ctx.lineTo(x(i), upper(i));
            for (let i = n - 1; i >= 0; --i)
                ctx.lineTo(x(i), lower(i));
            ctx.closePath();
            ctx.fillStyle = color;
            ctx.fill();
        };
        const line = (points, color) => {
            if (n < 1)
                return;
            ctx.beginPath();
            // A single reading still shows: a short stroke at the edge.
            ctx.moveTo(n === 1 ? x(0) - step : x(0), points(0));
            for (let i = 0; i < n; ++i)
                ctx.lineTo(x(i), points(i));
            ctx.lineWidth = 1;
            ctx.strokeStyle = color;
            ctx.stroke();
        };
        const at = (i) => history[from + i];

        if (kind === "stack") {
            const low = (i) => h - share(at(i).down) * h;
            const high = (i) => h - share(at(i).down + at(i).up) * h;
            fill(low, () => h, down);
            fill(high, low, up);
        } else if (kind === "mirror") {
            const middle = Math.round(h / 2) + 0.5;
            const reach = middle - 2;
            const above = (i) => middle - share(at(i).up) * reach;
            const below = (i) => middle + share(at(i).down) * reach;
            fill(above, () => middle, soft(up));
            fill(below, () => middle, soft(down));
            line(above, up);
            line(below, down);
            ctx.beginPath();
            ctx.moveTo(0, middle);
            ctx.lineTo(w, middle);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(Look.statText.r, Look.statText.g, Look.statText.b, 0.85);
            ctx.stroke();
        } else {
            const floor = h - 0.5;
            const level = (i) => Math.min(floor, h - share(typeof at(i) === "number" ? at(i) : at(i).up) * (h - 1));
            fill(level, () => floor, soft(up));
            line(level, up);
            if (n > 0) {
                ctx.beginPath();
                ctx.moveTo(n === 1 ? x(0) - step : x(0), floor);
                ctx.lineTo(w, floor);
                ctx.lineWidth = 1;
                ctx.strokeStyle = up;
                ctx.stroke();
            }
        }
    }
}
