# ambrosia — Packaging and Image

One layer of ambrosia's stack, owning `packaging/, iso/, tools/build-iso.sh, tools/vm.sh, tools/remote.sh`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer packaging-and-image` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer packaging-and-image add|set|drop <section> …`. Where it and the code disagree, the code is right.

Everything that turns the repo into an installable distro. packaging/PKGBUILD builds ambrosia-theme, ambrosia-shell and ambrosia-desktop from the checkout; packaging/quickshell rebuilds Quickshell for the installed Qt. iso/ is an archiso profile (from Arch's releng) whose live system logs into Ambrosia and carries the packages as a local repo for its installer. Built on an Arch host (tenet), tested in a headless QEMU VM.

## Where to change what

- **What each package installs and depends on:** packaging/PKGBUILD
- **SDDM defaults on installed systems:** packaging/sddm.conf
- **Our Quickshell build (pinned upstream commit):** packaging/quickshell/PKGBUILD
- **Image name, compression, file permissions:** iso/profiledef.sh
- **What's on the live image:** iso/packages.x86_64
- **Package sources at build time and on the image ([ambrosia] first):** iso/pacman.conf, tools/build-iso.sh
- **Live session: user, autologin, sudo, services:** iso/airootfs/etc/systemd/system/ambrosia-live-user.service, iso/airootfs/etc/sddm.conf.d/live.conf, iso/airootfs/etc/sudoers.d/10-live
- **The installer: questions, then the install:** iso/airootfs/usr/local/bin/ambrosia-install, iso/airootfs/usr/local/bin/ambrosia-install-system
- **Boot menu entries and kernel params:** iso/efiboot/loader/, iso/syslinux/

## How it works

- **Build:** make package (user) → out/pkg/*.pkg.tar.zst → sudo make iso → tools/build-iso.sh copies iso/ to out/profile, repo-adds the packages into airootfs/opt/ambrosia/repo, fills @REPO@ in pacman.conf → mkarchiso → out/iso/ambrosia-*.iso
- **Install:** boot → SDDM autologin live → Ambrosia session → autostart Konsole runs ambrosia-install (kdialog questions, answers file with a password hash) → sudo ambrosia-install-system (sgdisk EFI+root, pacstrap from [ambrosia]+mirrors, user, systemd-boot, sddm state) → reboot
- **Test:** tools/vm.sh install extracts the image's kernel and boots it with ambrosia.autoinstall (test answers, powers off) → tools/vm.sh installed → tools/vm.sh shot

## Rules and traps

- [ambrosia] must stay first in iso/pacman.conf: pacman takes a package from the first repo that has it, regardless of version, so our Quickshell rebuild only wins from there.
- Quickshell links Qt internals: when Arch's quickshell was built for an older Qt than the system's, run make quickshell and ship ours.
- Build and work dirs go under out/ on /home (tenet's / has ~25 GB); mkarchiso needs root, makepkg refuses it.
- The installer is UEFI-only and needs the internet (pacstrap pulls everything but our packages from Arch mirrors).

## What it talks to

- Shell and Session — ambrosia-shell ships shell/ and session/
- Theme Targets / Generator Core — the PKGBUILD runs bun tools/gen/index.ts and installs dist/ system-wide
- tenet (Arch build host) — reached with makima; tools/remote.sh rsyncs the checkout there
