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

1. **The pointer: built, not yet seen on KWin.** A theme of our own since
   round 1 (`design/cursors.ts`): a Mac's black arrow with its white rim and
   soft shadow, white hands, the I-beam, resize arrows, badges for copy,
   alias and not-allowed, and a wheel in the accent colors for busy. It
   lives in the same icon theme. It
   stays here until it has been looked at on tenet: KWin drawing the SVGs,
   the wheel turning, an Xwayland app, a GTK app, the login screen. Shapes
   still Breeze's (through `Inherits`): the skull of Kill Window, the color
   picker, the pencil. With it, KWin's launch feedback (the app's icon
   bouncing beside the pointer) is off in the session
   (`session/xdg/klaunchrc`): the Dock's icon bounces instead, as a Mac's
   does. Also to look at on tenet.
2. **Other apps' icons: begun, not yet seen on KWin.** Since round 2 the
   "Ambrosia" icon theme (over Breeze) gives the apps a new install starts
   with an icon of ours on the tile: Terminal, the text editor, the picture
   and document viewers, Calculator, the archiver, the store, Screenshot,
   system information; KDE's settings and Dolphin wear Settings' and Files'.
   The names are the ones those apps' desktop files ask for (read from
   KDE's sources). To look at on tenet: how the icons sit in the Dock,
   Search and Files. Still
   Breeze's or the app's own: every app not on that list (Firefox's mark
   has no tile; the Dock could put one under any icon that lacks it), the
   folders and document kinds in KDE's dialogs (Files draws its own), and
   the one-color status and action icons inside Qt apps.
3. **Other Qt apps' controls: begun, not yet switched on.** Breeze's widget
   style draws Konsole, Kate, Dolphin and the file dialog. Since round 3
   there is a style of ours over it (`style/`, `make gallery`): push
   buttons, checkboxes, radio buttons, text fields, pop-ups, steppers,
   sliders, progress and scroll bars, tool buttons, menus and tooltips as
   the Mac draws them; since round 4 also tabs (a tab view's as a
   segmented control, a window's own as a quiet row), group boxes, the
   rows and headers of lists, trees and tables, a pop-up button's menu,
   toolbars and menu bars. Installed, but the session still names Breeze
   until real apps have been run under it on tenet. Still Breeze's even
   then: dock widgets' title bars, tool boxes, dials, the calendar, an
   editable combo's list. Scroll bars always show, which is a Mac with a
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
7. **⌘Tab: built, not yet seen on KWin.** Since round 6 KWin's switcher
   walks apps, one window each, on a glass strip of large icons with the
   chosen app's name under it (the look-and-feel's `windowswitcher`); ← →
   move and Q closes the chosen window while it's up. The strip has been
   looked at; KWin has never loaded it. Short of a Mac's even then: no blur
   behind it (KWin gives that to Plasma's own dialogs), the name is the
   desktop file's last word, switching raises one window rather than all
   the app's, Q closes a window rather than quitting, no ⌘H. To look at on
   tenet.
8. **Mission Control and Spaces.** KWin's Overview is there but unstyled and
   on no Mac key or gesture (F3, ⌃↑, three fingers up; ⌃← ⌃→ and a swipe
   between desktops; ⌃↓ for one app's windows). From the code.
9. **Volume and brightness keys: built, not yet seen on KWin.** Since
   round 5 they show a glass capsule under the menu bar's right end, where
   the control center opens: a glyph and a level, or the name of the output
   sound moved to (`shell/Hud.qml`). The picture has been looked at; the
   listening for Plasma's calls has never run. It takes no clicks, where a
   Mac's can be dragged. To look at on tenet.
10. **⌘H and ⌘Q.** ⌘H minimizes one window instead of hiding the app; ⌘Q
    only works where the app has Ctrl+Q (`docs/keyboard.md`).
11. **The Dock's right side: Downloads opens as a stack, not yet seen on
    KWin.** Since round 7 clicking Downloads opens its newest things as a
    grid on glass over the Dock (pictures as themselves, the rest by kind),
    with a button for the folder (`shell/Stack.qml`, `StackGrid.qml`). The
    grid has been looked at; the folder reading and the placing have not
    run. Still missing: a fan, sorting and the stack's own menu, dragging
    out of it, minimized windows in the Dock, recent apps. To look at on
    tenet.
12. **Tiling.** Dragging a window to an edge and the green button's menu
    (Move & Resize, Full Screen on a display) are KWin's quick-tile with its
    own outline. From the code.
13. **Screenshots.** ⇧⌘3/4/5 run Spectacle with its own window; a Mac shows
    a floating toolbar, then a thumbnail in the corner that can be dragged
    or opens Markup. From `docs/keyboard.md`.
14. **The desktop itself.** No icons on it, no right-click menu, no widgets,
    no stacks. From the code.
15. **Trackpad gestures.** Whatever KWin does out of the box; nothing set
    to a Mac's (swipe between desktops and full-screen apps, Mission Control,
    pinch for the apps, two-finger swipe from the right edge for Notification
    Center). No real trackpad has been tried (`CONTEXT.md`).
16. **Menu bar extras from apps.** Apps' own status items (the tray) don't
    show; Sound, Bluetooth and the input source have no item of their own
    beside Wi-Fi, the battery and the control center. From the code.

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
| 8, 2026-11-18 | Tooling, for every shell gap | The shell's own files drawn on the Mac: stand-ins for Quickshell and Plasma (`tools/qmlshot/stubs/`, `stubs.h`), a staged copy of `shell/` with a qmldir for its singletons, `parts/Desk.qml` (the desktop as the shell puts it up) and ten `desktop-*` sheets that open things on it with real pointer and key events. Fixed from the first look: Notification Center's shadows cut by the list's clip, a wrapped card overlapped by the next, the Dock's menus placed from the scene instead of its window | On the Mac: `make shell-shots`, 13 sheets in light and dark, each looked at. The stand-ins are not Quickshell: nothing here has run on it |
| 7, 2026-11-18 | 11, the Dock's right side | Downloads as a stack: `shell/StackGrid.qml` (the grid's picture), `shell/Stack.qml` (reads the folder's newest 24 with `ls -t` and `file`, icons by kind from the icon theme, pictures as themselves), a place on the Overlay, `Popups.toggleStack` | On the Mac: the grid full, part full and empty, light and dark (`out/shots/shell-stack-*.png`). Not run under Quickshell |
| 6, 2026-11-18 | 7, ⌘Tab | A switcher layout of our own in the look-and-feel package (`contents/windowswitcher`): the strip's picture in `SwitcherStrip.qml`, KWin's side in `WindowSwitcher.qml`; kwinrc names it and sets one window an app | On the Mac: the strip with six apps and with fifteen (icons shrink to fit), light and dark (`out/shots/shell-switcher-*.png`); KWin's API read from its sources (TabBoxSwitcher, the model's roles, where a layout is looked for). Not run on KWin |
| 5, 2026-11-18 | 9, the keys' display | `shell/Hud.qml`: a capsule for the volume and brightness keys, fed by Plasma's own calls to `org.kde.osdService` heard on the bus; `tools/qmlshot` and `make shell-shots`, which draw pieces of the shell on the Mac with Qt's real renderer and no window | On the Mac: the panel in six states, light and dark (`out/shots/shell-hud-*.png`), in the Mac's font (no Inter here). The window, the blur and the listening need Quickshell: not run |
| 4, 2026-11-18 | 3, Qt apps' controls | The style's second cut: tabs (segmented for a tab view, a quiet row for a window's own, close buttons on the left under the pointer), group boxes, rows of lists, trees and tables (rounded highlight joining chosen neighbors, gray without the focus), tree arrows, table headers, a pop-up button's choices as a menu, flat toolbars, menu bar items, splitters, the focus ring on checkboxes and radios, a busy bar that moves; new `tab`, `box`, `row` tokens | On the Mac: the gallery in light and dark, each new control looked at, and the busy bar caught moving between two grabs. Over Fusion only; what could differ over Breeze is noted in `CONTEXT.md` |
| 3, 2026-11-18 | 3, Qt apps' controls | A Qt widget style (`style/`, ambrosia-style): a proxy over Breeze drawing twelve kinds of control from the Mac's measured sizes (new `controls` tokens), dialog buttons in the Mac's order, no underlined letters; a gallery that draws them with no display | On the Mac, for real: built against Qt 6.12 and rendered by the gallery in light and dark (`out/shots/style-*.png`), each control and state looked at. Over Fusion only: not yet over Breeze, nor in a real app |
| 2, 2026-11-18 | 2, app icons | The "Ambrosia" icon theme over Breeze: nine app icons drawn in `design/icons.ts` on the tile Files' and Settings' sit on, under the names the installed apps ask for; the pointer moved into it; named by the look-and-feel and the session's GTK defaults; the Dock takes its list of tile icons from the theme | On the Mac: `dist/icons/sheet.html` (each icon at 128, 48, 32 and 20, and in a row at the Dock's size on light and dark glass) and the review site's Iconography chapter; tests for names, links and what Qt's SVG reader can draw. Not on KWin |
| 1, 2026-11-18 | 1, the pointer | The "Ambrosia" pointer theme: 24 shapes drawn in `design/cursors.ts`, generated as Xcursor files, KWin SVGs and CSS; named by the look-and-feel, the session's GTK defaults and the login screen; in the preview and the review site | On the Mac: every shape looked over on `dist/cursors/sheet.html` (light, dark and mid grounds, hotspots marked) and in the review site's Input chapter; tests for the file format, sizes, hotspots on ink and the names apps ask for. Not on KWin: tenet doesn't take this Mac's key yet |
