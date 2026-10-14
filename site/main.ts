// The design review: one section per spec chapter and decision, each with its
// reasoning, live examples, a verdict and a notes thread.

import { marked } from "marked";
import * as t from "../design/tokens";
import { decisionsIntro, designIntro, groups, items, type Item } from "./content";
import { h, icon } from "./dom";
import * as review from "./review";
import { loadIcons, setIconIds, specimens } from "./specimens";

const root = document.documentElement;
const ACCENTS = Object.keys(t.accent.options);
const VERDICTS: { id: review.Verdict; label: string }[] = [
  { id: "approve", label: "Looks right" },
  { id: "change", label: "Change it" },
  { id: "discuss", label: "Discuss" },
];

// Appearance ------------------------------------------------------------------

type ThemeChoice = "light" | "dark" | "auto";
const system = matchMedia("(prefers-color-scheme: dark)");
let themeChoice = (localStorage.getItem("ambrosia-theme") as ThemeChoice | null) ?? "auto";

function applyAppearance() {
  root.dataset.theme = themeChoice === "auto" ? (system.matches ? "dark" : "light") : themeChoice;
  const accent = localStorage.getItem("ambrosia-accent") ?? t.accent.default;
  if (accent === t.accent.default) delete root.dataset.accent;
  else root.dataset.accent = accent;
  for (const b of document.querySelectorAll<HTMLElement>("[data-theme-choice]")) b.classList.toggle("on", b.dataset.themeChoice === themeChoice);
  for (const b of document.querySelectorAll<HTMLElement>("[data-accent-choice]")) b.classList.toggle("on", b.dataset.accentChoice === accent);
  dispatchEvent(new Event("ambrosia:appearance"));
}
system.addEventListener("change", applyAppearance);

function appearanceControls() {
  const themes: [ThemeChoice, string, string][] = [["light", "i-sun", "Light"], ["dark", "i-moon", "Dark"], ["auto", "i-contrast", "Match system"]];
  return [
    h("div", { class: "tool-group segmented" }, themes.map(([id, glyph, label]) =>
      h("button", { class: "tool", "data-theme-choice": id, title: label, "aria-label": label, onclick: () => {
        themeChoice = id;
        localStorage.setItem("ambrosia-theme", id);
        applyAppearance();
      } }, icon(glyph)))),
    h("div", { class: "accent-picker" }, ACCENTS.map((name) =>
      h("button", { class: "accent-dot", "data-accent-choice": name, title: name, "aria-label": `${name} accent`, style: { "--swatch": `var(--amb-accent-option-${name})` }, onclick: () => {
        localStorage.setItem("ambrosia-accent", name);
        applyAppearance();
      } }))),
  ];
}

// Review UI -----------------------------------------------------------------

const timeAgo = (iso: string) => {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric" });
};

function verdictControl(item: Item) {
  return h("div", { class: "tool-group verdicts", "data-verdicts": item.id }, VERDICTS.map((v) =>
    h("button", { class: `tool verdict ${v.id}`, "data-verdict": v.id, onclick: () => {
      review.setVerdict(item.id, review.getItem(item.id).verdict === v.id ? null : v.id);
    } }, h("i", { class: "dot" }), v.label)));
}

function thread(item: Item) {
  const list = h("div", { class: "messages", "data-thread": item.id });
  const field = h("textarea", { rows: 1, placeholder: "Add a note: what works, what doesn't, what to try…" });
  const send = h("button", { class: "send", disabled: true }, "Add note");
  const submit = () => {
    const text = field.value.trim();
    if (!text) return;
    review.addMessage(item.id, text);
    field.value = "";
    field.style.height = "";
    send.disabled = true;
  };
  field.addEventListener("input", () => {
    send.disabled = !field.value.trim();
    field.style.height = "auto";
    field.style.height = `${field.scrollHeight}px`;
  });
  field.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) submit();
  });
  send.addEventListener("click", submit);
  return h("div", { class: "thread" }, list, h("div", { class: "composer" }, field, send));
}

function renderThread(item: Item) {
  const list = document.querySelector(`[data-thread="${item.id}"]`);
  if (!list) return;
  list.replaceChildren(...review.getItem(item.id).thread.map((m) =>
    h("div", { class: `message ${m.author}` },
      h("div", { class: "message-head" }, m.author === "claude" ? icon("i-bowl", 12) : null, h("b", null, m.author === "claude" ? "Claude" : "You"), h("span", null, timeAgo(m.at))),
      m.author === "claude" ? h("div", { class: "message-body", html: marked.parse(m.text, { async: false }) }) : h("div", { class: "message-body" }, m.text))));
}

function refreshReview() {
  let reviewed = 0;
  for (const item of items) {
    const { verdict } = review.getItem(item.id);
    if (verdict) reviewed++;
    for (const b of document.querySelectorAll<HTMLElement>(`[data-verdicts="${item.id}"] [data-verdict]`)) b.classList.toggle("on", b.dataset.verdict === verdict);
    const nav = document.querySelector<HTMLElement>(`[data-nav="${item.id}"]`);
    if (nav) nav.dataset.verdict = verdict ?? "";
    renderThread(item);
  }
  document.getElementById("progress")!.textContent = `${reviewed} of ${items.length} reviewed`;
}

async function copyReview(button: HTMLButtonElement) {
  const md = review.toMarkdown(new Map(items.map((i) => [i.id, i.title])));
  await navigator.clipboard.writeText(md);
  button.textContent = "Copied";
  setTimeout(() => (button.textContent = "Copy review"), 1600);
}

// Page ------------------------------------------------------------------------

function section(item: Item) {
  const examples = item.group === "spec" ? specimens[item.slug]?.() ?? [] : [];
  return h("section", { class: "item", id: item.id },
    h("header", { class: "item-head" },
      h("div", null,
        h("span", { class: "eyebrow" }, item.group === "spec" ? "Spec" : item.group === "open" ? "Open question" : "Decision",
          item.status && item.group !== "open" ? h("span", { class: `status ${item.status}` }, item.status) : null),
        h("h2", null, item.title)),
      verdictControl(item)),
    h("div", { class: "prose", html: item.html }),
    examples.length ? h("div", { class: "specimens" }, examples) : null,
    thread(item));
}

function nav() {
  return groups.filter((g) => items.some((i) => i.group === g.id)).map((g) => h("div", { class: "nav-group" },
    h("h6", null, g.title),
    items.filter((i) => i.group === g.id).map((i) =>
      h("a", { href: `#${i.id}`, "data-nav": i.id, title: i.title }, h("i", { class: "nav-dot" }), h("span", null, i.title)))));
}

function overview() {
  const saving = review.storageMode() === "server"
    ? "Your verdicts and notes save to design/review.json in the repo. Claude reads them there and replies in the same threads, and replies show up here within a few seconds."
    : "This copy of the site has no review server, so verdicts and notes stay in this browser. Use Copy review to send them over, or run `bun run review` to save them into the repo.";
  const targets = ["GTK 4", "GTK 3", "KDE / Qt", "Shell (QML)", "fontconfig", "Web"];
  return h("section", { class: "overview", id: "overview" },
    h("span", { class: "eyebrow" }, "ambrosia"),
    h("h1", null, "Design review"),
    h("div", { class: "prose lead", html: designIntro }),
    h("div", { class: "pipeline" },
      h("code", null, "design/tokens.ts"), h("span", { class: "arrow" }, "→"), h("code", null, "tools/gen"), h("span", { class: "arrow" }, "→"),
      h("div", { class: "targets" }, targets.map((x) => h("span", null, x)))),
    h("div", { class: "how" },
      h("h3", null, "How to review"),
      h("p", null, "Every chapter of the spec and every decision below has a verdict (", h("b", null, "Looks right"), ", ", h("b", null, "Change it"), " or ", h("b", null, "Discuss"), ") and a notes thread. The examples are built from the real design values, so they show exactly what would ship."),
      h("p", null, saving)),
    h("div", { class: "prose", html: decisionsIntro }));
}

function trackActive() {
  const links = new Map([...document.querySelectorAll<HTMLElement>("[data-nav]")].map((a) => [a.dataset.nav!, a]));
  const observer = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      links.forEach((a) => a.classList.remove("selected"));
      links.get(e.target.id)?.classList.add("selected");
    }
  }, { rootMargin: "-30% 0px -60% 0px" });
  document.querySelectorAll(".item").forEach((el) => observer.observe(el));
}

async function main() {
  setIconIds(loadIcons());
  await review.load();

  const copy = h("button", { class: "tool-button" }, "Copy review");
  copy.addEventListener("click", () => copyReview(copy));

  document.getElementById("sidebar")!.append(
    h("a", { class: "brand", href: "#overview" }, icon("i-bowl", 18), h("span", null, "ambrosia"), h("small", null, "Design review")),
    h("nav", null, nav()),
    h("p", { class: "progress", id: "progress" }));

  document.getElementById("toolbar")!.append(
    h("b", { class: "toolbar-title" }, "Design review"),
    h("span", { class: "spacer" }),
    ...appearanceControls(),
    copy);

  document.getElementById("content")!.append(overview(), ...items.map(section));

  applyAppearance();
  refreshReview();
  review.onChange(refreshReview);
  trackActive();
  // Links from outside jump straight to their section once the fonts have
  // loaded and settled the layout; the sidebar glides.
  history.scrollRestoration = "manual";
  const jump = () => document.querySelector(location.hash || "#overview")?.scrollIntoView({ behavior: "instant" });
  const faces = ["400 13px Inter", "600 13px Inter", "700 26px Inter", "12px 'JetBrains Mono'"];
  if (location.hash) Promise.all(faces.map((f) => document.fonts.load(f))).then(() => requestAnimationFrame(jump));
  addEventListener("hashchange", jump);
  const glide = matchMedia("(prefers-reduced-motion: no-preference)");
  document.getElementById("sidebar")!.addEventListener("click", (e) => {
    const link = (e.target as Element).closest<HTMLAnchorElement>("a[href^='#']");
    if (!link) return;
    e.preventDefault();
    document.querySelector(link.hash)?.scrollIntoView({ behavior: glide.matches ? "smooth" : "instant" });
    history.replaceState(null, "", link.hash);
  });
}

main();
