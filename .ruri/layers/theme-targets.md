# ambrosia — Theme Targets

One layer of ambrosia's stack, owning `tools/gen/targets/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer theme-targets` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer theme-targets add|set|drop <section> …`. Where it and the code disagree, the code is right.

This layer turns the resolved theme model (Resolved/ResolvedMode from Generator Core) into per-toolkit output files. Each file in tools/gen/targets/ is a pure formatter: roles/colors plus shared helpers. Newcomers must grasp that nothing is resolved here — token truth and color math live upstream; targets only map and serialize.

## Where to change what

- **GTK theme overrides:** tools/gen/targets/gtk.ts, tools/gen/targets/shared.ts
- **KDE color schemes:** tools/gen/targets/kde.ts, tools/gen/targets/shared.ts
- **QML singleton for shell:** tools/gen/targets/qml.ts, tools/gen/targets/shared.ts
- **Web CSS custom properties:** tools/gen/targets/web.ts, tools/gen/targets/shared.ts
- **Fontconfig aliases and rasterization:** tools/gen/targets/fontconfig.ts, tools/gen/targets/shared.ts
- **Shared formatting helpers:** tools/gen/targets/shared.ts
- **Session kdeglobals (light scheme + type-scale fonts as QFont strings):** tools/gen/targets/kde.ts
- **KWin window decoration (Aurorae SVG theme: traffic lights, titlebar, window shadow):** tools/gen/targets/aurorae.ts

## How it works

- **Resolved model to toolkit file:** Generator Core produces Resolved / ResolvedMode → Target maps roles to toolkit vocabulary (libadwaita vars, KDE sets, QML tree, CSS vars) → Colors serialized via color helpers (toCss, toKde, toQtHex) and shared helpers (HEADER, pt, fontStack, kebab/slug) → Formatter returns file string for dist orchestration to write

## Key files

- tools/gen/targets/shared.ts — shared header, kebab/slug, fontStack, cssShadow, pt helpers
- tools/gen/targets/gtk.ts — libadwaita CSS vars (gtk4) and named colors per mode (gtk3)
- tools/gen/targets/kde.ts — opaque .colors sets, translucency flattened onto background
- tools/gen/targets/qml.ts — Ambrosia QML singleton tree with Theme.dark / Theme.accentName switching
- tools/gen/targets/web.ts — --amb-* CSS custom properties for preview/web surfaces
- tools/gen/targets/fontconfig.ts — sans-serif/monospace aliases and rasterization defaults
- tools/gen/targets/aurorae.ts — Aurorae theme per mode: rc layout, nine-slice decoration.svg painted as PNGs (window color, rim, edge, box-shadows), vector button SVGs

## Rules and traps

- Do not edit generated output; every file carries HEADER pointing back to design/tokens.ts via tools/gen.
- Do not resolve or derive colors here — use the passed Resolved model and color.ts / resolve.ts helpers.
- KDE output must stay opaque r,g,b: flatten translucent values with flat() onto their background set.
- GTK3 has no prefers-color-scheme: emit one file per mode; GTK4 emits light and dark in one file.
- Keep QML identifiers safe: slug token keys and prefix leading digits.
- QML property names can't be ECMAScript keywords; qml.ts suffixes them with _ (Theme.size.switch_), guarded by a test in tools/gen/rules.test.ts.
- Aurorae makes KWin's window shadow from what decoration.svg paints in its Padding*, slicing it at the pieces' own sizes; KSvg only takes a prefix whose -center element exists, so each button state has both 'x' and 'x-center'. The frame is 1x PNG (soft on HiDPI).

## What it talks to

- Design Tokens — reads type, color, font, shadow token definitions as input vocabulary
- Generator Core — consumes Resolved/ResolvedMode and color/spring serializers (toCss, toKde, toQtHex, toCssLinear, flat)
- Build and Install — dist orchestration writes formatter output to dist/ for install
