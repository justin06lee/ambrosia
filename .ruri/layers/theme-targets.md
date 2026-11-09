# ambrosia — Theme Targets

One layer of ambrosia's stack, owning `tools/gen/targets/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer theme-targets` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer theme-targets add|set|drop <section> …`. Where it and the code disagree, the code is right.

This layer turns the resolved theme model (Resolved/ResolvedMode from Generator Core) into per-toolkit output files. Each file in tools/gen/targets/ is a pure formatter: roles/colors plus shared helpers. Newcomers must grasp that nothing is resolved here; token truth and color math live upstream, and targets only map and serialize.

## Where to change what

- **GTK theme overrides:** tools/gen/targets/gtk.ts, tools/gen/targets/shared.ts
- **Traffic lights (window buttons) across KWin, GTK and QML:** tools/gen/targets/shared.ts, tools/gen/targets/kdecoration.ts, tools/gen/targets/gtk.ts, tools/gen/targets/qml.ts
- **KDE color schemes:** tools/gen/targets/kde.ts, tools/gen/targets/shared.ts
- **QML singleton for shell:** tools/gen/targets/qml.ts, tools/gen/targets/shared.ts
- **Web CSS custom properties:** tools/gen/targets/web.ts, tools/gen/targets/shared.ts
- **Fontconfig aliases and rasterization:** tools/gen/targets/fontconfig.ts, tools/gen/targets/shared.ts
- **Shared formatting helpers:** tools/gen/targets/shared.ts
- **Session kdeglobals (light scheme + type-scale fonts as QFont strings):** tools/gen/targets/kde.ts
- **KWin window frame's tokens (titlebar, lights, corner, rim, edge, shadow) as a C++ header for decoration/:** tools/gen/targets/kdecoration.ts

## How it works

- **Resolved model to toolkit file:** Generator Core produces Resolved / ResolvedMode → Target maps roles to toolkit vocabulary (libadwaita vars, KDE sets, QML tree, CSS vars) → Colors serialized via color helpers (toCss, toKde, toQtHex) and shared helpers (HEADER, pt, fontStack, kebab/slug) → Formatter returns file string for dist orchestration to write

## Key files

- tools/gen/targets/shared.ts — shared header, kebab/slug, fontStack, cssShadow, pt helpers, and the window-button symbol shapes
- tools/gen/targets/gtk.ts — libadwaita CSS vars (gtk4), named colors per mode (gtk3), and GTK's traffic-light sizing and edge
- tools/gen/targets/kde.ts — opaque .colors sets, translucency flattened onto background
- tools/gen/targets/qml.ts — Ambrosia QML singleton tree with Theme.dark / Theme.accentName switching
- tools/gen/targets/web.ts — --amb-* CSS custom properties for preview/web surfaces
- tools/gen/targets/fontconfig.ts — sans-serif/monospace aliases, rasterization defaults, and the session's font environment (FreeType stem darkening, QT_NO_SYNTHESIZED_BOLD)
- tools/gen/targets/kdecoration.ts — dist/kdecoration/tokens.h: the frame's sizes, per-mode colors, window-button shapes, light edge and shadow layers for the decoration plugin

## Rules and traps

- Do not edit generated output; every file carries HEADER pointing back to design/tokens.ts via tools/gen.
- Do not resolve or derive colors here; use the passed Resolved model and color.ts / resolve.ts helpers.
- KDE output must stay opaque r,g,b: flatten translucent values with flat() onto their background set.
- GTK3 has no prefers-color-scheme: emit one file per mode; GTK4 emits light and dark in one file.
- Keep QML identifiers safe: slug token keys and prefix leading digits.
- QML property names can't be ECMAScript keywords; qml.ts suffixes them with _ (Theme.size.switch_), guarded by a test in tools/gen/rules.test.ts.
- Window-control colors are per mode (resolved modes[m].windowControls, with inactive = fill.primary on the window); QML exposes them as Theme.windowControls, which follows Theme.dark.
- Window-button symbol shapes (×, −, zoom) are defined once in shared.ts; KWin, GTK and QML draw from that definition, so change them there, not per toolkit.
- Traffic lights must measure the same in every toolkit: 14 pt wide, 23 pt apart, symbols 50% black; a change to one toolkit's sizing needs the others checked against it.
- Traffic-light colours are the same in light and dark mode, as on macOS; do not give light mode its own set.
- The traffic-light edge is a thin darker shade of each light's own colour, not a grey ring; the KWin frame and GTK draw it that way.
- GTK lights move to the left only in sessions started after that setting shipped; a running session keeps the old placement, so check on a fresh login.
- Qt fakes bold for weight ≥700 when the face's OS/2 weight class is under 700. Variable fonts report their default instance (Inter Variable says 400), so their real Bold gets thickened again. fontEnvironment() sets QT_NO_SYNTHESIZED_BOLD=1, which startambrosia sources at login. fontconfig's embolden doesn't reach Qt.

## What it talks to

- Design Tokens — reads type, color, font, shadow token definitions as input vocabulary
- Generator Core — consumes Resolved/ResolvedMode and color/spring serializers (toCss, toKde, toQtHex, toCssLinear, flat)
- Build and Install — dist orchestration writes formatter output to dist/ for install
