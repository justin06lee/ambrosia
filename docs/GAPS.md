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
   them. Since round 21 the list a combo box to type in drops is a
   menu's panel with a menu's rows, and both kinds of combo list are glass
   (the style asks KWin to blur behind them itself; Breeze only asks for
   menus); a dial is a round knob with a dot; a tool box's tabs are
   headings with an arrow; a dock widget's title is a small quiet heading
   with two glyphs; the calendar is one sheet with the chosen day on a
   disc and today in the accent color. Seen on tenet in the gallery opened
   as a real window, which also showed two things Breeze had been drawing
   all along: every progress bar (Breeze paints its own track and lit
   part without asking the style on top) and a second arrow on a button
   with a menu. Both are ours now. A dock widget's title was seen in
   Dolphin too, its panels unlocked. Not seen in a real app yet: a
   calendar. Still not a
   Mac's: the calendar's bar is laid out Qt's way (the arrows at its two
   ends), a tool box's pages don't slide. A menu's shortcuts read as a Mac
   prints them since round 14 (⇧⌘S for Ctrl+Shift+S, as in the menu bar);
   a shortcut named anywhere else (a tooltip, a shortcuts dialog, a Qt
   Quick app's menu) is still Qt's spelling. Scroll bars always show, which is a Mac with a
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

6. **How windows open, close and minimize: ours, seen on KWin.**
   Since round 15 a window minimizes into its app's Dock tile with the
   Genie effect by default, as on a Mac (KWin's Magic Lamp, switched on in
   the session's `kwinrc`; the Dock has told KWin where each tile is all
   along, so the old line here, that it didn't land there, was wrong).
   Settings still switches to Scale (KWin's Squash). Seen on tenet
   (2026-11-18), slowed down to photograph: Konsole pours into its own
   tile. Its 400 ms is by eye, with no recording of a Mac to measure
   against. A session already running keeps its effects until the next
   login. Since round 16 a window swells open from 90% while it fades in,
   on the snappy spring's time (290 ms), and a closed one is simply gone,
   as on a Mac: a KWin effect of ours (`session/kwin-effects/
   ambrosia_windows`) in place of KWin's Scale, which shrank a closing
   window away. Seen on tenet slowed down, Konsole part-way open. The 90%
   is by eye, the curve is Qt's nearest to the spring and not the spring
   itself, and a dialog opens like any window where a Mac's alert pops.
   Seen since (round 18): a dialog opening the same way, and the Genie
   with the Dock on the left, which had poured the window downwards until
   KWin was told the Dock is a panel (its layer namespace is "dock").
   Not seen: the Genie with the Dock hidden; an Xwayland window opening;
   zooming with the green button (KWin's own Maximize effect).
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
12. **Tiling: the preview, the margins and the green light's menu are ours, seen on KWin.**
    Since round 17 a window dragged to a screen's edge shows where it will
    land as a rounded pane of glass a little inside the place, as a Mac
    previews a tile (`session/kwin-outline/outline.qml`, named by the
    session's `kwinrc`), not KWin's outline. Seen on tenet (2026-11-18):
    Konsole held at the left edge, the pane over the left half between the
    menu bar and the Dock, blurring what is behind. It is drawn over the
    dragged window, where a Mac's is under it. A corner and dark were seen
    in round 18, the top edge (the whole screen's pane) in round 22.
    Since round 22 a tiled window keeps a margin of 8 from the screen's
    edges and from the tile beside it, landing where the preview was (a
    KWin script of ours, `session/kwin-scripts/ambrosia_tiles`, gives
    KWin's halves and quarters a padding); the pointer resting on a
    window's green light brings up where it can go (halves, quarters,
    Center, Enter Full Screen) as a menu under the light, and the menu
    bar's Window menu has Center and Move & Resize. Seen on tenet
    (2026-11-23): Konsole sent right and to the top right from the menu,
    8 from the edges and 4 from the middle; the green light's menu from a
    test copy of the frame (a running KWin keeps the frame it loaded:
    the installed one shows at the next login), closed with Escape, not
    back until the pointer left and returned, and Right chosen from it.
    Short of a Mac's: the menu is words, where a Mac's is a row of small
    pictures; a window filling the screen (the top edge, Zoom) has no
    margin; no Fill, Arrange or Return to Previous Size; the green light
    still zooms on a click, where a Mac's enters full screen. A menu
    opened by a command (this one, Force Quit) doesn't come up until the
    menu bar has had a click since the shell started: the Overlay is a
    popup of the bar's, and a popup needs an input the bar was given.
13. **Screenshots: to the Desktop with a thumbnail in the corner, seen on
    KWin; the tool is Spectacle's.** Since round 23 ⇧⌘3 and ⇧⌘4 (`ambrosia
    screenshot screen|region`) save "Screenshot 2026-11-23 at 10.31.22.png"
    to the Desktop with no window and no notification, and the picture
    floats in the screen's bottom right corner inside a white edge for
    five seconds, longer while the pointer is on it; a click opens it
    (`shell/Screenshot.qml`, `ScreenshotThumb.qml`). Seen on tenet
    (2026-11-23), run by the command: the whole screen and a dragged-out
    part saved, the thumbnail in and out again, a click opening the
    picture in Gwenview. Not seen: the keys themselves (keyd is off on
    tenet). Short of a Mac's: the crosshair for a part is Spectacle's own
    (its dimmed screen and handles, Return to take it), ⇧⌘5 is
    Spectacle's window where a Mac has a floating toolbar, the thumbnail
    can't be dragged into an app or swiped away, a click opens the
    viewer where a Mac opens Markup, there is no shutter sound,
    ⇧⌘4 then Space (one window) isn't there, and the picture is taken a
    second or two after the key, the time Spectacle takes to start (KWin's
    own ScreenShot2 interface, asked by the shell, would be at once).
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
    press, it came up a second or two late after the shell started). Since round 19 Settings' Menu Bar
    pane lists the items the shell has seen under Allow in the Menu Bar,
    with a switch each, and an app's own pale icon used as a status item
    is left as a picture (it came out a solid dark square: a glyph is now
    one gray and mostly empty). Seen on tenet (2026-11-23) with a test
    item in color: there, hidden by its switch, back again. Not seen: an
    item without a menu, an Xembed-only tray icon (those need a proxy we
    don't run). Still missing: reordering by ⌘-drag, and an input source
    item.

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
22. **Force Quit: a list of ours, seen on KWin; the key is still KWin's.**
    Since round 20 the Ambrosia menu's Force Quit… opens Force Quit
    Applications on glass (`shell/ForceQuit.qml`): the apps with a window,
    one chosen, a button that asks once and then kills the app's
    processes; arrows, Return and Escape work, and `ambrosia force-quit`
    opens it too. Seen on tenet (2026-11-23): Konsole listed, asked about,
    gone. ⌥⌘Esc still gives KWin's skull pointer to click a window with
    (the shortcut is KWin's own; moving it belongs with the keyboard's
    gaps). It closes on a click outside, where a Mac's is a window that
    stays, and has no Relaunch for Files.
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
| 23, 2026-11-23 | 13, screenshots | `shell/Screenshot.qml` (runs Spectacle in the background into a file on the Desktop named as a Mac names one, then shows it) and `ScreenshotThumb.qml` (the picture fitted in a box, a white edge, a shadow) on a layer surface in the bottom right corner; `ambrosia screenshot screen|region` and the shell's IPC; two desktop files holding Super+Ctrl+Alt+3 and 4, which keyd's ⇧⌘3 and ⇧⌘4 now send (they were Spectacle's own Shift+Print chords); `screenshot` size and choreography tokens; a sheet, `screenshot` | On the Mac: `out/shots/shell-screenshot-*.png` (a wide picture, a tall one, one not read yet). On tenet: the command for the screen and for a part (dragged with the virtual pointer, Return), the files' sizes read back, the thumbnail photographed in the corner and gone five seconds on, a click opening Gwenview. A second Spectacle started while the crosshair was up ended it without a picture. After the r444 packages: once more from the installed files (the thumbnail comes some three seconds after the command: Spectacle starting). The shortcut daemon reads new desktop files at login, so the two chords aren't held yet on tenet. Not seen: the keys, dark |
| 22, 2026-11-23 | 12, the rest of tiling | `session/kwin-scripts/ambrosia_tiles` (a KWin script: a padding of 8 on any tile of KWin's own a window lands in; on in the session's `kwinrc`); `Apps.placeWindow` and `placeEntries` (KWin's quick-tile actions by their shortcuts' names, over kglobalaccel), Center and Move & Resize in the Window menu, `ambrosia window-menu X Y` (the shell's IPC opens the menu at that place); the frame's green light starts a 600 ms timer when the pointer comes to rest on it and runs that command with its own place on the screen (the pointer's, less its place in the frame); no tooltips on the lights; a sheet, `desktop-window-menu` | On the Mac: the sheet, light and dark. On tenet: the script loaded into the running KWin by a reconfigure; Konsole sent Right and Top Right from the menu (x 1284, width 1268, height 649: 8 and 4); the top edge's preview held and photographed; the green light's menu from a test copy of the plugin under another name, named in the user's `kwinrc` and taken out again. After the r441 packages: the Window menu's Move & Resize on tenet, Bottom Left chosen from it (a list set inside a menu row didn't come through as a list: a row's `submenu` is a function now). Not seen: dark, two tiles side by side dragged at their shared edge |
| 21, 2026-11-23 | 3, the Qt controls left | In `style/src/style.cpp`: the list of a combo to type in (rows of our own put in before Breeze puts its own, `ComboRows`; the frame round it is the menu's panel, `CE_ShapedFrame`), glass behind both kinds of combo list where KWindowSystem is built in (`Glass`), `CC_Dial`, `CE_ToolBoxTab`, `CE_DockWidgetTitle` and its two buttons, the calendar (its bar on the sheet's color, the weekend out of Qt's red, headings small, today, the chosen day's disc), `CE_ProgressBar` put together here, a menu button's title without Breeze's arrow. The gallery has the new controls and `--show`, which opens it as a window to use | On the Mac: `out/shots/style-*.png`, light and dark. On tenet: the gallery drawn there over Breeze, then opened in the live session with `--show`: both combo lists opened (the dropped one tinted by the slider behind it), the progress bars and the menu button before and after. From the r438 packages: Dolphin with its panels unlocked, Places under our heading. Not seen: a calendar in a real app, dark on tenet |
| 20, 2026-11-23 | 22, Force Quit | `shell/ForceQuit.qml` on the Overlay (kind "forceQuit": `Popups.toggleForceQuit`, the Overlay's keys, the Ambrosia menu, the shell's IPC and the `ambrosia` command), `Apps.forceQuit` (kill -KILL on the pids of the app's windows) after the confirmation dialog; the stand-in task model gives a pid; a sheet, `desktop-force-quit` | On the Mac: `out/shots/shell-desktop-force-quit-*.png`. On tenet: opened with `ambrosia force-quit` over Konsole, Return for the confirmation, Return again, Konsole's process gone. Light only; not from the menu itself, not with several apps |
| 19, 2026-11-23 | 16, hiding a status item | The shell records each app status item it sees (`menuBarExtras` in the settings, id and title, from `shell/MenuBar.qml`); Settings' Menu Bar pane lists them under Allow in the Menu Bar with a switch (`settings/qml/MenuBarPage.qml`: off is `extra:<id>` among the hidden). `shell/StatusIcon.qml` takes an icon for a glyph only when it is one gray and leaves most of its square empty | On the Mac: the extras sheet with a pale app icon as a status item, left as a picture. On tenet: a test item (Qt's tray icon from `qml6 --apptype widget`, Kate's icon) shown first as a dark square, then as itself; listed in Settings; switched off there, gone from the bar. Light only |
| 18, 2026-11-23 | What rounds 13 to 17 left unseen | A look at tenet's first fresh login since those rounds, and one fix: the Dock's layer surface is named "dock", which is how KWin knows it for a panel (`shell/Dock.qml`); `tools/live.sh unlock` and `lock` find the session themselves (its number changes with each login) | On tenet: ⌘Tab's strip of our own, at last from a KWin that started with it; in dark, a banner with Firefox on its tile, Kate's menu with the Mac's shortcut glyphs, the tiling preview at a corner; a file dialog part-way open with the effect slowed. The Genie with the Dock on the left showed nothing: KWin found no panel under the tile and poured the window downwards; with the surface named "dock" it pours into the tile, seen twice. Still not seen: the tiling preview at the top edge, Settings' pane showing Genie chosen |
| 17, 2026-11-18 | 12, the tiling preview | `session/kwin-outline/outline.qml`: KWin's outline window with a pane of our glass in it (the theme's clear tint, edge and rim, the window radius, KWin told to blur behind it through our `BlurBehind`), installed to `/usr/share/kwin/outline/ambrosia/` by ambrosia-shell and named by `[Outline] QmlPath` in the session's `kwinrc` | On tenet's running KWin (which loads the outline the first time it shows one, and had not yet): Konsole dragged to the left edge with the virtual pointer held down (`ui.py down`, `glide`, `sleep`, `up` in one call: the button is let go when the call ends), photographed while held. Light only; no corner or top edge |
| 16, 2026-11-18 | 6, opening and closing | A KWin effect of ours, `session/kwin-effects/ambrosia_windows` (a scripted effect: `metadata.json`, `contents/code/main.js`, a `Duration` setting in `contents/config/main.xml`), installed to `/usr/share/kwin/effects/` by ambrosia-shell and switched on by the session's `kwinrc` with KWin's Scale off: a window opens from 90% with a fade over the snappy spring's 290 ms; nothing answers a window closing | On tenet, loaded into the running KWin over DBus: with `Duration` at 20 s, a picture of Konsole part-way open, smaller and half see-through over Firefox; after it, no open/close effect but ours is loaded, so a closing window has nothing to play. The first try ignored `Duration`: KWin reads a scripted effect's settings only when its `main.xml` declares them. Not seen at its real speed, nor a dialog |
| 15, 2026-11-18 | 6, minimizing | Genie is the session's default for minimizing (`session/xdg/kwinrc`: Magic Lamp on, Squash off, 400 ms), and the gap's line is put right: the Dock already published each tile's place (`requestPublishDelegateGeometry` in `shell/Dock.qml`), so a window lands on its own tile | On tenet: KWin's `iconGeometry` for Konsole and Firefox is their Dock tiles (52 px squares in the Dock); with the effect slowed to 5 s, a picture of Konsole pouring into its tile; the defaults read back through the session's config path. A running KWin doesn't take the new default on reconfigure, so the live session was switched by hand the way Settings does it. Not seen: the Dock at a side, Settings' pane showing Genie chosen |
| 14, 2026-11-18 | 3, menus' shortcuts | The widget style prints a menu row's shortcut with the Mac's glyphs (`macShortcut` in `style/src/style.cpp`: it reads Qt's own spelling back into keys, so any language's; modifiers as ⌃⌥⇧⌘, Ctrl as ⌘ and Meta as ⌃ like the shell's menu bar, arrows and editing keys as symbols; text that isn't a shortcut is left alone), and takes back the width QMenu added for the longer spelling (`shortcutsSaved`). The gallery's menu has more shortcuts to show it | On the Mac: `out/shots/style-*.png` (Qt on a Mac prints glyphs itself, so this shows only that nothing broke). On tenet: the gallery drawn there (⌘N, ⇧⌘S, ⌥←, ⌦, the menu as wide as the Mac's), and Kate's right-click menu in the live session from the r422 packages (⌘X ⌘C ⌘V, ⇧⌘Ins), light only |
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
