# ambrosia — Files App

One layer of ambrosia's stack, owning `docs/finder/, files/, files/tools/, scratch/ql/shoot.sh, scratch/ql/wins.js, scratch/tags/shoot.sh, scratch/tags/tag.js, scratch/search/Look/build.sh, scratch/search/shoot.sh, scratch/search/shoot2.sh, scratch/thumbs/shoot.sh, scratch/thumbs/shootkinds.sh, scratch/thumbs/tools/prof.py, scratch/thumbs/tools/span.py, scratch/parity/shootscroll.sh, scratch/parity/ink.py, scratch/parity/shootmore.sh, scratch/parity/shootpane.sh`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer files-app` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer files-app add|set|drop <section> …`. Where it and the code disagree, the code is right.

Files, Ambrosia's Finder: a frameless Qt Quick window drawn like macOS 26's Finder (floating glass sidebar and toolbar, icon, list, column and gallery views, path bar, menus in the menu bar) over a C++20 core: getdents64 + parallel statx + natural-sort keys for local folders, KIO otherwise. Finder's measurements live in files/qml/Finder.qml; art is ours. A resident instance keeps an in-memory filename index of the home for ⌘F, with rg for contents. Built, benchmarked and recorded on tenet with files/tools/tenet.sh; the Mac only edits and runs git.

## Where to change what

- **App icon, desktop identity, the plan and its step tracking, the handoff note:** assets/icons/org.ambrosia.files.svg, docs/finder/PLAN.md, docs/finder/HANDOFF.md
- **The Finder window (sidebar with mounted disks and eject, Applications, toolbar, icon and column views, path bar, keys, selection, progress window for long copies and moves):** files/qml/FinderWindow.qml, files/qml/Sidebar.qml, files/qml/IconPane.qml, files/qml/ColumnPane.qml, files/qml/Toolbar.qml
- **Traffic lights (close, minimise, zoom) on Files' window:** files/qml/TrafficLights.qml
- **Search (⌘F): the toolbar's field, suggestions and token, the scope bar (This Computer, the folder) and Kind pop-up, search: results in Name/Kind/Date Last Opened, contents read with O_NOATIME, sidebar tags:** files/qml/SearchField.qml, files/qml/ScopeBar.qml, files/src/index.cpp, files/src/foldermodel.cpp, files/src/contents.cpp
- **Gallery view (⌘4), the preview (gallery pane and last column: Information, Show More, Tags, quick actions), thumbnails and their frame:** files/qml/GalleryPane.qml, files/qml/PreviewPane.qml, files/qml/PreviewDetails.qml, files/qml/QuickActions.qml, files/qml/FileIcon.qml
- **List view columns and user-resizable dividers (Size|Kind, Date|Size):** files/qml/ListPane.qml
- **Finder's menus in the menu bar (items, shortcuts, actions, Go menu with Applications, Edit undo and redo):** files/qml/MenuBar.qml
- **Finder's measured sizes and window colors (light/dark):** files/qml/Finder.qml
- **Folder listing, sorting, KIO fallback:** files/src/foldermodel.cpp, files/src/foldermodel.h, files/src/sortkey.cpp
- **Sizes, dates, kinds and tags as Finder shows them:** files/src/format.cpp, files/src/tags.cpp, files/qml/TagDots.qml, files/qml/TagField.qml
- **Folder and document art, line glyphs:** files/art/, files/qml/glyphs.js

## How it works

- **Menu action from the menu bar:** files/qml/MenuBar.qml exports each menu, item and shortcut over DBusMenu → the shell draws them on a grabbing popup and calls AboutToShow on every open (Quickshell -3) → each Platform.Menu counts itself into FinderWindow.menusOpen, so the window keeps looking active → the action runs against the window captured when the menu opened
- **Icon and identity:** assets/icons/org.ambrosia.files.svg → ambrosia-theme installs it to hicolor → the desktop id, its Icon= and the window icon are all org.ambrosia.files → Shell and Session's Dock pins the app by that name
- **Build and look on tenet:** files/tools/tenet.sh build rsyncs the Mac's files/ (uncommitted included) to /root/ambrosia-files/src → capped cmake+ninja in /root/ambrosia-files/build → offscreen grabs (--grab) or real-session takes with the helpers in /var/tmp/files-rec
- **File operation:** key, menu item or drop in FinderWindow.qml → FileOps starts a KIO job recorded by FileUndoManager → KDirWatch, or KDirNotify for trash:/, re-reads the folder → FolderModel diffs the listing against the rows on screen (inserts, removals, moves) → FinderWindow selects the results by URL
- **Search:** ⌘F or the toolbar's button opens SearchField → a search: URL in one history place → FolderModel asks Index for names (rows at once, statx a pass later), rg for contents in a folder scope → Index::changed rereads it

## Key files

- docs/finder/PLAN.md — the plan: research, stack, scope, measured targets, slices 1–8 and their follow-ups (r103–r205)
- docs/finder/HANDOFF.md — the handoff note for the next session: where Files stands at r205 and the open toolbar branch
- files/qml/MenuBar.qml — Finder's menu tree, with the shortcuts exported to the shell
- files/qml/TrafficLights.qml — Files' close, minimise and zoom lights, sized and drawn to match macOS
- files/src/fileops.cpp — KIO-backed move, copy, Trash, rename and new folder, with undo and redo labels
- files/src/foldermodel.cpp — folder listing, sorting and diffed re-reads
- files/tools/tenet.sh — builds, benchmarks and grabs the app on tenet, capped
- files/src/thumbnailer.cpp — image://thumb: freedesktop cache, two idle-I/O threads pausing above 30% I/O pressure, Finder's frame (/tile); previews.cpp makes video frames (ffmpeg on our fd), font tiles (FreeType), covers (TagLib), office pages (KZip)
- files/src/index.cpp — the home's in-memory index: parallel walk, inotify (watches in an array), ~/.cache snapshot checked as updatedb does, gone rows dropped on load and save, AVX2 name scan; --bench-search times it

## Rules and traps

- Import QtQuick.Controls.Basic only as a namespace (as Controls): its Label otherwise shadows files/qml/Label.qml.
- Grabs: offscreen (--grab) drops MultiEffect but shows thumbnails, whose frame is baked in; tenet.sh grab keeps MultiEffect but crashes KWin if Files stays past about 1 s (gf6dt). Check glass on the real screen.
- Every tenet build and benchmark runs capped (systemd-run MemoryMax=6G -j2 for builds, 4G for probes; nice 19, ionice -c3) and waits while tenet is strained; an uncapped ninja once took it down.
- Screen takes use tenet's one shared screen: one agent at a time, and lock it after. Keep scratch under /var/tmp or /root; tenet's /tmp is RAM.
- tenet.sh builds the Mac's working tree, uncommitted changes included (never point it at a checkout that follows pushed commits); stop a running Files before copying a new build, or the test runs the old one.
- Qt logs go to the journal when stderr isn't a terminal: set QT_FORCE_STDERR_LOGGING=1 to see QML errors over SSH.
- Command is Ctrl in Files (what the Mac-first keyd remap hands apps); the window also accepts Super directly; DBusMenu exports Control, which the shell draws as ⌘ (r120). KWin grabs Meta+Up and Meta+Alt+L on tenet.
- The traffic lights' size (14 pt, 23 pt apart) and 50% black symbols must match the KWin frame and GTK apps; change the shared shape source, not TrafficLights.qml alone.

## What it talks to

- Shell and Session — pins org.ambrosia.files in the Dock and makes it the default for folders; the Dock's Trash calls org.ambrosia.Files.Trash(as urls) (kioclient's trash isn't undoable); Search asks org.ambrosia.Files.Find(query, limit) for names from the index (path then cached thumbnail for each); ⌘Return calls org.freedesktop.FileManager1.ShowItems, which Files answers for every app's Show in Folder (files/src/app.cpp, main.cpp)
- Shell (menu bar) — draws Files' DBusMenu menus on a grabbing popup, which keeps the Files window active while a menu is open and shows each item's shortcut right-aligned
- Packaging and Image — ships ambrosia-files (depends include ripgrep, ffmpeg, taglib, karchive, freetype2; resident login unit) and the patched Quickshell (DBusMenu shortcuts, AboutToShow on every open)
- Design system — Files' traffic lights are drawn from the shared light and dark shape definitions in design/tokens.ts, generated by tools/gen
