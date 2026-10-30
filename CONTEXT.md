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
    `settings/`; both x86_64) and `ambrosia-desktop` (the meta package: SDDM,
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
    Ambrosia menu, the focused app's name and its own menus over DBus, Wi-Fi,
    Search, control center, clock), Search on Super+Space, the Dock, the
    control center (every control acts) and notification banners. KWin's
    window list comes through Plasma's task manager model (`Apps.qml`),
    granted by `session/org.ambrosia.shell.desktop`. Menus, the control
    center and confirmations draw on each screen's `Overlay`; their state is
    `Popups.qml`. The look still trails the preview: function came first.
  - `iso/`: archiso profile from Arch's releng: live user autologin into the
    Ambrosia session, NetworkManager, the Ambrosia packages as a local repo on
    the image (`/opt/ambrosia/repo`, listed first in pacman.conf), and the
    installer (`ambrosia-install` asks with kdialog and joins Wi-Fi itself when
    offline, `ambrosia-install-system` installs as root; UEFI only; needs the
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
  `/etc/pacman.conf.before-ambrosia`), and it runs the r291 packages with our
  Quickshell, installed with `pacman -U`, except `ambrosia-desktop` (r221):
  r224 on adds power-profiles-daemon, CUPS, Avahi and nss-mdns, which would
  come from a newer package list than tenet's, a partial upgrade. It hasn't synced since 2026-10-16
  (no `-Syu` while a GPU training job ran), so its next `pacman -Syu` fetches
  the hosted repo. gpg prints `release_dotlock: lockfile error` when its
  keyring is populated, but the key ends up trusted.

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
   wide, 23 apart); GTK 4's CSS is untested, as tenet has no GTK 4 app. A
   running KWin keeps the plugin it loaded, so a new frame shows after the
   next login (test it in a nested `kwin_wayland --wayland-display`).
   The Dock's Trash is Mac-style since 2026-10-21: the current macOS
   frosted bin, redrawn by hand and matched 1:1 against a screenshot (empty
   is the full bin without its paper: no empty screenshot to match), full or empty with the home trash
   (other drives' trashes aren't watched), and it takes dropped files.
   Files has its own Finder-style icon (2026-10-21, `assets/icons/`, hicolor
   `org.ambrosia.files`); until Ambrosia's Files app exists, Dolphin's Dock
   pin shows as Files with it (`standIns` in `shell/Dock.qml`).
   Still apart from the preview: Breeze's menu radius and row height (only our own
   QStyle could change them), real apps' icons (no Ambrosia icon theme),
   per-surface blur and saturation (KWin has one setting for all), and the
   control center's feathered blur edge (KWin's blur regions are hard-edged).
2. Gaps in the shell: no notification center or Focus icon in the bar, no Dock magnification or drag to reorder, GTK apps' menus don't
   reach the bar (needs appmenu-gtk-module).
3. The Mac-first keyboard layer with keyd.
4. Distro gaps: an SDDM theme of our own, BIOS boot (the installer is
   UEFI-only, though the image boots BIOS), boot menu art, and a license
   (Justin's call; the packages are public now, `license=(LicenseRef-TBD)`).
5. Rebuild the image when the user wants to reflash: the SanDisk still has
   the 2026-10-08 image without this shell.

## Machines

- **This Mac:** where the repo lives
  (`/Volumes/T7/Stockpile/Workspace/github.com/justin06lee/ambrosia`). No Qt or
  GTK; Docker is installed but its daemon is off. Don't start Docker Desktop
  without asking.
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
  `tools/remote.sh justin06lee@192.168.1.172 '/usr/lib/qt6/bin/qmllint shell/*.qml'`.
  `open preview/index.html` opens the preview
  (`?theme=dark&accent=honey&open=cc|view-menu`; D and A switch theme and
  accent).
- **tenet, from the Mac:** `tools/remote.sh justin06lee@192.168.1.172 <cmd>`
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
    or blanked screen photographs black: `loginctl unlock-session`,
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
  ionice -c3` with two jobs): tenet has no swap and runs other projects'
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
