# ambrosia — Packaging and Image

One layer of ambrosia's stack, owning `packaging/, iso/, tools/build-iso.sh, tools/vm.sh, tools/remote.sh, tools/publish-repo.sh, tools/repo-test.sh, tools/repo-check.sh`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer packaging-and-image` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer packaging-and-image add|set|drop <section> …`. Where it and the code disagree, the code is right.

Everything that turns the repo into an installable, updatable distro. packaging/PKGBUILD builds ambrosia-keyring, ambrosia-theme, ambrosia-shell and ambrosia-desktop from the checkout; packaging/quickshell rebuilds Quickshell v0.3.2 with a patch so the menu bar can read apps' real menus, including each item's shortcut, and so apps learn when each menu opens. tools/publish-repo.sh (make publish, on the Mac) builds them on tenet, signs them with a key kept on the Mac, and uploads them to the hosted [ambrosia] pacman repo: the rolling repo release of the public github.com/justin06lee/ambrosia-packages. iso/ is an archiso profile (from Arch's releng) whose live system logs into Ambrosia and carries the packages as a local repo for its installer, which puts [ambrosia] first in the installed system's pacman.conf. Built on an Arch host (tenet), tested in a headless QEMU VM.

## Where to change what

- **What each package installs and depends on (incl. the Aurorae window frame, ambrosia-shell's upgrade restart hook, and the Files app icon in the hicolor theme):** packaging/PKGBUILD, assets/icons/org.ambrosia.files.svg
- **SDDM defaults on installed systems:** packaging/sddm.conf
- **Our Quickshell build (pinned upstream commit; DBusMenu patch that reads menus, item shortcuts, and tells apps each menu opened):** packaging/quickshell/dbusmenu-source.patch, packaging/quickshell/PKGBUILD
- **Image name, compression, file permissions:** iso/profiledef.sh
- **What's on the live image:** iso/packages.x86_64
- **Package sources at build time and on the image ([ambrosia] first):** iso/pacman.conf, tools/build-iso.sh
- **Live session: user, autologin, sudo, services:** iso/airootfs/etc/systemd/system/ambrosia-live-user.service, iso/airootfs/etc/sddm.conf.d/live.conf, iso/airootfs/etc/sudoers.d/10-live
- **The installer: questions, Wi-Fi when offline, then the install:** iso/airootfs/usr/local/bin/ambrosia-install, iso/airootfs/usr/local/bin/ambrosia-install-system
- **Boot menu entries and kernel params:** iso/efiboot/loader/, iso/syslinux/
- **VM build / install / screenshot test tooling:** tools/vm.sh
- **The hosted repo: publishing, signing, the key installed systems trust:** tools/publish-repo.sh, packaging/keyring/, packaging/ambrosia-keyring.install
- **The system's name (os-release, its logo, the hooks that keep it in /etc):** packaging/os-release/
- **Testing the hosted repo from a fresh install in the VM:** tools/repo-test.sh, tools/repo-check.sh

## How it works

- **Build:** make package (user) → out/pkg/*.pkg.tar.zst → sudo make iso → tools/build-iso.sh copies iso/ to out/profile, repo-adds the packages into airootfs/opt/ambrosia/repo, fills @REPO@ in pacman.conf → mkarchiso → out/iso/ambrosia-*.iso
- **Install:** boot → SDDM autologin live → Ambrosia session → autostart Konsole runs ambrosia-install (lists nearby Wi-Fi and asks for password when offline, then kdialog questions, answers file with a password hash) → sudo ambrosia-install-system (sgdisk EFI+root, pacstrap from [ambrosia]+mirrors, user, systemd-boot, sddm state) → reboot
- **Test:** tools/vm.sh install extracts the image's kernel and boots it with ambrosia.autoinstall (test answers, powers off) → tools/vm.sh installed → tools/vm.sh shot
- **Publish:** make publish (Mac) → tools/remote.sh pushes HEAD to tenet's bare repo and resets ~/work/ambrosia to it → capped make package there (+ make quickshell when neither the release nor out/pkg has its version; skipped when out/pkg has this clean commit's packages) → the release's ambrosia.db, verified, + repo-add on tenet → gpg sign on the Mac → gh release upload (packages first, db last) → delete assets the db no longer lists
- **Update:** installed pacman.conf [ambrosia] (first, SigLevel Required) → Include /etc/pacman.d/ambrosia-mirrorlist → github.com/justin06lee/ambrosia-packages/releases/download/repo → signatures checked against the key ambrosia-keyring populated

## Key files

- packaging/PKGBUILD — builds the four ambrosia packages and what each installs
- tools/publish-repo.sh — builds, signs and uploads packages to the hosted repo
- iso/packages.x86_64 — what's on the live image
- iso/pacman.conf — package sources at build and on the image
- tools/vm.sh — VM install and screenshot test tooling
- packaging/quickshell/PKGBUILD — pinned Quickshell build, patch checksum and pkgrel
- packaging/quickshell/dbusmenu-source.patch — DBusMenu source patch: item shortcuts, and AboutToShow on every menu open

## Rules and traps

- [ambrosia] must stay first in pacman.conf (the image's, and the installed one the installer writes): pacman takes a package from the first repo that has it, whatever the version, so our Quickshell only wins from there. ambrosia-shell needs quickshell-dbusmenu-source, which only our build provides.
- Quickshell links Qt internals: when Arch updates qt6-base, bump pkgrel in packaging/quickshell/PKGBUILD and make publish (it rebuilds Quickshell when the release lacks that version).
- Any change to dbusmenu-source.patch must update its checksum and bump pkgrel in packaging/quickshell/PKGBUILD, because make publish only rebuilds Quickshell for a version the release lacks.
- The patch must make Quickshell send DBusMenu AboutToShow on every menu open, not only the first: Qt raises a menu's aboutToShow only from that call, so apps tracking open menus miss every later open otherwise.
- packaging/PKGBUILD must install ambrosia-shell's pacman restart hook (session/ambrosia-shell-restart.hook); without it, upgraded shell QML waits for the next login to take effect.
- App icons in assets/icons/ reach installed systems only if packaging/PKGBUILD installs them; a hand copy on tenet is replaced by the next package install, so a hand copy alone is not a fix.
- Build and work dirs go under ~/work/ambrosia/out on /home (tenet's / has ~25 GB); makepkg's Quickshell source is out/build/quickshell/src/quickshell. mkarchiso needs root, makepkg refuses it.
- The installer is UEFI-only and needs the internet (pacstrap pulls everything but our packages from Arch mirrors).
- Ship pipewire-jack, not jack2: the two conflict and broke restore/install when both were pulled in.
- tools/vm.sh must not forward host port 2222: makima uses it to reach tenet, so the test VM SSH forward lives on 10022.
- The installer copies live Wi-Fi profiles without interface-name: the live image names the card wlan0 (iwd), the installed system by its predictable name (wlo1).
- GitHub renames release assets with ':' or '~' (to '.'), so no epochs in our package versions; publish-repo.sh refuses such names. Assets can't be symlinks: ambrosia.db and .files are uploaded as real files.
- Hand copies on tenet (shell/, /etc/xdg/ambrosia) go only through pacman -U --overwrite, never -Syu; after an install pacman -Qkk must show 0 altered files and no .pacnew.

## What it talks to

- Shell and Session — ambrosia-shell ships shell/ and session/, including the pacman restart hook that session/ shell upgrades trigger; the Dock's Files icon (assets/icons/org.ambrosia.files.svg) is installed by the PKGBUILD; the menu bar's shortcut column reads item shortcuts from our patched Quickshell
- Files app — its active-while-menu-open look depends on the AboutToShow that our patched Quickshell sends on each menu open
- Theme Targets / Generator Core — the PKGBUILD runs bun tools/gen/index.ts and installs dist/ system-wide, including the generated Aurorae window frames
- tenet (Arch build host) — ssh as justin06lee@192.168.1.172 (root@ for pacman -U); tools/remote.sh pushes HEAD to its bare repo and resets ~/work/ambrosia to it
- GitHub — gh on the Mac: the private source remote (justin06lee/ambrosia) and the public package repo's repo release (justin06lee/ambrosia-packages)
