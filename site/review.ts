// Review state: a verdict and a notes thread per item. With the review server
// running it lives in design/review.json (so Claude can read and reply there);
// as a static site it falls back to this browser's localStorage.

export type Verdict = "approve" | "change" | "discuss";
export interface Message {
  author: "you" | "claude";
  text: string;
  at: string;
}
export interface ItemReview {
  verdict?: Verdict | null;
  thread: Message[];
}
export interface Review {
  items: Record<string, ItemReview>;
}

const KEY = "ambrosia-review";
let mode: "server" | "local" = "local";
let state: Review = { items: {} };
const listeners = new Set<() => void>();

export const storageMode = () => mode;
export const getItem = (id: string): ItemReview => state.items[id] ?? { thread: [] };
export const allItems = () => state.items;
export const onChange = (fn: () => void) => listeners.add(fn);
const emit = () => listeners.forEach((fn) => fn());

async function fetchServer(): Promise<Review | null> {
  try {
    const res = await fetch("/api/review", { cache: "no-store" });
    return res.ok ? ((await res.json()) as Review) : null;
  } catch {
    return null;
  }
}

export async function load() {
  const remote = await fetchServer();
  if (remote) {
    mode = "server";
    state = remote;
    // Pick up Claude's replies (written straight into the file) while open.
    setInterval(refresh, 8000);
    addEventListener("focus", refresh);
  } else {
    state = JSON.parse(localStorage.getItem(KEY) ?? '{"items":{}}');
  }
}

async function refresh() {
  const remote = await fetchServer();
  if (remote && JSON.stringify(remote) !== JSON.stringify(state)) {
    state = remote;
    emit();
  }
}

async function update(id: string, change: { verdict?: Verdict | null; message?: string }) {
  if (mode === "server") {
    const res = await fetch(`/api/review/${encodeURIComponent(id)}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(change),
    });
    if (res.ok) state = (await res.json()) as Review;
  } else {
    const item = (state.items[id] ??= { thread: [] });
    if (change.verdict !== undefined) item.verdict = change.verdict;
    if (change.message) item.thread.push({ author: "you", text: change.message, at: new Date().toISOString() });
    localStorage.setItem(KEY, JSON.stringify(state));
  }
  emit();
}

export const setVerdict = (id: string, verdict: Verdict | null) => update(id, { verdict });
export const addMessage = (id: string, message: string) => update(id, { message });

/** The whole review as markdown, to paste into a chat. */
export function toMarkdown(titles: Map<string, string>): string {
  const label: Record<Verdict, string> = { approve: "looks right", change: "change it", discuss: "discuss" };
  const lines = ["# ambrosia design review", ""];
  for (const [id, title] of titles) {
    const item = state.items[id];
    if (!item || (!item.verdict && item.thread.length === 0)) continue;
    lines.push(`## ${title}${item.verdict ? ` (${label[item.verdict]})` : ""}`, "");
    for (const m of item.thread) lines.push(`- **${m.author}:** ${m.text.replace(/\n+/g, " ")}`);
    lines.push("");
  }
  return lines.join("\n");
}
