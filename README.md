<div align="center">

<img src="assets/ambrosia.svg" alt="ambrosia" width="330" />

# ambrosia

**A Linux desktop that looks and moves as one thing.**<br>
*Glass, springs, and one design language across every toolkit, on Arch.*

</div>

---

Linux desktops usually look inconsistent because no one owns the whole stack.
Each toolkit, app and theme follows its own rules. ambrosia starts from the
other end. It has one design authority ([`design/DESIGN.md`](design/DESIGN.md)),
one file of design values ([`design/tokens.ts`](design/tokens.ts)), and a
generator that turns those values into a theme for every toolkit. GTK, Qt/KDE,
the shell and font rendering all read the same numbers.

## Status

The design system, the theme generator, a browser preview of the desktop and a
design review site exist. The distro pipeline has its first cut: Arch packages,
an Ambrosia session on KWin, and an installer image that boots a live desktop
and installs it. The shell works on real hardware: the menu bar with the
focused app's own menus, Search (Super+Space), the Dock, the control center
and notification banners. Its look still trails the design preview, and
compositor effects don't exist yet. The first first-party app, Files (a Finder
look-alike), browses folders in list and icon views; file operations, Quick
Look and search come next.

## Quick start

```sh
make                       # test, build every theme and the review site, install on Linux
bun run review             # the design review site at http://localhost:4747
make remote-build          # the build gate on tenet, the Arch build box (Mac stays light)
make review-remote         # the review site served from tenet, tunnelled to localhost:4747
open preview/index.html    # the mock desktop on its own (xdg-open on Linux)
```

On an Arch machine, the distro builds from the same checkout:

```sh
make package               # ambrosia-keyring, -theme, -shell, -files, -desktop into out/pkg/
make quickshell            # our Quickshell (with the app menu patch) for the installed Qt
sudo make iso              # the installer image, out/iso/ambrosia-*.iso
tools/vm.sh install        # install the image unattended in a headless VM
tools/vm.sh shot vm.png    # and photograph it
sudo tools/repo-test.sh    # install it in the VM, then pacman -Syu from the hosted repo
```

From the Mac, `make publish` builds the packages on tenet, signs them and
uploads them to Ambrosia's hosted pacman repo (`tools/publish-repo.sh`); the
signing key never leaves the Mac. Installed systems update from that repo:
the installer lists `[ambrosia]` first in their pacman.conf, and
`ambrosia-keyring` trusts its key.

`dd` the image onto a USB drive and boot it (UEFI). It starts a live Ambrosia
desktop and opens the installer, which asks for a disk, a name and a password
and does the rest; the installer needs the internet. Installing the packages
with `pacman -U` on an existing Arch system adds an "Ambrosia" session to the
login screen instead. `tools/remote.sh <host> <command>` runs a command in the
build box's own git checkout, synced from this one over SSH, and `tools/shot.sh`
photographs the shell on a headless KWin.

`make` needs [bun](https://bun.sh). On Linux it installs the themes for the
current user. Any config file ambrosia didn't write is kept beside it as
`<name>.before-ambrosia`. On other systems it only builds.

In the preview, **D** toggles dark mode, **A** cycles the accent, and
right-clicking a file opens its context menu. You can
also set the starting state in the URL: `?theme=dark&accent=honey&open=cc`
(the `open` value can be `cc` for the control center or `view-menu`).

## The design review site

`bun run review` serves a site for reviewing the design together. It has one
section per chapter of [`design/DESIGN.md`](design/DESIGN.md) and per entry in
[`design/DECISIONS.md`](design/DECISIONS.md). Each section shows the reasoning
and live examples built from the real tokens: the type scale, nested radii,
every accent with its measured contrast, the glass materials with each layer
switchable, the springs plotted and playable, and the desktop preview.

Each section takes a verdict (looks right, change it, discuss) and a notes
thread. With the review server running, these save to `design/review.json` in
the repo. Claude reads that file and replies in the same threads, and replies
appear in the open page within a few seconds. The site reads its text straight
from the two markdown files, so it can't drift from them.

`make build` also writes a static copy to `dist/site/`. Without the server it
keeps verdicts and notes in the browser, and **Copy review** turns them into
markdown you can paste into a chat.

## How it fits together

`design/tokens.ts` holds every value: type scale, 4px spacing grid, concentric
radii, OKLCH colors, glass materials, shadows and spring motion. `tools/gen`
resolves them once and writes each target from the same resolved model. It
converts colors to gamut-mapped sRGB, derives each accent's text and fill
colors to meet contrast targets, and solves the springs. Because of that,
an accent or a label color is identical in GTK, KDE and the shell.

| Output | For |
|---|---|
| `dist/gtk-4.0/gtk.css` | libadwaita apps (CSS variables, light and dark) |
| `dist/gtk-3.0/gtk-{light,dark}.css` | GTK3 apps on adw-gtk3 / Adwaita |
| `dist/kde/Ambrosia{Light,Dark}.colors` | Qt and KDE apps |
| `dist/qml/Ambrosia/Theme.qml` | the shell (`import Ambrosia`, then `Theme.color…`) |
| `dist/fontconfig/50-ambrosia.conf` | Inter and JetBrains Mono as system fonts, grayscale AA, slight hinting |
| `dist/environment.d/50-ambrosia-fonts.conf` | FreeType stem darkening, for fuller text |
| `dist/web/tokens.css` | the preview and any web surface |
| `dist/tokens.json` | everything resolved, for compositor effects and scripts |

`bun test` checks the spec's rules against the values: label and accent
contrast in both modes, concentric radii, and the spacing grid.

## Layout

```
CONTEXT.md     where things stand and what's next, for picking the work back up
design/        DESIGN.md (the rules), DECISIONS.md (the choices), tokens.ts (the values),
               review.json (review verdicts and notes)
tools/gen/     the generator and its tests
tools/         install.sh (per-user themes), build-iso.sh, vm.sh, shot.sh, remote.sh,
               publish-repo.sh (the hosted repo), repo-test.sh + repo-check.sh (its VM test)
shell/         the shell in QML for Quickshell: wallpaper, menu bar and menus, Search,
               Dock, control center, notifications
session/       the Ambrosia session: start script, systemd units, KWin and KDE defaults,
               the `ambrosia` command and the shell's desktop files
files/         Files, Ambrosia's Finder: Qt Quick UI, C++ core, art, benchmarks (bench/)
               and tools/tenet.sh to build and photograph it on tenet
docs/finder/   the Files plan: research, stack, v1 scope, performance targets
packaging/     PKGBUILDs: ambrosia-* and the Quickshell rebuild (with our DBusMenuSource patch),
               the repo's public key (keyring/), the os-release that names the system
iso/           the archiso profile: live desktop, installer (ambrosia-install)
preview/       the mock desktop, styled only from dist/web/tokens.css; glass.css is shared
site/          the design review site and its server
assets/        banner, icon and the "nectar" day/night wallpapers
```

## Roadmap

1. **Design system and theme generator.** Done.
2. **Packages and installer image.** First cut done: packages, the session, a
   live image, an unattended-testable installer, and a hosted, signed package
   repo installed systems update from. Everything after this ships through it.
3. **Shell** on KWin and Quickshell: menu bar, Dock, control center,
   notifications and Search work (first cut); next, matching the preview's
   look, a notification center and the Mac-first keyboard layer (keyd). Built
   and judged on tenet, the Arch desktop, with a Magic Trackpad.
4. **Compositor**: a KWin effect for glass refraction, window animations on
   the spring tokens, and window decorations.
5. **Toolkits**: a Qt widget style and a full GTK theme beyond colors, an icon
   set and a cursor theme.
6. **Apps**: the core first-party apps, plus an XDG portal file chooser so file
   dialogs in other apps match too.
7. **Onboarding**: a first-party onboarding app in place of the installer
   script (asking Mac-first or Linux-first), and a login screen and boot
   splash of our own.

Later: an ARM64 build for the Jetson Orin Nano.
