// Behaviour for the design preview: theme and accent switching, popups,
// focusable and draggable windows, sliders, and the live clock.
// Keys: D toggles dark mode, A cycles the accent.

const root = document.documentElement;
const ACCENTS = ["blue", "purple", "pink", "red", "orange", "honey", "green", "graphite"];
const params = new URLSearchParams(location.search);

// Superellipse (n = 5) app-icon mask, in objectBoundingBox units.
{
  const n = 5;
  const points = [];
  for (let i = 0; i < 360; i += 2) {
    const t = (i * Math.PI) / 180;
    const c = Math.cos(t), s = Math.sin(t);
    const x = 0.5 + 0.5 * Math.sign(c) * Math.abs(c) ** (2 / n);
    const y = 0.5 + 0.5 * Math.sign(s) * Math.abs(s) ** (2 / n);
    points.push(`${x.toFixed(4)} ${y.toFixed(4)}`);
  }
  const d = `M${points.join("L")}Z`;
  document.getElementById("squircle-path").setAttribute("d", d);
  // The same outline as a thin ring, used as a mask for the icons' glassy rim.
  const ring = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><path d="${d}" fill="none" stroke="white" stroke-width="0.05"/></svg>`;
  root.style.setProperty("--squircle-ring", `url("data:image/svg+xml,${encodeURIComponent(ring)}")`);
}

// Theme and accent ----------------------------------------------------------

const dark = matchMedia("(prefers-color-scheme: dark)");
const setTheme = (mode) => {
  root.dataset.theme = mode;
  document.getElementById("appearance").classList.toggle("on", mode === "dark");
};
setTheme(params.get("theme") ?? (dark.matches ? "dark" : "light"));
dark.addEventListener("change", (e) => setTheme(e.matches ? "dark" : "light"));
document.getElementById("appearance").addEventListener("click", () =>
  setTheme(root.dataset.theme === "dark" ? "light" : "dark"));

const swatches = document.getElementById("swatches");
const setAccent = (name) => {
  if (name === "blue") delete root.dataset.accent;
  else root.dataset.accent = name;
  for (const s of swatches.children) s.classList.toggle("on", s.dataset.accent === name);
};
for (const name of ACCENTS) {
  const s = document.createElement("button");
  s.className = "swatch";
  s.title = name[0].toUpperCase() + name.slice(1);
  s.dataset.accent = name;
  s.style.setProperty("--swatch", `var(--amb-accent-option-${name})`);
  s.addEventListener("click", () => setAccent(name));
  swatches.append(s);
}
setAccent(params.get("accent") ?? "blue");

// Popups --------------------------------------------------------------------

const notification = document.getElementById("notification");
const closeAll = (except) => {
  for (const p of document.querySelectorAll("[data-popup].open")) {
    if (p !== except) p.classList.remove("open");
  }
  for (const b of document.querySelectorAll("[data-popup-toggle].active")) {
    if (b.dataset.popupToggle !== except?.id) b.classList.remove("active");
  }
};
for (const button of document.querySelectorAll("[data-popup-toggle]")) {
  button.addEventListener("click", (e) => {
    e.stopPropagation();
    const popup = document.getElementById(button.dataset.popupToggle);
    closeAll(popup);
    const open = popup.classList.toggle("open");
    button.classList.toggle("active", open);
    if (popup.id === "cc") {
      notification.classList.toggle("away", open);
      // While opening, on-state fills light up a beat after the modules.
      popup.classList.toggle("opening", open);
      clearTimeout(popup.openingTimer);
      if (open) popup.openingTimer = setTimeout(() => popup.classList.remove("opening"), 400);
    }
  });
}
document.addEventListener("click", (e) => {
  if (!e.target.closest("[data-popup]")) closeAll();
});
notification.addEventListener("click", () => notification.classList.add("away"));
// Choosing a menu item closes the menu, as menus do.
for (const item of document.querySelectorAll(".menu-item:not(.disabled)")) item.addEventListener("click", () => closeAll());

// Right-click a file: select it and snap a context menu open at the pointer.
const contextMenu = document.getElementById("context-menu");
const items = document.querySelectorAll(".files .item");
const select = (item) => items.forEach((i) => i.classList.toggle("selected", i === item));
for (const item of items) item.addEventListener("click", () => select(item));
document.addEventListener("contextmenu", (e) => {
  const item = e.target.closest(".files .item");
  if (!item) return;
  e.preventDefault();
  closeAll();
  select(item);
  contextMenu.classList.add("open");
  const { width, height } = contextMenu.getBoundingClientRect();
  contextMenu.style.left = `${Math.min(e.clientX, innerWidth - width - 6)}px`;
  contextMenu.style.top = `${Math.min(e.clientY, innerHeight - height - 6)}px`;
});
for (const p of params.getAll("open")) document.querySelector(`[data-popup-toggle="${p}"]`)?.click();

// Control center ------------------------------------------------------------

for (const t of document.querySelectorAll("[data-toggle]")) {
  t.addEventListener("click", () => t.classList.toggle("on"));
}
for (const t of document.querySelectorAll("[data-toggle-child]")) {
  t.addEventListener("click", () => t.querySelector(".toggle").classList.toggle("on"));
}
const play = document.getElementById("play");
play.addEventListener("click", () => {
  const use = play.querySelector("use");
  use.setAttribute("href", use.getAttribute("href") === "#i-pause" ? "#i-play" : "#i-pause");
});
for (const slider of document.querySelectorAll(".slider")) {
  const set = (e) => {
    const r = slider.querySelector(".slider-track").getBoundingClientRect();
    slider.style.setProperty("--value", Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)).toFixed(3));
  };
  slider.addEventListener("pointerdown", (e) => {
    slider.setPointerCapture(e.pointerId);
    set(e);
    slider.onpointermove = set;
  });
  slider.addEventListener("pointerup", () => (slider.onpointermove = null));
}

// Control center blur: a rounded rect with a soft edge, drawn at the real size
// so the corners stay round (gradient masks can only make square corners).
{
  const blur = document.querySelector(".cc-blur");
  const draw = () => {
    const { width: w, height: h } = blur.getBoundingClientRect();
    const style = getComputedStyle(blur);
    const f = parseFloat(style.getPropertyValue("--feather"));
    const r = parseFloat(getComputedStyle(root).getPropertyValue("--amb-radius-control-center"));
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><filter id="s" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${f / 2}"/></filter><rect x="${f}" y="${f}" width="${w - 2 * f}" height="${h - 2 * f}" rx="${r}" filter="url(#s)"/></svg>`;
    blur.style.setProperty("--cc-mask", `url("data:image/svg+xml,${encodeURIComponent(svg)}")`);
  };
  new ResizeObserver(draw).observe(blur);
}

// Dock: one tooltip that follows the pointer from icon to icon.
const dock = document.querySelector(".dock");
const tip = document.getElementById("dock-tip");
for (const app of dock.querySelectorAll(".dock-app")) {
  app.addEventListener("pointerenter", () => {
    const icon = app.querySelector(".app-icon").getBoundingClientRect();
    const showing = tip.classList.contains("show");
    tip.textContent = app.dataset.name;
    if (!showing) tip.style.transition = "none";
    tip.style.left = `${icon.left + icon.width / 2}px`;
    tip.style.top = `${dock.getBoundingClientRect().top - 12}px`;
    if (!showing) {
      tip.getBoundingClientRect();
      tip.style.transition = "";
    }
    tip.classList.add("show");
  });
}
dock.addEventListener("pointerleave", () => tip.classList.remove("show"));

// Windows -------------------------------------------------------------------

const windows = [...document.querySelectorAll("[data-window]")];
const focus = (w) => windows.forEach((x) => x.classList.toggle("active", x === w));
for (const w of windows) {
  w.addEventListener("pointerdown", () => focus(w));
  for (const handle of w.querySelectorAll("[data-drag]")) {
    handle.addEventListener("pointerdown", (e) => {
      if (e.target.closest("button, input, .controls i")) return;
      const startX = e.clientX - w.offsetLeft;
      const startY = e.clientY - w.offsetTop;
      handle.setPointerCapture(e.pointerId);
      handle.onpointermove = (m) => {
        w.style.left = `${m.clientX - startX}px`;
        w.style.top = `${Math.max(28, m.clientY - startY)}px`;
      };
    });
    handle.addEventListener("pointerup", () => (handle.onpointermove = null));
  }
}

// Keys and clock ------------------------------------------------------------

document.addEventListener("keydown", (e) => {
  if (e.target.matches("input")) return;
  if (e.key === "d") setTheme(root.dataset.theme === "dark" ? "light" : "dark");
  if (e.key === "a") setAccent(ACCENTS[(ACCENTS.indexOf(root.dataset.accent ?? "blue") + 1) % ACCENTS.length]);
  if (e.key === "Escape") closeAll();
});

const clock = document.getElementById("clock");
const tick = () => {
  const now = new Date();
  const day = now.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).replace(",", "");
  clock.textContent = `${day}  ${now.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}`;
  document.getElementById("cal-day").textContent = now.toLocaleDateString("en-US", { weekday: "short" }).toUpperCase();
  document.getElementById("cal-date").textContent = now.getDate();
};
tick();
setInterval(tick, 15_000);
