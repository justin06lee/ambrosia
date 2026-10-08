# ambrosia: context for the next session

Read this first when picking the project back up. It records where things
stand, how the work runs, and what's next. The README covers the project
itself, `design/DESIGN.md` the rules, and `design/DECISIONS.md` the choices.

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

There is no git remote yet, so nothing has been pushed.

- **Design system (phase 1), done.** `design/tokens.ts` holds every value;
  `tools/gen` generates GTK 4/3, KDE color schemes plus session `kdeglobals`, a
  QML `Theme` singleton, fontconfig and CSS into `dist/`. `preview/` is the HTML
  mock of the desktop the real shell must match; `site/` is the review site.
- **Distro pipeline, first cut** (branch `feat/distro-pipeline`):
  - `packaging/PKGBUILD` builds `ambrosia-theme` (themes, wallpapers),
    `ambrosia-shell` (the QML shell, the session, KDE/KWin defaults) and
    `ambrosia-desktop` (the meta package: SDDM, portals, NetworkManager,
    PipeWire, Bluetooth, Konsole, Dolphin, System Settings, GTK skel).
  - `packaging/quickshell/PKGBUILD` is our Quickshell build, pinned to an
    upstream master commit with the Qt 6.12 fix (Arch's 0.3.1 was built for Qt
    6.11 and can't be rebuilt for 6.12 without it).
  - `session/`: `startambrosia` runs Plasma's session (`startplasma-wayland`)
    with `XDG_SESSION_DESKTOP=ambrosia`; `ambrosia-shell.service` runs
    Quickshell and a drop-in keeps plasmashell from starting, both keyed on that
    variable (so does a drop-in for Plasma's splash). Defaults in
    `/etc/xdg/ambrosia` (via `XDG_CONFIG_DIRS`): window buttons left in Mac
    order, no hot corner, Inter fonts, and the `org.ambrosia.desktop`
    look-and-feel package (`session/look-and-feel/`), which carries the
    Ambrosia color scheme.
  - `shell/`: wallpaper and menu bar (logo, app name, menus, status icons,
    clock) on `import Ambrosia`, thin glass through KWin's blur. The app name
    and menus are fixed ("Files") until the window bridge exists.
  - `iso/`: archiso profile from Arch's releng: live user autologin into the
    Ambrosia session, NetworkManager, the Ambrosia packages as a local repo on
    the image (`/opt/ambrosia/repo`, listed first in pacman.conf), and the
    installer (`ambrosia-install` asks with kdialog, `ambrosia-install-system`
    installs as root; UEFI only; needs the internet).
- **Verified in a VM on tenet** (2026-10-07): the image boots into the live
  Ambrosia session with the installer open; both the interactive installer
  (driven with keys) and the unattended one install, and the installed system
  boots to SDDM (Breeze theme, Wayland greeter, Ambrosia preselected) and logs
  into the menu bar desktop with no splash. Not yet tried on real hardware.
  The current image is `out/iso/ambrosia-2026.10.07-x86_64.iso` on tenet.
- **tenet has the packages installed**, so "Ambrosia" is a session on its GDM
  login screen. The user hasn't logged into it yet.

## Next

1. Have the user log into the Ambrosia session on tenet and judge the menu bar
   by feel; tune KWin's blur strength (global, `[Effect-blur]` in
   `session/xdg/kwinrc`) against the preview's thin material.
2. **The KWin window bridge**: KWin offers no window-list protocol Quickshell
   can read (no wlr or ext foreign-toplevel; plasma-window-management is
   restricted). Needed for the menu bar's app name and the dock's running dots.
   Likely a KWin script plus a small helper, or a C++ QML plugin on the
   plasma window-management protocol with a desktop file that grants it.
3. The dock, then the control center (Quickshell has Pipewire, Bluetooth,
   Networking and UPower modules), then notifications (Quickshell's
   NotificationServer, since plasmashell's is gone) and the launcher.
4. The Mac-first keyboard layer with keyd (system-wide, so ask before enabling
   it on tenet, where GNOME is still the daily session).
5. Distro gaps: an SDDM theme of our own (Breeze from plasma-desktop for now), `os-release`
   branding, a hosted package repo (installed systems have no `[ambrosia]`
   repo, so they can't update Ambrosia's packages yet), BIOS boot, our own
   boot menu art (syslinux still shows Arch's splash), a license.

## Machines

- **This Mac:** where the repo lives
  (`/Volumes/T7/Stockpile/Workspace/github.com/justin06lee/ambrosia`). No Qt or
  GTK; Docker is installed but its daemon is off. Don't start Docker Desktop
  without asking.
- **tenet:** i7-10700, 16 GB, GTX 1660 Ti on nvidia-open, 4K over HDMI, Arch,
  GNOME 51 as the user's daily session (still on GDM), plus KWin/Plasma 6.7,
  our Quickshell, archiso, QEMU/OVMF. **The user gave full permission to run
  any command on tenet as root** (2026-10-07). It was fully upgraded that day;
  the new kernel and NVIDIA driver take effect at its next reboot.
  - `makima possess tenet '<cmd>' < /dev/null` runs as root;
    `makima possess justin06lee@tenet '<cmd>'` as the user. The "Logging in as
    root" banner goes to stderr, so stdout is clean (base64 files back with it).
  - The checkout lives at `/home/justin06lee/ambrosia` (`/home` has 700 GB free;
    `/` only ~25 GB).

## How the work runs

- **Mac:** `make build` is the build gate (tests, generator, review site); it
  must pass after the last change. `bun run review` serves the review site on
  :4747. `open preview/index.html` opens the preview
  (`?theme=dark&accent=honey&open=cc|view-menu`; D and A switch theme and
  accent).
- **tenet, from the Mac:** `tools/remote.sh justin06lee@tenet <cmd>` rsyncs
  the checkout over makima and runs `<cmd>` in it.
  - `make package` (user) builds the ambrosia packages into `out/pkg/`;
    `make quickshell` rebuilds Quickshell. Install with
    `pacman -U out/pkg/*.pkg.tar.zst` as root.
  - `make iso` as root (`makima possess tenet 'cd /home/justin06lee/ambrosia && make iso'`)
    builds `out/iso/ambrosia-*.iso` (~15 minutes; the pacman cache makes
    rebuilds faster).
  - `tools/shot.sh out.png` photographs the installed shell on a headless KWin
    (virtual backend, private D-Bus), without touching the logged-in desktop.
    `AMBROSIA_SHELL=$HOME/ambrosia/shell AMBROSIA_WALLPAPERS=/usr/share/ambrosia/wallpapers`
    runs the checkout's shell instead.
  - `tools/vm.sh live|install|installed|shot|key|stop` runs the image in a
    headless QEMU VM (state in `out/vm/`). `install` boots with
    `ambrosia.autoinstall`, which installs to the VM's disk with test answers
    (user `test`, password `ambrosia`) and powers off.
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

- **Quickshell must be built against the Qt it runs on** (it uses Qt
  internals). When Arch's Quickshell lags a Qt update, `make quickshell`; the
  `[ambrosia]` repo is first in the image's pacman.conf so our build wins.
- **Plasma writes its look-and-feel's defaults into `~/.config/kdedefaults`
  at login and puts that directory first in `XDG_CONFIG_DIRS`**, ahead of
  `/etc/xdg/ambrosia`. Anything a look-and-feel sets (color scheme, widget
  style, icons, cursor, decoration, splash) must be set in our look-and-feel
  package, not in `/etc/xdg/ambrosia` alone.
- **Quickshell loads QML from a virtual `qrc:/qs-blackhole` base**, so
  relative URLs and `Qt.resolvedUrl` don't point at files. Build file URLs
  from `Quickshell.shellDir` with an explicit `file://`.
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
