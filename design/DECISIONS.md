# Decisions

The choices that shaped ambrosia, with their reasoning, so any of them can be
revisited on purpose rather than by drift. Each has a status: **accepted**
(settled, change only with a good reason), **proposed** (my recommendation,
waiting on review), or **open** (needs a call).

## One source of truth for design

Status: accepted

Every visual value lives in `design/tokens.ts`. A generator writes each
toolkit's theme from it, and generated themes are never edited by hand.

**Why:** Linux looks inconsistent because each toolkit's theme is maintained
separately and drifts. Generated from one file, a color or radius can't
disagree between GTK, Qt and the shell.

**Instead of:** hand-maintained themes per toolkit, which is how existing
macOS-style themes work and why they drift.

## Arch, KWin and Quickshell, with Qt as the native toolkit

Status: accepted

Arch as the base, KWin on Wayland as the compositor, the shell written in QML
with Quickshell, and Qt treated as the first-class toolkit.

**Why:** Qt is the only toolkit that can be restyled all the way down (a
QStyle or a QML controls style). KWin already has region blur, a global menu,
layer-shell and a custom effects API, so glass and window animations don't
need a compositor written from scratch.

**Instead of:** Hyprland (tiling-first, weaker for floating windows), GNOME
(libadwaita resists theming by design), or a new compositor on Smithay (full
control, but years of work).

## Inspired by macOS, not a copy of it

Status: accepted

The layout conventions carry over: a menu bar, a dock, window controls on the
left, and glass. The assets are all original: fonts, icons and wallpapers.

**Why:** Apple's fonts, symbols, icons and wallpapers are licensed for Apple
platforms only, so shipping them invites a takedown. A pixel-perfect clone also
reads as cheap the moment anything is slightly off.

## Behind-window glass for sidebars

Status: accepted

Sidebars sit flush against the window edge and blur what's behind the window.
They don't float over the app's own content the way macOS 26 sidebars do.

**Why:** behind-window glass only needs the app to mark a region translucent;
the compositor does the blur (KWin's blur protocol takes a region). That works
for every toolkit. A floating sidebar refracting in-window content needs
in-app blur, which GTK and most toolkits can't do.

## Inter and JetBrains Mono

Status: proposed

Inter (variable, with optical sizes) for the interface and JetBrains Mono for
code. FreeType stem darkening is on, so text renders fuller.

**Why:** Inter is the closest open typeface to the system faces it replaces,
has optical sizing for large text, and is packaged on Arch. Stem darkening is
most of the difference between Mac and Linux text weight.

**Instead of:** Geist (lovely, but less neutral at small sizes), IBM Plex Sans
(more character than a system font should have).

## Warm neutrals

Status: proposed

Every gray carries a faint warm tint (OKLCH hue 85, chroma about 0.004).

**Why:** it reads as paper rather than steel, and it's the quietest place to
give ambrosia its own identity without anything looking off-brand.

## Translucent labels and fills

Status: accepted

Text and fill colors are ink at an opacity (88%, 52%, 28%, 12%), not fixed
grays.

**Why:** they then sit correctly on any material or tint, glass included. For
toolkits that need opaque colors, the generator flattens them against the right
background.

## Blue by default, honey as the house color

Status: proposed

Blue is the default accent. Honey is one of the eight choices and is the brand
color for the logo, wallpapers and marketing.

**Why:** blue carries white text and reads as "interactive" everywhere. A honey
default would need dark text on buttons and would make every selection feel
like a warning.

## Springs for everything that moves

Status: accepted

Motion uses four springs (snappy, smooth, bouncy, gesture) defined by response
and damping. Exits run at 0.7 × the response. Fades are used only for opacity.

**Why:** springs can be interrupted and carry velocity, which is most of what
makes macOS feel smooth. Fixed-duration easing restarts awkwardly when
interrupted.

## Window controls on the left, as colored circles

Status: proposed

Close, minimize and zoom are three 12px circles in red, yellow and green on the
left. Glyphs appear on hover, and inactive windows show them gray.

**Why:** it's the single strongest signal of the macOS layout people expect,
and colored circles are a common convention rather than an Apple asset.

## Shortcut modifier: Ctrl or Super

Status: open

The preview shows Ctrl, which is what Linux apps use. Making Super act like
Command (Super+C copies everywhere) would feel like a Mac, but it needs a
system-wide key-remapping layer such as keyd, and it changes every app's
documentation.

## How far refraction goes

Status: open

Shell surfaces (dock, panels, menu bar) get the full Liquid Glass refraction
shader. App windows get blur and tint only. The question is whether toolbars
inside apps should opt in too.

## Dock magnification

Status: open

Off by default, as specified. Possible options: always off, opt-in, or on with
a subtle 1.3× maximum.

## Hardware to develop on

Status: open

Smoothness and glass can't be judged in a VM, so the shell work needs real
hardware: a PC laptop with a good trackpad, or an M1/M2 Mac running Asahi
Linux.
