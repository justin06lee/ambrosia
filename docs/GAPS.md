# What still tells Ambrosia from a Mac

The running list. The goal is a desktop nobody can tell from macOS 26 in look
and feel; this is everything known to fall short of that, biggest first. Work
goes in rounds: take the top gap that can be built and checked, build it,
look at it (a screenshot, or the thing driven for real), commit, strike it
here, take the next.

**How it's ranked:** by how much of the time the gap is in front of you,
then by how wrong it looks. The pointer is on screen always; a print dialog
once a month.

**What each line says:** the gap, where it stands, and how it was (or will
be) checked. "Seen" means a screenshot or a real run; "from the code" means
nobody has looked yet since this list began (2026-11-18), and the line may be
kinder or harsher than the truth. `CONTEXT.md` says where each lane's work
stands in detail; `docs/finder/PLAN.md`, `docs/settings/PLAN.md` and
`docs/keyboard.md` keep their own lists, which this one points at rather than
repeats.

**Not ours to match:** Apple's own drawings, fonts and sounds. Every icon,
pointer, wallpaper and sound is drawn or made here (DESIGN, the Dock's rules).
A gap closes when ours sits where the Mac's does and reads the same, not when
it is a copy.

## Open, biggest first

### Always in front of you

1. **The pointer: ours, seen on KWin; a few places not looked at.** A theme
   of our own since round 1 (`design/cursors.ts`): a Mac's black arrow with
   its white rim and soft shadow, white hands, the I-beam, resize arrows,
   badges for copy, alias and not-allowed, and a wheel in the accent colors
   for busy. It lives in the same icon theme. Seen on tenet (2026-11-18):
   KWin draws the arrow, the I-beam and the pointing hand over Firefox and
   both resize arrows at a window's edge and corner. Not looked at yet: the
   wheel turning, an Xwayland app, the login screen. Shapes
   still Breeze's (through `Inherits`): the skull of Kill Window, the color
   picker, the pencil. With it, KWin's launch feedback (the app's icon
   bouncing beside the pointer) is off in the session
   (`session/xdg/klaunchrc`): the Dock's icon bounces instead, as a Mac's
   does.
2. **Other apps' icons, folders and files: ours, seen on KWin.** Since round 2 the
   "Ambrosia" icon theme (over Breeze) gives the apps a new install starts
   with an icon of ours on the tile: Terminal, the text editor, the picture
   and document viewers, Calculator, the archiver, the store, Screenshot,
   system information; KDE's settings and Dolphin wear Settings' and Files'.
   The names are the ones those apps' desktop files ask for (read from
   KDE's sources). Seen on tenet (2026-11-18): they sit right in the Dock,
   in Search's results and in ⌘Tab. Since round 10 an app whose icon isn't
   ours (Firefox's fox, Breeze's own) sits on a plain tile of the same
   shape in the Dock, Search and ⌘Tab, as macOS 26 does with icons not
   drawn for it, so a row of apps is a row of tiles (`shell/AppTile.qml`;
   seen on tenet, light and dark, the Dock on each side). Since round 11
   folders and kinds of file are ours wherever an app asks the theme: KDE's
   file dialog, Dolphin, the Downloads stack. The folder, the page, the
   song's tile and the Trash are the art Files and the Dock draw; a special
   folder (Home, Desktop, Documents, Downloads, Pictures, Music, Videos,
   Public, Network) has its glyph pressed into the front, a folder given a
   color is tinted as Files tints a tagged one, and a page carries its
   kind's mark (lines, `</>`, a red PDF label, a picture, a zip, a green
   table, an orange slide; a play mark on the song's tile for a film).
   Under 32 px a special folder is its line glyph alone, in the text's
   color, which makes a sidebar read as a Mac's does; a list of the home
   folder at that size shows the same glyphs between blue folders, because
   KDE asks for one name in both places. Seen on tenet in Dolphin, Kate's
   file dialog and the stack, light and dark, and at twice the scale.
   A notification's icon sits on the plain tile as well when it is an
   icon by name (round 13); a picture it brings is left as it is.
   Still Breeze's or the app's own: the art inside those plain tiles,
   an app icon a notification brings as a file, kinds of file not listed in
   `design/icons.ts` (fonts, disk images, programs, the long tail of text
   and application types: a whole type's fallback can't be drawn without
   taking Breeze's action icons with it, see `tools/gen/lookup.ts`),
   devices, and the one-color status and action icons inside Qt apps (a
   few of which, asked for by a name ending -symbolic, come out as one of
   our colored app icons: kate-symbolic, utilities-terminal-symbolic).
3. **Other Qt apps' controls: ours, switched on.** Since round 3 there is
   a style of ours over Breeze (`style/`, `make gallery`): push
   buttons, checkboxes, radio buttons, text fields, pop-ups, steppers,
   sliders, progress and scroll bars, tool buttons, menus and tooltips as
   the Mac draws them; since round 4 also tabs (a tab view's as a
   segmented control, a window's own as a quiet row), group boxes, the
   rows and headers of lists, trees and tables, a pop-up button's menu,
   toolbars and menu bars. Seen on tenet (2026-11-18) in Kate, Konsole,
   Dolphin, the file dialog and a settings module (which is Qt Quick drawing
   through the style), and the session names it since (`widgetStyle=ambrosia`
   in the look-and-feel). Menus are glass there: as see-through as the
   session tells Breeze to make its own, which is when KWin blurs behind
   them. Still Breeze's: dock widgets' title bars, tool boxes, dials, the
   calendar, an editable combo's list. Menus' shortcuts read Ctrl+X, not ⌘X
   (the keyboard's list). Scroll bars always show, which is a Mac with a
   mouse; one with a trackpad hides them until you scroll.
4. **GTK apps beyond colors.** GTK 3 and 4 get our colors and the traffic
   lights; the controls are Adwaita's. GTK 4's CSS has never been looked at
   (no GTK 4 app on tenet). From the docs.
5. **Glass.** KWin blurs every surface the same and with hard edges: the
   design's heavy, saturated blur behind menus and the Dock, the light one
   behind the control center, its feathered edge, and refraction at the rim
   all wait for a compositor effect of our own (roadmap 4). Seen (parity pass,
   2026-10-20).

### Every few minutes: windows and motion

6. **How windows open, close and minimize.** KWin's own effects with their
   own curves; Settings switches Genie (Magic Lamp) and Scale (Squash) for
   minimizing, but nothing moves on the spring tokens and a minimized window
   doesn't land on its Dock tile. From the code.
7. **⌘Tab: ours, seen on KWin.** Since round 6 KWin's switcher walks apps,
   one window each, on a glass strip of large icons with the chosen app's
   name under it (the look-and-feel's `windowswitcher`); ← → move and Q
   closes the chosen window while it's up. Seen on tenet (2026-11-18): hold,
   Tab on, arrows, let go to switch, with ⌘ and with Alt; the pointer
   choosing, Q, and dark. Since that look it
   has KWin's blur behind the glass and the app's own name ("System
   Settings", not the window's title), both from a small module of ours
   inside KWin (`decoration/qml`, org.ambrosia.kwin). Short of a Mac's:
   switching raises one window rather than all the app's, Q closes a window
   rather than quitting, no ⌘H.
8. **Mission Control and Spaces.** KWin's Overview is there but unstyled and
   on no Mac key or gesture (F3, ⌃↑, three fingers up; ⌃← ⌃→ and a swipe
   between desktops; ⌃↓ for one app's windows). From the code.
9. **Volume and brightness keys: ours, seen on KWin.** Since round 5 they
   show a glass capsule under the menu bar's right end, where the control
   center opens: a glyph and a level, or the name of the output sound moved
   to (`shell/Hud.qml`). Seen on tenet (2026-11-18): the volume keys bring
   it up with the level they set (the bus monitor does hear Plasma's calls
   to a name nobody owns). Brightness was only shown by hand: tenet's
   display has no brightness keys. It takes no clicks, where a Mac's can be
   dragged.
10. **⌘H and ⌘Q.** ⌘H minimizes one window instead of hiding the app; ⌘Q
    only works where the app has Ctrl+Q (`docs/keyboard.md`).
11. **The Dock's right side: Downloads opens as a stack, seen on KWin.**
    Since round 7 clicking Downloads opens its newest things as a grid on
    glass over the Dock (pictures as themselves, the rest by kind), with a
    button for the folder (`shell/Stack.qml`, `StackGrid.qml`). Seen on
    tenet (2026-11-18): the folder read newest first, a picture as itself,
    long names cut, Open in Files, with the Dock at the bottom, left and
    right. Still missing: a fan, sorting and the
    stack's own menu, dragging out of it, minimized windows in the Dock,
    recent apps.
12. **Tiling.** Dragging a window to an edge and the green button's menu
    (Move & Resize, Full Screen on a display) are KWin's quick-tile with its
    own outline. From the code.
13. **Screenshots.** ⇧⌘3/4/5 run Spectacle with its own window; a Mac shows
    a floating toolbar, then a thumbnail in the corner that can be dragged
    or opens Markup. From `docs/keyboard.md`.
14. **The desktop itself: a right-click menu, seen on KWin; the rest
    open.** Since round 9 the right button on the desktop opens a menu
    (`shell/Wallpaper.qml`): New Folder, which makes "untitled folder" in
    ~/Desktop and shows it in Files, and Change Wallpaper…. Still no icons
    on the desktop (so the new folder appears in Files, not under the
    pointer), no widgets, no stacks, and none of a Mac's Sort By, Clean Up
    or Show View Options, which need the icons. Seen on tenet
    (2026-11-18): the menu opens at the pointer and both items do their
    work.
15. **Trackpad gestures.** Whatever KWin does out of the box; nothing set
    to a Mac's (swipe between desktops and full-screen apps, Mission Control,
    pinch for the apps, two-finger swipe from the right edge for Notification
    Center). No real trackpad has been tried (`CONTEXT.md`).
16. **Menu bar extras from apps: there, seen on KWin.** Since round 12 an
    app's own status item (the tray) sits in the menu bar, left of ours
    (`shell/MenuBar.qml`, `StatusIcon.qml`). A press opens the app's menu on
    our glass, as a Mac's status items are menus; an item with no menu does
    what its app does on a click, and the middle button always does. An
    icon that is mostly gray is drawn as its shape in the bar's own text
    color, light or dark, the way a Mac draws a template image; one in
    color is left alone. An item its app marks passive stays out. Seen on
    tenet (2026-11-18) with Discover's update notifier: the glyph in light
    and dark, its menu (read ahead of the first press: fetched at the
    press, it came up a second or two late after the shell started). Not seen: an item without a menu, one in color, an
    Xembed-only tray icon (those need a proxy we don't run). Still missing:
    a way to hide one in Settings (the bar already honors
    `menuBarHidden: ["extra:<id>"]`), reordering by ⌘-drag, and an input
    source item.

### System surfaces

17. **The lock screen.** KDE's locker in Breeze's look; the login screen is
    ours (`packaging/sddm-theme`) and the two should be one picture. Read
    from kscreenlocker's sources (2026-11-18): its QML no longer comes from
    the look-and-feel package but from a Plasma shell package
    (`contents/lockscreen/LockScreen.qml`, `X-Plasma-APIVersion` 2, named
    to the greeter with `--shell`; `org.kde.plasma.desktop` is the
    fallback), so ours needs a shell package of its own and a way to name
    it. A broken one falls back to a built-in screen rather than locking
    the user out. Left for when it can be run: it is the one surface where
    a mistake keeps someone out of their session.
18. **Starting up and shutting down.** No boot picture (Plymouth), kernel
    text on the way up and down; the image's UEFI menu is text (Needs Justin
    in `CONTEXT.md`).
19. **Password prompts.** polkit's and KWallet's dialogs are KDE's. A Mac's
    is a small sheet with the app's icon and a lock.
20. **Open and Save.** KDE's file dialog; ours should be Files' own panes, in
    every app, through the desktop portal (roadmap 6).
21. **Print, colors, fonts, emoji.** Qt's print dialog and color picker,
    KDE's emoji picker.
22. **Force Quit.** ⌥⌘Esc gives KWin's skull pointer to click a window with,
    not a list of apps.
23. **Sounds.** No sounds of our own: the alert, the Trash, a screenshot, the
    volume step.
24. **The first minutes.** The installer asks with kdialog; a new account
    lands on the desktop with no welcome (roadmap 7).

### Apps

25. **The apps a Mac comes with.** Ours: Files, Settings. Stand-ins, in
    Breeze's dress: Konsole (Terminal), Kate (TextEdit), Gwenview and Okular
    (Preview), KCalc (Calculator), Ark (Archive Utility), Discover (App
    Store), Spectacle (Screenshot), Firefox (Safari). Nothing yet for
    Activity Monitor, Disk Utility, Calendar, Notes, Reminders, Music,
    Photos, Mail, Font Book. Which to build and which to dress is the
    largest open piece of work on this list.
26. **Files.** `docs/finder/PLAN.md`, "Still short of Finder": Open With,
    Compress and Share in the menu, tag rename and delete, spring-loaded
    folders, tabs, Quick Look's black full screen.
27. **Settings.** What each pane leaves out is in `docs/settings/PLAN.md`
    and `CONTEXT.md` (Next, 7): the trackpad's gesture tabs, scanners,
    VoiceOver, and the sheets still of our own design.

### Feel

28. **Scrolling.** No rubber band at the end of a list and no momentum
    carried between apps the way a Mac's trackpad does; each toolkit scrolls
    its own way. Not measured.
29. **Text.** Inter stands in for San Francisco by decision; how it sets
    (weight at small sizes, emoji, the system's CJK faces) has only been
    compared in Settings and Files.

## Closed

Nothing since the list began. What was built before it (the menu bar, Search,
the Dock, the control center, Notification Center, the window frame, the
login screen, the keyboard, Files, Settings) is in `CONTEXT.md`.

## Rounds

| Round | Gap | What was built | Checked how |
|---|---|---|---|
| 13, 2026-11-18 | 2, notifications' icons | A banner's and a Notification Center card's icon goes through `AppTile`: one by name that isn't ours gets the plain tile (`NotificationStore.plainOf`; what was heard before is judged by its source, `plainSource`), a picture or a file doesn't. Found on tenet and fixed: notify-send hands an icon's name over as the picture (`image://icon/<name>`), so the rule reads that too; and a banner pushed down while still arriving stayed faint (ListView cuts the arrival short: the displaced transition now finishes it). The Mac's stand-in for icons answers from `sheets/art/` too (`other-app`) | On the Mac: `out/shots/shell-desktop-banner-*.png`, `shell-desktop-notifications-*.png` with a stand-in for another app's icon, light and dark. On tenet: Firefox's and a warning's icon by name on the tile, Kate's and Files' as they are, a PNG by path untiled, an entry from last week tiled, three banners arriving together all opaque; as banners and in Notification Center, light only |
| 12, 2026-11-18 | 16, menu bar extras | Apps' status items in the menu bar through Quickshell's tray service: a `MenuBarItem` can carry a picture; `shell/StatusIcon.qml` tells a glyph from a picture by its pixels and draws a glyph in the bar's text color; a press opens the app's own menu (the path the focused app's menus already take). A stand-in tray for the Mac (`stubs/Quickshell/Services/SystemTray`) and a sheet | On the Mac: `out/shots/shell-desktop-extras-*.png` (a white glyph with a blue dot comes out dark on the light bar and white on the dark one, a colored mark stays, a passive item stays out, the menu opens under its item). On tenet: Discover's notifier in the bar in light and dark, its menu opened and closed by pressing the item |
| 11, 2026-11-18 | 2, folders and files | The icon theme's folders (`places/`: plain, nine special ones with a glyph, eleven colors, the Trash), kinds of file (`mimetypes/`: ten kinds under 178 names) and the line icons a theme with "folder" must bring (`actions/`: New Folder and four more), each with a drawing for under 32 px and @2x folders for doubled screens; `tools/gen/lookup.ts` is KDE's rule for a name a theme lacks, and a test over Breeze's names (`tools/gen/breeze-names.txt`) holds that we take nothing we don't mean to. It found that every settings module in KDE's System Settings wore our gear since round 2 (the names `preferences-system` and `preferences-desktop`): taken out. In the stack, a picture that can't be read wears its kind's icon | On the Mac: `dist/icons/sheet.html` (every drawing at 96, 48, 32, 22 and 16, the small ones on light and dark), the stack's sheet with the theme's icons. On tenet: Dolphin (icons at home and in Downloads with a file of each kind, its sidebar, its shortcut menu's color row and Create New), Kate's file dialog (16 px rows and sidebar), the Downloads stack; Dolphin again in the dark scheme and at twice the scale; KDE's System Settings' own module icons after the package was installed |
| 10, 2026-11-18 | 2, app icons | A plain tile under any app icon that has none of its own: `shell/AppTile.qml` (only QtQuick, so KWin's switcher uses it too), in the Dock, Search's app results and ⌘Tab; the KWin module tells the switcher which icon an app wears (`Apps.icon`) | On the Mac: the switcher's sheet with a stand-in for another app's icon. On tenet: Firefox on its tile in the Dock, Search and ⌘Tab (from a test copy), light and dark. Looked at along the way: the Dock on the left and right (the stack and a Dock menu beside it), ⌘Tab's pointer and Q, ⌘Tab in dark |
| The tenet check, 2026-11-18 | Rounds 1 to 9 | Every round installed on tenet and driven on KWin 6.8 and Quickshell 0.3.2. All nine worked. Fixed from that look: ⌘Tab had no blur and named apps by their window's title (a module of ours inside KWin now gives both: `decoration/qml`); the style's menus were see-through by accident (painted as a disabled control) and are now glass on purpose, where KWin blurs behind them; a chosen row in the file dialog was two colors; KDE's push buttons kept their pictures; the Dock's menu overlapped the Dock's glass; a notification stack's peeking card had square corners; the note on showing the HUD by hand was wrong (`call hud -- show volume 45`). The session names our widget style since | On tenet's live session: pictures of each (`spectacle`), keys and clicks through a virtual keyboard and pointer. ⌘Tab's new files ran there from a test copy: a running KWin keeps the layout it loaded, so the installed one shows at the next login |
| 9, 2026-11-18 | 14, the desktop | A right-click on the desktop opens its menu at the pointer (`shell/Wallpaper.qml`, on the Overlay like every menu): New Folder (a script names it as a Mac does and Files is asked to show it) and Change Wallpaper… (Settings' pane) | On the Mac, through the stand-ins: a right press on the sheet's desktop opens the menu at the pointer in light and dark (`out/shots/shell-desktop-context-menu-*.png`); choosing New Folder ran the script and asked Files to show `untitled folder 2` by a well-formed URL. Not run under Quickshell or KWin |
| 8, 2026-11-18 | Tooling, for every shell gap | The shell's own files drawn on the Mac: stand-ins for Quickshell and Plasma (`tools/qmlshot/stubs/`, `stubs.h`), a staged copy of `shell/` with a qmldir for its singletons, `parts/Desk.qml` (the desktop as the shell puts it up) and ten `desktop-*` sheets that open things on it with real pointer and key events. Fixed from the first look: Notification Center's shadows cut by the list's clip, a wrapped card overlapped by the next, the Dock's menus placed from the scene instead of its window | On the Mac: `make shell-shots`, 13 sheets in light and dark, each looked at. The stand-ins are not Quickshell: nothing here has run on it |
| 7, 2026-11-18 | 11, the Dock's right side | Downloads as a stack: `shell/StackGrid.qml` (the grid's picture), `shell/Stack.qml` (reads the folder's newest 24 with `ls -t` and `file`, icons by kind from the icon theme, pictures as themselves), a place on the Overlay, `Popups.toggleStack` | On the Mac: the grid full, part full and empty, light and dark (`out/shots/shell-stack-*.png`). Not run under Quickshell |
| 6, 2026-11-18 | 7, ⌘Tab | A switcher layout of our own in the look-and-feel package (`contents/windowswitcher`): the strip's picture in `SwitcherStrip.qml`, KWin's side in `WindowSwitcher.qml`; kwinrc names it and sets one window an app | On the Mac: the strip with six apps and with fifteen (icons shrink to fit), light and dark (`out/shots/shell-switcher-*.png`); KWin's API read from its sources (TabBoxSwitcher, the model's roles, where a layout is looked for). Not run on KWin |
| 5, 2026-11-18 | 9, the keys' display | `shell/Hud.qml`: a capsule for the volume and brightness keys, fed by Plasma's own calls to `org.kde.osdService` heard on the bus; `tools/qmlshot` and `make shell-shots`, which draw pieces of the shell on the Mac with Qt's real renderer and no window | On the Mac: the panel in six states, light and dark (`out/shots/shell-hud-*.png`), in the Mac's font (no Inter here). The window, the blur and the listening need Quickshell: not run |
| 4, 2026-11-18 | 3, Qt apps' controls | The style's second cut: tabs (segmented for a tab view, a quiet row for a window's own, close buttons on the left under the pointer), group boxes, rows of lists, trees and tables (rounded highlight joining chosen neighbors, gray without the focus), tree arrows, table headers, a pop-up button's choices as a menu, flat toolbars, menu bar items, splitters, the focus ring on checkboxes and radios, a busy bar that moves; new `tab`, `box`, `row` tokens | On the Mac: the gallery in light and dark, each new control looked at, and the busy bar caught moving between two grabs. Over Fusion only; what could differ over Breeze is noted in `CONTEXT.md` |
| 3, 2026-11-18 | 3, Qt apps' controls | A Qt widget style (`style/`, ambrosia-style): a proxy over Breeze drawing twelve kinds of control from the Mac's measured sizes (new `controls` tokens), dialog buttons in the Mac's order, no underlined letters; a gallery that draws them with no display | On the Mac, for real: built against Qt 6.12 and rendered by the gallery in light and dark (`out/shots/style-*.png`), each control and state looked at. Over Fusion only: not yet over Breeze, nor in a real app |
| 2, 2026-11-18 | 2, app icons | The "Ambrosia" icon theme over Breeze: nine app icons drawn in `design/icons.ts` on the tile Files' and Settings' sit on, under the names the installed apps ask for; the pointer moved into it; named by the look-and-feel and the session's GTK defaults; the Dock takes its list of tile icons from the theme | On the Mac: `dist/icons/sheet.html` (each icon at 128, 48, 32 and 20, and in a row at the Dock's size on light and dark glass) and the review site's Iconography chapter; tests for names, links and what Qt's SVG reader can draw. Not on KWin |
| 1, 2026-11-18 | 1, the pointer | The "Ambrosia" pointer theme: 24 shapes drawn in `design/cursors.ts`, generated as Xcursor files, KWin SVGs and CSS; named by the look-and-feel, the session's GTK defaults and the login screen; in the preview and the review site | On the Mac: every shape looked over on `dist/cursors/sheet.html` (light, dark and mid grounds, hotspots marked) and in the review site's Input chapter; tests for the file format, sizes, hotspots on ink and the names apps ask for. Not on KWin: tenet doesn't take this Mac's key yet |
