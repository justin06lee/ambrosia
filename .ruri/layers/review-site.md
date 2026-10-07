# ambrosia — Review Site

One layer of ambrosia's stack, owning `site/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer review-site` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer review-site add|set|drop <section> …`. Where it and the code disagree, the code is right.

The Review Site is a design-review web app that renders every `## ` section of DESIGN.md/DECISIONS.md as a reviewable item with live specimens, a verdict and a notes thread. Specimens are built with the same tokens and resolver the generator ships, so review matches output. State lives in `design/review.json` via a Bun server when present, otherwise in browser localStorage; `build.ts` emits a static fallback into `dist/site/`.

## Where to change what

- **Live specimens per spec section:** site/specimens.ts, site/dom.ts, site/main.ts
- **Review page layout and sections:** site/main.ts, site/index.html, site/content.ts
- **Verdict buttons and notes thread:** site/main.ts, site/review.ts
- **Review state, server/local fallback:** site/review.ts, site/server.ts
- **Review server and persistence API:** site/server.ts, site/review.ts
- **Review items sourced from design docs:** site/content.ts, site/main.ts
- **Theme / accent appearance switcher:** site/main.ts, site/site.css
- **Site styling in own design language:** site/site.css, site/index.html
- **Static site build:** site/build.ts, site/index.html
- **Icon sprite reuse from preview:** site/specimens.ts, site/dom.ts
- **Element builder helper:** site/dom.ts, site/specimens.ts

## How it works

- **Review a design item:** content.ts splits DESIGN.md/DECISIONS.md into items → main.ts renders section with reasoning plus specimens → review.ts load() tries /api/review, falls back to localStorage → user sets verdict / posts note via setVerdict/addMessage → server.ts queues write into design/review.json or local mode saves locally → onChange listeners re-render verdict and thread
- **Serve live review:** server.ts serves index.html with HMR on port 4747 → STATIC preview/, dist/web/, assets/ served as plain files → client fetches /api/review for shared state → POST verdict/message serialized through one write queue
- **Build static review site:** build.ts Bun.builds index.html into dist/site/ → copies preview, dist/web, assets/wallpapers alongside → no server: review.ts stays in localStorage mode

## Key files

- site/main.ts — page assembly, appearance switcher, verdict/thread UI wiring
- site/specimens.ts — live token/resolver-driven examples per spec section
- site/review.ts — verdict/thread state with server-then-localStorage fallback
- site/server.ts — Bun server, hot reload, queued writes to design/review.json
- site/content.ts — parses DESIGN.md/DECISIONS.md headings into review items
- site/site.css — review-site styling; values only from dist/web/tokens.css
- site/build.ts — static build into dist/site/ plus preview asset copies
- site/index.html — shell: sidebar, toolbar, content, wallpaper, sprite mounts
- site/dom.ts — tiny h/s/icon element builder used by specimens

## Rules and traps

- Never hardcode review copy: items and intros come from DESIGN.md/DECISIONS.md via content.ts.
- No ad-hoc styling values: every value comes from dist/web/tokens.css, glass from preview/glass.css.
- Verdicts are only approve/change/discuss (or null); server rejects anything else.
- Review writes must go through the single queued writer; concurrent writes interleave otherwise.
- Do not assume the server exists: static builds must keep verdicts/notes in localStorage.
- Static build must copy preview, dist/web, assets/wallpapers or the preview iframe breaks.

## What it talks to

- Design Tokens — specimens and accent list read design/tokens; review item source is DESIGN.md/DECISIONS.md
- Generator Core — specimens render through tools/gen resolve, color, spring
- Preview Desktop — embeds preview/index.html in iframe; reuses its icon sprite and preview/glass.css
- Build and Install — static output lands in dist/site/; live site consumes dist/web/tokens.css
- Theme Targets — specimens show what formatters will ship; review approves that output
