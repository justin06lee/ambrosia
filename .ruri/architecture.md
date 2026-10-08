# ambrosia — architecture

The shape of this project, for a model that has never seen it: the stack it is built as, top to bottom, how the parts connect, where things are, how to run it. This is the index. Each layer has a sheet of its own in `.ruri/layers/` — where to change what inside it, how it works, its key files, its traps — so read the one for the layer you are about to work in (`ruri layer <slug>` prints it), and leave the rest. Where the work stands — git, decisions, what worked and what didn't, what's open — is in catchup.md beside this file.
Don't edit this file: ruri writes it. `ruri architecture` prints it with every line numbered, and once you have read it that way you can put right what your work changed — `ruri architecture add|set|drop <section> …`. The user corrects it on the architecture page.

Read from the repo at 43429bc; folded forward from finished turns since. Where it and the code disagree, the code is right.

Ambrosia is a Linux distro on Arch that looks and moves as one thing — one design authority, one token file, a generator theming every toolkit identically — shipped as Arch packages and an archiso installer image. The design system, preview and review site exist; the distro pipeline (packages, Ambrosia session on KWin, live image, installer) has a first cut; the shell has its menu bar.

## The stack, top to bottom

1. **Preview Desktop** — Static HTML/JS mock desktop (draggable windows, popups, clock) styled only from dist/web/tokens.css (`preview/, assets/`) → `.ruri/layers/preview.md`
2. **Design Tokens** — TypeScript single source of truth: type scale, 4px grid, radii, OKLCH colors, glass, shadows, springs (`design/`) → `.ruri/layers/design-tokens.md`
3. **Generator Core** — Bun+TypeScript resolver: OKLCH→sRGB, contrast derivation, spring solver, dist orchestration (`tools/gen/ · 4 files`) → `.ruri/layers/generator-core.md`
4. **Theme Targets** — Per-toolkit formatters turning resolved model into GTK, KDE, QML, fontconfig, web output (`tools/gen/targets/`) → `.ruri/layers/theme-targets.md`
5. **Build and Install** — Bun, TypeScript, Make orchestration: test, build dist/, per-user Linux install with backups (`./, tools/ · 4 files`) → `.ruri/layers/build-install.md`
6. **Review Site** — Design review website with live specimens, verdict threads, review server and static build (`site/`) → `.ruri/layers/review-site.md`
7. **Shell and Session** — Quickshell QML shell (wallpaper, menu bar) and the Ambrosia session: Plasma's services with plasmashell swapped out, KWin/KDE defaults (`shell/, session/, tools/ · 1 file`) → `.ruri/layers/shell-and-session.md`
8. **Packaging and Image** — Arch PKGBUILDs (ambrosia-theme/-shell/-desktop, the Quickshell rebuild), the archiso profile with live desktop and installer, ISO build and VM test scripts (`packaging/, iso/, tools/ · 3 files`) → `.ruri/layers/packaging-and-image.md`

## How it flows

- **Token to theme:** design/tokens.ts → tools/gen/resolve.ts → tools/gen/targets/* → dist/ (gtk, kde, qml, fontconfig, web, tokens.json) → tools/install.sh
- **Preview a change:** design/tokens.ts → make build (bun test + bun tools/gen/index.ts) → dist/web/tokens.css → preview/index.html + preview/preview.js
- **Review design:** design/DESIGN.md + design/DECISIONS.md → site/ (bun run review on :4747) → design/review.json verdicts and replies
- **Ship it:** tokens + shell/ + session/ → packaging/PKGBUILD (make package) → out/pkg → tools/build-iso.sh (local repo on the image) → mkarchiso → out/iso/*.iso → tools/vm.sh install

## Where things are

- design/ — DESIGN.md rules and tokens.ts values, the single source of truth
- tools/gen/ — index.ts orchestrator, resolve.ts, color.ts, spring.ts plus tests
- tools/gen/targets/ — gtk.ts, kde.ts, qml.ts, fontconfig.ts, web.ts, shared.ts formatters
- tools/install.sh — per-user Linux theme install with .before-ambrosia backups
- preview/ — index.html + preview.js mock desktop, styled only from dist/web/tokens.css
- site/ — review site: spec content, live specimens, verdict threads, server + static build
- assets/ — banner SVG and nectar day/night wallpapers
- dist/ — generated output: gtk-*, kde/, qml/, fontconfig/, web/, tokens.json (never hand-edit)
- Makefile / package.json / tsconfig.json — build, bun+typescript toolchain definition
- CONTEXT.md — handoff sheet: what stands, what's next, machines (tenet), how to build/test, gotchas
- shell/ — Quickshell QML shell (wallpaper, menu bar) on import Ambrosia
- session/ — startambrosia, systemd units swapping plasmashell, /etc/xdg/ambrosia defaults
- packaging/ — PKGBUILDs for ambrosia-theme/-shell/-desktop and the Quickshell rebuild
- iso/ — archiso profile: live desktop, local [ambrosia] repo, installer scripts
- out/ — build output on the Arch host: pkg/, iso/, vm/ (git-ignored)

## How to run it

- make — test, build all themes into dist/, install on Linux
- make build — bun test + bun run build (build-only, all systems)
- open preview/index.html — run the mock desktop (D dark, A accent)
- bun test — check contrast, radii, and spacing-grid spec rules
- bun run build — tsc --noEmit + bun tools/gen/index.ts
- make clean — remove dist/
- make package / make quickshell — Arch only: packages into out/pkg/
- sudo make iso — Arch only: installer image into out/iso/
- tools/remote.sh justin06lee@tenet <cmd> — rsync the checkout to tenet over makima and run there
- tools/shot.sh out.png — screenshot the shell on a headless KWin; tools/vm.sh live|install|installed|shot — the image in a headless QEMU VM

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
- Preview blur-only control center, dock, tooltips and badges
- Preview menus snap open instantly with right-click file menu
- Review site renders spec with live specimens and verdict threads
- Installs themes per-user on Linux preserving prior configs
- Mac-first keyboard spec with Super-as-Command and switcher
- Roadmap toward KWin/Quickshell shell, effects, and archiso image
- Arch packages and an archiso live image that installs Ambrosia (UEFI), testable unattended in QEMU
- Ambrosia session: Plasma's services with a Quickshell menu bar and wallpaper in place of plasmashell
