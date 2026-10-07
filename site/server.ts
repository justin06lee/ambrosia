// The review server: serves the site with hot reload and stores verdicts and
// notes in design/review.json, where Claude can read them and reply.
//
//   bun run review            → http://localhost:4747

import { join, normalize } from "node:path";
import homepage from "./index.html";
import type { Review, Verdict } from "./review";

const root = join(import.meta.dir, "..");
const store = join(root, "design/review.json");
const VERDICTS = new Set<Verdict | null>(["approve", "change", "discuss", null]);
// The preview iframe and its assets are plain files from the repo.
const STATIC = ["preview/", "dist/web/", "assets/"];

async function read(): Promise<Review> {
  const file = Bun.file(store);
  return (await file.exists()) ? ((await file.json()) as Review) : { items: {} };
}

// Writes go through one queue so two quick clicks can't interleave.
let queue = Promise.resolve();
const write = (fn: (review: Review) => void) =>
  (queue = queue.then(async () => {
    const review = await read();
    fn(review);
    await Bun.write(store, `${JSON.stringify(review, null, 2)}\n`);
  }));

const server = Bun.serve({
  port: Number(process.env.PORT ?? 4747),
  // No hot module reload: Bun's HMR re-imports the markdown docs incorrectly
  // after they change. A plain page refresh rebuilds them correctly.
  development: { hmr: false, console: true },
  routes: {
    "/": homepage,
    "/api/review": { GET: async () => Response.json(await read()) },
    "/api/review/:id": {
      POST: async (req) => {
        const id = req.params.id;
        if (!/^[a-z0-9-]{1,80}$/.test(id)) return new Response("bad id", { status: 400 });
        const body = (await req.json().catch(() => null)) as { verdict?: Verdict | null; message?: unknown } | null;
        if (!body) return new Response("bad body", { status: 400 });
        if (body.verdict !== undefined && !VERDICTS.has(body.verdict)) return new Response("bad verdict", { status: 400 });
        const message = typeof body.message === "string" ? body.message.trim().slice(0, 8000) : "";
        await write((review) => {
          const item = (review.items[id] ??= { thread: [] });
          if (body.verdict !== undefined) item.verdict = body.verdict;
          if (message) item.thread.push({ author: "you", text: message, at: new Date().toISOString() });
        });
        return Response.json(await read());
      },
    },
  },
  async fetch(req) {
    const path = normalize(decodeURIComponent(new URL(req.url).pathname)).replace(/^\/+/, "");
    if (!STATIC.some((prefix) => path.startsWith(prefix))) return new Response("Not found", { status: 404 });
    const file = Bun.file(join(root, path.endsWith("/") ? `${path}index.html` : path));
    return (await file.exists()) ? new Response(file) : new Response("Not found", { status: 404 });
  },
});

console.log(`ambrosia design review: ${server.url}`);
