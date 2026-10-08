# ambrosia — Generator Core

One layer of ambrosia's stack, owning `tools/gen/index.ts, tools/gen/resolve.ts, tools/gen/color.ts, tools/gen/spring.ts`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer generator-core` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer generator-core add|set|drop <section> …`. Where it and the code disagree, the code is right.

Generator Core resolves design/tokens.ts into a concrete sRGB + solved-spring model that every target formats. It is built as Bun+TypeScript: color math, spring solver, a per-mode resolver, and a dist orchestrator. A newcomer must grasp that targets never read tokens directly — resolve() is the single agreement point for derived colors and motion.

## Where to change what

- **Token resolution (per-mode model):** tools/gen/resolve.ts, tools/gen/index.ts
- **OKLCH to sRGB conversion with gamut mapping:** tools/gen/color.ts, tools/gen/resolve.ts
- **Contrast derivation and label flattening:** tools/gen/color.ts, tools/gen/resolve.ts
- **Accent derivation (bg/fg/text/hover/pressed/highlight):** tools/gen/resolve.ts, tools/gen/color.ts
- **Spring solving (response/damping to constants/curve):** tools/gen/spring.ts, tools/gen/resolve.ts
- **Dist orchestration (generate all targets):** tools/gen/index.ts, tools/gen/resolve.ts

## How it works

- **Generate dist from tokens:** tools/gen/index.ts calls resolve() → resolve.ts parses OKLCH via color.ts and solves springs via spring.ts → index.ts passes Resolved model to each formatter in tools/gen/targets/ → Formatted strings written to dist/ paths (web, gtk, kde, qml, fontconfig) plus resolved dump
- **Derive a concrete color:** parseOklch() parses oklch() string → toLinear + gamut-mapped conversion to RGBA in color.ts → over()/withAlpha() composite translucency → contrast()/ensureContrast() enforce readability for accents and labels

## Key files

- tools/gen/resolve.ts — resolves tokens.ts into per-mode Resolved colors, accents, material, glass, shadows and springs
- tools/gen/index.ts — orchestrates generation: resolves once, formats every target, writes dist/
- tools/gen/color.ts — OKLCH parsing, OKLCH to sRGB with gamut mapping, compositing, contrast, and output formatters
- tools/gen/spring.ts — solves (response, damping) springs into stiffness/damping, settle duration, and sampled curve

## Rules and traps

- Never read design/tokens.ts directly from a target for colors — go through resolve() so derived accents and flattened labels agree everywhere.
- Never bypass color.ts gamut mapping and contrast helpers with ad-hoc conversion — out-of-gamut OKLCH and unreadable text result.
- Keep Resolved/ResolvedMode/ResolvedAccent shapes stable — every formatter in tools/gen/targets/ depends on them.

## What it talks to

- Design Tokens — sole input: reads design/tokens.ts types and values, never the reverse
- Theme Targets — sole consumer: every formatter takes the Resolved model from resolve()
- Build and Install — runs the generator to produce dist/ before install and test
