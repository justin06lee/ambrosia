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

This is the foundation phase. The design system, the theme generator and a
browser preview of the desktop exist. The Linux shell, the compositor effects
and the distro itself don't yet.

## Quick start

```sh
make                       # test, generate every theme into dist/, install on Linux
open preview/index.html    # the mock desktop (xdg-open on Linux)
```

`make` needs [bun](https://bun.sh). On Linux it installs the themes for the
current user. Any config file ambrosia didn't write is kept beside it as
`<name>.before-ambrosia`. On other systems it only builds.

In the preview, **D** toggles dark mode and **A** cycles the accent. You can
also set the starting state in the URL: `?theme=dark&accent=honey&open=cc`
(the `open` value can be `cc` for the control center or `view-menu`).

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
design/        DESIGN.md (the rules) and tokens.ts (the values)
tools/gen/     the generator and its tests
tools/install.sh
preview/       the mock desktop, styled only from dist/web/tokens.css
assets/        banner and the "nectar" day/night wallpapers
```

## Roadmap

1. **Design system and theme generator.** Done.
2. **Shell** on Arch with KWin and Quickshell: menu bar, dock, control center,
   notifications and launcher, all on `Theme.qml`.
3. **Compositor**: a KWin effect for glass refraction, window animations on
   the spring tokens, and window decorations.
4. **Toolkits**: a Qt widget style and a full GTK theme beyond colors, an icon
   set and a cursor theme.
5. **Apps**: the core first-party apps, plus an XDG portal file chooser so file
   dialogs in other apps match too.
6. **Distro**: archiso image and Calamares installer.
