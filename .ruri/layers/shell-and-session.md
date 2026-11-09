# ambrosia — Shell and Session

One layer of ambrosia's stack, owning `shell/, session/, tools/shot.sh, decoration/`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer shell-and-session` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer shell-and-session add|set|drop <section> …`. Where it and the code disagree, the code is right.

The desktop shell (Quickshell QML on the generated Ambrosia Theme module) and the session that hosts it. startambrosia runs Plasma's session with XDG_SESSION_DESKTOP=ambrosia; systemd units keyed on that variable swap plasmashell for Quickshell, and /etc/xdg/ambrosia carries session-only KDE/KWin defaults. The shell is now functional, not just visual: menu bar with real app menus, Spotlight launcher on Super+Space, dock, control center and notification banners, and it must match preview/ visually.

## Where to change what

- **Menu bar (logo, app name, menus, status icons, clock):** shell/MenuBar.qml, shell/MenuBarItem.qml, shell/MenuView.qml
- **App menus in the top bar (the app's own DBus menus, through our patched DBusMenuSource):** shell/AppMenu.qml, shell/MenuView.qml, shell/Apps.qml, shell/MenuBar.qml
- **Search on Super+Space:** shell/Search.qml
- **Dock (pins, running dots, Downloads, live Trash, Files icon):** shell/Dock.qml, assets/icons/org.ambrosia.files.svg, shell/trash-empty.svg, shell/trash-full.svg
- **Control center (wifi, bluetooth, brightness, volume, appearance):** shell/ControlCenter.qml, shell/Brightness.qml, shell/Appearance.qml
- **Notification banners:** shell/Notifications.qml, shell/shell.qml
- **System actions (about, sleep, restart, shutdown, lock, logout, confirm):** shell/Session.qml, shell/Settings.qml, shell/ConfirmDialog.qml
- **Shared shell primitives (popups, glass, buttons, overlay):** shell/Popups.qml, shell/Glass.qml, shell/PushButton.qml, shell/Overlay.qml
- **Line icons (same paths as the preview sprite):** shell/icons.js, shell/Icon.qml
- **Text in the type scale:** shell/Label.qml
- **Desktop wallpaper:** shell/Wallpaper.qml
- **Which windows/screens the shell puts up:** shell/shell.qml
- **Window traffic lights (close, minimise, zoom in window frames):** decoration/src/button.cpp
- **Session start, env and defaults scope:** session/startambrosia, session/ambrosia.desktop
- **Swapping plasmashell for the shell:** session/ambrosia-shell.service, session/plasmashell.conf
- **KWin's grant of its window list to the shell; Super+Space for Search; the ambrosia command:** session/org.ambrosia.shell.desktop, session/org.ambrosia.search.desktop, session/ambrosia

## How it works

- **Login:** SDDM/GDM → startambrosia (XDG_SESSION_DESKTOP=ambrosia, XDG_CONFIG_DIRS=/etc/xdg/ambrosia:…) → startplasma-wayland → plasma-core.target → ambrosia-shell.service (ExecCondition) runs quickshell --path /usr/share/ambrosia/shell; plasma-plasmashell.service skipped by drop-in
- **Look at it without logging in:** tools/shot.sh → dbus-run-session kwin_wayland --virtual → quickshell → spectacle --background screenshot
- **App menus:** app (KDE platform theme) sees com.canonical.AppMenu.Registrar → exports its dbusmenu, tells KWin over org_kde_kwin_appmenu → task model's ApplicationMenuServiceName/ObjectPath → AppMenu.qml DBusMenuSource → MenuBar titles → MenuView (+ patched DBusMenuItem.shortcut)
- **Super+Space:** kglobalaccel reads X-KDE-Shortcuts in org.ambrosia.search.desktop → /usr/bin/ambrosia search → quickshell ipc call shell search → Popups.toggleSearch
- **Test on tenet:** rsync shell/ to /usr/share/ambrosia/shell → systemctl --user -M justin06lee@ restart ambrosia-shell (reset-failed after a load error) → /root/ui.py click/key/type → spectacle -b -n -f as the user, WAYLAND_DISPLAY=wayland-1; the shell logs to journalctl _SYSTEMD_USER_UNIT=ambrosia-shell.service

## Key files

- shell/shell.qml — top-level shell composition, which windows go on which screens
- shell/MenuBar.qml — menu bar container and menu switching
- shell/MenuBarItem.qml — single menu-bar title item
- shell/MenuView.qml — dropdown menu view
- shell/Apps.qml — running-app / menu model for app menus and dock
- shell/Search.qml — Spotlight search and launch UI
- shell/Dock.qml — app dock with running dots, Downloads, live Trash, Files icon and context menu
- assets/icons/org.ambrosia.files.svg — hand-drawn Files icon, used by the Files app and its Dock pin
- shell/trash-empty.svg — hand-drawn empty Trash for the dock
- shell/trash-full.svg — hand-drawn full Trash for the dock
- shell/ControlCenter.qml — quick-settings toggles and sliders
- shell/Notifications.qml — notification banners
- shell/Session.qml — launching apps (kstart), opening URLs, settings, sleep, restart, shut down, lock, log out
- shell/Appearance.qml — dark mode and accent color controls
- shell/Brightness.qml — display brightness control
- shell/Overlay.qml — each screen's grabbing popup for menus, the control center and confirmations
- shell/Popups.qml — what's open and where: menu levels, control center, confirmation, Search

## Rules and traps

- Build file URLs from Quickshell.shellDir with an explicit file:// — Quickshell's QML base URL is qrc:/qs-blackhole, so relative URLs and Qt.resolvedUrl don't reach files.
- All values come from import Ambrosia (Theme.*); never hard-code colors or sizes that a token has.
- Dock and Trash artwork is hand-drawn vector art; never copy or extract Apple's images from Dock.app or any system bundle.
- Dock icons, including the Files icon, are our own drawings: never trace Finder.app or any macOS file; the face and shapes must be ours even when the squircle and colours match macOS.
- The Dock's Trash is sized against its neighbouring icons by macOS's squircle-to-bin ratio; resize it with them, not on its own.
- Window traffic lights use macOS's colours in both light and dark mode, and each light's edge is a thin darker shade of its own colour, not grey.
- KWin gives its window list (org_kde_plasma_window_management) only to programs a desktop file grants, matched by Exec path: org.ambrosia.shell.desktop names /usr/bin/quickshell. No other desktop file may Exec /usr/bin/quickshell (KWin takes the first match), so shortcuts run /usr/bin/ambrosia.
- Plasma's appmenu kded only collects apps' menus while org.kde.kappmenuview is on the bus; Apps.qml holds it with dbus-test-tool black-hole. Apps check at startup, so ones started before the shell keep their in-window menus.
- A QML file loaded by file:// URL (Loader) gets its own copies of the shell's singletons; pass it values instead (AppMenu.qml).
- Menus, the control center and confirmations draw on Overlay.qml, a grabbing PopupWindow of the menu bar: KWin sends it keys without activating it, so the app stays active (Search, a keyboard-taking layer surface, deactivates it). It spans the screen, bar strip masked: Qt hands an open popup the bar's pointer events by position. Apps.frozen holds the bar's app; window actions capture their window at open.
- Compare a window with the screen it was made for (home), not its live screen, which changes as it maps and unmaps and loops through visible.
- Start apps through kstart (Session.launch/run), never execDetached on the app: it would live in ambrosia-shell.service's cgroup and die when the shell restarts.
- Pinned apps' AppId ends in .desktop, running ones' not (use Apps.entryFor). Windows keep their pin's Dock spot only with launchInPlace and separateLaunchers: true.
- Glass.qml draws preview/glass.css: top-lit rim (ring: true for the Dock's all-round rim), a 135° specular ring, 0.5px edge, shadow outside only. Use it for any glass surface instead of a plain tinted Rectangle.
- KWin's blur is global: [Effect-blur] BlurStrength and Saturation (integer, 100 = none) in session/xdg/kwinrc apply to every glass surface; the control center's untinted backdrop sets them (6, 100). Reload with /Effects reconfigureEffect blur, not KWin.reconfigure.

## What it talks to

- Theme Targets — imports the generated Ambrosia QML module (/usr/lib/qt6/qml/Ambrosia) and kdeglobals
- Packaging and Image — ambrosia-shell installs shell/ to /usr/share/ambrosia/shell and session/ files system-wide, and ships assets/icons/org.ambrosia.files.svg with them
- Preview Desktop — the visual reference the QML must match
- Files app — pinned in the Dock; Trash drops use its DBus Trash method
- Settings app (ambrosia-settings, settings/) — the menu bar's Settings items and the Dock open it instead of KDE's settings module
