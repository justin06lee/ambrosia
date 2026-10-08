# Decisions

The choices that shaped ambrosia, with their reasoning, so any of them can be
revisited on purpose rather than by drift. Each has a status: **accepted**
(settled, change only with a good reason), **proposed** (my recommendation,
waiting on review), or **open** (needs a call). A decision renamed after review
keeps an `Id:` line, so its review thread stays attached.

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

Status: accepted

Inter (variable, with optical sizes) for the interface and JetBrains Mono for
code. FreeType stem darkening is on, so text renders fuller.

**Why:** Inter is the closest open typeface to the system faces it replaces,
has optical sizing for large text, and is packaged on Arch. Stem darkening is
most of the difference between Mac and Linux text weight.

**Instead of:** Geist (lovely, but less neutral at small sizes), IBM Plex Sans
(more character than a system font should have).

## Warm neutrals

Status: accepted

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

Status: accepted

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

Status: accepted

Close, minimize and zoom are three 12px circles in red, yellow and green on the
left. Glyphs appear on hover, and inactive windows show them gray.

**Why:** it's the single strongest signal of the macOS layout people expect,
and colored circles are a common convention rather than an Apple asset.

## Mac-first keyboard, chosen at onboarding

Status: accepted
Id: shortcut-modifier-ctrl-or-super

Onboarding asks one question: **Mac-first** or **Linux-first**. Mac-first is
the default. Moving from a Mac to ambrosia should feel the same in the hands,
in every app, not only in ambrosia's own.

- **Mac-first:** Super is Command. A system-wide remapping layer (keyd) turns
  Super shortcuts into what each app expects. Super+C copies and Super+Q quits
  in any app, and in terminals Super+C becomes Ctrl+Shift+C, so Ctrl stays free
  for the shell. Super+Space opens the launcher, Super+Tab switches apps,
  Option (Alt) and Super with the arrow keys move by word and by line, and
  menus show ⌘ ⌥ ⌃ ⇧ glyphs.
- **Linux-first:** no remapping. Ctrl shortcuts as every Linux app documents
  them, with menus showing Ctrl+ and Alt+.

The choice can be changed later in Settings.

**Why:** most of what makes a Mac feel like a Mac is in the hands. Choosing at
onboarding serves both kinds of user, and the remapping layer means it works in
apps ambrosia doesn't control.

## Refraction on shell surfaces only, for now

Status: accepted
Id: how-far-refraction-goes

Shell surfaces (dock, panels, menu bar) get the full refraction shader. App
windows get blur and tint only.

**Why:** an app toolbar can only refract if the app tells the compositor where
the toolbar is, and only ambrosia's own apps would do that. A mixed desktop
would look inconsistent. Revisit once the first-party apps exist.

## Dock magnification is opt-in

Status: accepted
Id: dock-magnification

Off by default and available in Settings. Hovering lifts an icon instead.

**Why:** magnification looks great in demos, but it moves targets while the
pointer is moving toward them. The hover lift gives the same sense of life
without that.

## Develop on tenet, with a Magic Trackpad

Status: accepted
Id: hardware-to-develop-on

The shell is built and judged on **tenet**, the Arch desktop on the makima
mesh: an i7-10700 with 16 GB of RAM and a GTX 1660 Ti on the open NVIDIA driver
(615, kernel modesetting on), driving a 4K display. An Apple Magic Trackpad
adds real gestures. It works on Linux over USB-C or Bluetooth, and libinput
handles its multitouch.

**Why:** smoothness and glass can't be judged in a VM, and there's no spare
laptop. A desktop GPU on the open driver is a good KWin Wayland setup, and the
4K screen runs at 2× scale, which is the case that matters most.

**Later:** the Jetson Orin Nano (ARM64, NVIDIA Tegra) is a separate effort with
its own boot and driver story. It's on the roadmap but not scheduled.

## Ship as an installer image from the start

Status: accepted
Id: ship-as-an-image

Everything ships as Arch packages (`ambrosia-theme`, `ambrosia-shell`,
`ambrosia-desktop`) and an archiso image that boots a live Ambrosia desktop and
installs it. tenet runs the same packages the image installs; nothing is set up
on it by hand.

**Why:** the goal is an image anyone can flash onto a computer. Building
through packages from the first day keeps every piece installable, and testing
on tenet tests the distro.

**Instead of:** configuring one machine first and packaging at the end, which
hides everything a fresh install needs until the end.

## Plasma's session services, Ambrosia's shell

Status: proposed
Id: session-on-plasma-services

The Ambrosia session starts Plasma's session (KWin, kded, portals, the polkit
agent, power management, display configuration, global shortcuts) and swaps
plasmashell for the Ambrosia shell. Session defaults (fonts, colors, window
buttons) come in through `XDG_CONFIG_DIRS`, so they apply in the Ambrosia
session only.

**Why:** each of those services already works and fits KWin. The shell takes
them over one at a time (notifications, on-screen displays, the launcher) as
its own versions are ready, instead of all at once before the first login.

**Instead of:** a bare `kwin_wayland` session, which would need all of that
plumbing rewritten before anything runs.

## A simple installer now, an onboarding app later

Status: proposed
Id: installer

The image's installer is a short script with native dialogs: a disk, a name, a
password, a computer name and a time zone. It erases the disk, installs, and
sets up booting (UEFI). A first-party onboarding app in QML replaces it later,
and that app also asks Mac-first or Linux-first.

**Why:** a complete install that can be tested unattended in a VM matters more
right now than how the installer looks. Calamares isn't in Arch's repositories
and doesn't look like Ambrosia; the first thing a new user sees should be ours.

**Instead of:** archinstall (a terminal UI whose config format changes between
releases) or Calamares.
