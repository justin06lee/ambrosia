# ambrosia — architecture

The shape of this project, for a model that has never seen it: where to change what, the stack it is built as, how the parts connect, where things are, how to run it. Where the work stands — git, decisions, what worked and what didn't, what's open — is in catchup.md beside this file.
Don't edit this file: ruri writes it. `ruri architecture` prints it with every line numbered, and once you have read it that way you can put right what your work changed — `ruri architecture add|set|drop <section> …`. The user corrects it on the architecture page.

Read from the repo at 43429bc; folded forward from finished turns since. Where it and the code disagree, the code is right.

Ambrosia is a Linux desktop on Arch that looks and moves as one thing — one design authority, one token file, and a generator theming every toolkit identically. Currently in foundation phase: design system, theme generator, and browser preview exist; shell, compositor effects, and distro do not.

## The stack, top to bottom

1. **Preview Desktop** — Static HTML/JS mock desktop (draggable windows, popups, clock) styled only from dist/web/tokens.css (`preview/, assets/`)
2. **Design Tokens** — TypeScript single source of truth: type scale, 4px grid, radii, OKLCH colors, glass, shadows, springs (`design/`)
3. **Generator Core** — Bun+TypeScript resolver: OKLCH→sRGB, contrast derivation, spring solver, dist orchestration (`tools/gen/ · 4 files`)
4. **Theme Targets** — Per-toolkit formatters turning resolved model into GTK, KDE, QML, fontconfig, web output (`tools/gen/targets/`)
5. **Build and Install** — Bun, TypeScript, Make orchestration: test, build dist/, per-user Linux install with backups (`./, tools/ · 4 files`)

## How it flows

- **Token to theme:** design/tokens.ts → tools/gen/resolve.ts → tools/gen/targets/* → dist/ (gtk, kde, qml, fontconfig, web, tokens.json) → tools/install.sh
- **Preview a change:** design/tokens.ts → make build (bun test + bun tools/gen/index.ts) → dist/web/tokens.css → preview/index.html + preview/preview.js

## Where things are

- design/ — DESIGN.md rules and tokens.ts values, the single source of truth
- tools/gen/ — index.ts orchestrator, resolve.ts, color.ts, spring.ts plus tests
- tools/gen/targets/ — gtk.ts, kde.ts, qml.ts, fontconfig.ts, web.ts, shared.ts formatters
- tools/install.sh — per-user Linux theme install with .before-ambrosia backups
- preview/ — index.html + preview.js mock desktop, styled only from dist/web/tokens.css
- assets/ — banner SVG and nectar day/night wallpapers
- dist/ — generated output: gtk-*, kde/, qml/, fontconfig/, web/, tokens.json (never hand-edit)
- Makefile / package.json / tsconfig.json — build, bun+typescript toolchain definition

## How to run it

- make — test, build all themes into dist/, install on Linux
- make build — bun test + bun run build (build-only, all systems)
- open preview/index.html — run the mock desktop (D dark, A accent)
- bun test — check contrast, radii, and spacing-grid spec rules
- bun run build — tsc --noEmit + bun tools/gen/index.ts
- make clean — remove dist/

## Conventions

- Never hand-edit dist/ output; change design/tokens.ts and regenerate
- Targets must read the resolved model, never tokens.ts colors directly
- make requires bun; on non-Linux it builds into dist/ only

## What it does

- Single OKLCH token file drives every toolkit theme identically
- Generates GTK4, GTK3 light/dark, KDE colors, and QML shell theme
- Generates fontconfig, FreeType env, web CSS, and resolved JSON
- Gamut-maps colors to sRGB with contrast-derived accent variants
- Solves response/damping springs into constants and easing curves
- Validates contrast, concentric radii, and spacing grid via tests
- Browser mock desktop preview styled only from generated tokens
- Preview toggles dark mode and cycles accents via keys/URL
- Installs themes per-user on Linux preserving prior configs
- Roadmap toward KWin/Quickshell shell, effects, and archiso image
