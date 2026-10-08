# ambrosia — Design Tokens

One layer of ambrosia's stack, owning `design/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer design-tokens` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer design-tokens add|set|drop <section> …`. Where it and the code disagree, the code is right.

Single-file source of truth for ambrosia's look and motion, exporting type scale, 4px spacing, radii, OKLCH colors, glass/materials, shadows, and springs. All dist themes are generated from it via tools/gen, so this file is edited instead of generated output. Newcomer must grasp: colors are OKLCH strings for perceptually even lightness and everything is light/dark Mode pairs.

## Where to change what

- **Type scale and fonts:** design/tokens.ts
- **Spacing grid (4px):** design/tokens.ts
- **Radii and icon corners:** design/tokens.ts
- **Light/dark color pairs:** design/tokens.ts
- **Palette and accents:** design/tokens.ts
- **Status and window-control colors:** design/tokens.ts
- **Glass and materials:** design/tokens.ts, design/DESIGN.md
- **Shadows:** design/tokens.ts
- **Springs and motion:** design/tokens.ts, design/DESIGN.md
- **Control center module metrics:** design/tokens.ts, design/DESIGN.md
- **Dock metrics:** design/tokens.ts

## Key files

- design/tokens.ts — the single source of truth: font/type/tracking, space, radius, OKLCH color pairs, glass, shadow, springs
- design/DESIGN.md — reasoning behind the numbers before retuning values

## Rules and traps

- Never hand-edit generated output in dist/; change design/tokens.ts and regenerate.
- Keep colors as OKLCH strings (oklch(L C H) or with / A) so generator can convert and gamut-map to sRGB.
- Provide both light and dark values via Mode/Pair for mode-dependent tokens.
- See DESIGN.md for reasoning behind the numbers before retuning values.
- Menus snap open instantly with no open animation (close fades 120ms); control-center panel is blur-only with no fill, border, or shadow, controls carry their own glass.

## What it talks to

- Generator Core — resolves design/tokens.ts: OKLCH to sRGB, contrast, springs, dist orchestration
- Theme Targets — format the resolved model into GTK, KDE, QML, fontconfig, web output
- Preview Desktop — styled only from generated dist/web/tokens.css, never this file directly
