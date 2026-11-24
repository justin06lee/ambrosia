# ambrosia: context for the next session

Read this first when picking the project back up. It records where things
stand, how the work runs, and what's next. The README covers the project
itself, `design/DESIGN.md` the rules, and `design/DECISIONS.md` the choices.

**The standing goal (Justin, 2026-11-18):** keep building until Ambrosia can't
be told from macOS in look and feel. Work in rounds: take the biggest visible
gap, build it, check it with a screenshot, commit, take the next.
`docs/GAPS.md` is the running list, ranked, with a log of the rounds; keep it
current. Ask Justin only about architecture (platforms, the base distro, the
compositor); decide the rest.

## What this is

A Linux distro on Arch that looks and feels like macOS: glass, springs, one
consistent design across every toolkit. Its fonts, icons and wallpapers are its
own. The user wants it to feel identical to a Mac in the hands, and judges
details by comparing against their own Mac (screenshots, screen recordings).

**The end product is an installer image**: flash it, boot it, and it installs
Ambrosia. The user asked for that explicitly, over configuring their own
machine, so everything is built as Arch packages plus an archiso image from the
start (DECISIONS: "Ship as an installer image from the start").

## Where it stands

The source is private on GitHub: `origin` is
`github.com/justin06lee/ambrosia` (master). It must never be made public. The
built packages are public, in `github.com/justin06lee/ambrosia-packages` (the
package repo below), and they carry `shell/` and `session/` as they are.

- **Design system (phase 1), done.** `design/tokens.ts` holds every value;
  `tools/gen` generates GTK 4/3, KDE color schemes plus session `kdeglobals`, a
  QML `Theme` singleton, fontconfig and CSS into `dist/`. `preview/` is the HTML
  mock of the desktop the real shell must match; `site/` is the review site.
- **Distro pipeline, first cut** (branch `feat/distro-pipeline`):
  - `packaging/PKGBUILD` builds `ambrosia-keyring` (the repo's key and
    address), `ambrosia-theme` (themes, wallpapers, icons), `ambrosia-shell`
    (the QML shell, the session, KDE/KWin defaults), `ambrosia-files` (Files,
    built with CMake from `files/`), `ambrosia-settings` (Settings, from
    `settings/`; both x86_64), `ambrosia-input` (the session's input method,
    from `input/`, x86_64) and `ambrosia-desktop` (the meta package: SDDM,
    portals, NetworkManager, PipeWire, Bluetooth, power-profiles-daemon, CUPS
    and Avahi, Konsole, Dolphin, Files, Settings, GTK skel, os-release).
  - `packaging/quickshell/PKGBUILD` is our Quickshell build: upstream v0.3.2
    with the DBusMenuSource patch, served from the hosted repo.
  - `session/`: `startambrosia` runs Plasma's session (`startplasma-wayland`)
    with `XDG_SESSION_DESKTOP=ambrosia`; `ambrosia-shell.service` runs
    Quickshell and a drop-in keeps plasmashell from starting, both keyed on that
    variable (so does a drop-in for Plasma's splash). Defaults in
    `/etc/xdg/ambrosia` (via `XDG_CONFIG_DIRS`): window buttons left in Mac
    order, no hot corner, Inter fonts, and the `org.ambrosia.desktop`
    look-and-feel package (`session/look-and-feel/`), which carries the
    Ambrosia color scheme.
  - `shell/` (working on real hardware since 2026-10-13): the menu bar (the
    Ambrosia menu, the focused app's name and its own menus over DBus, apps'
    own status items (round 12: Quickshell's tray service, each a
    `MenuBarItem` with a picture; `StatusIcon.qml` draws a mostly gray icon
    as its shape in the bar's text color; a press opens the app's menu),
    Wi-Fi, Search, control center, clock), Search on Super+Space, the Dock, the
    control center (every control acts) and notification banners. KWin's
    window list comes through Plasma's task manager model (`Apps.qml`),
    granted by `session/org.ambrosia.shell.desktop`. Menus, the control
    center and confirmations draw on each screen's `Overlay`; their state is
    `Popups.qml`. The look still trails the preview: function came first.
  - `iso/`: archiso profile from Arch's releng: live user autologin into the
    Ambrosia session, NetworkManager, the Ambrosia packages as a local repo on
    the image (`/opt/ambrosia/repo`, listed first in pacman.conf), and the
    installer (`ambrosia-install` opens the shell's assistant,
    `shell/Installer.qml`, and answers its questions; `--dialogs` asks with
    kdialog instead; `ambrosia-install-system` installs as root; needs the
    internet).
  - **The package repo** (2026-10-20): installed systems update from
    `[ambrosia]`, the rolling `repo` release of the public
    `justin06lee/ambrosia-packages`. Its address is
    `/etc/pacman.d/ambrosia-mirrorlist` and its key is trusted by
    `ambrosia-keyring` (as archlinux-keyring does Arch's). The installer lists
    it first in the installed pacman.conf with `SigLevel = Required`.
    `make publish` on the Mac fills it. Our Quickshell is served from it.
    Verified 2026-10-20 with `tools/repo-test.sh`, twice: fresh installs from
    images carrying r62 and r64 upgraded to r64 and r67 from GitHub, every
    signature checked. That image (r64, with the installer's repo setup) is
    `out/iso/ambrosia-2026.10.20-x86_64.iso` on tenet.
  - **The system is called Ambrosia** (2026-10-20): ambrosia-desktop ships an
    os-release (`ID=ambrosia`, `ID_LIKE=arch`, `LOGO=ambrosia-logo`, the
    mark from `assets/icon.svg`) that a pacman hook copies over Arch's
    `/etc/os-release` symlink, and again whenever filesystem puts it back.
    About This Computer (`kcm_about-distro`), the console's `/etc/issue` and
    `hostnamectl` read it.
- **Verified in a VM on tenet** (2026-10-07): the image boots into the live
  Ambrosia session with the installer open; both the interactive installer
  (driven with keys) and the unattended one install, and the installed system
  boots to SDDM (Breeze theme, Wayland greeter, Ambrosia preselected) and logs
  into the menu bar desktop with no splash. Not yet tried on real hardware.
  The current image is `out/iso/ambrosia-2026.10.07-x86_64.iso` on tenet.
- **tenet runs Ambrosia** (flashed from the SanDisk on 2026-10-13, account
  justin06lee). Its old setup isn't restored yet: `/Volumes/T7/Backups/tenet`
  `./restore.sh` brings it back (makima, services, home) whenever the user
  wants. The restore leaves our quickshell and ambrosia-* packages alone.
  Since 2026-10-20 its pacman.conf lists `[ambrosia]` first (the old one is
  `/etc/pacman.conf.before-ambrosia`). On 2026-11-09 it had a full
  `pacman -Syu` (214 packages, r316 of every ambrosia-* package, Arch
  current; backups in `/var/tmp/ambrosia-syu`), and avahi-daemon, cups.socket
  and power-profiles-daemon were enabled as the installer does. Kernel 7.2.14
  is installed but it still runs 7.2.10 until a reboot (the running kernel's
  modules were put back in `/usr/lib/modules`). On 2026-11-11 it got r385
  of every ambrosia-* package but ambrosia-desktop (still r316: the new one
  pulls in keyd and switches the login screen, see Needs Justin), from
  local packages (`pacman -U`). Reach it as `ssh tenet`
  (Tailscale, 100.97.46.114); its LAN address is now 192.168.1.232. gpg
  prints `release_dotlock: lockfile error` when its keyring is populated, but
  the key ends up trusted.

## Next

1. **Make it look like the preview.** A first parity pass is done
   (2026-10-20, branch `feat/visual-parity`): glass rims and specular ring,
   menus, Dock tiles and tooltip, banner motion, control center spacing,
   KWin's blur, Breeze's frames and menus. Side-by-side screenshots are in
   `out/parity/` on the Mac. Windows have traffic lights since 2026-10-20;
   since 2026-10-28 they're our own KWin decoration plugin (`decoration/`,
   its sizes and colors from `dist/kdecoration/tokens.h`), with rounded
   corners all round and all three glyphs on hover, as on a Mac. The glyphs
   are macOS 26's shapes, fitted at 2x and kept once in the tokens; the frame,
   Files and GTK's titlebuttons all draw them. GTK 3's lights match too (14
   wide, 23 apart), and GTK 4's since round 32 (measured in the test VM;
   there the light is the button's image, see GTK apps' controls below). A
   running KWin keeps the plugin it loaded, so a new frame shows after the
   next login (test it in a nested `kwin_wayland --wayland-display`).
   The Dock's Trash is Mac-style since 2026-10-21: the current macOS
   frosted bin, redrawn by hand and matched 1:1 against a screenshot (empty
   is the full bin without its paper: no empty screenshot to match), full or empty with the home trash
   (other drives' trashes aren't watched), and it takes dropped files.
   Files has its own Finder-style icon (2026-10-21, `assets/icons/`, hicolor
   `org.ambrosia.files`); until Ambrosia's Files app exists, Dolphin's Dock
   pin shows as Files with it (`standIns` in `shell/Dock.qml`).
   **There is an "Ambrosia" icon theme** (2026-11-18, built into
   `dist/icons/Ambrosia`, shipped in ambrosia-theme as
   `/usr/share/icons/Ambrosia`, inheriting Breeze). It holds **the pointer**
   (`design/cursors.ts`, `tools/gen/targets/cursors.ts`: 24 shapes and 90
   other names, as Xcursor files from 24 to 96 and as SVGs for KWin) and
   **app icons** (`design/icons.ts`, `tools/gen/targets/icons.ts`: Terminal,
   a text editor, picture and document viewers, Calculator, an archiver,
   the store, Screenshot and system information, under the icon names
   Konsole, Kate, Gwenview, Okular, KCalc, Ark, Discover, Spectacle and
   Info Center ask for; KDE's settings and Dolphin wear Settings' and
   Files'). The look-and-feel names the theme for icons and pointer,
   `startambrosia` keeps Plasma's copy of both current for existing users,
   GTK gets them through the session's dconf defaults and the login screen
   its pointer through sddm.conf. The Dock shows every icon of ours at tile
   size (`Theme.tileIcons`, generated; Settings' icon wasn't on the old
   list). **An app icon that isn't ours sits on a plain tile** (round 10,
   `shell/AppTile.qml`: the Dock, Search's app results, ⌘Tab; it is only
   QtQuick and is linked into the switcher's folder like Glass.qml).
   "Ours" is `Theme.tileIcons`; in ⌘Tab the icon's name comes from the
   KWin module (`Apps.icon`), or the desktop file's own name where a
   running KWin still holds an older module. A notification's icon gets
   the tile too when it came by name (round 13, `NotificationStore.plainOf`:
   the app's icon, or a name notify-send hands over as the picture, which
   Quickshell turns into `image://icon/<name>`); a picture or a file's
   path is shown as it is. **Folders and kinds of
   file are in the theme too** (round 11; `places/`, `mimetypes/`,
   `actions/` under `dist/icons/Ambrosia`): built on Files' art
   (`files/art/folder.svg`, `document.svg`, `document-small.svg`,
   `audio.svg`) and the Dock's Trash, with glyphs, colors, marks and every
   name in `design/icons.ts`. Each has a drawing for 32 px and up and one
   under it (`small`, with `small@2x` and `@3x` as links for doubled
   screens); a special folder's small drawing is its line glyph, which KDE
   recolors with the scheme. **How KDE picks an icon decides what a theme
   over Breeze may name** (`tools/gen/lookup.ts`, Gotchas): seen on tenet
   in Dolphin, Kate's file dialog and the stack, light, dark and at 2×.
   Drawn on the Mac (`dist/icons/sheet.html`,
   `dist/cursors/sheet.html`, the review site's Input and Iconography
   chapters) and **seen on tenet's KWin (2026-11-18)**: the arrow, I-beam
   and pointing hand over Firefox, both resize arrows at a window's edge
   and corner, and our icons in the Dock, Search and ⌘Tab. Not looked at
   yet: the wheel turning, an Xwayland app, the login screen (its KWin
   reads no Ambrosia config, so it may keep Breeze's arrow under a greeter
   that draws its own), Files' Applications, and Breeze's one-color icons
   following dark mode under our theme (`FollowsColorScheme`).
   **Qt apps wear a widget style of ours** (2026-11-18, `style/`, package
   ambrosia-style, key `ambrosia`): a QProxyStyle over Breeze (Fusion where
   Breeze isn't installed) that repaints push buttons, checkboxes, radio
   buttons, text fields, pop-up buttons, steppers, sliders, progress bars,
   scroll bars (thin, no arrows), tool buttons, menus (rounded, a rounded
   accent highlight, 22-point rows) and tooltips with the Mac's measured
   sizes (`controls` and `controlColor` in the tokens, the numbers
   Settings' Look.qml carries), takes the accent and text from the app's
   palette, lays dialog buttons out the Mac's way and drops underlined
   letters. A menu row's shortcut is printed with the Mac's glyphs (round
   14, `macShortcut`: Ctrl is ⌘, Meta ⌃, as in the shell's menus; the
   menu's width is corrected for what QMenu measured, `shortcutsSaved`;
   Qt on a Mac prints glyphs by itself, so look at this in a gallery
   drawn on tenet). Its second cut (round 4, the same day) adds: a tab view's tabs
   as a segmented control in the middle of its pane's top edge, and a
   window's own tabs (Qt's document mode: Konsole, Kate, Dolphin) as a
   quiet row with the chosen one on a face and a close button that shows
   under the pointer, on the left; group boxes as a bold heading over a
   faint rounded box; lists', trees' and tables' rows 24 tall with a
   rounded highlight that joins chosen neighbors and is gray where the
   keyboard isn't (a list without the focus, a window behind); tree arrows
   in place of branch lines; table headers small, the sorted column bold
   with its arrow; a pop-up button's choices as a menu over the button with
   the current one ticked; flat toolbars, menu bar items, splitters and
   status bars; the focus ring on checkboxes and radio buttons; a busy
   progress bar that moves. `make gallery` builds it and draws every control into
   `out/shots/style-{light,dark}.png` with no display, on the Mac too (it
   has Homebrew's qtbase, cmake and ninja for this since 2026-11-18).
   **Seen on tenet over Breeze (2026-11-18) and switched on:** Kate (its
   window, a context menu, its settings, the file dialog), Konsole, Dolphin
   and a Qt Quick settings module (`kcmshell6 kcm_mouse`, which draws
   through the style) all came out clean, so the look-and-feel says
   `widgetStyle=ambrosia` and `startambrosia` keeps Plasma's copy current
   for users from before. Fixed from that look: a menu's panel was painted
   through the helper that dims disabled controls (QMenu hands its panel
   over with no state), so every menu was 45% see-through by accident; it
   is glass on purpose now, as solid as breezerc's `MenuOpacity` (the
   session's says 72) because that setting is also what makes Breeze, under
   us, ask KWin to blur behind menus, and solid where Breeze isn't
   underneath (`blurredMenuOpacity`). A chosen row is one color from edge
   to edge even where a view's own delegate draws it (the file dialog
   calls `PE_PanelItemViewItem` directly). A push button with a title
   draws no picture (KDE's apps set one whatever the style hint says).
   Round 21 (2026-11-23) drew the rest: the list a combo to type in
   drops, dials, tool boxes, a dock widget's title and the calendar, and
   asks KWin itself to blur behind a combo's list (KWindowSystem, when
   it is there to build against; Breeze only asks for menus). **Breeze
   doesn't always ask the style on top:** it paints a progress bar's
   pieces and a menu button's arrow by calling itself, and gives a combo's
   list rows of its own when the combo is polished, so those three are
   put together in ours (`CE_ProgressBar`, `CE_PushButtonLabel`, the rows
   swapped in before Breeze's polish). The picture `make gallery` draws
   has no hover and no real popup: `ambrosia-style-gallery --show` opens
   the same controls as a window (on tenet: `tools/live.sh run
   ~/work/ambrosia/out/build/style/ambrosia-style-gallery --show`), which
   is how the progress bars were caught. Not drawn: scroll bars that hide
   (a Mac with a mouse shows them always, as ours do).
   **GTK apps' controls are ours too** (round 32, 2026-11-25,
   `tools/gen/targets/gtkcontrols.ts`): CSS over the stock themes, from
   the tokens the Qt style reads, written into `dist/gtk-4.0/gtk.css` and
   `dist/gtk-3.0/gtk-{light,dark}.css`, which each user's `gtk.css`
   imports. A user's stylesheet outranks a theme's rule whatever its
   selector, so a rule on `button` reaches every button and each kind a
   theme tells apart (flat, linked, round, in a bar, a stepper's, a
   table header's) has to be told apart again there; anything named
   after the controls (the traffic lights) must be at least as specific
   as the controls' rules that would touch it (`button.image-button`
   pads). GTK 4 names colors by `--amb-*` variables, defined for light
   and dark; GTK 3 has neither variables nor a dark query, and Adwaita
   there has its colors written in, so its file per mode also sets
   windows, views, lists and selections. Don't put rules on `.view` or
   `window` in the GTK 4 file: they outrank libadwaita's own exceptions
   (a pop-up row's label got a dark box). GTK recolors a symbolic picture
   by filling its paths, so a mark is a filled outline, never a stroke.
   Dark: GTK 4 and libadwaita ask the portal (it answers from KDE's
   color scheme; `gsettings color-scheme` is not what they read here,
   as the session sets `GDK_DEBUG=portals`); GTK 3 is told by
   `/usr/lib/ambrosia/gtk-appearance light|dark`, which the shell runs
   at its start and on a change (`Appearance.qml`), for apps opened
   after. To try a change: `bun tools/gen/index.ts`, copy
   `dist/gtk-{3,4}.0` over `/usr/share/ambrosia/` in the test VM
   (`pacman -S gtk3-demos gtk4-demos python-gobject`), run
   `gtk3-widget-factory` or `gtk4-widget-factory` as the user and read
   `journalctl --user` for "Theme parsing error". What can be measured is
   better measured than looked at: `tools/px.py shot.png row Y X0 X1`
   prints the runs of color along a line of a screenshot (a control's
   width, the gap between two, the color a row took), and
   `tools/vm-try.sh pull` brings a file out of the VM.
   **The volume and brightness keys have a display** (round 5, 2026-11-18,
   `shell/Hud.qml` and `HudPanel.qml`): a glass capsule under the menu
   bar's right end with a glyph and a level, or the name of the output
   sound moved to. Plasma handles the keys (plasma-pa's kded module,
   PowerDevil) and tells plasmashell's `org.kde.osdService` what to show;
   plasmashell isn't here, so `Hud.qml` runs `busctl --user monitor` for
   those calls and shows what they say. **Seen on tenet (2026-11-18):**
   the volume keys bring it up with the right level, so the bus does hand
   a monitor calls nobody takes. By hand:
   `quickshell ipc --path /usr/share/ambrosia/shell call hud -- show volume 45`
   (the `--` matters: without it quickshell reads "show" as its own
   `ipc show`). Brightness was only shown that way: tenet's display has no
   brightness keys.
   **⌘Tab has a switcher of ours** (round 6, 2026-11-18): the
   look-and-feel package's `contents/windowswitcher/` (KWin looks there
   first for the layout kwinrc names, `LayoutName=org.ambrosia.desktop`),
   with `ApplicationsMode=1` so it walks apps. `SwitcherStrip.qml` is the
   picture (seen, by `make shell-shots`); `WindowSwitcher.qml` is KWin's
   side (`KWin.TabBoxSwitcher`, a plain transparent `Window`, icons through
   Kirigami, the mode from KWin's palette). Glass.qml, Label.qml and
   icons.js are symlinks to the shell's (the PKGBUILD copies with `-L`).
   **Seen on tenet's KWin (2026-11-18):** hold, Tab on, arrows, let go,
   with ⌘ and with Alt. Two things it lacked there come from a small QML
   module of ours that KWin loads (`decoration/qml`, `org.ambrosia.kwin`,
   in ambrosia-decoration): `BlurBehind` gives KWin's blur the strip's
   rounded outline (one of KWin's own windows isn't a Wayland client and
   can't ask as the shell does; `KWindowEffects` can, from C++ only), and
   `Apps.name()` gives the app's name from its desktop file. KWin's QML
   has `KWin.Workspace.windows`, not `windowList()`, and warns about any
   binding that reads it, so the list is read once when the strip opens.
   **A running KWin keeps the layout it first loaded** (and the module):
   the new one ran there from a copy under another name
   (`~/.local/share/plasma/look-and-feel/<name>/contents/windowswitcher/`,
   `LayoutName=<name>` in the user's kwinrc), and the installed one shows
   at the next login. Dark, the pointer choosing and Q were looked at the
   same day (round 10) and work. In KWin's QML don't chain `?.` into a
   call (`a?.b?.(x)` threw "of null"): test for the function plainly, as
   `ask()` does.
   **A right-click on the desktop opens a menu** (round 9, 2026-11-18;
   `shell/Wallpaper.qml`): New Folder (makes "untitled folder", or
   "untitled folder 2"…, in ~/Desktop and asks Files to show it, since
   nothing is drawn on the desktop yet) and Change Wallpaper…. **Seen on
   tenet (2026-11-18):** KWin hands the wallpaper's layer the press, the
   menu opens at the pointer, New Folder makes the folder and Files shows
   it, Change Wallpaper… opens Settings' pane. Not tried: the screen's
   edges, a right-click while another menu is open.
   **A window minimizes into its Dock tile with the Genie** (round 15,
   2026-11-18): KWin's Magic Lamp is the session's default
   (`session/xdg/kwinrc`, 400 ms by eye), and the Dock publishes each
   tile's place to KWin (`publish()` in `shell/Dock.qml`; check with
   `tools/live.sh js` printing a window's `iconGeometry`). Seen on tenet
   slowed down, with the Dock at the bottom and on the left (KWin types
   a layer surface by its namespace: the Dock's is "dock", or the Genie
   finds no panel and pours downwards). A running KWin doesn't load or unload effects when the
   defaults file changes, even on reconfigure: call `/Effects` `loadEffect`
   and `unloadEffect` as Settings does, or log in again. **Opening and
   closing are an effect of ours** (round 16, `session/kwin-effects/
   ambrosia_windows`, in ambrosia-shell, on in the session's kwinrc with
   KWin's Scale off): a window swells open from 90% with a fade and
   closes at once. To look at it, write `Duration=20000` under
   `[Effect-ambrosia_windows]` in the user's kwinrc, `reconfigureEffect`,
   photograph two seconds after starting an app, and delete the key.
   **The preview of where a dragged window will tile is ours** (round 17,
   `session/kwin-outline/outline.qml`, `[Outline] QmlPath` in the
   session's kwinrc; it needs `org.ambrosia.kwin` from
   ambrosia-decoration for the blur). KWin loads the outline's QML once,
   the first time it shows one: after an edit, only a new KWin (a login,
   or a nested one) shows the change.
   **Tiled windows keep a margin, and the green light has a menu**
   (round 22). `session/kwin-scripts/ambrosia_tiles` sets a padding of 8
   on KWin's own halves and quarters (`window.tile.padding`, which KWin
   leaves at nothing; a layout drawn in KWin's tile editor has its own
   and is left alone); KWin loads a newly enabled script on
   `reconfigure`. The frame's zoom light (`decoration/src/button.cpp`)
   runs `ambrosia window-menu X Y` when the pointer has rested on it for
   600 ms, and the shell opens Left, Right, Top, Bottom, the quarters,
   Center and Enter Full Screen there (`Apps.placeEntries`,
   `placeWindow`: KWin's actions through kglobalaccel's
   `invokeShortcut`). KWin doesn't tell a frame where it is on the
   screen: `QCursor::pos()` works inside KWin, and the pointer's place in
   the frame comes with its hover events. **To try a frame plugin in a
   running KWin** (which keeps the one it loaded): build a copy under
   another name and Id (`sed` over `CMakeLists.txt` and
   `metadata.json`), install it beside ours, name it in the user's
   `kwinrc` (`[org.kde.kdecoration2] library=`), `reconfigure`; put the
   name back and delete the copy after. **A menu opened by a command
   comes up before the shell has had any input** only with our Quickshell
   (round 24, `packaging/quickshell/popup-grab.patch`, pkgrel 4): the
   Overlay is a grabbing popup of the bar's, and Qt refuses one until a
   press or a key has reached the program ("Failed to create grabbing
   popup"); the patch hands Qt the seat with no serial, which KWin takes
   (it doesn't check a grab's serial).
   **⌘H hides the app, with no motion** (round 24): the session's KWin
   effect (`session/kwin-effects/ambrosia_windows/contents/code/main.js`)
   registers Ambrosia Hide App, Hide Others, Show All and Show Without
   Motion as KWin shortcuts (the first two on Super+Ctrl+Alt+H and
   +Shift, which keyd sends for ⌘H and ⌥⌘H); the shell's menus and Dock
   run them by name (`Apps.kwin`). Hidden windows are minimized ones.
   KWin's Genie plays for every minimize unless some effect has the whole
   screen, so ours takes it (an animation with `fullScreen: true`) for
   the instant, holding blur on meanwhile. **An animation on a window
   that isn't drawn never ends** (KWin advances it when it paints the
   window): the effect cancels its own, or puts it on the bottom window.
   KWin's `animationEnded` gives no id (always 0); the effect listens to
   `isActiveFullScreenEffectChanged`. **To slow an effect down in a
   running KWin**: write its key to the user's `kwinrc`, `qdbus6
   org.kde.KWin /KWin reconfigure`, then unload and load the effect
   (without the reconfigure it keeps the old value); `/Effects
   activeEffects` then says whether it is running. **keyd leaves
   `/root/ui.py`'s device alone** (a pointer with keys isn't a keyboard
   to it): to press a ⌘ chord through keyd on tenet, make a uinput
   device with keys only and a whole board of them (python-evdev,
   `UInput({EV_KEY: list(range(1, 128))})`: with a handful of keys keyd
   says "ignoring"), wait two seconds for keyd to take it, then write
   the keys. keyd stopped by
   systemd is left "failed" (it exits 15): `systemctl reset-failed keyd`.
   **What is in ~/Desktop lies on the desktop as icons** (round 25,
   `shell/DesktopIcons.qml`, loaded by the first screen's
   `Wallpaper.qml`): a `FolderListModel` only watches the folder; each
   change re-runs one `sh` loop (`stat -c %Y`, `file -bL --mime-type`)
   whose lines become the icons, ordered by `Settings.desktopSort`. The
   wallpaper is a background layer surface that never has the keyboard,
   so the icons take the pointer only. A drag out is Qt's own
   (`Drag.Automatic`, `text/uri-list`), which the Dock's Trash and apps
   take; `shell/FileKinds.qml` picks icons for the stack too. The Mac
   pictures answer the two commands through `Quickshell.shotRun` (sheet
   `desktop-icons`; HOME there is `/home/ada`, so the Mac's own Desktop
   is never read).
   **Open and Save are Files** (round 30): the resident Files owns
   `org.freedesktop.impl.portal.desktop.ambrosia` and answers
   `FileChooser` (`files/src/portal.cpp`; `files/ambrosia.portal` and a
   D-Bus service file that starts it). A request makes a `FinderWindow`
   with `panel` set (kind, title, accept, multiple, name, filters); its
   `panelAccepted(urls, filter)` or its closing is the answer.
   xdg-desktop-portal picks Files from `/etc/xdg/ambrosia/
   xdg-desktop-portal/portals.conf` (it reads the first portals.conf on
   `XDG_CONFIG_DIRS`), and apps ask the portal because `startambrosia`
   sets `PLASMA_INTEGRATION_USE_PORTAL`, `GTK_USE_PORTAL` and
   `GDK_DEBUG=portals` (a session from before keeps KDE's dialog until
   the next login). **To try the panel without the portal**:
   `ambrosia-files --panel open|save|folder [folder]` opens a stand-in
   one (`files/tools/tenet.sh grab NAME --panel save …` photographs it),
   and a real request can be sent over the bus: `busctl --user
   --timeout=300 call org.freedesktop.impl.portal.desktop.ambrosia
   /org/freedesktop/portal/desktop org.freedesktop.impl.portal.FileChooser
   SaveFile osssa{sv} /org/freedesktop/portal/desktop/request/t/a1 "" ""
   "Save As" 1 current_name s "notes.txt"` prints the answer (`0` and
   the URLs, `1` cancelled). **End to end**: `kdialog --getopenfilename
   ~` started inside the session prints what the panel chose.
   **The picture while starting up is a Plymouth theme** (round 29,
   generated: `tools/gen/targets/plymouth.ts` → `dist/plymouth/ambrosia`,
   installed by ambrosia-theme; `dist/plymouth/sheet.png` is a drawing of
   it to look over on the Mac). Plymouth's script plugin knows nothing of
   a display's scale, so the script sizes everything by the screen's
   height (1080 is 1x) from pictures drawn at 1x to 4x. It is switched on
   by `/usr/lib/ambrosia/boot-picture` (ambrosia-desktop; the installer
   runs it in the new system, which is why `plymouth` is in the
   installer's list and only an optional dependency of the package: as a
   dependency it would make `pacman -U` on an installed system pull from
   a newer package list). **To see it**: `tools/vm-try.sh up`, install
   plymouth and the packages there, run `boot-picture`, `systemctl
   reboot`, and photograph in a loop (`screendump` through the monitor
   socket every 0.2 s: the splash is up for under two seconds in the VM).
   `plymouthd --mode=boot --tty=tty1; plymouth show-splash` with SDDM
   stopped holds it still, and `plymouth ask-for-password` shows the
   field. **Run from an image** (2026-11-24, `ambrosia-2026.11.24`): the
   live image and an install made from it both start behind the picture.
   `tools/vm.sh install` deletes `out/vm/vars.fd` (and stale variables
   make `live` hang in the firmware: delete the file first); give it
   `VM_DISK` to spare `disk.qcow2`. `tools/vm-try.sh` takes
   `VM_TRY_DISK` and `VM_TRY_VARS` to copy another install than
   `fresh.qcow2`: that day's is kept as `out/vm/fresh-1124.qcow2` with
   `vars-fresh-1124.fd` (today's Arch, KDE 6.8.3, plymouth on; user
   test, password ambrosia).
   **The shell is the polkit agent** (round 28, `shell/Authorization.qml`
   on `Quickshell.Services.Polkit`): a session has one agent, so
   `plasma-polkit-agent.service` has a drop-in that skips it in our
   session (in a session from before the upgrade: `systemctl --user stop
   plasma-polkit-agent`, then restart the shell). A request is shown by
   `Popups.confirm` with `hold` (stays up until `Popups.finish()` or
   `refused()`) and `cancel` (run when it is put away by anything).
   **To ask for one by hand**, from inside the session and not from
   SSH's own (polkit looks for the agent of the caller's session, and
   pkexec there ends with 127): `systemd-run --user --collect sh -c
   'pkexec true; echo $? > /tmp/out'`; 126 is a refusal, 0 a yes.
   **The lock screen is the login screen's file** (round 27): KDE's
   locker (`kscreenlocker_greet`, started by KWin at each lock) loads
   `contents/lockscreen/LockScreen.qml` from the Plasma shell package
   that `plasmashellrc`'s `[Shell] ShellPackage` names (the session's is
   `/etc/xdg/ambrosia/plasmashellrc`; ours is `session/plasma-shell/
   org.ambrosia.desktop`, and what a package lacks comes from Plasma's).
   `LockScreen.qml` has ids named `sddm`, `userModel`, `sessionModel`,
   `keyboard` and `config`, which `Login.qml` (a link to
   `packaging/sddm-theme/Main.qml`) finds as SDDM's: a change to that
   file changes both screens, so look at both. The locker's
   `authenticator.respond(password)` drops a password PAM hasn't asked
   for yet: ours keeps `startAuthenticating()` going once a second and
   holds a password typed early until `promptForSecretChanged`. The
   picture behind is the locker's own doing, from `kscreenlockerrc`
   (`[Greeter][Wallpaper][org.kde.image][General] Image`), which
   `shell/Wallpaper.qml` writes. **To look at it without locking**:
   `/usr/lib/kscreenlocker_greet --testing --shell org.ambrosia.desktop`
   (it covers the screen and takes the keyboard all the same; end it
   with `pkill -x kscreenlocker_g`, never `pkill -f`, which matches the
   shell that runs it). **To try a real lock where the password is
   known**: `tools/vm-try.sh` on tenet as root (user `test`, password
   `ambrosia`; `loginctl lock-session`, type, `loginctl show-session
   -p LockedHint`). A lock screen that loads and doesn't unlock keeps
   its user out: `loginctl unlock-session <id>` from SSH or a console
   lets in.
   **Mission Control is a KWin effect of ours** (round 26,
   `session/kwin-effects/ambrosia_mission`, a `SceneEffect` in QML:
   KWin draws nothing else while it is up, so the wallpaper, the menu
   bar and the Dock are drawn there as `WindowThumbnail`s; the shell's
   surfaces are told apart by `window.layer`, 0 the wallpaper, 3 and up
   the bars, since KWin types only the Dock). The windows are laid out
   by KWin's private `ExpoLayout`/`ExpoCell` (`org.kde.kwin.private.
   effects`, what its Overview uses: it may change with a KWin release).
   Shortcuts "Ambrosia Mission Control" and "Ambrosia App Windows"
   (Super+Ctrl+Alt+↑/↓; keyd's `[control]` layer sends them for ⌃↑ ⌃↓,
   and KWin's own Super+Ctrl+←/→ for ⌃← ⌃→). KWin's Overview is off in
   the session's `kwinrc` (same four-finger swipe). Global shortcuts
   still fire while a scene effect has the keyboard, so the same key
   closes it. **To try an edit in the running KWin**: copy the package
   to `~/.local/share/kwin/effects/<a new id>` (the id in
   `metadata.json` too; a new one each edit, KWin keeps loaded QML),
   `qdbus6 org.kde.KWin /Effects loadEffect <id>`, and run it with
   `qdbus6 org.kde.kglobalaccel /component/kwin invokeShortcut
   "Ambrosia Mission Control"`; errors are in `journalctl --user
   _COMM=kwin_wayland`. **KWin holds the `Theme` it first loaded**: QML
   of ours inside KWin sees a new token only after a login (for a try,
   put numbers in the copy).
   **⇧⌘3 and ⇧⌘4 save to the Desktop and float a thumbnail** (round 23,
   `shell/Screenshot.qml`, `ambrosia screenshot screen|region`): Spectacle
   takes the picture in the background (`--background --nonotify
   --fullscreen|--region --output`), the shell shows it in the bottom
   right corner for five seconds and opens it on a click. The two chords
   are desktop files of ours (Super+Ctrl+Alt+3 and 4, sent by keyd); the
   Print key's chords are still Spectacle's. Spectacle is one instance:
   another started while its crosshair is up ends that shot.
   **Force Quit… in the Ambrosia menu opens a list of apps** (round 20,
   `shell/ForceQuit.qml`, `ambrosia force-quit`): choose one, confirm,
   and its windows' processes are killed (`Apps.forceQuit`). ⌥⌘Esc opens
   it since round 24 (`session/org.ambrosia.force-quit.desktop`,
   Super+Ctrl+Alt+Esc); `ambrosia quit` asks the app in front's windows
   to close (`org.ambrosia.quit.desktop`, for apps named "quit" in
   `keys.json`).
   **⌃⌘Space opens an emoji picker of ours** (round 31,
   `shell/EmojiPicker.qml` on the Overlay, kind "emoji"; `ambrosia emoji`;
   `session/org.ambrosia.emoji.desktop` holds Super+Ctrl+Alt+Space, which
   keyd's ⌃⌘Space sends). Its list is `shell/emoji.js`, written by
   `bun tools/emoji.ts` from Unicode's emoji-test.txt and CLDR's English
   annotations (run by hand when Unicode adds emoji; the result is in the
   repo). The ones chosen lately are kept in Quickshell's state folder
   (`emoji.json`). A choice is typed into the app in front by
   **`ambrosia-input`** (`input/`, its own package): KWin starts it as the
   session's input method (`[Wayland] InputMethod` in the session's
   `kwinrc`, the one program KWin gives the input-method protocol), it
   listens on `$XDG_RUNTIME_DIR/ambrosia-input`, and `ambrosia-input type
   TEXT` commits TEXT at the insertion point of whatever field has the
   keyboard (ends 1 when none does: the picker then copies its choice). The
   picker has the keyboard while it is up, so the helper waits for the
   app's field to come back before it writes. Someone who chooses another
   input method in KDE's settings (fcitx5 for Chinese, Japanese or Korean)
   displaces it; the picker falls back to copying.
   **Trackpad gestures** (round 34, 2026-11-25): the fingers are heard
   in the Mission Control effect's `main.qml` (`SwipeGestureHandler`,
   `PinchGestureHandler`; KWin's own three- and four-finger sideways
   swipe switches desktops). An effect can't run a program or call
   another effect, so the pinches press shortcuts by name through
   kglobalaccel (`KWin.DBusCall`, `invokeShortcut`). Show Desktop is in
   `ambrosia_windows/contents/code/main.js`; KWin's own (Super+D, an
   app's request, `org.kde.KWin.showDesktop`) would hide the shell's
   wallpaper and menu bar, so `session/kwin-scripts/ambrosia_desktop`
   switches it off the moment it comes on and presses ours (round 35; a
   script hears of it only as each window's `hiddenByShowDesktopChanged`,
   from inside KWin's pass over the windows, so it acts on a 0 ms timer). Three traps from building
   it: KWin emits `animationEnded` from inside its own pass over the
   animations, so a handler there must not `animate`, `set` or `cancel`
   (it crashed KWin seconds later; it may minimize); a `set` or
   `animate` keeps a closing window alive unless `keepAlive: false`;
   an effect's window has `geometry`, not `frameGeometry`. The test VM's
   KWin renders in software and loads no scripted animation effect
   (`isEffectSupported` false) unless the account has
   `KWIN_EFFECTS_FORCE_ANIMATIONS=1` in `~/.config/environment.d/`. A
   changed effect QML needs a new KWin (in the VM: reboot); reloading a
   JS effect by `unloadEffect`/`loadEffect` works but check
   `coredumpctl list` after any effect test. Fingers for the VM:
   `tools/fake-touchpad.py` as root there (`systemd-run
   --unit=fake-touchpad python3 /root/fake-touchpad.py`, needs
   python-evdev), then `echo "swipe 3 up" > /run/fake-touchpad`,
   `pinch 4 out`.
   **A new account gets a welcome** (round 33, 2026-11-25,
   `shell/Welcome.qml`): a layer surface over the first screen with two
   pages, Welcome to Ambrosia and Choose Your Look (Light, Dark, Auto;
   the choice goes through `Appearance`, so everything follows at once).
   Who sees it: `Settings.qml` sets `welcome` true only in the branch
   where it finds neither `~/.config/ambrosia/settings.json` nor the old
   state file, which is an account's first login; the end clears it.
   That branch must also do what `onLoaded` does (migrate, then
   `loaded = true`): nothing is read back after the shell writes the
   defaults, and until round 33 a new account's first session never had
   `Settings.loaded`, so nothing waiting on it ran. An
   existing account never has the key, so it reads false. The live
   image's user must not see it (the installer starts there by itself):
   `ambrosia-live-user.service` writes that user an empty settings file.
   To see it again: `ambrosia welcome`; as a new account would, in the
   test VM: remove the user's settings.json and
   `~/.local/state/quickshell/by-shell/*/settings.json`, restart
   ambrosia-shell. Its sizes are `size.welcome` in the tokens.
   **A shell that crashes comes back by itself** (2026-11-25):
   `ambrosia-shell.service` sets `QS_DISABLE_CRASH_HANDLER=1` (and our
   Quickshell, pkgrel 5, is built without the handler), so a crash ends
   the process and systemd starts it again within seconds (`kill -SEGV`
   in the test VM: no window, `NRestarts` up by one, the notification
   server's name with the new shell). With Quickshell's handler the
   shell came back under a "Quickshell has crashed" window whose default
   button opens a bug report in the browser, and the dead shell's
   parent kept `org.freedesktop.Notifications`, so banners were gone
   until the next login. The crash that showed this: once, in the test
   VM, while `pacman -S` ran its icon-cache hooks, in
   `KIconEngine::createPixmap` under Quickshell's icon provider as a
   list gained a row (a status item or a banner); two more installs did
   not repeat it. KDE's or Qt's to fix, not found again.
   **The installer is an assistant of the shell's** (round 37,
   2026-11-25, `shell/Installer.qml`, `Popups.installerOpen`, `ambrosia
   install`): pages on the welcome's panel; nothing in it touches a disk.
   The live image's `/usr/local/bin/ambrosia-install` is its other half:
   `disks`, `online`, `wifi`, `join SSID` (password on standard input),
   `timezone`, `timezones` print tab-separated lines; `run` reads
   `key=value` lines and then `start` from standard input (it must not
   wait for the end of input: Quickshell's `Process` keeps the pipe
   open) and prints `progress FRACTION words`, then `done` or `failed`.
   To look at the assistant without a disk to lose, on any installed
   system: put the script somewhere, a wrapper at
   `/usr/local/bin/ambrosia-install` that sets
   `AMBROSIA_INSTALL_PRETEND=1` and runs it, then `ambrosia install`.
   With no arguments the script asks the shell for ten seconds (it may
   still be starting at login) and then opens the old dialogs in a
   terminal. A window that opens while it or the welcome is up takes
   the keyboard: KWin hands a layer surface the keyboard at the moment
   it starts to ask (`handleAcceptsFocusChanged`), not for as long as it
   asks. Both watch `Window.active` and, when it goes, stop asking for
   80 ms and ask again; Quickshell sends a changed keyboard mode only
   with the window's next frame, so the change must draw one (the 1 px
   `redrawn`). From the packages, with the VM's screen dimmed, that
   alone did not bring it back, so 300 ms later a window still without
   the keyboard is unmapped and mapped again (`shown`), which always
   does (seen with `redrawn` taken out). `quickshell log --path /usr/share/ambrosia/shell` is
   where the shell's `console.log` goes, not the journal.
   **Seen from an image** (`ambrosia-2026.11.24`, built 2026-11-25 from
   r487): `tools/vm.sh live` with `VM_DISK` a new file, the assistant
   driven by `tools/vm.sh key` and `type`, the install real, then
   `tools/vm.sh installed`. Kept as `out/vm/fresh-1125.qcow2` with
   `vars-fresh-1125.fd` (user mina, password nectar; `tools/vm-try.sh`
   takes it by `VM_TRY_DISK` and `VM_TRY_VARS`).
   **Sounds** (round 36, 2026-11-25): a freedesktop sound theme of ours,
   `ambrosia`, synthesized at build from recipes (`design/sounds.ts`:
   layers of tones, noise bursts, grains; `tools/gen/targets/sounds.ts`
   → `dist/sounds/ambrosia/stereo/*.wav`, other names as links), in
   ambrosia-theme. The session's kdeglobals names it (`[Sounds] Theme`,
   which KWin's bell, KDE's notifications and the volume keys read) and
   dconf does for GTK. What nothing else plays goes through
   `/usr/lib/ambrosia/sound NAME` (`session/sound`): the shell's
   `Session.sound()` for a screenshot and Empty Trash, Files for a move
   to the Trash. The volume pop is off by default
   (`session/xdg/plasmaparc`), as a Mac's. **Nobody has heard them**: to
   judge one, `paplay dist/sounds/ambrosia/stereo/bell.wav` on a machine
   with ears (or `afplay` on the Mac), then tune its recipe. To see what
   plays without ears, in the test VM: `pactl list sink-inputs` in a
   loop names each stream's file; `parec -d auto_null.monitor` records
   the output to measure; `strace -e openat` shows which file
   libcanberra or KWin opened; `pactl list samples` shows the volume
   pop once cached.
   **Downloads in the Dock opens as a stack** (round 7, 2026-11-18): a
   grid of the folder's newest things on the Overlay (`Popups.toggleStack`,
   kind "stack"; `shell/Stack.qml` reads the folder, `StackGrid.qml` is the
   picture, seen by `make shell-shots`). **Seen on tenet (2026-11-18)**
   with a bottom Dock: just clear of the Dock's glass and centered on the
   tile, newest first, icons by kind, a picture as its own icon, a long
   name with spaces cut, Open in Files; and with the Dock on the left and
   on the right (round 10). Not tried: clicking a thing, an empty folder
   and no folder at all.
   **The shell itself can be drawn on the Mac** (pieces since round 5,
   the whole desktop since round 8): `make shell-shots` builds
   `tools/qmlshot` (a Qt Quick window that is never shown, drawn into a
   picture with the real renderer) and draws each sheet in
   `tools/qmlshot/sheets/` in light and dark. The shell's own files load
   unchanged, over stand-ins for Quickshell and Plasma
   (`tools/qmlshot/stubs/`, `stubs.h`; its README says what each is and
   what a picture from here doesn't show: Quickshell's agreement, Inter's
   metrics, KWin's blur). `parts/Desk.qml` puts up the wallpaper, menu
   bar, Dock, Search, banners and the menus' layer with a few apps
   running; a `desktop-*` sheet then opens something on it, by calling the
   shell or with `shotPointer` (real moves, clicks and typing): an app's
   menu and submenu, the Ambrosia menu, the Dock's tooltip and menu,
   Control Center, Notification Center, banners, a confirmation, Search.
   A new surface gets a sheet; one that is only a picture (HudPanel,
   StackGrid, SwitcherStrip) can still have a sheet of its own.
   The first look found and fixed three things: Notification Center's
   cards' shadows were cut in a straight line by the list's clip, a card
   whose text wrapped was overlapped by the next app's, and the Dock
   placed its menus by `mapToItem(null)` (now its own `contentItem`).
   Still apart from the preview: Breeze's menu radius and row height (ours once
   the style above is switched on), real apps' icons (no Ambrosia icon theme),
   per-surface blur and saturation (KWin has one setting for all), and the
   control center's feathered blur edge (KWin's blur regions are hard-edged).
2. Gaps in the shell (Shell lane, 2026-11-10). **Notification Center** is
   on the clock, as macOS 26 (`NotificationCenter.qml`, its store
   `NotificationStore.qml`, one card for it and the banners): past
   notifications by app as stacks that spread, clear one, an app's or all,
   the Focus state on top, kept across restarts; Focus holds back banners,
   not the center. The moon shows in the bar while Do Not Disturb is on.
   **Dock**: drag an app to reorder, a running app's tile in to keep it, a
   pin out (Remove) to drop it; magnification follows `dockMagnification`
   (it did already). Files in the first place stays there, as Finder does:
   it isn't dragged or removed and nothing drops ahead of it. Checked
   headless on tenet (a copy of the shell showing
   the center in a layer window, `scratch/shell/mkview.sh`: menus and the
   center never map on a headless KWin) and in the VM (the clock opens it;
   stacks, the Calendar widget under it, light and dark; the Dock's drag
   reorders and saves, magnification swells the icon under the pointer,
   2026-11-10). Not tried in the VM: pulling a pin out, dragging a running
   app in. GTK menus: ambrosia-desktop depends on appmenu-gtk-module
   (tenet's settings.ini already loads it), which reaches the bar for GTK 3
   windows on X11 only: KWin offers no `gtk_shell1` (checked with
   wayland-info), so a Wayland GTK window can't name its menu, and GTK 4 has
   no modules (libadwaita apps have no menu bar anyway). Native GTK menus
   would need a bridge of our own (match the app's exported menu by PID).
3. **The Mac-first keyboard is built** (Packaging lane, 2026-11-10;
   `docs/keyboard.md` has the tables, the gaps and what was driven).
   ambrosia-desktop depends on keyd and carries `/etc/keyd/ambrosia.conf`:
   Super held is Ctrl for the app, with the system's shortcuts and a Mac's
   text keys written out; terminals get Ctrl+Shift and Files keeps ⌘ with
   the arrows, switched by the shell (`shell/KeyLayer.qml` writes the kind
   of app to `/run/ambrosia-keys`; `ambrosia-keys.service`, as its own user
   in keyd's group, applies the bindings filed under it). The installer and
   the live image enable keyd. **It is on only where `keyd.service` is
   enabled**: an existing system (tenet) changes nothing by upgrading, and
   gets it with `systemctl enable --now keyd` (Linux-first is `disable`).
   Driven in the VM from a fresh install. Konsole no longer hands ⌘ chords
   it has no use for to the shell (⌘C with nothing selected interrupted the
   job): the session's Konsole profile uses a key table of ours
   (`session/konsole/`, 2026-11-11; in the VM the chords did nothing, copy
   with a selection and paste worked, a plain Ctrl+C still interrupted; a
   profile of the user's own must choose the "Ambrosia" key bindings).
   Open: ⌘Q only where the app has Ctrl+Q; the question at install and the switch
   in Settings › Keyboard. **Trackpads too**: one nobody has set up comes up
   with natural scrolling and two-finger secondary click
   (`session/xdg/kcminputrc`, KWin's `[Libinput][Defaults][Touchpad]`; a
   value Settings saved wins, setting by setting), from the next login.
4. Distro gaps. **The login screen is ours** (2026-11-10,
   `packaging/sddm-theme`, current in ambrosia-desktop's sddm.conf; logged in
   through it in the VM; it replaces Breeze's at the next start of SDDM once
   the package is installed, unless System Settings' `kde_settings.conf`
   names another). **BIOS computers install too** (2026-11-10): the
   installer makes the disk boot the way the computer started, GPT and
   systemd-boot on UEFI, an MBR disk and syslinux (the new system's own) on
   a BIOS, the kernel on a FAT `/boot` either way; `VM_FIRMWARE=bios
   tools/vm.sh live|install|installed` tests it on SeaBIOS. **The BIOS boot
   menu has our picture** (`iso/syslinux/splash.svg`, rendered by
   `tools/build-iso.sh`); the UEFI menu is systemd-boot's text, which can't
   show one. The installer also puts mdns in nsswitch's hosts line (printers'
   `.local` names) and ambrosia-desktop brings ipp-usb; on a system installed
   before this, add `mdns_minimal [NOTFOUND=return]` ahead of `resolve` by
   hand. Still open: a license (Justin's call; the packages are public now,
   `license=(LicenseRef-TBD)`).
5. **The current image is `out/iso/ambrosia-2026.11.10-x86_64.iso`** in
   tenet's `~/work/ambrosia` (r385 of every ambrosia-* package, built from
   local packages, nothing published). Installed from it in the VM on
   2026-11-11 (UEFI, unattended, four minutes) and read back: every package
   at r385 with its files intact, no failed unit, `[ambrosia]` first in
   pacman.conf, our login screen taking the password, the shell and Files
   running from the first login, keyd and its pipe up. With real keys
   (QEMU's keyboard, so through keyd): Search opens Konsole, which is on
   our profile (⌘C with nothing selected leaves a job alone, Ctrl+C
   interrupts it, ⌘Q quits), opens Settings at a pane, finds a file and
   ⌘Return shows it in Files. The BIOS way was last installed from the r352
   image (2026-11-10, `~/work/ambrosia-packaging`); nothing in it has
   changed since. Not tried on real hardware; the SanDisk still has the
   2026-10-08 image. The whole test is one job on tenet, as root, holding
   the VM lock: `/var/tmp/fresh-all.sh` (image, install to
   `out/vm/fresh.qcow2`, log in, the checks in `/var/tmp/fresh2b.sh`, power
   off; 25 minutes; `tools/vm.sh install` alone would delete the Settings
   VM's firmware variables and its disk's backing file, which the job keeps).
   The Packaging lane's VM scripts are on tenet in
   `/var/tmp/ambrosia-packaging` (`vm-up.sh uefi|bios` boots an install with
   root SSH through systemd credentials, under either firmware).
6. Files (Finder parity, `docs/finder/PLAN.md`): search is Finder's since
   2026-11-10 (This Computer, names or contents read without touching Date
   Last Opened, Name/Kind/Date Last Opened), and so is the right-click menu
   with its tag colors and Tags…, with Undo Tags, sidebar tag colors and
   tags set while Files was off. Quick Look full screen and in the Trash and
   ⌘I on several items are checked. The sidebar's Locations lists other
   disks since 2026-11-10 (Solid; a click mounts and opens, the eject button
   unmounts and ejects the media or powers the drive down): driven in the
   VM with a hot-plugged QEMU USB stick and USB disk (lsblk and window
   titles read back; a disk in use gets Finder's alert and stays); a disc
   and drops on a disk's row weren't tried. Applications is in the sidebar
   too (`applications:/`: the desktop entries a launcher shows, by name and
   icon, in every view; opening one starts it): driven in the VM by keys
   (a new entry found and started, a NoDisplay one not listed, Kate
   started, ⇧⌘A); a double-click couldn't be made with the VM's `ui.py`
   (it didn't open a plain folder either). A copy or move that runs for
   over a second gets Finder's progress window (`FileOps.jobs`,
   `qml/ProgressWindow.qml`: a bar, the amount done, the time left, a stop
   button): driven in the VM with a stick read at 4 MB/s (a 48 MB paste
   shown and finished, another stopped by its button, a tiny one with no
   window); two at once, a move and the Trash weren't tried. Files runs
   from the first login of a fresh install (checked in the VM,
   2026-11-11). Next: the plan's "Still short of
   Finder" list (Open With and Compress in the menu, tag rename and
   delete, spring-loaded folders, Quick Look's black full screen).
7. Settings (docs/settings/PLAN.md): steps 1–6 are built. Step 6 (Battery/
   Energy, Lock Screen, Login Password, Users & Groups, Privacy & Security)
   was driven for real in the VM on 2026-11-10 (Battery against
   scratch/settings/fake-upower.py, as no machine here has a battery); its
   sheets' layouts (Battery Health, Charging, Options…, Change Password, a
   user's ⓘ, Add User…, Privacy's lists) are ours until the Mac's photos:
   run scratch/settings/mac-sheets7.sh when the Mac is unlocked and idle.
   Update Now now asks for an administrator's password (our polkit rule).
   Step 7 has begun: Keyboard (repeat and delay in the Mac's steps,
   backlight, Input Sources) and Mouse (KWin's InputDevice settings,
   double-click speed) were driven in the VM on 2026-11-10: each slider step
   read back from KWin (`wayland-info` for the repeat, the InputDevice
   properties for the mouse), and the run found double-click speed never
   reaching kdeglobals (fixed). Not seen there: the keyboard backlight row
   (no such keyboard on the VM or tenet). Trackpad (tracking speed,
   secondary click, tap to click, natural scrolling; KWin's touchpad
   settings) was driven the same day against a virtual clickpad
   (`scratch/settings/fake-touchpad.py`, uinput): real taps and presses on
   it clicked or didn't as set. No real trackpad has been tried. Its
   gesture demo, tabs and More Gestures are left out (nothing here acts on
   them). Printers & Scanners is on CUPS (2026-11-11): its own queues and
   the printers it finds on the network (which print without being added),
   the default printer and paper size (yours, `~/.cups/lpoptions`, written
   by us: lpoptions saves nothing while CUPS has no queue of its own), Add
   Printer… by address (driverless only), a printer's sheet with a test
   page and Remove Printer…. Driven in the VM against two `ippeveprinter`
   printers: found, made default, paper size, added by address as the wheel
   user with no password, test page received, removed, an unreachable
   address's error; a removed printer's saved defaults go with it.
   Left out: scanners, the queue window, Options &
   Supplies…, sharing, USB printers that need a driver. No real printer
   has been printed to. Accessibility (2026-11-11) lists the Mac's
   sections that act here: Zoom (or the lens, with KWin's own keys shown),
   Display (color filters, shake to locate, pointer size), Motion (reduce
   motion, a steady cursor), Audio (flash for an alert), Keyboard (Sticky
   and Slow Keys), Pointer Control (Mouse Keys, and with a trackpad that
   taps, dragging by tapping with or without drag lock: read back from
   KWin in the VM, the drag itself not performed). Driven in the VM: every
   switch read back from kwinrc, kaccessrc, kcminputrc and kdeglobals, the
   effects loaded and unloaded in the running KWin, and Sticky Keys
   latched Shift for real; the others' effect on screen wasn't watched.
   Left out: VoiceOver and speech (no screen reader installed), Invert
   (KWin can't say whether it's on), captions, Voice and Switch Control.
   Spotlight (2026-11-11) says which kinds of result Search shows: the
   shell's Search finds apps, Settings' panes, sums, and now files and
   folders by name, asked of Files' index over D-Bus
   (`org.ambrosia.Files.Find`; Files runs from login) and drawn with Files'
   folder and document art (`ambrosia-folder`, `ambrosia-document` in
   hicolor, from ambrosia-theme) or the thumbnail the cache already has.
   The pane's switches (Calculator, System Settings; Apps, Files, Folders)
   write settings.json's `searchOff`. Driven in the VM: names with accents
   found, Return opened a file in Kate and a folder in Files, each switch
   read back and seen to drop its kind, light and dark. ⌘Return shows a
   file in its folder, selected: Files answers
   `org.freedesktop.FileManager1` (ShowItems, ShowFolders,
   ShowItemProperties), so other apps' Show in Folder comes to Files too
   (driven in the VM by busctl and from Search; a browser's own Show in
   Folder wasn't tried). Where a Dolphin already holds that name (tenet's
   session has one), Files waits in line for it and Search asks Files by
   its own name (driven in the VM through the shell with another program
   holding the name; on tenet since r383).
   Files' ⓘ opens the Mac's sheet of file kinds (Developer, Documents,
   Images, Movies, Music, Others, PDFs, Presentations, Spreadsheets): the
   shell sorts a file by its name's ending and leaves out the kinds turned
   off (`files:images` in `searchOff`; driven in the VM). Left out: what
   Search doesn't have (history, clipboard, other apps' content, menu
   items), Hidden File Types, Search Privacy…, and searching inside files.
   Mac-first trackpad
   defaults (KWin starts a new pad with corner clicks and natural scrolling
   off) are with the Packaging lane. Step 6's Mac photos were taken 2026-11-11
   (`out/settings/mac/sheets/bat-*`, `lock-*`, `pw-change`, `priv-*`) and
   our wording and menus follow them now, and a user's ⓘ sheet is laid out
   as the Mac's (`users-info-nosheet.png`: picture on top, User name and
   Password, the admin switch, Cancel and OK; seen in the VM).
   Add User… and the lock message's Set… weren't reached (an earlier sheet
   was still up), and Battery Health's ⓘ opened nothing: those stay our
   own design.

## Needs Justin

- **tenet's session wants a fresh login** (not urgent). Its KWin has run
  since 2026-10-16, across a system upgrade (it is 6.8.0 in memory, 6.8.2
  on disk). It keeps the ⌘Tab layout and window frame it loaded, so the
  blur behind ⌘Tab and anything else KWin-side from 2026-11-18 show after
  logging out and in. Its own shortcuts (Alt+Tab, Meta+W…) were also dead
  in the global-shortcut daemon, cause unknown; they were switched back on
  by hand (see Gotchas), which a login does properly.
- Publishing needs the signing key copied from its backup into
  `~/.config/ambrosia/gnupg`.
- tenet starts in text still: the picture (round 29) needs `sudo pacman -S
  plymouth && sudo /usr/lib/ambrosia/boot-picture` there and a restart to
  see it. It rebuilds the initramfs, so it was left for Justin.
- The image's UEFI boot menu is plain text (systemd-boot draws no pictures).
  A picture there means starting the image with GRUB instead (archiso's
  `uefi.grub`), a boot path not yet proven on tenet's hardware: wanted?
- Master's packages (Settings through step 7, the shell's Notification
  Center, Dock and Search, the keyboard layer, the login screen) are not
  published: publishing pushes to the public ambrosia-packages repo. Say
  when.
- tenet runs master's packages since 2026-11-18, ambrosia-desktop
  included. That pulled in keyd, which is **off** (`systemctl enable --now
  keyd` remaps the live keyboard: Super becomes Command) and makes SDDM use
  our login screen at its next start: say whether tenet should get the
  keyboard layer too.
- Files' memory target #13 (≤120 MB): count own memory (USS, met at 119-123
  MB with the 100k folder) or RSS (a bare Qt Quick window is already 177 MB)?

## Machines

- **This Mac** (since 2026-11-16): a Mac mini (M4, 16 GB, macOS 26,
  `justins-mac-mini-1` on the tailnet); the repo is at
  `~/code/github.com/justin06lee/ambrosia`. bun and gh are set up, and Homebrew's qtbase, cmake and
  ninja (for `make gallery`, the Qt widget style) and qtdeclarative with
  qtsvg (for `make shell-shots`, pieces of the shell); no Quickshell, KDE,
  GTK, Inter, Docker or VM tool. tenet takes this Mac's key since
  2026-11-18 (`ssh tenet` is justin06lee, `ssh root@tenet` root). Two things didn't come across from the MacBook and the
  T7 drive: **the signing key**
  (`~/.config/ambrosia/gnupg`; its backup is on the T7, so nothing can be
  published from here until it's restored) and the old worktrees
  (`.worktrees/` on the T7; their branches are all merged). The Makefile
  and `tools/remote.sh` reach tenet by its Tailscale name now
  (`justin06lee@tenet`), with the MacBook's key where it exists and this
  Mac's usual one otherwise.
- **The MacBook** (8 GB, before 2026-11-16): where the repo used to live
  (`/Volumes/T7/Stockpile/Workspace/github.com/justin06lee/ambrosia`), with
  the key tenet knows (`~/.ssh/id_ed25519_justin`).
- **tenet:** i7-10700, 16 GB, GTX 1660 Ti on nvidia-open, an LG UltraGear
  over HDMI at 2560x1440, now running Ambrosia (one 915 GB root partition).
  **The user gave full permission to run any command on tenet as root**
  (2026-10-07).
  - Until the restore brings makima back, reach it over plain SSH:
    `ssh -i ~/.ssh/id_ed25519_justin -o IdentitiesOnly=yes root@192.168.1.172`
    (Wi-Fi, DHCP; the address may change); `justin06lee@` the same for
    user work. The repo's tools default to that over SSH.
  - **Its checkout is a real git clone** (since 2026-10-21):
    `~/work/ambrosia` (`/home/justin06lee/work/ambrosia`), cloned from the
    bare repo `~/git/ambrosia.git`, which the Mac pushes to over SSH (no
    GitHub credentials on tenet). Build output, the ISO and the VM live in its
    `out/`. The old rsynced `~/ambrosia` is no longer used.

## How the work runs

- **The Mac (8 GB) only edits, runs git and signs packages; heavy work runs
  on tenet.** `make remote-build` runs the build gate (tests, generator,
  review site) on tenet, capped; it must pass after the last change.
  `make review-remote` serves the review site from tenet through an SSH
  tunnel on localhost:4747. `make shot-remote` photographs the preview in
  headless Firefox on tenet into `out/shots/preview.png` (`PAGE='preview/index.html?theme=dark'`
  or a URL such as the review site's, `SHOT=name`); it shows layout and
  colour but not the glass blur. `qmllint` is
  `tools/remote.sh justin06lee@tenet '/usr/lib/qt6/bin/qmllint shell/*.qml'`.
  `open preview/index.html` opens the preview
  (`?theme=dark&accent=honey&open=cc|view-menu`; D and A switch theme and
  accent).
- **tenet, from the Mac:** `tools/remote.sh justin06lee@tenet <cmd>`
  pushes HEAD to tenet's bare repo, checks it out in `~/work/ambrosia`, lays
  any uncommitted changes over it (rsync, without `.git`, `.ruri` and `out/`),
  and runs `<cmd>` there. Put heavy commands under the cap (below).
  - `make package` (user) builds the ambrosia packages into `out/pkg/`;
    `make quickshell` rebuilds Quickshell. Install with
    `pacman -U out/pkg/*.pkg.tar.zst` as root.
  - `make iso` as root, in `/home/justin06lee/work/ambrosia`
    builds `out/iso/ambrosia-*.iso` (~15 minutes; the pacman cache makes
    rebuilds faster). Cap it like every build on tenet:
    `systemd-run --unit=ambrosia-iso -p MemoryMax=6G -p Nice=19 -p IOSchedulingClass=idle -p WorkingDirectory=/home/justin06lee/work/ambrosia make iso`.
  - **Testing the shell in the live session** (2026-10-13 loop): rsync
    `shell/` onto `/usr/share/ambrosia/shell/` and
    `systemctl --user -M justin06lee@ restart ambrosia-shell`; photograph
    with `spectacle -b -n -f -o` run as the user with `XDG_RUNTIME_DIR`,
    `DBUS_SESSION_BUS_ADDRESS` and `WAYLAND_DISPLAY=wayland-0`; click and
    type with `/root/ui.py` (a python-evdev absolute pointer and keyboard:
    `ui.py click X Y`, `rclick`, `key super+space`, `type text`). The
    session's Wayland socket is `wayland-1` now. A locked
    or blanked screen photographs black: `tools/live.sh unlock` (and `lock` after; they look the session up, as its number changes with each login; by hand `loginctl unlock-session`),
    `kscreen-doctor --dpms on`, and hold `kde-inhibit --screenSaver` while
    testing. The shell logs to the user journal.
  - `tools/shot.sh out.png` photographs the installed shell on a headless KWin
    (virtual backend, private D-Bus), without touching the logged-in desktop.
    `AMBROSIA_SHELL=$HOME/ambrosia/shell AMBROSIA_WALLPAPERS=/usr/share/ambrosia/wallpapers`
    runs the checkout's shell instead.
  - `tools/vm.sh live|install|installed|shot|key|stop` runs the image in a
    headless QEMU VM (state in `out/vm/`). `install` boots with
    `ambrosia.autoinstall`, which installs to the VM's disk with test answers
    (user `test`, password `ambrosia`) and powers off.
  - `sudo tools/repo-test.sh` tests the hosted repo: it installs the newest
    image in the VM, boots the installed system into `tools/repo-check.sh`
    alone (a 9p share, and a command line systemd-boot reads from SMBIOS),
    which runs `pacman -Syu` and installs from the repo, and prints its
    report. Publish packages newer than the image first, so it upgrades.
- **Publishing packages, from the Mac:** `make publish` (or
  `tools/publish-repo.sh [user@host]`). It syncs to tenet's checkout with
  tools/remote.sh and builds there (`make package`, plus
  `make quickshell` when the release lacks the version in
  `packaging/quickshell/PKGBUILD` and tenet's `out/pkg` doesn't have it yet),
  signs on the Mac, uploads, and drops the versions it replaced. **Builds on
  tenet are capped** (`systemd-run --user --scope -p MemoryMax=6G nice -n 19
  ionice -c3 env MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2`: two jobs,
  without which ninja's 18 run into the 6G and the build is killed;
  `make quickshell` takes about six minutes so): tenet has no swap and runs other projects'
  services (mira's gateway), and an uncapped Quickshell build (ninja's 18
  jobs) starved it on 2026-10-21. Its disk is one hard drive: when other
  work saturates it (`/proc/pressure/io` above ~50%), the idle-class build
  waits, so run `make publish` with room to finish (it took 2 hours on
  2026-10-21). If its Mac side dies, makepkg on tenet dies too; stop its
  `run-*.scope` there if it lingers and rerun: with a clean tree, a run whose
  build had finished picks the packages up from tenet's `out/pkg`.
  **The signing key** (ed25519, fingerprint
  `2DB46FDF911241FC9406002BCF43580DA0F59EB8`, no passphrase) lives only in
  `~/.config/ambrosia/gnupg` on the Mac, backed up with its revocation
  certificate in `/Volumes/T7/Backups/ambrosia-signing/`. Without it, installed
  systems can't trust new packages: keep the backup.
- **The review server** may still be running detached from an earlier
  session: PID in `/tmp/ambrosia-review.pid`, logs in `/tmp/ambrosia-review.log`.
- **Conventions** (the zanka and omniscience skills): bun only; the default
  branch is `master`; one branch per feature, merged with `--no-ff` and tagged
  (`feat-<slug>`); conventional commits ending with the Co-Authored-By line;
  the README stays current; stop any server you start unless asked to keep it.
- **Change design values in `design/tokens.ts`, never in `dist/`.** Keep
  `DESIGN.md` general: exact numbers belong in tokens and the preview.
- **ruri:** the component library has "the design preview desktop", "the
  design review site" and "the real menu bar" (the QML one in `shell/`). After changing one, `ruri edit <slug> --shot …`.
- **Check visual work** by looking at it: the bridge browser for the preview,
  `tools/shot.sh` or `tools/vm.sh shot` for the real shell.

## Gotchas

- **A QML Canvas reads pixels back in the screen's units and a frame
  late.** `getImageData(0, 0, w, h)` takes device pixels (the top-left
  quarter at 2×), and after `drawImage(anImageItem)` it returned the frame
  before. `shell/StatusIcon.qml` has the canvas load the icon itself
  (`loadImage`), reads `size × Screen.devicePixelRatio`, and only counts
  pixels; the recolor is a `source-in` fill, never a write of pixel data.

- **A name in the icon theme answers for more than itself.** KDE looks a
  name up in one theme at a time, and inside a theme cuts a missing name
  down word by word before it asks the next theme: with "folder" in ours,
  Breeze's `folder-new` is our folder; with `preferences-desktop`, every
  settings module was our gear (rounds 2 to 10); a bare `audio-x-generic`
  would take `audio-volume-high`. So: never name a whole type's fallback
  (`text-x-generic`, `image-x-generic`, …), spell kinds out, and when a
  name is added run `bun test`: it replays KDE's rule
  (`tools/gen/lookup.ts`) over Breeze's names
  (`tools/gen/breeze-names.txt`, with the command that lists them again)
  and fails on an action, status or settings icon we'd take. KDE also
  merges a theme's folders from every data dir: a copy in
  `~/.local/share/icons/Ambrosia` adds to `/usr/share/icons/Ambrosia`, it
  doesn't replace it.
- **`tools/remote.sh` leaves `.worktrees/` behind** (old worktrees, 9 MB,
  untracked on tenet, so each run cleaned and re-sent them: a sync could
  take two minutes on a slow link).

- **Looking at a change on tenet's live session** (`tools/live.sh`: run,
  click, type, photograph, run a KWin script). What cost time on 2026-11-18:
  - Start an app with `tools/live.sh run <app>` (systemd-run, the session's
    whole environment). From the SSH shell it lacks
    `~/.config/kdedefaults` in `XDG_CONFIG_DIRS` and comes up in Breeze's
    colors and style.
  - **A running KWin keeps the QML and plugins it loaded**: a changed
    ⌘Tab layout or frame shows at the next login. To try a layout now,
    copy it under a new name (see ⌘Tab in Next 1), a new name each edit.
  - **`kwriteconfig6 --delete` on a key a system file sets leaves
    `Key[$d]`** in the user's file, which hides the system's value: take
    the line out by hand.
  - **KWin's own shortcuts can be dead while every other app's work**
    (Alt+Tab and Meta+W did nothing; the volume keys did). They were "not
    present" in the global-shortcut daemon KWin itself hosts:
    `qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.isActive`
    said false. `tools/live.sh keys` marks them present again. Why they
    dropped out isn't known (the session was a month old and had been
    upgraded under); locking and `reconfigure` don't do it.
  - **Wake the display first** (`tools/live.sh ui move 600 400`): locked,
    it sleeps, KWin draws nothing, and a picture comes out dim with the
    shell's old windows still fading under the new.
  - The shell's settings are `~/.config/ambrosia/settings.json`, watched:
    edit `dockPosition`, `appearance` and `dark` there to see a left Dock
    or dark mode, from a backup you put back.
  - To hold a key for a picture: `ui.py kdown alt key tab sleep 5 kup alt`
    in the background and `spectacle` meanwhile, both on tenet (an SSH
    round trip is too slow).
- **Quickshell must be built against the Qt it runs on** (it uses Qt
  internals). When Arch updates qt6-base, bump `pkgrel` in
  `packaging/quickshell/PKGBUILD` and `make publish`.
- **pacman takes a package from the first repo that has it**, whatever the
  version: on `-Syu` it compares only with that repo's, and says "local is
  newer" rather than downgrade. So ours wins where `[ambrosia]` comes first
  (and ambrosia-shell needs `quickshell-dbusmenu-source`, which only our build
  provides). A system without `[ambrosia]` takes Arch's quickshell on `-Syu`
  and loses the app menus: tenet did on 2026-10-16.
- **GitHub renames release assets**: `:` and `~` become `.` (`+` survives),
  so a package version with an epoch would 404; `publish-repo.sh` refuses such
  names. Assets can't be symlinks, so `ambrosia.db` and `.files` are uploaded
  as real files.
- **Plasma writes its look-and-feel's defaults into `~/.config/kdedefaults`
  at login and puts that directory first in `XDG_CONFIG_DIRS`**, ahead of
  `/etc/xdg/ambrosia`. Anything a look-and-feel sets (color scheme, widget
  style, icons, cursor, decoration, splash) must be set in our look-and-feel
  package, not in `/etc/xdg/ambrosia` alone.
- **KWin's blur is one setting for every surface**: `[Effect-blur]`
  `BlurStrength` (its default is stronger than 9) and `Saturation` (an
  integer, 100 = none; its default boosts color like the preview's 160-180%
  glass). `org.kde.KWin.reconfigure` doesn't reload them: call
  `/Effects reconfigureEffect blur`. It doesn't unload effects either
  (`unloadEffect fadingpopups`).
- **The installed shell doesn't reload itself when its files change**
  (`settings.watchFiles` in `shell.qml`): pacman replaces them one at a time,
  and Quickshell reloading partway through found no `shell.qml` and stayed
  down. ambrosia-shell's pacman hook (`session/ambrosia-shell-restart.hook`)
  restarts running shells after an upgrade of the shell, the Theme module or
  Quickshell. After rsyncing `shell/` onto a system, restart it yourself.
- **Plasma rewrites `~/.config/kdedefaults` only when the look-and-feel
  package's name changes** (`kdedefaults/package`), so keys added to our
  look-and-feel's `defaults` never reach existing users. Settings no
  look-and-feel touches (Breeze's `breezerc`) go in `/etc/xdg/ambrosia`; the
  window decoration, which it does set, `startambrosia` copies from the
  look-and-feel into `kdedefaults/kwinrc` at every login.
- **KWin rounds a decorated window's content to the decoration's
  `setBorderRadius`** (KDecoration3, Plasma 6.3+), so the plugin rounds all
  four corners; the window shadow is the decoration's own image, painted
  once per mode and focus (`decoration/src/shadow.cpp`). Plasma's task model only puts a pinned app's windows at its
  launcher (`launchInPlace`) with `separateLaunchers: true`.
- **Quickshell loads QML from a virtual `qrc:/qs-blackhole` base**, so
  relative URLs and `Qt.resolvedUrl` don't point at files. Build file URLs
  from `Quickshell.shellDir` with an explicit `file://`. A file loaded that
  way gets its own copies of the shell's singletons (Apps, Popups...), so
  pass it values instead (see `AppMenu.qml`).
- **Apps only send their menus to the bar while `org.kde.kappmenuview` is on
  the bus** (Plasma's appmenu kded only collects them then). `Apps.qml` holds
  the name with `dbus-test-tool black-hole`.
- **Menus keep the app's window active; Search doesn't.** Menus, the control
  center and confirmations draw on a grabbing popup of the menu bar
  (`Overlay.qml`): KWin sends it the keys without activating it. A layer
  surface taking the keyboard (Search) becomes KWin's active window. The
  popup spans the whole screen with the bar's strip masked out, since Qt
  hands it the bar's pointer events first, by position. The menu bar still
  freezes its app while one is open (`Apps.frozen`), and window actions
  capture their window when the menu opens.
- Pinned apps' ids from the task model end in `.desktop`; running ones don't
  (`Apps.entryFor`).
- **QML rejects ECMAScript keywords as property names.** The generator renames
  them with a trailing underscore (`Theme.size.switch_`); a test guards it.
- KWin's blur strength is one global setting, not per surface; per-material
  blur needs the phase 4 compositor effect.
- Bun's hot reload re-imports `with { type: "text" }` markdown wrongly after a
  `.md` changes, so the review server runs with `hmr: false`.
- Fractional space tokens are `--amb-space-1_5` / `--amb-space-0_5` in CSS
  (underscore). An unknown `var()` silently breaks the property.
- Count tokens (like `columns`) are emitted without `px`.
- A blurred backdrop isn't clipped by a parent's rounded corners, so the
  surface must round itself. The same applies to KWin blur regions.
- Bun's CSS bundler can reorder `<link>`ed stylesheets, so the site
  `@import`s `preview/glass.css` to keep the cascade order.
- The Mac's `openrsync` works with `rsync -e 'makima possess'`; macOS `tar`
  adds AppleDouble files, so use rsync, not tar pipes.
