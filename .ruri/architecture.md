# ambrosia — architecture

The shape of this project, for a model that has never seen it: the stack it is built as, top to bottom, how the parts connect, where things are, how to run it. This is the index. Each layer has a sheet of its own in `.ruri/layers/` — where to change what inside it, how it works, its key files, its traps — so read the one for the layer you are about to work in (`ruri layer <slug>` prints it), and leave the rest. Where the work stands — git, decisions, what worked and what didn't, what's open — is in catchup.md beside this file.
Don't edit this file: ruri writes it. `ruri architecture` prints it with every line numbered, and once you have read it that way you can put right what your work changed — `ruri architecture add|set|drop <section> …`. The user corrects it on the architecture page.

Read from the repo at 43429bc; folded forward from finished turns since. Where it and the code disagree, the code is right.

Ambrosia is a Linux distro on Arch that looks and moves as one thing: one design authority, one token file, a generator theming every toolkit identically. It ships as Arch packages and an archiso installer image. The design system, preview and review site exist; the distro pipeline (packages, Ambrosia session on KWin, live image, installer) has a first cut; the shell has its menu bar and traffic-light window frames.

## The stack, top to bottom

1. **Preview Desktop** — Static HTML/JS mock desktop (draggable windows, popups, clock) styled only from dist/web/tokens.css (`preview/, assets/`) → `.ruri/layers/preview.md`
2. **Design Tokens** — TypeScript single source of truth: type scale, 4px grid, radii, OKLCH colors, glass, shadows, springs (`design/`) → `.ruri/layers/design-tokens.md`
3. **Generator Core** — Bun+TypeScript resolver: OKLCH→sRGB, contrast derivation, spring solver, dist orchestration (`tools/gen/ · 4 files`) → `.ruri/layers/generator-core.md`
4. **Theme Targets** — Per-toolkit formatters turning resolved model into GTK, KDE, QML, fontconfig, web output (`tools/gen/targets/`) → `.ruri/layers/theme-targets.md`
5. **Build and Install** — Bun, TypeScript, Make orchestration: test, build dist/, per-user Linux install with backups (`./, tools/ · 4 files`) → `.ruri/layers/build-install.md`
6. **Review Site** — Design review website with live specimens, verdict threads, review server and static build (`site/`) → `.ruri/layers/review-site.md`
7. **Shell and Session** — Quickshell QML shell (wallpaper, menu bar) and the Ambrosia session: Plasma's services with plasmashell swapped out, KWin/KDE defaults (`shell/, session/, tools/ · 1 file`) → `.ruri/layers/shell-and-session.md`
8. **Packaging and Image** — Arch PKGBUILDs (ambrosia-theme/-shell/-desktop, the Quickshell rebuild), the archiso profile with live desktop and installer, ISO build and VM test scripts (`packaging/, iso/, tools/ · 6 files`) → `.ruri/layers/packaging-and-image.md`
9. **Files App** — our Finder look-alike file manager: Qt 6 QML front end on the Ambrosia theme, C++20 core with KF6/KIO, in-memory filename index, rg content search, benchmarks (`docs/finder/, files/, files/tools/`) → `.ruri/layers/files-app.md`

## How it flows

- **Token to theme:** design/tokens.ts → tools/gen/resolve.ts → tools/gen/targets/* → dist/ (gtk, kde, aurorae, qml, fontconfig, web, tokens.json) → tools/install.sh
- **Preview a change:** design/tokens.ts → make build (bun test + bun tools/gen/index.ts) → dist/web/tokens.css → preview/index.html + preview/preview.js
- **Review design:** design/DESIGN.md + design/DECISIONS.md → site/ (bun run review on :4747) → design/review.json verdicts and replies
- **Ship it:** tokens + shell/ + session/ + files/ → packaging/PKGBUILD via make publish (tenet builds from git checkout ~/work/ambrosia, pushed from the Mac) → Mac signs packages and database → GitHub release repo ambrosia-packages (database uploaded last, old versions deleted) → installed systems: pacman -Syu; ISO via tools/build-iso.sh, then tools/vm.sh install

## Where things are

- design/ — DESIGN.md rules and tokens.ts values, the single source of truth
- tools/gen/ — index.ts orchestrator, resolve.ts, color.ts, spring.ts plus tests
- tools/gen/targets/ — gtk.ts, kde.ts, aurorae.ts (traffic-light window frames), qml.ts, fontconfig.ts, web.ts, shared.ts formatters
- tools/ — install.sh (per-user theme install with .before-ambrosia backups); remote.sh and publish-repo.sh (sync to and build on tenet over SSH; make publish signs and uploads the repo); repo-check.sh (counts our packages)
- preview/ — index.html + preview.js mock desktop, styled only from dist/web/tokens.css
- site/ — review site: spec content, live specimens, verdict threads, server + static build
- assets/ — banner SVG, nectar day/night wallpapers, Files app icon (assets/icons/org.ambrosia.files.svg, installed as hicolor org.ambrosia.files)
- dist/ — generated output: gtk-*, kde/, qml/, fontconfig/, web/, aurorae/, tokens.json (never hand-edit)
- Makefile — build, test, review, screenshot targets; remote-build, review-remote and shot-remote run on tenet
- package.json / tsconfig.json — bun+typescript toolchain definition
- CONTEXT.md — handoff sheet: what stands, what's next, machines (tenet), how to build/test, gotchas
- shell/ — Quickshell QML shell: menu bar and menus on a grabbing popup (MenuView.qml, Overlay.qml), Spotlight, dock (hand-drawn trash-full/empty.svg, no Apple art), control center, notifications, appearance; watchFiles off when installed under /usr
- session/ — startambrosia (copies decoration settings into ~/.config/kdedefaults/kwinrc at login), systemd units swapping plasmashell, /etc/xdg/ambrosia defaults (kwinrc, breezerc), look-and-feel defaults, pacman hook ambrosia-shell-restart(.hook) restarting the shell after upgrades
- packaging/ — PKGBUILDs for ambrosia-theme/-shell/-desktop, ambrosia-files, and the Quickshell rebuild (DBusMenu shortcut patch; debug packages off)
- iso/ — archiso profile: live desktop, local [ambrosia] repo, installer scripts
- files/ — Files, Ambrosia's Finder: Qt Quick front end (MenuBar with DBusMenu-exported Edit, View and Go menus, FinderWindow, Toolbar, ListPane.qml resizable columns, RenameField.qml, swappable Sidebar/SidebarList with SidebarFlush stub), C++20 core with KF6/KIO (foldermodel.cpp, fileops.cpp undoable copy/move/trash with undo/redo labels), benchmarks in files/bench/; installs /usr/bin/ambrosia-files

## How to run it

- make — test, build all themes into dist/, install on Linux
- make build — bun test + bun run build (build-only, all systems)
- open preview/index.html — run the mock desktop (D dark, A accent)
- bun test — check contrast, radii, and spacing-grid spec rules
- bun run build — tsc --noEmit + bun tools/gen/index.ts
- make clean — remove dist/
- make package / make quickshell — Arch only: packages into out/pkg/
- sudo make iso — Arch only: installer image into out/iso/
- tools/remote.sh justin06lee@192.168.1.172 <cmd> — push HEAD to tenet's bare repo, reset its ~/work/ambrosia checkout (uncommitted changes rsynced on top) and run there; make remote-build / review-remote / shot-remote — the build gate, the review site (tunnelled to :4747) and headless Firefox screenshots on tenet
- tools/shot.sh out.png — screenshot the shell on a headless KWin; tools/vm.sh live|install|installed|shot — the image in a headless QEMU VM

## Conventions

- Never hand-edit dist/ output; change design/tokens.ts and regenerate
- Targets must read the resolved model, never tokens.ts colors directly
- make requires bun; on non-Linux it builds into dist/ only
- The 8 GB Mac only edits, runs git and signs packages; builds, tests, servers and screenshots run on tenet, capped (systemd-run --user --scope -p MemoryMax=…, nice 19, ionice -c3), scratch on disk, not /tmp

## What it does

- Single OKLCH token file drives every toolkit theme identically
- Generates GTK, KDE, Aurorae, QML, fontconfig, web CSS, JSON from tokens
- Gamut-maps colors to sRGB with contrast-derived accent variants
- Solves response/damping springs into constants and easing curves
- Validates contrast, concentric radii, and spacing grid via tests
- Browser mock desktop preview and review site render spec with live specimens
- Dark mode and accents via keys/URL; verdict threads in review
- Installs themes per-user on Linux preserving prior configs
- Mac-first keyboard: Super-as-Command, ⌘ glyphs in menus, Files shortcuts
- Signed Arch pacman repo on GitHub; archiso installer, UEFI, QEMU-testable
- Menu bar: focused-app menus with shortcuts, Wi-Fi, search, clock
- Super+Space Spotlight; dock keeps pinned order, separate launchers, Mac-style Trash
- Control center: pure blur glass, modes, sliding notification banners
- Honey-bowl Ambrosia branding in menu bar, banner, favicon, preview and review site
- Finder-style file manager: list, folders, menus, undo/redo copy/move/trash/rename, drag-drop
- Starter apps: Firefox, Kate, Gwenview, Okular, Ark, Discover
