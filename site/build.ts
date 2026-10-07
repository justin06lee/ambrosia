// Builds the review site as static files into dist/site/. Without the review
// server, verdicts and notes are kept in the visitor's browser instead.

import { cp, rm } from "node:fs/promises";
import { join } from "node:path";

const root = join(import.meta.dir, "..");
const out = join(root, "dist/site");

await rm(out, { recursive: true, force: true });
const result = await Bun.build({
  entrypoints: [join(import.meta.dir, "index.html")],
  outdir: out,
  minify: true,
  target: "browser",
});
if (!result.success) {
  for (const log of result.logs) console.error(log);
  process.exit(1);
}

// The desktop preview runs in an iframe from these plain files.
for (const dir of ["preview", "dist/web", "assets/wallpapers"]) {
  await cp(join(root, dir), join(out, dir), { recursive: true });
}

console.log(`ambrosia: built the review site into dist/site/ (${result.outputs.length} files)`);
