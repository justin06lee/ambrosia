# Files: Ambrosia's Finder, plan (step 1)

Ambrosia's own file manager. It looks identical to macOS Finder in light and
dark, it is faster than Dolphin and Nautilus, and it replaces Dolphin in the
Dock and as the default file manager. Its app id is `org.ambrosia.files` (the
Dock already maps Dolphin's stand-in to that icon), and it is called Files, as
the Dock already calls it.

This is step 1: the research, the stack, the v1 scope, the targets and how
step 2 runs. Nothing is built yet.

## 1. Research: the fastest approach

Measured on tenet on 2026-10-21 unless a source is linked. tenet is an
i7-10700 (16 threads) with 16 GB of RAM, ext4 on a **7200 rpm HDD** (Seagate
ST1000DM010), Dolphin 26.08.2, KIO 6.31 and kernel 7.2. The GPU was idle.
Every run was at `nice 19` with a warm cache, best of 3 to 5 runs. The test
folders were made in /var/tmp and deleted afterwards. The test programs
(`dents.c`, `scan.c`, `gioenum.c`) go into `files/bench/floors/` in step 2.

### (a) Filename search

| What | Number | Source |
|---|---|---|
| Justin's home on tenet | 238,152 entries in 20,923 directories; the full path list is 27 MB | measured |
| `find ~ -iname '*train*'` | 175 ms | measured |
| `rg --files -uuu ~` (the `ignore` crate's parallel walker) | 45 ms with 16 threads, 150 ms with 1 thread, 340 ms on the first run | measured |
| Substring scan of the whole path list held in memory (`memmem`, lower-cased) | **4.3 to 6.1 ms** per query | measured |
| Baloo (KDE's indexer, running on tenet) | 0.9 ms query, but 142 to 214 ms for `baloosearch6` as a process; it indexes only 21,227 of the 238k entries and its index is **275 MiB** | measured |
| plocate vs mlocate on 27M entries | 8 ms vs 20.1 s; index 466 MB vs 1.1 GB; a trigram index read through io_uring | [plocate.sesse.net](https://plocate.sesse.net/) |
| fd vs find on 4M files in 750k directories | 855 ms vs 11.2 to 19.9 s | [fd README](https://github.com/sharkdp/fd) |
| voidtools Everything (Windows) | 1M files: about 1 min to index, 100 MB of RAM; kept fresh from NTFS's USN journal, which Linux has no equivalent of | [voidtools FAQ](https://www.voidtools.com/faq/) |
| Baloo's own figures | 100 to 1000 files a second; bugs with 8 GB RSS (404057) and 50 to 100% CPU (358548) | [KDE wiki](https://community.kde.org/Baloo/Debugging), [404057](https://bugs.kde.org/show_bug.cgi?id=404057), [358548](https://bugs.kde.org/show_bug.cgi?id=358548) |
| updatedb's reuse rule | a directory is reread only if max(ctime, mtime) changed | [mlocate.db(5)](https://manpages.opensuse.org/Leap-16.0/mlocate/mlocate.db.5.en.html) |
| fanotify | whole-filesystem marks (`FAN_MARK_FILESYSTEM`, kernel 4.20) and names (`FAN_REPORT_DFID_NAME`, kernel 5.9) both need CAP_SYS_ADMIN; unprivileged fanotify (kernel 5.13) gets inode marks only | [fanotify_mark(2)](https://man7.org/linux/man-pages/man2/fanotify_mark.2.html), [fanotify_init(2)](https://man7.org/linux/man-pages/man2/fanotify_init.2.html) |
| inotify | `max_user_watches` is 524,288 on tenet (since kernel 5.11 the default is 1% of RAM, clamped to [8192, 1048576]); the home needs 20,923 watches, 4% of that | measured, [kernel commit 92890123](https://github.com/torvalds/linux/commit/92890123749bafc317bbfacbe0a62ce08d78efb7) |

**Choice: a persistent index held in memory, kept fresh by inotify, which
Files keeps resident.** At home-folder scale a trigram index buys nothing: a
plain scan of every path takes 4 to 6 ms, under a frame, and the index can
hold names in a tree rather than full paths, which makes it several times
smaller and faster still. plocate's trigram posting lists only pay off at millions of
entries. That is the design to switch to if search grows to the whole disk.

- **Kept fresh:** one inotify watch per directory under the home and on
  mounted drives, all unprivileged. At startup it applies updatedb's rule:
  stat each directory and reread only the ones whose ctime or mtime moved,
  which costs about 21k stats instead of a full walk. The index is saved as an
  mmap'd snapshot in `~/.cache/ambrosia/files/`.
- **Whole-disk search** ("This Mac") needs fanotify with `CAP_SYS_ADMIN`,
  which means a small root helper. That is later, not v1.
- **Walking instead** is the fallback for anything not indexed (a network
  share, a fresh USB drive): a parallel walker like rg's, streaming results.
  It takes 45 ms for the home with a warm cache, but seconds on tenet's HDD
  with a cold cache, which is why the index exists at all.
- **Type-select and filtering in the open folder** never touch the
  filesystem. The folder model already holds its names and sort keys, so a
  prefix search over the sorted keys or a linear filter over 100k names takes
  well under a millisecond. Finder's type-select (type letters to select an
  item) and the search field's "this folder" scope both use it.

### (b) Content search: ripgrep as a library or as a subprocess

| What | Number | Source |
|---|---|---|
| Starting `rg` as a process | **about 1 ms** | measured |
| `rg -c PATH_MAX /usr/include` (23,904 files, 345 MB) | 22 to 46 ms warm; **30 s cold** on the HDD | measured |
| `grep -rc` on the same | 97 ms | measured |
| rg vs others on the Linux kernel tree | rg 0.082 s, git grep -P 0.273 s, ag 0.443 s | [ripgrep README](https://github.com/BurntSushi/ripgrep) |
| Library API | grep-searcher (Searcher, Sink, binary detection, mmap choice) with grep-regex | [grep-searcher](https://docs.rs/grep-searcher/latest/grep_searcher/) |
| `rg --json` | JSON lines (`begin`, `match`, `end` with stats), byte offsets per submatch | [grep-printer JSON](https://docs.rs/grep-printer/latest/grep_printer/struct.JSON.html) |

**Choice: a subprocess, `rg --json`, streamed.** With 1 ms to start, the
library saves nothing a user can feel. The subprocess also isolates the UI
from a pathological file and cancels cleanly: each keystroke kills the
previous search. The library only wins if the search core moves to Rust (see
the stack). Content search runs on demand, as Finder's "Contents" scope does.
A Spotlight-style content index is not v1: Baloo already shows what one costs
(275 MiB on tenet for 21k files).

### (c) Listing huge folders

| Folder, warm | Names (getdents64) | Names + statx | `ls -l` | Python `scandir` | KIO, as Dolphin uses it | GIO, as Nautilus uses it |
|---|---|---|---|---|---|---|
| 100k files | **14 ms** | 62 ms | 195 ms | 40 ms | 276 ms (`kioclient ls`; 29 ms of it is starting up) | 68 ms for name and type; 196 ms adding size, date and fast type; **1,498 ms** for Nautilus's attribute set |
| 1M files | 138 ms | 676 ms (one thread) | 2,175 ms | 311 ms | 2,620 ms | 3,018 ms (`gio list`, names only, printing included) |

- **Buffer size changes how many calls are made, not the time.** 100k entries
  take 124 calls with a 32 KiB buffer and 5 with 1 MiB, both 14 ms. The first
  batch arrives in 0.13 ms with 32 KiB but 4 ms with 1 MiB, so the first call
  is small, for first paint, and the rest are large. glibc's readdir buffer is
  32 KiB to 1 MiB, in practice 32 KiB
  ([opendir.c](https://raw.githubusercontent.com/bminor/glibc/master/sysdeps/unix/sysv/linux/opendir.c)).
- **stat is the real cost** (0.5 µs a file), and asking for more than you
  show is worse. GIO with Nautilus's full attribute set is 22x the cost of
  name and type. KDE profiled a 7k-file folder taking 5 s or more and found
  per-file `group()` lookups dominating
  ([discuss.kde.org](https://discuss.kde.org/t/dolphin-struggles-to-load-directories-which-contain-many-files/15450)).
  So: d_type from getdents gives the kind with no stat; statx runs only for
  the rows on screen, then for the rest in parallel when a column or the sort
  needs size or date. No owner or group lookups until Get Info.
- **Sorting is the other third.** Dolphin's bug 306290 ("unusable on huge
  folders", reopened) splits the time about evenly between sorting, painting
  and everything else, and reporters see 10-minute freezes on KF6
  ([306290](https://bugs.kde.org/show_bug.cgi?id=306290)). We compute
  collation keys (natural, numeric-aware, like Finder) on the worker thread,
  sort an index permutation there, and hand the model finished batches.
- **Views are virtualized.** Qt Quick's ListView and GridView create delegates
  only for visible items, `reuseItems` recycles them, and TableView recycles
  by default ([ListView](https://doc.qt.io/qt-6/qml-qtquick-listview.html),
  [TableView](https://doc.qt.io/qt-6/qml-qtquick-tableview.html)). The model is
  columnar arrays, with no QObject per file. Nautilus's GTK4 list view still
  showed about 2 s to the first row on 200 images in its first release
  ([#2498](https://gitlab.gnome.org/GNOME/nautilus/-/issues/2498)).
- io_uring statx runs on an io-wq worker every time
  ([io_uring/statx.c](https://raw.githubusercontent.com/torvalds/linux/master/io_uring/statx.c)),
  so a plain thread pool of statx calls is as good and simpler.

### (d) Thumbnails

| What | Number | Source |
|---|---|---|
| Decoding a 24 MP JPEG (7.2 MB, noisy, synthetic) with `djpeg` | 103 ms full; 88 ms at 1/2; 81 ms at 1/4; **66 ms at 1/8** | measured |
| Mozilla, 21 MP: IDCT prescale plus Lanczos vs Lanczos alone | 1/8: 66 ms vs 156 ms | [bug 2033250](https://bugzilla.mozilla.org/show_bug.cgi?id=2033250) |
| KIO's EXIF-embedded thumbnail fast path, about 3,500 12 MP JPEGs | **80 to 120 ms down to 3 to 5 ms** per image | [kio-extras MR 163](https://invent.kde.org/network/kio-extras/-/merge_requests/163) |
| GNOME's sandboxed thumbnailers | 1.7 s direct vs 3.3 s with bubblewrap (MP3 over Samba) | [gnome-desktop #69](https://gitlab.gnome.org/GNOME/gnome-desktop/-/issues/69) |
| GPU JPEG decode | only NVIDIA's A100 hardware decoder has published gains (up to 20x, at batch 128); nothing at thumbnail scale, and no VA-API figures | [NVIDIA blog](https://developer.nvidia.com/blog/leveraging-hardware-jpeg-decoder-and-nvjpeg-on-a100/) |
| freedesktop cache | `~/.cache/thumbnails/{normal 128, large 256, x-large 512, xx-large 1024}`, named by the MD5 of the URI, PNG with `Thumb::URI` and `Thumb::MTime`, failures in `fail/<app>/` | [spec](https://specifications.freedesktop.org/thumbnail/latest/directory.html) |

**Choice:** read and write the shared freedesktop cache, so thumbnails made
by Dolphin, GTK apps or us are reused by all. Generate thumbnails in-process
on a nice'd thread pool, visible items first, cancelled when they scroll away.
For each file, take the first that works:

1. the embedded EXIF thumbnail, if it is big enough for the tile at 2x;
2. libjpeg-turbo's scaled decode, through `QImageReader::setScaledSize`;
3. Qt's image plugins for PNG, WebP, AVIF and JXL;
4. `KIO::PreviewJob` for video (ffmpegthumbs), PDF (kdegraphics-thumbnailers),
   fonts and office files.

**No GPU decode.** It has no measured win at this size, it adds CUDA or VA-API
dependencies, and tenet's GPU belongs to the training job. The GPU's job is
drawing: Qt Quick uploads finished thumbnails as textures.

## 2. Stack

**Qt 6 Qt Quick (QML) for the UI, C++20 for the core, KF6 (KIO, Solid,
KWindowSystem) where it is the native answer. One resident process, like
Finder.**

- **QML** is what the shell is written in, and it imports the same generated
  `Ambrosia` Theme module (`dist/qml`), so every color, size, radius and spring
  comes from `design/tokens.ts`. We draw the whole window: Finder's look isn't
  something Breeze can be styled into.
- **C++ core.** Local folders take our own fast path: getdents64 and statx on
  worker threads, inotify, and a columnar model. Everything else goes through
  KIO, which Plasma already ships: `trash:/` (the same Trash the Dock fills
  with `kioclient move`), smb, sftp and mtp, `recentlyused:/`, and all file
  operations (CopyJob, rename, mkdir, trash, undo through FileUndoManager,
  conflict prompts we draw ourselves). Solid supplies drives and eject.
- **Resident process.** A systemd user unit starts `ambrosia-files` at login
  with no window, as Finder is always running. New windows skip Qt and QML
  startup, and the index and thumbnail caches stay warm. It serves
  `org.freedesktop.FileManager1` (apps' "Show in folder") and an
  `org.ambrosia.Files` D-Bus search API that the shell's Spotlight can use
  later.
- **The window draws its own title bar.** Finder's unified toolbar puts the
  traffic lights inside the sidebar and toolbar, so a server-side frame can't
  match it. The window is frameless, with our traffic lights (the same art as
  the Aurorae frame in `tools/gen/targets/aurorae.ts`), `startSystemMove`
  and `startSystemResize`, KWindowShadow for the shadow and
  KWindowEffects blur-behind for the glass.
- **Menus** come from Qt.labs.platform `MenuBar`, which Qt's platform theme
  should export over DBusMenu, so Files' File, Edit, View, Go, Window and Help
  menus show in Ambrosia's menu bar through the existing AppMenu path. That is
  checked first thing in step 2.

Considered and passed over:

- **Fork Dolphin:** QtWidgets, and restyling it to match Finder exactly is a
  fight with QStyle. Its slow paths (KIO listing, sorting, bug 306290) are the
  ones we would replace anyway.
- **Nautilus or GTK4:** the wrong toolkit for Ambrosia, where Qt is primary
  and the shell is QML.
- **A Rust core via cxx-qt:** the same speed as C++. Its one real gift,
  ripgrep's crates, saves 1 ms over the subprocess. It costs a second
  toolchain and an FFI layer between the model and QML.
- **Electron or Tauri:** startup time and memory.

**No stack fork for Justin.** The one real fork was the look of the sidebar:

> **Decided (2026-10-21): the floating glass sidebar.** This Mac runs macOS
> 26.6.2, whose Finder sidebar is an inset, rounded glass panel floating
> inside the window. `design/DECISIONS.md` ("Behind-window glass for
> sidebars") chose flush sidebars, because GTK can't blur in-app content.
> Files is QML and *can* match macOS 26, so the options were (A) match the
> Mac with a floating sidebar, or (B) keep the house rule, flush. Justin
> picked (A): Files' sidebar is the floating inset glass panel, an exception
> to the house rule for this app only. The flush variant is dropped.

## 3. v1 scope

A polished basic v1, identical to Finder in light and dark:

- **Sidebar:**
  - Favorites: Recents, Applications (installed apps as a folder, opened with
    kstart), Desktop, Documents, Downloads, Home.
  - Locations: this computer, mounted and removable drives with eject.
  - Tags: Finder's seven colors plus custom ones.
  - Items can be dragged to reorder or add.
- **Views:** icon, list (sortable columns, disclosure triangles), column
  (Miller columns with a preview column) and gallery (big preview with a
  filmstrip). Cmd-1 to 4 switch them.
- **Toolbar:** back and forward, the title, the view switcher, the group and
  sort menu, and the search field (filename at once from the index; scopes:
  This Folder or Home; a Contents toggle runs rg).
- **Path bar** (View > Show Path Bar): each segment is clickable and takes
  drops. **Status bar** with the item count and free space.
- **Quick Look on Space:**
  - images;
  - PDFs, through poppler-qt6 (already on tenet);
  - plain text and code;
  - audio and video through Qt Multimedia, software-decoded on tenet;
  - folders;
  - a big icon with metadata for anything else.
  - Arrow keys step through items, and Space or Esc closes it.
- **Drag and drop** within and between windows, to the sidebar and path bar,
  to other apps (text/uri-list), and onto the Dock's Trash. The Dock's
  DropArea already takes MoveAction drops and runs `kioclient move … trash:/`;
  the drag must offer MoveAction. Spring-loaded folders if time allows.
- **File operations:**
  - copy, move, rename (Return, or click a selected name), new folder
    (Cmd-Shift-N), duplicate, Move to Trash (Cmd-Delete);
  - Undo (Cmd-Z);
  - a Finder-style progress window and conflict prompt.
- **Get Info (Cmd-I):**
  - name and extension, kind, size (a folder's computed in the background),
    where, created and modified (statx birth time);
  - tags, Open With, a preview, permissions.
- **Tags:**
  - stored in the `user.xdg.tags` xattr, so Dolphin sees the same tags;
  - colors kept in `~/.config/ambrosia/files/tags.json`;
  - set from the context menu, the File menu and Get Info;
  - the index reads them, so a sidebar tag lists its files at once.
- **Keyboard:** Mac-first, Super as Cmd, as in the rest of Ambrosia:
  - Cmd-N, Cmd-W, Cmd-[ and Cmd-]
  - Cmd-Up and Cmd-Down
  - Cmd-Shift-G (Go to Folder)
  - Cmd-F
  - type-select

Not v1:

- tabs;
- iCloud, AirDrop, and a Network browser (typing a KIO URL in Go to Folder
  still works);
- smart folders and saved searches;
- Open and Save dialogs (the portal's FileChooser);
- Compress, Share and Burn;
- desktop icons;
- whole-disk search (the root fanotify helper);
- a content index.

### Matching the look

- **References:** screenshots of this Mac's Finder (macOS 26.6.2).
  - Taken with `screencapture -o -l <window>` at a fixed window size, over a
    fixture folder that `files/bench/fixture.sh` makes identically on the Mac
    and on tenet (same names, sizes and dates), so the two windows hold the
    same content.
  - Every view, in light and dark: the sidebar, toolbar and path bar, Get
    Info, Quick Look, the tag menu, the progress window.
  - Screen recordings for timing (opening Quick Look, switching views),
    measured frame by frame by timestamp, as for the control center.
  - All of it stays in gitignored `out/parity/files/`, never in git or
    packages.
- **1:1 overlay,** the method that worked for the Dock's Trash: render ours at
  the screenshot's pixel size (headless KWin at the same scale), overlay it,
  take a difference image, and track PSNR per region (sidebar, toolbar, rows,
  path bar) as it climbs, as the Trash went from 18.9 to 20.9 dB.
  Before-and-after pairs go to midna for Justin.
- **Tokens:** every measured value goes into `design/tokens.ts` (a `files`
  group) and reaches QML through `import Ambrosia`: sidebar width, row
  heights, icon grid, toolbar height, radii, selection and tag colors.
  Nothing is hard-coded.
- **Type:** Inter Variable with its optical sizes and the dynamic tracking
  curve already in tokens.ts, in place of SF Pro; tabular figures for sizes
  and dates.
- **Art, our own, drawn by hand in SVG:**
  - sidebar and toolbar glyphs, in the line style of `shell/icons.js`;
  - the blue folder and its special-folder variants;
  - generic document icons by kind;
  - tag dots.
  - No SF Symbols, nothing from Finder.app, CoreTypes.bundle or any system
    bundle, no SF fonts.
  - The app icon is Shell and Session's `assets/icons/org.ambrosia.files.svg`,
    installed by ambrosia-theme as the hicolor icon `org.ambrosia.files`. The
    desktop file (`Icon=org.ambrosia.files`) and the window icon use that
    name.

## 4. Performance targets

On tenet, warm cache, measured by the step 2 harness with a 4K screen at 2x.
**TBM** means to be measured in step 2. The current-app columns give the
backend floor measured today; a full GUI time is TBM. Dolphin is 26.08.2.
Nautilus isn't installed on tenet, and installing it now would mean a
`pacman -S` without `-Syu`, so it is measured in the QEMU VM (or after
tenet's next sanctioned upgrade).

| # | Scenario | Files target | Dolphin now | Nautilus now | Floor (measured) |
|---|---|---|---|---|---|
| 1 | New window with the home listed (process resident) | ≤ 100 ms | TBM | TBM | — |
| 2 | Cold launch to a listed window | ≤ 400 ms | 348 ms (50 files, whole window) | TBM | — |
| 3 | 100k-file folder: first rows painted | **≤ 30 ms** | TBM | TBM | 0.13 ms first batch |
| 4 | 100k-file folder: complete, sorted by name | **≤ 150 ms** | 2,151 ms whole window (KIO listing alone 276 ms) | TBM (GIO with its attributes alone 1.5 s) | 14 ms names, 62 ms with statx |
| 5 | 1M-file folder: first rows / complete | ≤ 250 ms (was ≤ 50) / ≤ 1 s | TBM (KIO alone 2.6 s; bug 306290) | TBM (GIO names alone 3.0 s) | 138 ms / 676 ms |
| 6 | Type-select or filter in the 100k folder | ≤ 4 ms a keystroke | TBM | TBM | — |
| 7 | Filename search over the home (238k entries) | **≤ 10 ms** a keystroke | TBM (Baloo: 0.9 ms query, 142 ms per call, 21k files indexed) | TBM | scan 4 to 6 ms; walk 45 to 175 ms |
| 8 | Content search: first hit | ≤ 100 ms, streaming | TBM | TBM | rg 22 to 46 ms on 345 MB |
| 9 | A screenful (about 40) of cached thumbnails | ≤ 50 ms | TBM | TBM | — |
| 10 | First uncached thumbnail, 24 MP JPEG | **≤ 20 ms** with EXIF, ≤ 80 ms without | TBM (EXIF path 3 to 5 ms) | TBM | 66 ms at 1/8 |
| 11 | Quick Look, 24 MP JPEG, to first frame | ≤ 100 ms | n/a | TBM (Sushi) | — |
| 12 | Scrolling a 100k list or icon view at 4K | no frame over 16.7 ms | TBM | TBM | — |
| 13 | Memory with the 100k folder open | ≤ 120 MB RSS | 224 MB (software GL) | TBM | — |
| 14 | Index: load at login / a change reflected | ≤ 100 ms / ≤ 1 s | — | — | — |

Slice 1 as measured by `files/bench/run.sh` (warm): #3 40 ms, #4 64 ms, #5
232 ms / 513 ms. #3 misses by 10 ms: about 25 ms is the worker, the rest is
the GUI thread still building the first window. #5's first-rows target was
50 ms; reading the 1M names alone takes 138 ms, so no sorted first screen can
come sooner, and the target is now 250 ms.

Whole windows, timed from outside by `files/bench/gui.sh` (2026-10-21, r127
plus the probe's accessible name): from exec until the window reports the
folder's count over AT-SPI, on a headless KWin at 2x with Mesa's software GL,
warm cache, median of five after a warm-up run. Dolphin is timed the same way
by its status bar.

| Folder | Files, list | Files, icons | Dolphin | RSS: Files / Dolphin |
|---|---|---|---|---|
| 50 files | 137 ms | 130 ms | 348 ms | 231 / 120 MB |
| 100k files | 157 ms | 141 ms | 2,151 ms | 241 / 224 MB |

So #2 holds with room to spare, and the 100k window is complete 14x sooner
than Dolphin's. #4's whole-window 157 ms is 7 ms over the 150 ms target; most of
it is starting the app, which #2 counts too. #13 misses: Files sits near 235 MB
whatever the folder size, which points at the Qt Quick scene graph on software
GL rather than the model; it is to be re-measured on the GPU in the real
session before it counts. The 1M run was stopped by the strain watchdog at a
load of 14, while other jobs were running on tenet (memory peaked at 831 MB of
the run's 4 GB cap), so #5 is still to be measured whole.

Cold-cache numbers matter on tenet's HDD (rg went from 22 ms to 30 s).
Measuring them means dropping caches system-wide, which is only done when
tenet is idle and with an okay; until then it's warm only.

## 5. Step 2: build it on a branch, with the benchmarks in the repo (in progress)

**Shipping in slices** (the lead's call, 2026-10-21). Each usable slice is
merged, packaged and reported with screenshots, a recording and its numbers.
Slice 1, a Finder window that browses folders (sidebar, toolbar, list and
icon views, path bar, menus in the menu bar), merged in 59e9610 and ships as
`ambrosia-files` from r103. Slice 2 is file operations and drag and drop;
with it, Shell and Session moved the Dock pin and the default for folders
from Dolphin to Files (d0dd093), and Dolphin stays installed; it shipped
in r148. Slice 3, the Columns view, shipped in r152; slice 4 is the
Gallery view, shipped in r159.

**Slice 2, file operations** (`FileOps` in `src/fileops.cpp`, all through
KIO and recorded in KIO's undo manager):

- New Folder (⇧⌘N) opens "untitled folder" in its rename field.
- Rename: Return, or a click on a selected name. The field selects the name
  without its extension, and a taken name gets Finder's alert.
- Duplicate (⌘D) makes "notes copy.md", then "notes copy 2.md".
- Copy (⌘C), Paste Item (⌘V) and Move Item Here (⌥⌘V). Cut stays greyed,
  as in Finder.
- Move to Trash (⌘⌫) goes to the real freedesktop Trash; in the Trash the
  same key is Put Back.
- Undo (⌘Z) and Redo (⇧⌘Z) carry Finder's labels both ways: "Undo Move of
  “notes.md”" becomes "Redo Move of “notes.md”", and also "Undo Rename" and
  "Undo New Folder". Undoing New Folder skips KIO's delete prompt, while
  undoing a copy still asks.
- Drag and drop: rows and icons drag out to other apps and to the Dock.
  Drops land on folder rows and icons, the sidebar, the path bar and the
  folder's empty space. A drop moves on the same disk; across disks, or
  with Option, it copies.
- Views stay put through all of it: a re-read is matched against the rows
  on screen and applied as inserts, removals and moves, so scroll and
  selection survive. The Trash view follows KDirNotify.
- `org.ambrosia.Files.Trash(as urls)` on `/org/ambrosia/files` (service
  `org.ambrosia.files`) trashes undoably. The Dock's Trash should call it
  while Files runs, because `kioclient move … trash:/` isn't recorded by
  KIO's undo.
- The sidebar is swappable behind one interface (`SidebarList.qml` holds the
  shared contents). The default is the floating inset glass panel
  (`Sidebar.qml`). The flush behind-window panel (`SidebarFlush.qml`) is
  kept as an unpolished stub, chosen with `--sidebar flush` or
  `sidebar=flush` in `~/.config/ambrosia/files.conf`.
- Not yet: a progress view for long copies (jobs run with KIO's progress
  hidden), and spring-loaded folders.

**Slice 3, the Columns view** (⌘3; `qml/ColumnPane.qml`), measured from
this Mac's Finder:

- **Layout:** 245-point columns with 24-point rows, 18-point icons and
  names at 40 points. The selection is a pill inset 10.5 points. Folders
  carry a chevron.
- **What it shows:** the folders from the columns' root down to the
  window's folder, each greying the item that leads on. After them comes
  the one item selected: a folder's contents, or a preview of a file (its
  icon, name, kind and size, and date modified).
- **The window's folder is the focused column,** so keys, the selection,
  type-select, rename, New Folder, drag and drop, Undo and Redo work there
  as in the other views.
- **Moving between columns:** a click in any column moves the window there.
  → goes into the selected folder and selects its first item; ← goes back
  out. Moving between columns doesn't add to Back. Going somewhere else
  (the sidebar, Back, ⌘↑, the path bar) starts the columns afresh.
- **Each column reads its own folder.** FolderModel shares complete
  listings by folder and order, so the window's model takes a column's
  listing at once as it moves in, and re-reads it in the background.
- **Resizing:** dragging a divider sizes its column; with Option, every
  column.
- **Not yet:** Finder's full preview pane (Quick Look, More…) and
  remembered column widths.

**Files stays running, as Finder does** (r155):
- **At login:** `ambrosia-files.service`, a user unit for the Ambrosia
  session that `plasma-workspace.target` wants, starts `ambrosia-files
  --background` with no window, at about 65 MB.
- **Closing the last window keeps it running,** and the Dock's Quit only
  closes windows.
- **Every launch is a window in that one process:** the Dock, a folder
  opened anywhere, `ambrosia-files <dir>`.
- **So the Dock's Trash always trashes through Files,** and ⌘Z undoes it.

**Slice 4, the Gallery view** (r159; ⌘4; `qml/GalleryPane.qml`,
`qml/PreviewPane.qml`), measured from this Mac's Finder:
- **Layout:** the item selected, large (an icon 0.8 of the space under the
  toolbar), over a filmstrip of 59-point cells with 48-point thumbnails. The
  selection sits on a grey rounded square. Pictures Qt reads (PNG, JPEG,
  WebP, GIF, BMP, TIFF, SVG) show as themselves, at the size shown;
  everything else shows as its icon.
- **The preview pane:** 240 points on the window's right, on Finder's grey,
  under the toolbar. It shows the item's icon, name, kind and size, and
  Created, Modified and Last opened (`FolderModel.timesAt`). With several
  selected it says "N items". View > Show Preview (⇧⌘P) hides it; the same
  item hides the Columns view's preview column. The pane hides by itself
  when the window is too narrow for it.
- **Always an item:** the first in a folder just shown; when the item shown
  is trashed or moved, the one now in its place.
- **Keys and the mouse:** arrows and type-select move through the
  filmstrip. A click selects (with ⇧ or ⌘, adds), and a double-click opens,
  in the filmstrip or on the large item. Return renames in the pane (under
  the large item when the pane is hidden). Drags start from either; drops
  on a folder in the filmstrip go into it, anywhere else into the folder.
  New Folder, Trash, Undo and Redo work as in the other views.
- **Not yet:** thumbnails of documents (slice 8), Tags and More… in the
  pane, folder sizes, and the selected item in the path bar.
- `--active` draws the first window active, so headless grabs compare
  fairly with Finder's active references. Without it, the Columns view's
  earlier report blamed a difference on the code that was really the grab's.

**Branch** `feat/files`. A worktree is fine for development; publishing is
always from the main checkout (packaging trap gyv6e).

**Where things go:**

- `files/`, the app:
  - `CMakeLists.txt` (C++20, Qt 6.12, KF6 KIO, Solid, KWindowSystem);
  - `src/`: Lister, FolderModel, Index, Search, Thumbnailer, FileOps, Tags,
    DBus;
  - `qml/`: Window, Sidebar, Toolbar, PathBar, IconView, ListView,
    ColumnView, GalleryView, QuickLook, GetInfo;
  - `art/`, the hand-drawn SVGs;
  - `org.ambrosia.files.desktop` and `ambrosia-files.service` (the systemd
    user unit).
- `files/bench/`, the benchmarks:
  - `fixture.sh` makes the deterministic folders (1k, 10k, 100k and 1M
    files, a photo set with and without EXIF thumbnails). The same script
    runs on the Mac for references.
  - `floors/` holds today's `dents.c`, `scan.c` and `gioenum.c`.
  - `probe.py` times any app the same way, from outside: from exec until its
    status bar reads "N items" through AT-SPI, and the first frame with rows
    from KWin's screenshots. The same probe covers Files, Dolphin and
    Nautilus, so the table is apples to apples.
  - In-process QBENCHMARKs for the model: insert, sort, filter, collation.
  - `run.sh` runs every scenario × app and writes
    `out/bench/files/<host>-<date>.json`.
  - `targets.json` holds the table above.
  - `report.ts` (bun) prints the table and exits non-zero when a target is
    missed or a number regresses by more than 10%.

**How it runs:**

- `make files` builds.
- `make bench-files` runs the benchmarks on the local machine.
- On tenet: `AMBROSIA_RSH=ssh tools/remote.sh root@192.168.1.172 make
  bench-files`.
  - Always under `nice 19 ionice -c3`, in a headless `kwin_wayland --virtual`,
    so Justin's screen is never touched.
  - Never on the GPU; video decodes in software.
  - No `-Syu`.
  - Fixtures go in /var/tmp and are deleted afterwards.

**Order of work.** Each item lands with its numbers and a before-and-after
pair:

1. The harness, the fixtures and the Dolphin baselines.
2. Lister and FolderModel with the list view, proving targets 3 to 6 before
   anything else.
3. Window chrome, sidebar, toolbar and path bar, to overlay parity in light
   and dark.
4. Icon, column and gallery views.
5. File operations, undo and drag and drop, including onto the Dock's Trash.
6. Quick Look, Get Info and tags.
7. The index and search.
8. Thumbnails.
9. Packaging and the Dock switch, done by their owners (below). Then tenet,
   a demo video, and a report to midna.

**Work for other teammates when v1 is ready:**

- **Packaging and Image:**
  - a new `ambrosia-files` package. It depends on qt6-declarative, kio,
    kio-extras, solid, kwindowsystem, libjpeg-turbo, poppler-qt6,
    qt6-multimedia, ripgrep, ffmpegthumbs and kdegraphics-thumbnailers. The
    last two aren't on tenet yet.
  - ambrosia-desktop then depends on it; Dolphin stays until v1 is accepted.
- **Shell and Session:**
  - the Dock pin moves from `org.kde.dolphin` to `org.ambrosia.files`, the
    stand-in goes, and the menu bar's "New Window" action follows;
  - `inode/directory` defaults to Files in `/etc/xdg/ambrosia`'s mimeapps
    list;
  - Files' running dot: the process is always up, as Finder's is;
  - later, Spotlight's file results from `org.ambrosia.Files`.
  - Trap to check: Dolphin also ships an `org.freedesktop.FileManager1`
    D-Bus service, and two activatable owners of the same name is ambiguous.

**What step 2 will settle:** whether Baloo stays on in the Ambrosia session
once Files' index covers filename search. That is Shell and Session's call,
with these numbers.
