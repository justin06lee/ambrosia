// The review items, read straight from the design docs so the site can't
// drift from them: every "## " section of DESIGN.md and DECISIONS.md is one item.

import { marked } from "marked";
import decisionsMd from "../design/DECISIONS.md" with { type: "text" };
import designMd from "../design/DESIGN.md" with { type: "text" };

export type Status = "accepted" | "proposed" | "open";
export type Group = "spec" | "decisions" | "open";

export interface Item {
  id: string;
  /** Key into the specimens for spec sections, e.g. "typography". */
  slug: string;
  group: Group;
  title: string;
  status?: Status;
  html: string;
}

const slugify = (text: string) => text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const render = (md: string) => marked.parse(md, { async: false }) as string;

function split(md: string) {
  const [head = "", ...parts] = md.split(/^## /m);
  return {
    intro: head.replace(/^# .*\n/, "").trim(),
    sections: parts.map((part) => {
      const nl = part.indexOf("\n");
      return { title: part.slice(0, nl).trim(), body: part.slice(nl + 1).trim() };
    }),
  };
}

const design = split(designMd);
const decisions = split(decisionsMd);

export const designIntro = render(design.intro);
export const decisionsIntro = render(decisions.intro);

export const items: Item[] = [
  ...design.sections.map(({ title, body }): Item => ({
    id: `spec-${slugify(title)}`,
    slug: slugify(title),
    group: "spec",
    title,
    html: render(body),
  })),
  ...decisions.sections.map(({ title, body }): Item => {
    const status = (body.match(/^Status:\s*(\w+)/m)?.[1] ?? "proposed") as Status;
    return {
      id: `decision-${slugify(title)}`,
      slug: slugify(title),
      group: status === "open" ? "open" : "decisions",
      title,
      status,
      html: render(body.replace(/^Status:.*\n+/m, "")),
    };
  }),
];

export const groups: { id: Group; title: string }[] = [
  { id: "spec", title: "The spec" },
  { id: "decisions", title: "Decisions" },
  { id: "open", title: "Open questions" },
];
