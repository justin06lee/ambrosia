// Live examples for each spec section, built from the same tokens and
// resolver the theme generator uses, so what you review is what ships.

import * as t from "../design/tokens";
import type { Mode } from "../design/tokens";
import { contrast, toCss, toHex, type RGBA } from "../tools/gen/color";
import { flat, resolve } from "../tools/gen/resolve";
import type { SolvedSpring } from "../tools/gen/spring";
import previewHtml from "../preview/index.html" with { type: "text" };
import { h, icon, s, type Child } from "./dom";

const r = resolve();
const ratio = (n: number) => `${n.toFixed(1)}:1`;
const em = (n: number) => `${n >= 0 ? "+" : "−"}${Math.abs(n).toFixed(3)}em`;
const pt = (px: number) => +(px * 0.75).toFixed(2);

const caption = (text: string) => h("p", { class: "specimen-caption" }, text);
const specimen = (title: string, ...children: Child[]) =>
  h("figure", { class: "specimen" }, h("figcaption", null, title), ...children);

/** Copies the preview's icon sprite into the page, so both use one icon set. */
export function loadIcons() {
  const doc = new DOMParser().parseFromString(previewHtml as unknown as string, "text/html");
  const sprite = document.getElementById("sprite")!;
  for (const symbol of doc.querySelectorAll("svg.sprite symbol")) sprite.append(document.importNode(symbol, true));
  return [...doc.querySelectorAll("svg.sprite symbol[id^='i-']")].map((el) => el.id);
}

// A small line plot ------------------------------------------------------------

interface Plot {
  width: number;
  height: number;
  x: [number, number];
  y: [number, number];
  lines: { points: [number, number][]; className: string }[];
  guides?: number[];
  dots?: { x: number; y: number; label: string }[];
}

function plot({ width, height, x, y, lines, guides = [], dots = [] }: Plot) {
  const pad = 8;
  const px = (v: number) => pad + ((v - x[0]) / (x[1] - x[0])) * (width - pad * 2);
  const py = (v: number) => height - pad - ((v - y[0]) / (y[1] - y[0])) * (height - pad * 2);
  return s(
    "svg",
    { class: "plot", viewBox: `0 0 ${width} ${height}`, width, height },
    ...guides.map((g) => s("line", { class: "plot-guide", x1: pad, x2: width - pad, y1: py(g), y2: py(g) })),
    ...lines.map((l) =>
      s("polyline", { class: l.className, points: l.points.map(([a, b]) => `${px(a).toFixed(1)},${py(b).toFixed(1)}`).join(" ") }),
    ),
    ...dots.flatMap((d) => [
      s("circle", { class: "plot-dot", cx: px(d.x), cy: py(d.y), r: 3 }),
      s("text", { class: "plot-label", x: px(d.x), y: py(d.y) - 8, "text-anchor": "middle" }, d.label),
    ]),
  );
}

// Typography -------------------------------------------------------------------

const samples: Record<string, string> = {
  largeTitle: "Welcome to ambrosia",
  title1: "Appearance",
  title2: "Displays",
  title3: "Wallpaper",
  headline: "Documents",
  body: "Glass, springs and one design language across every toolkit.",
  callout: "Edited yesterday at 4:59 PM",
  caption: "Favorites",
  footnote: "Beta",
};

function typography() {
  const scale = Object.entries(t.type).map(([name, st]) =>
    h(
      "div",
      { class: "type-row" },
      h("div", { class: "type-meta" }, h("b", null, name), h("span", null, `${st.size}/${st.line} · ${st.weight}`), h("span", null, `${em(t.tracking(st.size))} · ${pt(st.size)}pt`)),
      h("div", { class: "type-sample", style: { font: `${st.weight} ${st.size}px/${st.line}px var(--amb-font-ui)`, letterSpacing: `${t.tracking(st.size)}em` } }, samples[name] ?? name),
    ),
  );

  const sizes = Array.from({ length: 33 }, (_, i) => 8 + i);
  const curve = plot({
    width: 520, height: 150, x: [8, 40], y: [-0.03, 0.035],
    guides: [0],
    lines: [{ points: sizes.map((sz) => [sz, t.tracking(sz)]), className: "plot-line" }],
    dots: Object.values(t.type)
      .filter((st, i, all) => all.findIndex((o) => o.size === st.size) === i)
      .map((st) => ({ x: st.size, y: t.tracking(st.size), label: `${st.size}` })),
  });

  return [
    specimen("Type scale", h("div", { class: "type-scale" }, scale), caption("Tracking follows Inter's curve: slightly open when small, tighter as text grows. GTK and KDE get the size in points.")),
    specimen(
      "Faces",
      h(
        "div",
        { class: "faces" },
        h("div", { class: "face" }, h("span", { class: "face-glyph" }, "Aa"), h("b", null, t.font.ui[0]), h("span", null, "Regular · Semibold · Bold"), h("p", null, "Sphinx of black quartz, judge my vow. 0123456789")),
        h("div", { class: "face mono" }, h("span", { class: "face-glyph" }, "{ }"), h("b", null, t.font.mono[0]), h("span", null, "Code and terminals"), h("pre", null, "const accent = tokens.accent;\nfor (const n of [0, 1, 2]) ok();")),
      ),
    ),
    specimen("Tracking by size", curve, caption("The dots are the sizes the scale uses.")),
  ];
}

// Space and shape -------------------------------------------------------------

function space() {
  return [
    specimen(
      "The 4px grid",
      h("div", { class: "space-rows" }, Object.entries(t.space).filter(([, v]) => v > 0).map(([k, v]) =>
        h("div", { class: "space-row" }, h("code", null, `space["${k}"]`), h("span", { class: "space-bar", style: { width: `${v}px` } }), h("span", null, `${v}px`)),
      )),
    ),
  ];
}

function superellipse(size: number, n = 5) {
  const pts: string[] = [];
  for (let i = 0; i < 360; i += 2) {
    const a = (i * Math.PI) / 180;
    const c = Math.cos(a);
    const sn = Math.sin(a);
    pts.push(`${(size / 2 + (size / 2) * Math.sign(c) * Math.abs(c) ** (2 / n)).toFixed(2)} ${(size / 2 + (size / 2) * Math.sign(sn) * Math.abs(sn) ** (2 / n)).toFixed(2)}`);
  }
  return `M${pts.join("L")}Z`;
}

function shape() {
  const sizes: Record<string, [number, number]> = {
    window: [150, 100], sheet: [130, 90], panel: [130, 96], card: [100, 72], popover: [100, 80],
    row: [100, 28], control: [84, 28], controlSmall: [64, 22], tooltip: [80, 26], dock: [180, 68],
  };
  const tiles = Object.entries(sizes).map(([name, [w, hgt]]) =>
    h("div", { class: "radius-tile" },
      h("div", { class: "radius-shape", style: { width: `${w}px`, height: `${hgt}px`, borderRadius: `${t.radius[name as keyof typeof t.radius]}px` } }),
      h("b", null, name), h("span", null, `${t.radius[name as keyof typeof t.radius]}px`)),
  );

  const nest = (inner: number, good: boolean) =>
    h("div", { class: `nest ${good ? "good" : "bad"}` },
      h("div", { class: "nest-outer", style: { borderRadius: `${t.radius.panel}px` } },
        h("div", { class: "nest-inner", style: { borderRadius: `${inner}px` } })),
      h("b", null, good ? `Concentric: ${t.radius.panel} − 10 = ${inner}` : `Same radius inside: ${inner}`),
      h("span", null, good ? "The gap stays even all the way round." : "The gap pinches at every corner."));

  const size = 150;
  const iconShape = s("svg", { class: "icon-compare", viewBox: `-4 -4 ${size + 8} ${size + 8}`, width: size + 8, height: size + 8 },
    s("path", { d: superellipse(size), class: "icon-squircle" }),
    s("rect", { x: 0, y: 0, width: size, height: size, rx: size * t.iconCorner, class: "icon-rounded" }));

  return [
    specimen("Radii", h("div", { class: "radius-grid" }, tiles)),
    specimen("Nesting", h("div", { class: "nest-pair" }, nest(t.radius.card, true), nest(t.radius.panel, false))),
    specimen("App icon shape", h("div", { class: "icon-shape" }, iconShape,
      h("p", null, "Filled: the superellipse ambrosia icons use. Outline: a plain rounded rectangle at 22.5%. The superellipse starts curving earlier, so there's no visible point where the straight edge meets the corner."))),
  ];
}

// Color -----------------------------------------------------------------------

function swatch(color: RGBA, name: string, mode: Mode) {
  const on = r.modes[mode].bg.content;
  return h("div", { class: "swatch-cell" },
    h("span", { class: "swatch-chip", style: { background: toCss(color) } }),
    h("b", null, name),
    h("span", { style: { color: toCss(flat(r.modes[mode].label.secondary, on)) } }, color.a < 1 ? `${toHex(color)} · ${Math.round(color.a * 100)}%` : toHex(color)));
}

function modePanel(mode: Mode) {
  const m = r.modes[mode];
  const on = m.bg.content;
  const ink = (c: RGBA) => toCss(flat(c, on));
  return h("div", { class: "mode-panel", style: { background: toCss(on), color: ink(m.label.primary) } },
    h("h4", null, mode === "light" ? "Light" : "Dark"),
    h("div", { class: "swatch-row" }, Object.entries(m.bg).map(([k, c]) => swatch(c, k, mode))),
    h("div", { class: "label-stack" }, Object.entries(m.label).map(([k, c]) =>
      h("div", { class: "label-line" }, h("span", { style: { color: toCss(c) } }, `${k[0]!.toUpperCase()}${k.slice(1)} label`),
        h("span", { class: "ratio", style: { color: ink(m.label.secondary) } }, ratio(contrast(flat(c, on), on)))))),
    h("div", { class: "fill-row" }, Object.entries(m.fill).map(([k, c]) =>
      h("span", { class: "fill-chip", style: { background: toCss(c) } }, k))),
  );
}

function accents() {
  const cell = (name: string, mode: Mode) => {
    const m = r.modes[mode];
    const a = m.accents[name]!;
    const on = m.bg.content;
    const textRatio = contrast(a.text, on);
    const fgRatio = contrast(a.fg, a.bg);
    const ok = textRatio >= t.accent.textContrast && fgRatio >= t.accent.fgContrast;
    return h("div", { class: "accent-cell", style: { background: toCss(on), color: toCss(flat(m.label.secondary, on)) } },
      h("span", { class: "accent-button", style: { background: toCss(a.bg), color: toCss(a.fg) } }, "Save"),
      h("span", { class: "accent-link", style: { color: toCss(a.text) } }, "Learn more"),
      h("span", { class: `ratio ${ok ? "pass" : "fail"}`, title: "Button text on fill · link text on content" }, `${ratio(fgRatio)} · ${ratio(textRatio)}`));
  };
  return h("div", { class: "accent-table" },
    h("div", { class: "accent-head" }, h("span", null, ""), h("span", null, "Light"), h("span", null, "Dark")),
    Object.keys(t.accent.options).map((name) =>
      h("div", { class: "accent-row" }, h("b", null, name, name === t.accent.default ? h("small", null, " default") : null), cell(name, "light"), cell(name, "dark"))));
}

function color() {
  return [
    specimen("Backgrounds, labels and fills", h("div", { class: "mode-pair" }, modePanel("light"), modePanel("dark")),
      caption("Labels and fills are translucent ink; the ratios are measured after flattening onto the content background.")),
    specimen("Accents", accents(), caption(`Each cell: a primary button and a link. The ratios are button text on its fill (needs ${t.accent.fgContrast}:1) and link text on content (needs ${t.accent.textContrast}:1).`)),
    specimen("System palette", h("div", { class: "palette" }, Object.keys(t.palette).map((name) =>
      h("div", { class: "palette-cell" },
        h("span", { class: "palette-chip", style: { "--light": toCss(r.modes.light.palette[name]!), "--dark": toCss(r.modes.dark.palette[name]!) } }),
        h("span", null, name)))), caption("Each chip shows the light value on the left and the dark value on the right.")),
  ];
}

// Materials and elevation ------------------------------------------------------

function materials() {
  const layers = ["blur", "tint", "rim", "edge", "specular", "noise"];
  const stage = h("div", { class: "glass-stage" },
    h("div", { class: "drifter one" }), h("div", { class: "drifter two" }),
    ...Object.entries(t.material).map(([name, m]) =>
      h("div", { class: `glass ${name} glass-pane` },
        h("b", null, name),
        h("span", null, `blur ${m.blur} · saturate ${m.saturate}`),
        h("span", null, `tint ${Math.round(r.modes.light.material[name as keyof typeof t.material].tint.a * 100)}% / ${Math.round(r.modes.dark.material[name as keyof typeof t.material].tint.a * 100)}%`),
        h("p", null, "Wi-Fi is connected to Olympus."))));

  const toggle = (label: string, cls: string, on = true) =>
    h("label", { class: "switch-row" },
      h("input", { type: "checkbox", checked: on, onchange: (e: Event) => stage.classList.toggle(cls, (e.target as HTMLInputElement).checked !== on) }),
      h("span", { class: "switch" }), label);

  const { refraction } = t.glass;
  return [
    specimen("The four materials",
      h("div", { class: "switches" }, layers.map((l) => toggle(l[0]!.toUpperCase() + l.slice(1), `no-${l}`)), toggle("Reduce transparency", "opaque", false)),
      stage,
      caption("Turn layers off to see what each one contributes. Reduce transparency shows the opaque fallback every material has.")),
    specimen("Refraction (compositor only)", h("dl", { class: "facts" },
      h("dt", null, "Edge band"), h("dd", null, `${refraction.edge}px`),
      h("dt", null, "Strength"), h("dd", null, `${refraction.strength}`),
      h("dt", null, "Dispersion"), h("dd", null, `${refraction.dispersion}`),
      h("dt", null, "Light angle"), h("dd", null, `${refraction.specularAngle}°, intensity ${refraction.specular}`)),
      caption("Browsers can't refract what's behind an element, so this is the shader's parameter set rather than a demo.")),
  ];
}

function elevation() {
  const describe = (name: string) => r.modes.light.shadows[name]!.layers.map(([, y, blur, , a]) => `y ${y} · blur ${blur} · ${Math.round(a * 100)}%`).join("  +  ");
  return [
    specimen("Shadows", h("div", { class: "shadow-grid" }, Object.keys(t.shadow).map((name) =>
      h("div", { class: "shadow-card", style: { boxShadow: `0 0 0 0.5px var(--amb-glass-edge), var(--amb-shadow-${name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)})` } },
        h("b", null, name), h("span", null, describe(name))))),
      caption("Values shown are the light mode's; dark mode shadows are much stronger so they read against dark wallpapers.")),
  ];
}

// Motion and input ------------------------------------------------------------

function springCard(name: string, enter: SolvedSpring, exit: SolvedSpring) {
  const spec = t.spring[name as keyof typeof t.spring];
  const longest = Math.max(enter.duration, exit.duration);
  const points = (sp: SolvedSpring) => sp.samples.map((v, i): [number, number] => [(i / (sp.samples.length - 1)) * sp.duration, v]);
  const track = h("div", { class: "track", style: { "--enter": `var(--amb-spring-${name})`, "--exit": `var(--amb-spring-${name}-exit)` } }, h("span", { class: "puck" }));
  const go = () => track.classList.toggle("end");
  track.addEventListener("click", go);
  return h("div", { class: "spring-card" },
    h("div", { class: "spring-head" }, h("b", null, name), h("span", null, `response ${spec.response}s · damping ${spec.damping}`)),
    plot({ width: 300, height: 110, x: [0, longest], y: [0, 1.15], guides: [1],
      lines: [{ points: points(exit), className: "plot-line faint" }, { points: points(enter), className: "plot-line" }] }),
    h("span", { class: "spring-meta" }, `in ${enter.duration}ms · out ${exit.duration}ms · k ${enter.stiffness} · c ${enter.damping}`),
    track,
    h("button", { class: "tool-button", onclick: go }, "Play"));
}

function motion() {
  const cards = Object.keys(t.spring).map((name) =>
    springCard(name, r.springs[name as keyof typeof t.spring], r.exits[name as keyof typeof t.spring]));

  const compare = h("div", { class: "compare" },
    ...[
      ["Linear, 300ms", "300ms linear"],
      ["Ease, 300ms", "300ms ease"],
      ["Snappy spring", "var(--amb-spring-snappy)"],
    ].map(([label, timing]) =>
      h("div", { class: "compare-row" }, h("span", null, label), h("div", { class: "track", style: { "--enter": timing!, "--exit": timing! } }, h("span", { class: "puck" })))));
  const playAll = () => compare.querySelectorAll(".track").forEach((tr) => tr.classList.toggle("end"));

  return [
    specimen("Springs", h("div", { class: "spring-grid" }, cards),
      caption("Solid line: entering. Faint line: leaving, at 0.7 × the response. Click a track while the puck is moving to retarget it mid-flight.")),
    specimen("Why springs", compare, h("button", { class: "tool-button", onclick: playAll }, "Play all"),
      caption("Press Play all twice in quick succession: the spring turns around smoothly, while the eased versions snap into a new curve.")),
  ];
}

function input() {
  const sheet = h("div", { class: "rubber-sheet" }, Array.from({ length: 5 }, (_, i) =>
    h("div", { class: "rubber-row" }, icon(["i-doc", "i-folder", "i-photos", "i-music", "i-notes"][i]!), ["DESIGN.md", "Projects", "nectar-day.png", "Honey Light.flac", "Notes"][i])));
  const box = h("div", { class: "rubber" }, sheet);
  let start = 0;
  box.addEventListener("pointerdown", (e) => {
    start = e.clientY;
    box.setPointerCapture(e.pointerId);
    sheet.style.transition = "none";
  });
  box.addEventListener("pointermove", (e) => {
    if (!box.hasPointerCapture(e.pointerId)) return;
    const d = box.clientHeight;
    const x = Math.abs(e.clientY - start);
    const offset = Math.sign(e.clientY - start) * (1 - 1 / ((x * t.input.rubberBand) / d + 1)) * d;
    sheet.style.transform = `translateY(${offset}px)`;
  });
  box.addEventListener("pointerup", () => {
    sheet.style.transition = "transform var(--amb-spring-gesture)";
    sheet.style.transform = "";
  });
  return [
    specimen("Rubber-band edges", box,
      caption(`Drag the list up or down past its edge. It resists more the further you pull (coefficient ${t.input.rubberBand}), then settles back on the gesture spring.`)),
  ];
}

// Shell, icons, voice ---------------------------------------------------------

function shellAnatomy() {
  // Rendered at a real screen size, then scaled to fit the column.
  const frame = h("iframe", { class: "preview-frame", title: "ambrosia desktop preview", loading: "lazy", width: 1280, height: 800 });
  const screen = h("div", { class: "preview-screen" }, frame);
  new ResizeObserver(() => screen.style.setProperty("--scale", `${screen.clientWidth / 1280}`)).observe(screen);
  let open = "";
  const sync = () => {
    const root = document.documentElement;
    const params = new URLSearchParams({ theme: root.dataset.theme ?? "light", accent: root.dataset.accent ?? t.accent.default });
    if (open) params.set("open", open);
    frame.src = `preview/index.html?${params}`;
  };
  addEventListener("ambrosia:appearance", sync);
  sync();
  const show = (state: string) => () => { open = state; sync(); };
  const facts = Object.entries(t.size).map(([group, v]) =>
    h("div", null, h("dt", null, group), h("dd", null, typeof v === "number" ? `${v}` : Object.entries(v).map(([k, n]) => `${k} ${n}`).join(" · "))));
  return [
    specimen("The desktop",
      h("div", { class: "tool-row" }, h("button", { class: "tool-button", onclick: show("") }, "Desktop"),
        h("button", { class: "tool-button", onclick: show("cc") }, "Control center"),
        h("button", { class: "tool-button", onclick: show("view-menu") }, "Menu")),
      screen, caption("This is the same preview as preview/index.html, shown at 1280 × 800 and scaled down. It follows the theme and accent chosen in the toolbar above.")),
    specimen("Measurements", h("dl", { class: "facts wide" }, facts)),
  ];
}

let iconIds: string[] = [];
export const setIconIds = (ids: string[]) => (iconIds = ids);

function iconography() {
  const cells = (size: number) => iconIds.map((id) => h("div", { class: "icon-cell", title: id }, icon(id, size), h("span", null, id.slice(2))));
  return [
    specimen("Symbols at 16px", h("div", { class: "icon-grid" }, cells(16))),
    specimen("At 24px", h("div", { class: "icon-grid big" }, cells(24)), caption("1.5px rounded strokes on a 24 grid. Filled only to show state.")),
  ];
}

function voice() {
  const pairs = [
    ["Show hidden files", "Show Hidden Files"],
    ["Delete", "OK"],
    ["Couldn't join Olympus. Check the password and try again.", "Error: connection failed (code 4)"],
    ["Start at login", "Do you want this app to start at login?"],
  ];
  return [
    specimen("Do and don't", h("div", { class: "voice" }, pairs.map(([good, bad]) =>
      h("div", { class: "voice-pair" }, h("span", { class: "do" }, icon("i-check", 14), good), h("span", { class: "dont" }, bad))))),
  ];
}

export const specimens: Record<string, () => Node[]> = {
  typography,
  space,
  shape,
  color,
  materials,
  elevation,
  motion,
  input,
  "shell-anatomy": shellAnatomy,
  iconography,
  voice,
};
