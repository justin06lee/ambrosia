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
The shell is the session's notification server; banners top right on regular glass slide in and out on the smooth spring, step aside while the control center is open, leave after the app's timeout (5 s by default) unless urgent or marked never-expiring, which wait for an answer; click runs the default action, other actions are a row of buttons under the text; Focus holds them back.
Its files: shell/Notifications.qml
Reaches into: shell/Glass.qml, shell/Settings.qml
Tags: shell, notification, qml

## window-traffic-lights — the traffic lights
Window frames for every app: our own KWin decoration plugin (decoration/, KDecoration3) built on the tokens — 14pt lights 23pt apart in a 32pt bar, measured from macOS 26, in its own colours (#ec6765, #f2ca44, #65c466, the same in light and dark); on hover all three show macOS 26's glyphs (bold ×, capsule −, split-square zoom; filled black at 50%, kept once in the tokens and drawn the same by Files, Settings and GTK); gray when inactive, centered title, four rounded corners that clip the content, the preview's shadow. GTK 3's titlebuttons match (14 wide, 23 apart, left); Firefox uses the system titlebar. tenet's running KWin keeps the old light colours until its next login.
Its files: tools/gen/targets/kdecoration.ts, decoration/src/decoration.cpp, decoration/src/button.cpp, decoration/src/shadow.cpp
Reaches into: session/look-and-feel/org.ambrosia.desktop/contents/defaults, session/startambrosia, session/dconf/ambrosia.d/00-window-controls, tools/gen/targets/gtk.ts, packaging/PKGBUILD, packaging/firefox/ambrosia.js
Tags: kwin, window, decoration, theme, gtk

## files-column-view — the column view
Files' Finder column browser (⌘3): 245-pt columns from the root down to the window's folder, grey pills on the path, chevrons on folders, then the selected folder's column or a file preview; rows run up under the toolbar (fading) and scrolled-away columns under the sidebar (blurred in its margin). Row click/drag handlers live on an item below the toolbar line so the toolbar still moves the window; column lists keep currentIndex -1 (a current item steals the rename field's focus).
Its files: files/qml/ColumnPane.qml
Reaches into: files/qml/FinderWindow.qml, files/qml/Finder.qml, files/qml/RenameField.qml, files/qml/FileIcon.qml, files/src/foldermodel.cpp
Tags: files, columns, qml, finder

## files-gallery-view — the gallery view
Files' Finder gallery (⌘4): the selected item large over a filmstrip (59-pt cells, 48-pt thumbs, grey rounded square on the selection), and the 240-pt preview pane on the right (name, kind – size, Created/Modified/Last opened via FolderModel.timesAt; ⇧⌘P hides it). Pictures Qt reads show as themselves, others as icons. The window keeps one item shown (FinderWindow.galleryKeep).
Its files: files/qml/GalleryPane.qml, files/qml/PreviewPane.qml, files/qml/Thumbnail.qml
Reaches into: files/qml/FinderWindow.qml, files/qml/Finder.qml, files/qml/FileIcon.qml, files/qml/RenameField.qml
Tags: files, view, qml, finder

## files-quick-look — the Quick Look window
Files' Quick Look (Space, ⌘Y): a panel over its Finder window that follows the selection. A picture shows at one point a pixel, text in an 816×849 page, anything else in a 576×328 panel with a 256-pt icon and its name, size and date. It has close and full-screen circles and an "Open with <app>" capsule. Space, Esc or ⌘Y closes it, and the arrows go to the window. Data comes from ItemInfo (src/iteminfo.cpp).
Its files: files/qml/QuickLook.qml
Reaches into: files/qml/FinderWindow.qml, files/qml/Finder.qml, files/qml/FileIcon.qml, files/src/iteminfo.cpp
Tags: files, window, qml, finder, preview

## files-info-window — the Info window
Files' Get Info (⌘I): a 400-pt window per item. At the top are its name, size, modified date and tag tokens (Return adds a tag, ⌫ removes the last). Then Finder's collapsible sections: General, More Info, Name & Extension (renames undoably), Comments (user.xdg.comment), Open with, Preview, and Sharing & Permissions. The window grows as sections open (KWin re-centres it). ItemInfo follows the item through renames by its inode.
Its files: files/qml/InfoWindow.qml, files/qml/InfoSection.qml
Reaches into: files/qml/TrafficLights.qml, files/qml/Thumbnail.qml, files/qml/FileIcon.qml, files/qml/Glyph.qml, files/qml/Appearance.qml, files/src/iteminfo.cpp, files/src/app.cpp
Tags: files, window, qml, finder, inspector

## files-tag-dots — the tag dots
An item's Finder tags beside its name: 10-pt dots in the tag colours (Finder.tagFill/tagRim). The first tag is on the right; each further one sits 5 pt to the left, in front, ringed in the background's colour (pass `ring`). Used at the end of the list's Name column, before icon-view names, and before the Columns chevron.
Its files: files/qml/TagDots.qml
Reaches into: files/qml/Finder.qml, files/qml/ListPane.qml, files/qml/IconPane.qml, files/qml/ColumnPane.qml
Tags: files, qml, finder, tags

## files-search-field — the search field
Files' toolbar search (⌘F): Finder's search button opened into a 240-pt capsule with magnifier, text, clear ⓧ and accent focus ring; while typing it shows Finder's suggestions (Name Contains / Contains), and one chosen becomes a NAME or CONTENTS token (⌫ removes it). It drives FinderWindow's search state (typeSearch, chooseSearchToken, closeSearch).
Its files: files/qml/SearchField.qml
Reaches into: files/qml/Toolbar.qml, files/qml/FinderWindow.qml, files/qml/Finder.qml, files/qml/Glyph.qml
Tags: files, qml, finder, search, toolbar

## files-scope-bar — the scope bar
Under Files' toolbar while searching: Finder's "Search: Home “Folder”" row (the chosen scope on a pill) and the "Kind is Any" criteria row, whose pop-up buttons open the in-window pop-up menu. It pushes the results view down by two 32-pt rows.
Its files: files/qml/ScopeBar.qml, files/qml/PopupButton.qml
Reaches into: files/qml/FinderWindow.qml, files/qml/PopupMenu.qml, files/qml/Finder.qml
Tags: files, qml, finder, search

## settings-window — the Settings window
Ambrosia's System Settings, measured from macOS 26 (docs/settings/FRAME.md, every size and colour in Look.qml): 723-wide frameless window, floating glass sidebar with its own traffic lights (zoom is vertical only, through KWin) and search, panes in macOS order, back/forward capsule, boxes of rows; General and About are ours, other panes open KDE's modules until built, and a pane with nothing behind it isn't listed.
Its files: settings/qml/SettingsWindow.qml, settings/qml/Sidebar.qml, settings/qml/SearchField.qml, settings/qml/Toolbar.qml, settings/qml/Capsule.qml, settings/qml/TrafficLights.qml, settings/qml/Panes.qml, settings/qml/PaneIcon.qml, settings/qml/glyphs.js, settings/qml/Page.qml, settings/qml/Box.qml, settings/qml/FormRow.qml, settings/qml/NavRow.qml, settings/qml/HeaderBox.qml, settings/qml/SectionHeading.qml, settings/qml/GeneralPage.qml, settings/qml/AboutPage.qml, settings/qml/Look.qml
Reaches into: settings/src/app.cpp, settings/src/about.cpp
Tags: settings, window, sidebar, qml

## settings-controls — the settings controls
System Settings' controls, measured from the Mac: switch 36×16, pop-up (plain value + chevron capsule), slider (6 track, 20×16 knob, 2 pt tick dots 3 under the track, speaker or microphone ends at the Mac's size, captions), segmented control (24 tall, 6 corners), checkbox 16 with 4 corners (Mute), push and help buttons. ControlsPage is a dev-only copy of the Mac's Sound layout (--pane controls).
Its files: settings/qml/Switch.qml, settings/qml/PopUpButton.qml, settings/qml/PopupMenu.qml, settings/qml/Slider.qml, settings/qml/Segmented.qml, settings/qml/CheckBox.qml, settings/qml/PushButton.qml, settings/qml/HelpButton.qml, settings/qml/ControlsPage.qml
Tags: settings, controls, switch, slider, qml

## settings-sound — the Sound pane
Settings' Sound, as macOS 26 lays it out, on PipeWire through pulse (pulseaudio-qt): alert sound/device/volume, volume-change feedback, the Output & Input device table (devices with nothing plugged in left out), output volume with Mute, balance, input volume and the 15-pill input level meter (its peak stream open only on the Input side); --pane sound?input opens the Input side.
Its files: settings/qml/SoundPage.qml, settings/qml/DeviceTable.qml, settings/qml/LevelMeter.qml, settings/src/sound.h, settings/src/sound.cpp
Reaches into: settings/qml/FormRow.qml, settings/qml/Slider.qml, settings/qml/Look.qml, settings/qml/SettingsWindow.qml
Tags: settings, sound, pane, qml

## settings-wifi — the Wi‑Fi pane
Settings' Wi‑Fi as macOS 26 lays it out, on NetworkManager: large switch, the network in use (10 pt green dot, Connected), Known Networks (40 tall, tick), Other Networks (44 tall, Connect on hover) with lock and three-bar signal measured from the Mac. Details…, the ⋯ menu, Other… and Advanced… are hidden until the Mac's sheets are captured.
Its files: settings/qml/WiFiPage.qml, settings/qml/NetworkRow.qml, settings/qml/NetworkSignal.qml, settings/qml/Spinner.qml, settings/src/wifi.h, settings/src/wifi.cpp
Reaches into: settings/qml/glyphs.js, settings/qml/Switch.qml, settings/qml/Box.qml, settings/qml/Look.qml, settings/qml/Panes.qml
Tags: settings, wifi, pane, qml

## settings-bluetooth — the Bluetooth pane
Settings' Bluetooth as macOS 26 lays it out, on BlueZ: large switch, discoverable note, My Devices (57-tall rows, name and Connected/Not Connected, matched to the Mac within 0.5 pt), Nearby Devices with spinner and Searching…; Connect/Disconnect on hover; pairing codes come as KDE's banner. ⓘ (rename, forget) hidden until the Mac's sheet is captured.
Its files: settings/qml/BluetoothPage.qml, settings/qml/DeviceRow.qml, settings/src/bluetooth.h, settings/src/bluetooth.cpp
Reaches into: settings/qml/glyphs.js, settings/qml/Switch.qml, settings/qml/Box.qml, settings/qml/Spinner.qml, settings/qml/PushButton.qml, settings/qml/Look.qml, settings/qml/Panes.qml
Tags: settings, bluetooth, pane, qml

## settings-network — the Network pane
Settings' Network as macOS 26 lists it, on NetworkManager: services connected first, a VPN row when NetworkManager holds VPN/WireGuard profiles, then Other Services; 52-tall rows with a 26 pt pane icon, 8.25 pt status dot (green, yellow, the Mac's red), caption status and chevron, within 0.5 pt of the Mac at 2x. Wi-Fi opens our pane; the rest open KDE's connection editor until the service page and ⋯ menu are captured. No Firewall row (none shipped).
Its files: settings/qml/NetworkPage.qml, settings/qml/ServiceRow.qml, settings/src/network.h, settings/src/network.cpp
Reaches into: settings/qml/PaneIcon.qml, settings/qml/Box.qml, settings/qml/SectionHeading.qml, settings/qml/glyphs.js, settings/qml/Look.qml, settings/qml/Panes.qml
Tags: settings, network, pane, qml
