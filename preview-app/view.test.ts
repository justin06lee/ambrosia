import { expect, test } from "bun:test";
// @ts-ignore: a plain module, shared with the QML
import * as View from "./qml/view.mjs";

const chrome = { side: 0, toolbar: 52, margin: 26, beside: 96, minWidth: 480, minHeight: 300 };
const screen = { width: 1880, height: 950 };

test("fit takes the tighter of the two ways", () => {
    expect(View.fit(1000, 500, 500, 500)).toBe(0.5);
    expect(View.fit(500, 1000, 500, 500)).toBe(0.5);
    expect(View.fit(100, 100, 400, 300)).toBe(3);
    expect(View.fit(0, 100, 400, 300)).toBe(1);
});

test("two steps in double the size, and stepping stops at actual size", () => {
    expect(View.zoomed(View.zoomed(1, 1, 0.1, 16), 1, 0.1, 16)).toBeCloseTo(2);
    expect(View.zoomed(0.8, 1, 0.1, 16)).toBe(1);
    expect(View.zoomed(1.3, -1, 0.1, 16)).toBe(1);
    expect(View.zoomed(1, -1, 0.1, 16)).toBeCloseTo(Math.SQRT1_2);
});

test("zoom stays within its limits", () => {
    expect(View.zoomed(15, 1, 0.1, 16)).toBe(16);
    expect(View.zoomed(0.11, -1, 0.1, 16)).toBe(0.1);
});

test("pages lie one under another, a turned one on its side", () => {
    const sizes = [{ width: 612, height: 792 }, { width: 612, height: 792 }, { width: 612, height: 792 }];
    const plan = View.layout(sizes, {}, 1, 10);
    expect(plan.tops).toEqual([0, 802, 1604]);
    expect(plan.width).toBe(612);
    expect(plan.height).toBe(2396);
    const turned = View.layout(sizes, { 1: 1 }, 0.5, 10);
    expect(turned.tops).toEqual([0, 406, 722]);
    expect(turned.width).toBe(396);
    expect(View.layout([], {}, 1, 10).height).toBe(0);
});

test("the page at a height", () => {
    const tops = [0, 802, 1604];
    expect(View.pageAt(tops, 0)).toBe(0);
    expect(View.pageAt(tops, 801)).toBe(0);
    expect(View.pageAt(tops, 802)).toBe(1);
    expect(View.pageAt(tops, 5000)).toBe(2);
    expect(View.pageAt(tops, -40)).toBe(0);
    expect(View.pageAt([], 10)).toBe(0);
});

test("zooming holds the point under the pointer, inside the content", () => {
    // Half way along 1000, shown from 0 in a view of 400: the middle stays in the middle.
    expect(View.hold(0.5, 2000, 0, 200, 400, 2000)).toBe(800);
    expect(View.hold(0, 2000, 0, 200, 400, 2000)).toBe(0);
    expect(View.hold(1, 2000, 0, 200, 400, 2000)).toBe(1600);
});

test("a picture opens at its own size, as a Mac's Preview measured", () => {
    // 1200 by 750 opened in a window 1200 by 854 there.
    expect(View.pictureWindow({ width: 1200, height: 750 }, screen, chrome)).toEqual({ zoom: 1, width: 1200, height: 854 });
});

test("a picture too large for the screen opens fitted, a small one in the smallest window", () => {
    const large = View.pictureWindow({ width: 4000, height: 3000 }, screen, chrome);
    expect(large.zoom).toBeCloseTo(846 / 3000);
    expect(large.height).toBe(950);
    expect(View.pictureWindow({ width: 32, height: 32 }, screen, chrome)).toEqual({ zoom: 1, width: 480, height: 300 });
});

test("a PDF opens at actual size beside its sidebar, as a Mac's Preview measured", () => {
    // Three Letter pages opened 913 wide there, the sidebar 205 of it.
    const opened = View.pagesWindow({ width: 612, height: 792 }, 2396, screen, { ...chrome, side: 205 });
    expect(opened.zoom).toBe(1);
    expect(opened.width).toBe(913);
    expect(opened.height).toBe(950);
    expect(View.pagesWindow({ width: 612, height: 792 }, 792, screen, chrome).height).toBe(844);
});

test("pictures open together, PDFs each in a window of its own", () => {
    const isPdf = (file: string) => file.endsWith(".pdf");
    expect(View.groups(["a.png", "b.pdf", "c.jpg", "d.pdf"], isPdf)).toEqual([["a.png", "c.jpg"], ["b.pdf"], ["d.pdf"]]);
    expect(View.groups(["b.pdf"], isPdf)).toEqual([["b.pdf"]]);
    expect(View.groups([], isPdf)).toEqual([]);
});
