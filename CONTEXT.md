# ambrosia: context for the next session

Read this first when picking the project back up. It records where things
stand, how the work runs, and what's next. The README covers the project
itself, `design/DESIGN.md` the rules, and `design/DECISIONS.md` the choices.

## What this is

A Linux desktop (an Arch-based distro, eventually) that looks and feels like
macOS: glass, springs, one consistent design across every toolkit. Its fonts,
icons and wallpapers are its own. The user wants it to feel identical to a
Mac in the hands, and judges details by comparing against their own Mac
(screenshots, screen recordings).

## Where it stands

**Phase 1 is done.** Everything below is built, reviewed and merged on
`master`. There is no git remote yet, so nothing has been pushed.

- `design/tokens.ts` holds every value. `tools/gen` generates GTK 4/3, KDE
  color schemes, a QML `Theme` singleton, fontconfig and CSS into `dist/`.
  Tests enforce contrast and concentric radii.
- `preview/` is an HTML mock of the desktop: menu bar, dock, control center,
  windows, menus. It's the visual reference the real shell must match.
- `site/` is the design review site. `bun run review` serves it on port 4747.
  Your verdicts and notes save to `design/review.json`, and Claude replies by
  editing that file; the page polls it every 8s.
- Every decision in `DECISIONS.md` is **accepted**; nothing is open. Key ones:
  - Arch + KWin + Quickshell, with Qt as the native toolkit.
  - Behind-window sidebar glass.
  - A Mac-first keyboard (Super acts as ⌘ via keyd), chosen at onboarding.
  - Refraction on shell surfaces only.
  - Opt-in dock magnification.
  - Inter + JetBrains Mono, warm neutrals, blue default accent with honey as
    the house color.
- The latest UI work matched macOS 26 references: a capsule-module control
  center on a light, untinted blur with soft rounded edges and a fade
  choreography measured frame by frame from a recording; a roomy, ringed dock;
  menus and context menus that snap open.

**Never verified on Linux.** The QML theme, the GTK CSS and the KDE color
schemes have never been loaded on a Linux machine.

## Next: phase 2, the shell, on tenet

The user said to carry on with the roadmap rather than keep polishing the
spec. The next steps:

1. **Ask before changing tenet.** It's the user's Arch desktop on the makima
   mesh, and so far it has only been looked at read-only. Phase 2 means
   installing packages there (KWin/Plasma session alongside GNOME, Quickshell,
   qt6-declarative, keyd), which needs explicit permission.
2. Get the repo onto tenet, run `make` there (installs the themes per user),
   and `qmllint` the generated `dist/qml/Ambrosia/Theme.qml`.
3. Build the shell in QML on `Theme.qml`, matching `preview/`: menu bar first,
   then the dock, then the control center.
4. The Mac-first keyboard layer with keyd, including per-app terminal rules.

The user plans to buy an Apple Magic Trackpad for tenet. The Jetson Orin Nano
is "later" and not scheduled.

## Machines

- **This Mac:** where the repo lives
  (`/Volumes/T7/Stockpile/Workspace/github.com/justin06lee/ambrosia`). It has
  no Qt or GTK, and Docker is installed but its daemon is off. Don't start
  Docker Desktop without asking.
- **tenet:** i7-10700, 16 GB of RAM, GTX 1660 Ti on nvidia-open 615 with
  kernel modesetting, a 4K display over HDMI, Arch with kernel 7.2, GNOME 50,
  no KWin yet, a USB mouse. Run commands with
  `makima possess tenet '<cmd>' < /dev/null`. **This logs in as root**, so
  stick to read-only commands unless the user okays changes.

## How the work runs

- **Running things:**
  - `make` tests, builds and installs (the install is Linux only).
  - `make build` is the build gate; it must pass after the last change.
  - `bun run review` starts the review site on :4747.
  - `open preview/index.html` opens the preview. `?theme=dark&accent=honey&open=cc|view-menu`
    sets its starting state, and the D and A keys switch theme and accent.
- **The review server** is currently running detached because the user asked
  for it. PID is in `/tmp/ambrosia-review.pid`, logs in
  `/tmp/ambrosia-review.log`. Restart it with
  `kill $(cat /tmp/ambrosia-review.pid); nohup bun site/server.ts > /tmp/ambrosia-review.log 2>&1 & echo $! > /tmp/ambrosia-review.pid`.
- **Conventions** (the zanka and omniscience skills):
  - bun only.
  - The default branch is `master`.
  - One branch per feature, merged with `--no-ff` and tagged
    (`feat-<slug>`); conventional commits ending with the Co-Authored-By line.
  - The README stays current.
  - Stop any server you start, unless the user asked for it to keep running.
- **Change design values in `design/tokens.ts`, never in `dist/`.** Keep
  `DESIGN.md` general: exact numbers belong in tokens and the preview. The user
  asked for the spec not to sprawl into specifics.
- **ruri:** the component library has "the design preview desktop" (aliases:
  control center, dock, menu bar, context menu) and "the design review site".
  After changing one, update its entry with `ruri edit <slug> --shot …`.
- **Check visual work in the bridge browser** (open it, screenshot it) before
  reporting. To copy a macOS animation, extract the user's screen recording
  with ffmpeg and select frames by timestamp, because recordings have a
  variable frame rate. Then sample the preview's real opacities with a
  requestAnimationFrame loop and compare.

## Gotchas

- Bun's hot reload re-imports `with { type: "text" }` markdown wrongly after
  a `.md` changes, so the review server runs with `hmr: false`. Refresh the
  page instead.
- Fractional space tokens are `--amb-space-1_5` / `--amb-space-0_5` in CSS
  (underscore). An unknown `var()` silently breaks the property.
- Count tokens (like `columns`) are emitted without `px`.
- A blurred backdrop isn't clipped by a parent's rounded corners, so the
  surface must round itself. The same applies to KWin blur regions.
- Bun's CSS bundler can reorder `<link>`ed stylesheets, so the site
  `@import`s `preview/glass.css` to keep the cascade order.
