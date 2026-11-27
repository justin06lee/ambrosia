// Preview's arithmetic: zoom steps, fitting a picture or a page to a view,
// where a PDF's pages lie one under another, and the window a document
// opens in. A module so that bun can test it (preview-app/view.test.ts);
// the QML imports it.

// One press of Zoom In: two of them double the size.
export const step = Math.SQRT2;

export function clamp(value, least, most) {
    return Math.min(most, Math.max(least, value));
}

// The zoom at which w by h just fits a view (1 when there is nothing to fit).
export function fit(w, h, viewW, viewH) {
    if (!(w > 0 && h > 0 && viewW > 0 && viewH > 0))
        return 1;
    return Math.min(viewW / w, viewH / h);
}

// One step in (direction > 0) or out, stopping at actual size on the way
// past it, within the limits.
export function zoomed(zoom, direction, least, most) {
    let next = direction > 0 ? zoom * step : zoom / step;
    const close = Math.abs(Math.log(next)) < 0.02;
    if (close || (zoom < 1 && next > 1) || (zoom > 1 && next < 1))
        next = 1;
    return clamp(next, least, most);
}

// The size a page shows at: its own, or lying on its side after a quarter
// turn or three.
export function turned(size, turns) {
    return turns % 2 !== 0 ? { width: size.height, height: size.width } : { width: size.width, height: size.height };
}

// Pages one under another, `gap` apart: each one's top, the widest, and the
// whole height. `sizes` are in points, `turns` quarter turns by page.
export function layout(sizes, turns, zoom, gap) {
    const tops = [];
    let y = 0, width = 0;
    for (let i = 0; i < sizes.length; ++i) {
        const size = turned(sizes[i], turns[i] ?? 0);
        tops.push(y);
        y += Math.round(size.height * zoom) + gap;
        width = Math.max(width, Math.round(size.width * zoom));
    }
    return { tops: tops, width: width, height: Math.max(0, y - gap) };
}

// The page at a height: the last whose top is at or above it.
export function pageAt(tops, y) {
    let low = 0, high = tops.length - 1;
    while (low < high) {
        const middle = (low + high + 1) >> 1;
        if (tops[middle] <= y)
            low = middle;
        else
            high = middle - 1;
    }
    return Math.max(0, low);
}

// Where a view must scroll to so that the point `fraction` of the way along
// what it shows (now `extent` long, starting at `origin`) stays under
// `point` of the view, without leaving the content.
export function hold(fraction, extent, origin, point, viewport, content) {
    return clamp(fraction * extent + origin - point, 0, Math.max(0, content - viewport));
}

// The window a picture opens in: at its own size when the screen has room
// (a picture point for each of the screen's), else as large as fits, with
// `margin` of the view's ground above and below it.
export function pictureWindow(size, screen, chrome) {
    const roomW = screen.width - chrome.side, roomH = screen.height - chrome.toolbar - 2 * chrome.margin;
    const zoom = Math.min(1, fit(size.width, size.height, roomW, roomH));
    return {
        zoom: zoom,
        width: Math.max(chrome.minWidth, Math.round(size.width * zoom) + chrome.side),
        height: Math.max(chrome.minHeight, Math.round(size.height * zoom) + chrome.toolbar + 2 * chrome.margin),
    };
}

// The window a PDF opens in: its first page at actual size with `beside`
// of ground around it, as tall as the pages need or the screen has.
export function pagesWindow(page, pagesHeight, screen, chrome) {
    const roomW = screen.width - chrome.side - chrome.beside;
    const zoom = page.width > 0 ? Math.min(1, roomW / page.width) : 1;
    return {
        zoom: zoom,
        width: Math.max(chrome.minWidth, Math.round(page.width * zoom) + chrome.side + chrome.beside),
        height: clamp(Math.round(pagesHeight * zoom) + chrome.toolbar, chrome.minHeight, screen.height),
    };
}

// The windows a launch's files open in: pictures together in one, each PDF
// in its own. `isPdf` says which a file is.
export function groups(files, isPdf) {
    const pictures = files.filter(file => !isPdf(file));
    const windows = files.filter(isPdf).map(file => [file]);
    if (pictures.length > 0)
        windows.unshift(pictures);
    return windows;
}
