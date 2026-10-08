# ambrosia — Shell and Session

One layer of ambrosia's stack, owning `shell/, session/, tools/shot.sh`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer shell-and-session` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer shell-and-session add|set|drop <section> …`. Where it and the code disagree, the code is right.

The desktop shell (Quickshell QML on the generated Ambrosia Theme module) and the session that hosts it. startambrosia runs Plasma's session with XDG_SESSION_DESKTOP=ambrosia; systemd units keyed on that variable swap plasmashell for Quickshell, and /etc/xdg/ambrosia (via XDG_CONFIG_DIRS) carries session-only KDE/KWin defaults. The shell must match preview/ visually.

## Where to change what

- **Menu bar (logo, app name, menus, status icons, clock):** shell/MenuBar.qml, shell/MenuBarItem.qml
- **Desktop wallpaper:** shell/Wallpaper.qml
- **Line icons (same paths as the preview sprite):** shell/icons.js, shell/Icon.qml
- **Text in the type scale:** shell/Label.qml
- **Which windows/screens the shell puts up:** shell/shell.qml
- **Session start, env and defaults scope:** session/startambrosia, session/ambrosia.desktop
- **Swapping plasmashell for the shell:** session/ambrosia-shell.service, session/plasmashell.conf
- **KWin defaults (button order, hot corner, blur) and splash off:** session/xdg/kwinrc, session/ksplash.conf
- **Session look-and-feel (colors, widget style, splash off):** session/look-and-feel/org.ambrosia.desktop/

## How it works

- **Login:** SDDM/GDM → startambrosia (XDG_SESSION_DESKTOP=ambrosia, XDG_CONFIG_DIRS=/etc/xdg/ambrosia:…) → startplasma-wayland → plasma-core.target → ambrosia-shell.service (ExecCondition) runs quickshell --path /usr/share/ambrosia/shell; plasma-plasmashell.service skipped by drop-in
- **Look at it without logging in:** tools/shot.sh → dbus-run-session kwin_wayland --virtual → quickshell → spectacle --background screenshot

## Rules and traps

- Build file URLs from Quickshell.shellDir with an explicit file:// — Quickshell's QML base URL is qrc:/qs-blackhole, so relative URLs and Qt.resolvedUrl don't reach files.
- All values come from import Ambrosia (Theme.*); never hard-code colors or sizes that a token has.
- KWin has no window-list protocol Quickshell reads (no wlr/ext foreign-toplevel), so ToplevelManager is empty; app name and dock dots need a KWin bridge.
- KWin blur strength is global ([Effect-blur] in kwinrc), not per surface; BackgroundEffect.blurRegion only sets where.

## What it talks to

- Theme Targets — imports the generated Ambrosia QML module (/usr/lib/qt6/qml/Ambrosia) and kdeglobals
- Packaging and Image — ambrosia-shell installs shell/ to /usr/share/ambrosia/shell and session/ files system-wide
- Preview Desktop — the visual reference the QML must match
