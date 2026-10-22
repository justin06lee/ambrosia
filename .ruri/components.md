# Component library

Every piece of this project's interface ruri has on file: the user's own
name for it, its handle, and its files. When the user names something
here, this is what they mean — go straight to its files rather than
searching for their words. Before building interface, look here first
and reuse what exists: `ruri search <words>` finds one, `ruri show <slug>`
reads it with its code and its pictures, `ruri add <slug>` copies it into
place, `ruri help` says the rest.

ruri maintains this file. Don't edit it by hand; it is rewritten whenever
the library changes.

## design-preview-desktop — the design preview desktop
HTML mock of the whole ambrosia desktop: menu bar, the dock (roomy, ringed, glassy icon rims, badges, a following tooltip), Files + terminal windows, notification, the control center (no panel: capsule modules on a feathered blur, fade choreography measured from macOS), View menu and right-click context menu (both snap open). Styled only from dist/web/tokens.css; run make build first; D/A keys or ?theme=&accent=&open= switch state.
Also called: control center
Its files: preview/index.html
Reaches into: dist/web/tokens.css, assets/wallpapers/nectar-day.svg, assets/wallpapers/nectar-night.svg
Tags: desktop, preview, glass, dock, menu bar, control center

## design-review-site — the design review site
Review site for the design: one section per DESIGN.md chapter and DECISIONS.md entry, with live examples built from the real tokens, a verdict control and a notes thread per section that saves to design/review.json (`bun run review`, port 4747). Static copy in dist/site keeps notes in localStorage instead.
Its files: site/site.css, site/review.ts
Reaches into: dist/web/tokens.css, preview/glass.css, preview/index.html, design/DESIGN.md, design/DECISIONS.md, design/review.json, site/main.ts, site/specimens.ts, site/content.ts, site/dom.ts, site/server.ts, site/build.ts, site/index.html
Tags: site, review, docs, glass, specimens

## shell-menu-bar — the real menu bar
The Linux menu bar in QML (Quickshell, import Ambrosia): the bowl (Ambrosia menu), the focused app's name and its own DBus menus (AppMenu.qml), a Window menu for apps without one, Wi-Fi, Search, control center and clock. Menus open on press, switch on hover, work from the keyboard. Thin glass over KWin's blur.
Its files: shell/MenuBar.qml, shell/MenuBarItem.qml
Reaches into: shell/shell.qml, dist/qml/Ambrosia/Theme.qml, shell/icons.js, shell/Icon.qml, shell/Label.qml
Tags: shell, menu bar, qml, quickshell

## shell-dock — the dock
The real Dock in QML: pinned apps (running ones keep their pinned spot) then other running ones from Plasma's task model, running dots, a name tooltip with a point that follows the pointer, right-click New Window / Keep in Dock / Quit. Icons drawn on a whole macOS-style tile (the Trash, Files: tileIcons) show at tileArt = 1/0.805 of the icon size. Files (org.ambrosia.files) is pinned first. Downloads is a glass tile; the Trash is the frosted bin, full while the home trash has anything, takes drops (through Files over DBus while it runs, so ⌘Z undoes them), Open / Empty Trash…. Pins live in Settings.dock.
Its files: shell/Dock.qml, shell/trash-empty.svg, shell/trash-full.svg
Reaches into: shell/Glass.qml, shell/Overlay.qml, shell/Settings.qml, shell/Apps.qml
Tags: shell, dock, qml

## shell-control-center — the control center
The real control center in QML: Wi-Fi, Bluetooth, Now Playing, Focus (Do Not Disturb), Night Light, Dark Mode, display brightness (when dimmable), sound with its output button, accent — every control acts. Frosted modules on KWin's blur, no panel. Drawn on the screen's Overlay, opened from the menu bar.
Its files: shell/ControlCenter.qml
Reaches into: shell/Overlay.qml, shell/Popups.qml, shell/Settings.qml, shell/Appearance.qml, shell/Brightness.qml
Tags: shell, control center, qml

## shell-search — Spotlight search
Search on Super+Space or the menu bar magnifier: finds apps by name, generic name and keywords, arrows to choose, Return opens through kstart.
Its files: shell/Search.qml, session/org.ambrosia.search.desktop
Reaches into: shell/Glass.qml, shell/Popups.qml, session/ambrosia
Tags: shell, search, launcher, qml

## shell-menus — the menus
Menu panels for the menu bar, apps' own DBus menus, submenus and the Dock's right-click menus: thick glass with a top-lit rim and specular ring, accent highlight, checkmarks, a right-aligned shortcut column in Mac glyphs (an app's Ctrl as ⌘, ⇧⌘F, ⌘↑, ⌘[), keyboard navigation; KWin keeps the app's window active while one is open. Leading, trailing and doubled separators from apps are dropped. One slot per depth on each screen's Overlay (a grabbing popup of the menu bar).
Its files: shell/MenuView.qml
Reaches into: shell/Glass.qml, shell/MenuBar.qml, shell/Overlay.qml, shell/Popups.qml
Tags: shell, menu, qml

## shell-notifications — notification banners
The shell is the session's notification server; banners top right on regular glass slide in and out on the smooth spring, step aside while the control center is open, leave after a few seconds unless urgent; click runs the default action, Focus holds them back.
Its files: shell/Notifications.qml
Reaches into: shell/Glass.qml, shell/Settings.qml
Tags: shell, notification, qml

## window-traffic-lights — the traffic lights
Window frames for every app: KWin Aurorae theme generated from the tokens (light and dark) — red/yellow/green buttons with hover glyphs, gray when inactive, 40px titlebar with centered title, rounded top corners, the preview's window shadow, rim and edge. Bottom corners stay square (Aurorae can't round app content).
Its files: tools/gen/targets/aurorae.ts
Reaches into: session/look-and-feel/org.ambrosia.desktop/contents/defaults, session/startambrosia, shell/Appearance.qml, packaging/PKGBUILD
Tags: kwin, window, decoration, theme

## files-column-view — the column view
Files' Finder column browser (⌘3): 245-pt columns from the root down to the window's folder, grey pills on the path, chevrons on folders, then the selected folder's column or a file preview; the window's folder is the focused column, so keys and file operations work there. Column lists keep currentIndex -1 (a current item steals the rename field's focus).
Its files: files/qml/ColumnPane.qml
Reaches into: files/qml/FinderWindow.qml, files/qml/Finder.qml, files/qml/RenameField.qml, files/qml/FileIcon.qml, files/src/foldermodel.cpp
Tags: files, columns, qml, finder
