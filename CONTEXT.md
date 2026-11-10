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
  `/etc/pacman.conf.before-ambrosia`). On 2026-11-09 it had a full
  `pacman -Syu` (214 packages, r316 of every ambrosia-* package, Arch
  current; backups in `/var/tmp/ambrosia-syu`), and avahi-daemon, cups.socket
  and power-profiles-daemon were enabled as the installer does. Kernel 7.2.14
  is installed but it still runs 7.2.10 until a reboot (the running kernel's
  modules were put back in `/usr/lib/modules`). On 2026-11-11 it got r369
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
   Driven in the VM from a fresh install. Open: ⌘C in Konsole with nothing
   selected interrupts (Konsole hands the unused Ctrl+Shift+C to the shell);
   ⌘Q only where the app has Ctrl+Q; the question at install and the switch
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
   tenet's `~/work/ambrosia-packaging` (r352 of every ambrosia-* package,
   built from local packages, nothing published). Installed from it in the
   VM both ways on 2026-11-10, UEFI and BIOS: our login screen, the desktop,
   Settings and Files open, Files running from the first login, keyd and its
   pipe up. Not tried on real hardware; the SanDisk still has the
   2026-10-08 image. The Packaging lane's VM scripts are on tenet in
   `/var/tmp/ambrosia-packaging` (`vm-up.sh uefi|bios` boots an install with
   root SSH through systemd credentials, under either firmware).
6. Files (Finder parity, `docs/finder/PLAN.md`): search is Finder's since
   2026-11-10 (This Computer, names or contents read without touching Date
   Last Opened, Name/Kind/Date Last Opened), and so is the right-click menu
   with its tag colors and Tags…, with Undo Tags, sidebar tag colors and
   tags set while Files was off. Quick Look full screen and in the Trash and
   ⌘I on several items are checked. Next: login autostart on a fresh system
   (the VM), then the plan's "Still short of Finder" list (sidebar
   Applications and drives, Open With and Compress in the menu, tag rename
   and delete, Quick Look's black full screen).
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
   and Slow Keys), Pointer Control (Mouse Keys). Driven in the VM: every
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
   its own name: on master after r369, checked on a private bus on tenet
   but not yet through the shell in the VM, and not installed on tenet.
   Left out: what Search doesn't have (history,
   clipboard, other apps' content, menu items), Files' sheet of file
   kinds, Search Privacy…, and searching inside files. Mac-first trackpad
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

- The image's UEFI boot menu is plain text (systemd-boot draws no pictures).
  A picture there means starting the image with GRUB instead (archiso's
  `uefi.grub`), a boot path not yet proven on tenet's hardware: wanted?
- Master's packages (Settings through step 7, the shell's Notification
  Center, Dock and Search, the keyboard layer, the login screen) are not
  published: publishing pushes to the public ambrosia-packages repo. Say
  when.
- tenet runs r369 of everything but ambrosia-desktop (r316). Installing
  master's ambrosia-desktop there pulls in keyd (off until
  `systemctl enable --now keyd`, which remaps the live keyboard: Super
  becomes Command) and switches SDDM to our login screen at its next start:
  say whether tenet should get the keyboard layer and the login screen too.
- Files' memory target #13 (≤120 MB): count own memory (USS, met at 119-123
  MB with the 100k folder) or RSS (a bare Qt Quick window is already 177 MB)?

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
