# ambrosia design spec

This is the design authority for ambrosia. When the shell, a theme, or an app
disagrees with this document, the other thing is wrong. Every number here lives
in [`tokens.ts`](tokens.ts); this file explains why the numbers are what they
are. Change a value in `tokens.ts`, never in generated output.

## Principles

1. **Content first, chrome recedes.** Window chrome, bars, and panels are glass
   that takes its color from whatever sits behind it. Nothing in the chrome
   competes with the document.
2. **One of everything.** One UI typeface, one icon style, one corner shape,
   one motion language. A second way of doing something is a bug, not a variant.
3. **Concentric.** Shapes nest. An inner radius is the outer radius minus the
   inset between them, so curves stay parallel.
4. **Physical motion.** Everything that moves is a spring. Animations can be
   interrupted and retargeted mid-flight; nothing teleports and nothing moves
   linearly.
5. **Quiet surfaces.** No gradients on controls, no heavy borders. Elevation is
   shown by shadow and material, separation by hairlines and space.
6. **On the grid.** Every size and gap is a multiple of 4 (2 for hairline-scale
   detail). If a number is not in the tokens, it should not be in the UI.

## Typography

- **UI face: Inter** (variable, with optical sizing so large text uses Inter
  Display's tighter shapes). **Mono: JetBrains Mono.** Both are open-licensed
  and packaged on Arch (`inter-font`, `ttf-jetbrains-mono`).
- Tracking follows Inter's dynamic-metrics curve
  (`-0.0223 + 0.185·e^(-0.1745·size)` em): slightly open at 10–11px, slightly
  tight above 15px. Generated themes apply it wherever the toolkit allows.
- Numbers that change in place (clock, battery, progress) use tabular figures.

| Style | Size / line | Weight | Used for |
|---|---|---|---|
| largeTitle | 26 / 32 | 700 | Onboarding, empty states |
| title1 | 22 / 28 | 700 | Settings page titles |
| title2 | 17 / 22 | 600 | Section titles, dialogs |
| title3 | 15 / 20 | 600 | Group headings |
| headline | 13 / 16 | 600 | Window titles, emphasized rows |
| body | 13 / 16 | 400 | Everything by default |
| callout | 12 / 15 | 400 | Secondary text in rows |
| caption | 11 / 14 | 400 | Sidebar section labels, metadata |
| footnote | 10 / 13 | 500 | Badges, fine print |

Sizes are logical pixels. GTK and KDE take points, so the generator converts
(`pt = px × 0.75`).

**Rendering** (shipped as a fontconfig fragment): grayscale antialiasing, slight
hinting, no LCD filter, embedded bitmaps off, and FreeType stem darkening on.
Stem darkening is the main reason Mac text looks fuller than Linux text at the
same size. Qt's synthetic bold is off in the session: it would thicken Inter
Variable's real Bold again, as the variable file reports a Regular weight.

## Space

A 4px grid: `2 4 6 8 12 16 20 24 32 40 48 64`. Tokens are named by step
(`space["1"] = 4`, `space["4"] = 16`). Default rhythm is 8 between related
items, 16 between groups, 24 around page content.

## Shape

| Surface | Radius | Note |
|---|---|---|
| Window, sheet | 16 | |
| Control center modules | 30 | capsules: half the 60px unit |
| Control center blur region | 44 | module 30 + padding 14 |
| Shell panels (notifications, launcher) | 22 | |
| Panel tiles, cards | 12 | panel 22 − padding 10 |
| Menus, popovers | 12 | |
| Menu items, list selection, sidebar rows | 6 | popover 12 − padding 6 |
| Controls (buttons, fields) | 8 | small controls 6 |
| Tooltips | 8 | |
| Dock | 28 | icon corner 12 + padding 16 |
| App icons | 22.5% of size | continuous-curvature superellipse, never a plain rounded rect |

The concentric rule is `inner = max(outer − inset, 4)`. The floor keeps small
things from turning into sharp-cornered boxes.

## Color

Colors are authored in OKLCH, so lightness steps look even and hues keep their
character between light and dark. Neutrals carry a faint warm tint (hue 85,
chroma ≈ 0.004). That reads as paper rather than steel and is the quietest part
of the ambrosia identity.

**Backgrounds:** `window` (behind toolbars and sidebars), `content` (documents,
lists, text), `sidebar` and `elevated` (opaque fallbacks for when blur is
unavailable), and `control` (button faces).

**Labels and fills are translucent ink**, not fixed grays (`label.primary` is
88% ink, then 52%, 28%, 12%), so they sit correctly on any material or tint.
Toolkits that need opaque colors (KDE color schemes) get them flattened against
the right background by the generator.

**Accent.** Users pick one of eight: blue (default), purple, pink, red, orange,
honey, green, graphite. Honey is the house color. From each accent the
generator derives:

- `bg`: fills for primary buttons, switches, and the focused selection.
- `fg`: text on `bg`. White if it reaches 3:1 against `bg`, otherwise dark ink.
- `text`: the accent used as text or links, darkened or lightened until it
  reaches 4.5:1 on `content`.
- `hover`, `pressed`, and `highlight` (text selection, accent at 28%).

Unfocused selections drop to `fill.primary`. The accent only shows where
attention actually is.

**System palette:** red, orange, yellow, green, mint, teal, cyan, blue, indigo,
purple, pink, brown, gray, with tuned light and dark values. Status roles map
onto it: destructive and error → red, warning → orange, success → green.

## Materials

Glass is the signature of the system, so it has rules:

| Material | Blur | Saturate | Tint (light / dark) | Used for |
|---|---|---|---|---|
| thin | 20 | 1.6 | 38% / 38% | Menu bar, OSDs (volume, brightness), control center modules |
| regular | 28 | 1.8 | 55% / 50% | Dock, sidebars, notifications |
| thick | 36 | 1.8 | 72% / 68% | Menus, popovers, launcher, anything with dense text |
| clear | 4 | 1.2 | 12% / 14% | Controls that float over glass or media |
| backdrop | 10 | 1.0 | none | Control center: blur only, the modules carry the glass |

Every glass surface also gets:

- A **rim**: a 1px inner highlight along the top edge (white at 65% light, 16%
  dark). It reads as the lit edge of a pane.
- An **edge**: a 0.5px outside hairline that separates glass from a similar
  background.
- **Noise**: about 2% grain, to stop banding in the blur.

**Refraction** (compositor shader only): within 14px of a glass edge, the
background is displaced outward with strength 0.55 and very slight dispersion
(0.015), and a specular highlight is lit from −45°. Shell surfaces get the full
effect. App windows get blur and tint only.

**Fallbacks:** with blur unavailable (software rendering, Reduce Transparency
on), every material becomes its opaque `bg.sidebar` or `bg.elevated` color.
Legibility never depends on the blur.

## Elevation

Shadows are warm (shadow ink is hue 60) and layered: one wide, soft ambient
layer plus one tight contact layer. Dark mode shadows are much stronger,
because they have to be visible against dark wallpapers.

- **window**: active windows float; inactive windows settle (smaller, lighter shadow).
- **popover**: menus and popovers.
- **dock / panel**: shell surfaces.
- **control**: a hairline contact shadow under raised buttons.

## Motion

Everything that moves is a spring, defined by `response` (seconds, roughly the
time to settle) and `damping` (1 = no overshoot):

| Spring | Response | Damping | Used for |
|---|---|---|---|
| snappy | 0.24 | 0.92 | Controls, toggles, menus opening, hover states |
| smooth | 0.38 | 1.00 | Windows opening/closing, panels, layout changes |
| bouncy | 0.45 | 0.72 | Dock feedback, playful moments, sparingly |
| gesture | 0.32 | 0.86 | Settling after a 1:1 gesture is released (velocity carries in) |

Physics: mass 1, stiffness `(2π / response)²`, damping coefficient
`4π·damping / response`. The generator also emits a sampled CSS `linear()`
curve and a settle duration for toolkits without spring support.

Rules:

- **Exits are quicker than entrances**: use 0.7 × the entrance response.
- **Opacity-only changes** use fades (120 / 200 / 320 ms, decelerating), not springs.
- **Menus snap.** Menus, context menus and submenus appear instantly, with no
  entrance animation, and fade out over 120 ms when dismissed. Anything opened
  with a click or a key to be read and acted on at once should be there
  immediately. Panels fade in place instead.
- **Gestures are 1:1.** While a finger is down, the UI follows it exactly.
  On release, the `gesture` spring takes over from the current velocity.
- **Interruptible.** A new target retargets the running spring. Never queue an
  animation behind another one.
- **Reduce Motion** replaces movement and scaling with a 200 ms crossfade.

## Input

- Scrolling uses momentum with a deceleration rate of 0.998 per ms.
- Edges rubber-band with `offset = (1 − 1 / (x·0.55 / d + 1)) · d`, where `x`
  is how far past the edge and `d` is the viewport size.
- Tooltips appear after 600 ms. Once one is showing, the next appears immediately.
- Minimum hit target: 24 × 24.

## Keyboard

Onboarding offers two layouts, Mac-first (the default) and Linux-first.

**Mac-first** makes the hands work the way they do on a Mac in every app. A
system-wide remapping layer (keyd) translates shortcuts into what each app
expects:

| Key | Acts as | Glyph |
|---|---|---|
| Super | Command | ⌘ |
| Alt | Option | ⌥ |
| Ctrl | Control | ⌃ |
| Shift | Shift | ⇧ |

- **Editing:** ⌘C ⌘V ⌘X ⌘Z ⇧⌘Z ⌘A ⌘S ⌘F behave as on a Mac. ⌥←/→ moves by
  word, ⌘←/→ to the start or end of the line, ⌘↑/↓ to the start or end of the
  document. ⌥⌫ deletes a word and ⌘⌫ deletes to the line start.
- **Windows and apps:** ⌘W closes, ⌘Q quits, ⌘N opens a new window, ⌘T a new
  tab, ⌘M minimizes, ⌘H hides, ⌃⌘F toggles full screen, and ⌘, opens settings.
- **System:** ⌘Space opens the launcher, ⌘Tab switches apps, and ⌘` cycles an
  app's windows.
- **Terminals:** ⌘C and ⌘V become Ctrl+Shift+C and Ctrl+Shift+V, so Ctrl
  passes straight through to the shell.

Menus show shortcuts as glyphs in the fixed order ⌃ ⌥ ⇧ ⌘, then the key
(`⌃⌘F`), in `label.tertiary`.

**Linux-first** applies no remapping. Menus show shortcuts as `Ctrl+Shift+K`.

## Shell anatomy

The exact metrics live in `size`, `radius` and `choreography` in tokens.ts,
and the preview is the visual reference. In brief:

- **Menu bar:** 28 tall, `thin` glass across the full width. Highlights are
  capsules, and the clock uses tabular figures.
- **Dock:** roomy (16px around and between 52px icons), `regular` glass ringed
  in light. Icons are superellipses with a glassy rim. Hovering lifts an icon,
  and one tooltip follows the pointer. Magnification is opt-in.
- **Control center:** no panel. Capsule modules of `thin` glass on a 4-column
  grid float on a light, untinted blur with soft rounded edges. Toggles that
  are on are solid circles. It fades in place (blur first, then the modules)
  rather than springing.
- **Windows:** three 12px controls on the left, with glyphs on hover and gray
  when inactive. The title bar is 40 tall, or 52 with a toolbar.
- **Sidebar:** 220 wide, flush to the window edge, behind-window glass that
  rounds its own outer corners (a parent's rounded corners don't reliably clip
  a blurred backdrop). It goes opaque when its window is inactive.
- **Controls:** 22 / 28 / 36 tall. The focus ring is 3px of accent at 50%.
  Scrollbars overlay the content and hide when idle.

## Iconography

- **Symbolic icons:** 16/20/24 grids, 1.5px rounded strokes, rounded caps and
  joins, filled only to show state (a selected or active variant). Stroke
  weight follows the text weight next to it.
- **App icons:** the 22.5% superellipse on a 1024 grid with a 100px margin, one
  light source from above. A soft gradient is allowed on app icons only. No
  photorealism.

## Voice

Sentence case everywhere ("Show hidden files", not "Show Hidden Files").
Buttons name the action ("Delete", not "OK"). Errors say what happened and
what to do next. Settings are worded as statements, not questions.
