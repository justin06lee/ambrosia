# ambrosia — Preview Desktop

One layer of ambrosia's stack, owning `preview/, assets/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer preview` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer preview add|set|drop <section> …`. Where it and the code disagree, the code is right.

Preview Desktop is a static HTML/JS mock macOS-like desktop for visually reviewing generated tokens. It renders draggable/focusable windows, menubar popups, sliders, control center, dock, and a live clock with no build step beyond `make build`. Every color, type, radius, shadow, and motion value comes from dist/web/tokens.css; preview.css holds only mock-desktop layout positions, and the menubar/README/favicon use the Ambrosia bowl logo while assets/ also holds the hand-drawn Files app icon.

## Where to change what

- **Mock desktop shell (wallpaper, menubar, dock, windows):** preview/index.html, preview/preview.css, preview/preview.js
- **Control center (capsule modules, toggles, sliders, Edit Controls):** preview/index.html, preview/preview.js, preview/preview.css
- **Dock (padding, glassy icons, tooltip, badges, separators):** preview/index.html, preview/preview.js, preview/preview.css
- **Glass material recipe:** preview/glass.css, preview/preview.css
- **Theme and accent switching (D / A keys, URL params):** preview/preview.js, preview/index.html
- **Draggable and focusable windows:** preview/preview.js, preview/preview.css
- **Menubar popups / menus:** preview/preview.js, preview/index.html
- **Live clock:** preview/preview.js, preview/index.html
- **App-icon squircle mask:** preview/preview.js, preview/index.html
- **Ambrosia bowl branding (menubar logo, favicon):** assets/ambrosia.svg, assets/icon.svg, preview/index.html, preview/preview.css
- **Files app icon (Finder-style two-tone face, Dock Files pin):** assets/icons/org.ambrosia.files.svg

## How it works

- **View updated tokens:** Run make build to regenerate dist/web/tokens.css → Open preview/index.html which links tokens.css + glass.css + preview.css → preview.js reads ?theme= / ?accent= params and prefers-color-scheme → Toggle with D (dark mode) and A (accent cycle) to review
- **Window interaction:** Click window to focus (preview.js manages z-order / active class) → Drag via titlebar to reposition (layout literals in preview.css) → Open menubar popups / sliders to check glass and controls

## Key files

- preview/index.html — mock desktop markup, SVG icon sprite, stylesheet links (requires dist/web/tokens.css)
- preview/preview.js — theme/accent switching, popups, draggable windows, sliders, clock, squircle mask
- preview/preview.css — mock-desktop layout; all design values via var(--amb-*) / var(--glass-*)
- preview/glass.css — shared glass recipe (tint, blur, rim, edge, specular ring, grain)
- assets/ambrosia.svg — bowl-with-scoops-and-spoon brand mark used in menubar and preview
- assets/icon.svg — app/favicon form of the bowl mark
- assets/icons/org.ambrosia.files.svg — hand-drawn Files app icon on a blue squircle, matched to the macOS Dock grid

## Rules and traps

- Never hardcode design values in preview/*.css — use vars from dist/web/tokens.css; only layout positions may be literals.
- Run `make build` first — preview is broken/stale without generated dist/web/tokens.css.
- Do not add build tooling or JS dependencies — static HTML/JS only.
- Keep glass.css shared-safe — it is also used by the review site, so no preview-specific layout in it.
- Round inner panels (e.g. sidebar) to their own outer corners — scaled-down blur is cut to the window shape only if the panel itself is rounded, otherwise corners render sharp/square.
- Keep file selection highlight behind the icon — replacing the document page fill with selection color turns clicked icons black.
- Draw app icons by hand as our own vectors; never trace Apple's artwork, and keep reference screenshots of macOS only in the gitignored out/ folder.

## What it talks to

- Design Tokens via dist/web/tokens.css — sole source of colors, type, radii, shadows, springs; preview breaks without a build
- Build and Install — `make build` generates dist/web/tokens.css that preview links
- Shell Dock and Packaging — the Files icon in assets/icons/org.ambrosia.files.svg is the Dock's Files pin and is installed by the package build
