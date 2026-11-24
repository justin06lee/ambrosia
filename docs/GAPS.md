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
4. **GTK apps' controls: ours, seen in the test VM and on tenet.** Since round 32 GTK 3
   and GTK 4 apps draw their controls as the Qt widget style does, from
   the same tokens (`tools/gen/targets/gtkcontrols.ts`, into the two
   stylesheets a user's `gtk.css` imports): push buttons (the default one
   in the accent color, a destructive one in red letters, a toolbar's with
   no face until pointed at), a switcher of pages as a segmented control,
   text fields with a hairline and the accent ring, steppers, pop-up
   buttons, checkboxes and radio buttons with our marks, switches, sliders
   with the capsule knob, progress and level bars, menus (rounded, 22-point
   rows, a rounded accent highlight), tooltips, tabs, a table's header,
   thin scroll bars, and a keyboard focus ring in the accent color. GTK 3's
   Adwaita has its colors written into it, so its windows, lists, text
   views, sidebars and selections are given ours too, per mode. GTK 3 apps
   now follow dark: the shell runs `gtk-appearance` (`session/`) at its
   start and on a change, which points the user's `gtk.css` at the other
   mode's file and asks for Adwaita's dark half in `settings.ini`. GTK 4's
   traffic lights were wrong and never seen (the theme stretches a window
   button to the bar's height: three tall ovals); the light is the
   button's image now, 14 wide and 23 apart by measure, the glyphs on all
   three under the pointer. Seen in the test VM (2026-11-25, GTK 3.24, GTK
   4.24, libadwaita 1.10; GTK's two widget demos and a libadwaita window
   of settings rows), light and dark: every control above, a GTK 3 context
   menu and its highlight, a libadwaita menu and a pop-up's list, dark
   reaching libadwaita through the portal when the shell changes. On
   tenet (2026-11-25, from the r472 packages, which has GTK 3 only): a
   GTK 3 window of buttons, a switch, a checkbox and a text to scroll, in
   light and in dark, the shell having moved GTK 3's two files each way
   by itself. Short of
   a Mac's: a GTK 3 app already open keeps the mode it opened in (GTK 3
   reads its CSS once); a menu's shortcuts read Ctrl+N, GTK's own
   spelling; a GTK 4 app not on libadwaita keeps that theme's own window
   and list colors under our controls; libadwaita's bars, rows and cards
   keep GNOME's sizes (a 47-point bar, 15-point window corners where the
   app draws its own); a notebook's tabs sit at the left, not as a
   centered segmented control; a switch's knob is a circle, Settings' a
   capsule; steppers keep GTK's − and + side by side; Flatpak apps don't
   read `~/.config/gtk-4.0` unless given it, and Firefox draws its own
   controls. Not seen: a tooltip (the pointer rested on a button and none
   came up in the picture), a file chooser of GTK's own, an info bar, a
   GTK app at 2x, a real GTK app on tenet (it has none but Firefox, left
   alone while running), Firefox restarted there under the new CSS (in
   the VM its settings page and menus looked as before).
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
   switching raises one window rather than all the app's (a hidden app's
   all come back, gap 10), Q closes a window rather than quitting, and H
   while it's up does nothing.
8. **Mission Control and Spaces: ours, seen on KWin.** Since round 26 a
   KWin effect of ours (`session/kwin-effects/ambrosia_mission`, in place
   of KWin's Overview, which is off) spreads this desktop's windows over
   the wallpaper with the menu bar and the Dock left in place. Under the
   menu bar is a strip of the desktops: their names, and once the pointer
   has been on it a small picture of each; a click goes to one, + adds
   one, the button on a picture removes it, and a window dragged onto a
   picture moves there. The window the pointer is on gets a ring in the
   accent color and its name under it; a click, or the arrows and Return,
   goes to it; Esc, the key again or a click beside the windows leaves.
   ⌃↓ is the same with the front app's windows only, minimized ones too,
   over a darkened desktop (the Dock's menu has it as Show All Windows).
   ⌃← and ⌃→ go to the desktop beside this one (KWin's own, with its
   slide). Seen on tenet (2026-11-23), light and dark; the keys through
   keyd. Short of a Mac's: no full-screen apps as spaces of their own and
   no desktop per display (KWin's desktops span the screens); the strip's
   pictures can't be dragged into another order; a window can't be
   dragged to the strip's + for a new desktop, or onto another window for
   Split View; the Dock and the menu bar are pictures while it is up (a
   click on either only leaves); no F3 or Launchpad key; windows are laid
   out by KWin's rows, which keep less of where they were than a Mac
   does; sizes, the ring and the timing are by eye. The four-finger
   swipes are written but no trackpad has been tried (gap 15). A KWin
   still running from before the upgrade draws it only after the next
   login (it holds the old tokens); as packaged it was seen in the test
   VM after a fresh login (round 27).
9. **Volume and brightness keys: ours, seen on KWin.** Since round 5 they
   show a glass capsule under the menu bar's right end, where the control
   center opens: a glyph and a level, or the name of the output sound moved
   to (`shell/Hud.qml`). Seen on tenet (2026-11-18): the volume keys bring
   it up with the level they set (the bus monitor does hear Plasma's calls
   to a name nobody owns). Brightness was only shown by hand: tenet's
   display has no brightness keys. It takes no clicks, where a Mac's can be
   dragged.
10. **⌘H and ⌘Q: hiding is ours, seen on KWin; ⌘Q is still the app's.**
    Since round 24 ⌘H hides the app in front and ⌥⌘H every other, and the
    app menu has Hide, Hide Others and Show All: every window of the app is
    put away at once, with no motion, and they are all back at once when
    the app is next brought forward from the Dock or ⌘Tab. It is the
    session's KWin effect (`session/kwin-effects/ambrosia_windows`): the
    windows are minimized, and the effect takes the whole screen for that
    instant, which is the one thing that keeps KWin's Genie from playing.
    Seen on tenet (2026-11-23) with the Genie slowed to tell: Konsole's
    two windows hidden and back from the Dock and from the switcher, Hide
    Others, Show All, the menu's rows, and a plain minimize still pouring
    into the Dock. Short of a Mac's: a hidden app looks no different in
    the Dock and ⌘Tab; the Dock brings back every window of an app that
    has them all put away, minimized one by one or hidden; an app that
    brings itself forward (a notification's click) gets one window out of
    the Dock before the rest appear. ⌘Q is the app's own Ctrl+Q, as
    before; an app without one can be named in `~/.config/ambrosia/
    keys.json` (`"quit"`) to have the shell close its windows instead
    (`ambrosia quit`, seen closing Kate). The shell can't tell which apps
    those are by itself (`docs/keyboard.md`). Our own menus still show no
    shortcuts beside their rows.
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
    still zooms on a click, where a Mac's enters full screen. (Until
    round 24 a menu opened by a command, this one or Force Quit, didn't
    come up before the shell had had a click: Qt refuses a popup that
    takes the keyboard until then. Our Quickshell build now carries a
    patch for it, `packaging/quickshell/popup-grab.patch`.)
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
14. **The desktop itself: its icons and its menu, seen on KWin.** Since
    round 9 the right button on the desktop opens a menu
    (`shell/Wallpaper.qml`): New Folder, Change Wallpaper…. Since round 25
    what is in ~/Desktop lies on the first screen's picture as icons
    (`shell/DesktopIcons.qml`): in columns from the top right corner,
    clear of the menu bar and the Dock, by name unless the menu's Sort By
    says Kind or Date Modified; a picture as itself inside a white edge,
    anything else by its kind's icon; the name in white on two lines. A
    click chooses one (⌘ or Shift adds), a drag over the picture draws a
    rectangle and chooses what it crosses, a double click opens, the
    right button gives Open, Move to Trash and Show in Files, a chosen
    icon drags into a window or onto the Trash, and a file dropped on the
    picture moves into the folder. The folder is watched, so a screenshot
    or a new folder (chosen as it arrives) appears by itself. Seen on
    tenet (2026-11-23) with a text file, a PDF, a picture and folders:
    all of that but ⌘-click and a drop from a window. Short of a Mac's:
    icons can't be put where you like (they are always in order), no
    renaming in place (Return), no keys at all (the desktop never has the
    keyboard: no arrows, ⌘⌫, Space for a look), no Get Info, Copy or
    Duplicate, no stacks or widgets, names cut at the end where a Mac
    cuts the middle, sizes by eye, and drives don't show.
15. **Trackpad gestures: a Mac's four, seen in the test VM by a made-up
    trackpad.** Since round 34: three or four fingers sideways go to the
    next desktop (KWin's own, following the fingers); three or four up
    open Mission Control and down the front app's windows, the other way
    out of either (four were ours since round 26, three is a Mac's
    setting as it comes); the thumb and three fingers pinched open Search,
    which is where apps are found, and spread show the desktop: every
    window slides off past the edge nearest it and is put away, and the
    same pinch, the shortcut again or any window coming forward slides
    them back (`Ambrosia Show Desktop` in the windows effect, on
    Super+Ctrl+Alt+D, which is what F11 sends through keyd since round
    35; KWin's own Show Desktop is not used: it puts the shell's
    wallpaper and menu bar away too and leaves a black screen with the
    Dock. Since round 35 whoever asks for KWin's, its Super+D with the
    Linux-first keyboard or an app, gets ours: the `ambrosia_desktop`
    script switches KWin's off the moment it comes on and presses ours;
    seen in the test VM by KWin's shortcut, its DBus call and F11, and
    fourteen in a row with KWin up; whether a frame of KWin's black
    screen can show in between wasn't measured, and none was seen).
    Seen in the test VM
    (2026-11-25) with `tools/fake-touchpad.py`, a trackpad made of
    uinput: each of those, read off KWin's state and the screen, and
    twenty Show Desktops in a row, six of them 150 ms apart, a window
    closed mid-slide and Mission Control over a shown desktop, KWin up
    through all of it. No real trackpad has been tried: how the motion
    feels under fingers (none of ours follows the fingers but KWin's
    desktop switch), thresholds and accidental triggers are unjudged.
    Short of a Mac's: no two-finger swipe from the right edge for
    Notification Center (KWin is given no edge swipes of a trackpad),
    no swipe between pages or smart zoom (an app's own), no three-finger
    drag, no pinch to Launchpad's grid (there is none; Search stands in),
    Show Desktop leaves no slivers of the windows at the edges, and
    Settings' Trackpad pane has no tab to choose or switch these off.
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

17. **The lock screen: ours, seen on KDE's locker.** Since round 27 it is
    the login screen's own picture (`packaging/sddm-theme/Main.qml`, shared
    by a link): the date and time, the account's picture and name, a
    password field that shakes at a wrong one. KDE's locker takes it from a
    Plasma shell package of ours (`session/plasma-shell/org.ambrosia.
    desktop`, named by the session's `plasmashellrc`; `LockScreen.qml`
    stands in for what SDDM hands the login screen and talks to PAM as
    Plasma's own lock screen does) and draws the user's desktop picture
    behind it, which the shell keeps in step in `kscreenlockerrc`. Seen in
    the test VM (2026-11-23) on a real lock: a wrong password refused, the
    right one letting in, twice; on tenet in the locker's testing mode. A
    file that doesn't load falls back to KDE's built-in screen, and
    `loginctl unlock-session` always lets in. Short of a Mac's: the text is
    dark in the light appearance and light in the dark one, whatever the
    picture (a Mac's is always light, with the picture dimmed under it), so
    a dark picture chosen in the light appearance leaves it hard to read;
    no Touch ID line, no Switch User, no sleep on Esc, no media controls or
    notifications on it, no blur of the desktop as it comes down; an
    account without a password is let in on Return. Not seen: dark, Caps
    Lock's mark, two screens, a fingerprint reader, a custom picture or a
    color.
18. **Starting up and shutting down: a picture of ours, seen in the test
    VM.** Since round 29 the computer starts behind a black screen with the
    mark in white in its middle and a thin bar under it that fills, and
    shuts down behind the mark alone, with none of the kernel's text: a
    Plymouth theme (`tools/gen/targets/plymouth.ts`, its sizes in
    `size.boot`, a drawing of it in `dist/plymouth/sheet.png`). The
    installer switches it on for a new system and the live image starts
    behind it too (`/usr/lib/ambrosia/boot-picture`: the theme, Plymouth's
    hook in the initramfs, `splash` on the kernel's command line); a disk's
    password, where one is asked, goes in a field where the bar is. Seen
    in the test VM (2026-11-23): the mark alone on the way down, the mark
    and the bar filling on the way up, the login screen after; the field
    taking a typed password. Short of a Mac's: about a second of black
    between the bar finishing and the login screen (the login screen's
    compositor starting; Plymouth leaves its last frame up, but KWin
    clears the screen before it has anything to draw); the firmware's own
    logo comes first, where a Mac shows nothing but its mark; the bar goes
    by how long the last start took, and in the VM's two seconds is
    three-quarters full when first seen; sizes are by eye; logging out
    shows no mark. A system installed before this (tenet) shows it once
    `plymouth` is installed and `/usr/lib/ambrosia/boot-picture` has been
    run as root: not done on tenet, since it rebuilds the initramfs of a
    machine that can't be restarted to check. From a built image
    (2026-11-24, in a VM): the live image starts behind the mark and the
    bar, and a system it installed starts and shuts down behind them. The
    live image then shows some seconds of black while its desktop starts.
    That install's very first start showed Plymouth's own text screen
    (gray, three squares) for eight seconds instead, once, while the host
    was busy building: Plymouth gives a graphics driver eight seconds
    before it settles for text. Not seen: a BIOS computer, a real disk
    password, a screen at twice the scale.
    The image's UEFI menu is still text (Needs Justin in `CONTEXT.md`).
19. **Password prompts: polkit's is ours, seen on KWin.** Since round 28
    the shell is the session's polkit agent (`shell/Authorization.qml`, on
    Quickshell's; Plasma's own is kept from starting): a program that needs
    the password gets our confirmation with a lock, what polkit says it is
    for, the account's name and a password field. A wrong password shakes
    it and asks again; Cancel, Escape or a click beside it refuses. Seen on
    tenet (2026-11-23) for `pkexec` up to the refusal, and in the test VM
    with the password. Short of a Mac's: the wording is polkit's
    ("Authentication is needed to run …"), not "X wants to make changes";
    the lock is a line drawing with no app icon on it; one account only
    (the first polkit offers: no User Name field); no Touch ID; KWallet's
    prompt and `sudo` in a terminal are still their own.
20. **Open and Save: Files' own panels, seen on KWin.** Since round 30 an
    app that asks the desktop portal for a file gets a Files window as a
    panel (`files/src/portal.cpp` answers the portal's file chooser;
    `session/xdg/xdg-desktop-portal/portals.conf` names Files for it): the
    sidebar, the four views, search and the path bar as in Files, with
    Cancel and Open or Save under the folder, the kinds of file the app
    takes as a pop-up, and what can't be chosen dimmed. Saving adds a Save
    As field over the folder (the name selected up to its extension; a
    file clicked lends its name), New Folder, and a question before
    anything is written over. It opens over the window that asked, where
    the app says or where the last panel chose. The session tells Qt and
    KDE apps, GTK apps and Firefox to ask the portal
    (`session/startambrosia`). Seen on tenet (2026-11-24), asked over the
    bus: a picture opened through an Images filter with a text file
    dimmed and refused, a save under a name that exists (asked, cancelled,
    renamed; asked, replaced), a folder chosen, Escape and the app's own
    Close cancelling. In the test VM, from the packages and through the
    portal itself: `kdialog`'s open and save (a Qt app) brought the panel
    up, and got back the file whose name was typed and chosen with
    Return, and the name typed to save under. Not seen: Firefox or a GTK
    app asking, several files at once, a Save over the app's own window
    (the requests had no window behind them). Short of a Mac's: it is a window of Files
    beside the app's, not a sheet on it (the menu bar says Files while it
    has the keyboard, the app's window can still be used, and there is no
    small form of the Save panel); the Save As row sits right of the
    sidebar where a Mac's is above it; no Tags field, and what an app
    adds to its panel (a format, an encoding: the portal's "choices") is
    left out; a path bar where a Mac has a location pop-up; only folders
    on this computer can be saved into; the panel's size isn't kept. An
    app that brings its own dialog never asks: Kate's Open and Save
    (KDE's own, for its encoding box) and anything else built on KDE's
    file widget stay KDE's, in our controls.
21. **Print, colors, fonts, emoji: the emoji picker is ours, seen on KWin.**
    Since round 31 ⌃⌘Space opens a picker of ours on glass
    (`shell/EmojiPicker.qml`): a field to search by, the emoji in a Mac's
    eight groups under the ones used lately, a strip of the groups along
    the bottom; the arrows move, Return or a click chooses, Escape empties
    the field and then closes. The choice is typed into the app in front at
    its insertion point and nothing touches the clipboard: the session has
    an input method of ours (`input/`, `ambrosia-input`), which KWin starts
    and the shell hands the emoji to. Where nothing in front takes text,
    the choice is copied instead. Seen on tenet (2026-11-24), the helper
    started in the running KWin: opened by its command over a text field,
    in light and in dark; "fire" typed and Return putting 🔥 in the field;
    the Flags tab pressed and a flag clicked; a choice into KWrite (saved,
    and read back from the file) and into a shell's prompt in Konsole; one
    made with nothing in front copied, and pasted after. In the test VM
    from the packages, logged in afresh: KWin starting the helper from the
    session's settings, ⌃⌘Space through keyd opening the picker, and
    choices by search and by the arrows arriving; and Firefox there
    taking one into a page's text box (its window's title, set from the
    box, read 🚀ok; the page itself drew a blank where the emoji is, which
    is that Firefox's fonts and not looked into). Not seen: a GTK app,
    Firefox on tenet, two screens.
    Short of a Mac's: it opens in the middle of the screen, not at the
    insertion point (KWin doesn't tell an input method where that is unless
    it draws its own panel there); no skin tones (a long press on a Mac),
    no name under the pointer, no window of every character (a Mac's
    Character Viewer: arrows, letters, the rest of Unicode); the words it
    finds by are English only; an app's own Edit menu has no Emoji &
    Symbols row; the emoji are Noto's, where a Mac's are Apple's (not ours
    to match); an Xwayland app gets the copy, not the typing; KDE's own
    picker still answers Super+. without keyd.
    Still Qt's: the print dialog, the color picker and the font dialog, in
    our controls.
22. **Force Quit: a list of ours, seen on KWin, on ⌥⌘Esc.**
    Since round 20 the Ambrosia menu's Force Quit… opens Force Quit
    Applications on glass (`shell/ForceQuit.qml`): the apps with a window,
    one chosen, a button that asks once and then kills the app's
    processes; arrows, Return and Escape work, and `ambrosia force-quit`
    opens it too. Seen on tenet (2026-11-23): Konsole listed, asked about,
    gone. Since round 24 ⌥⌘Esc opens it (Super+Ctrl+Alt+Esc, a desktop
    file of ours that keyd's ⌥⌘Esc sends; KWin's skull pointer keeps its
    own Super+Ctrl+Esc), and it opens by command before the shell has had
    a click (seen on tenet straight after a shell restart, the arrows
    moving the choice). It closes on a click outside, where a Mac's is a
    window that stays, and has no Relaunch for Files.
23. **Sounds: a theme of our own, played where a Mac plays them; nobody
    has heard it.** Since round 36 the session's sound theme is ours
    (`ambrosia`, `/usr/share/sounds/ambrosia`): seven short sounds
    synthesized by the generator from recipes of tones and filtered noise
    (`design/sounds.ts`, `tools/gen/targets/sounds.ts`). The alert, one
    soft wooden note, is KWin's bell and every app's warning, error and
    question; a shutter when a screenshot is taken; a thump when
    something lands in the Trash and paper crumpled when the Dock empties
    it; a small pop at each step of the volume keys, off as on a Mac
    until Settings' Sound switches it on; two notes for a notification
    that asks for a sound, one long note for the power adapter. KDE and
    GTK find them by name in the theme; the shell and Files play theirs
    through `/usr/lib/ambrosia/sound`, in the alert's role, so Settings'
    alert volume and device hold. A sound we have none of is Ocean's.
    **I can't hear, and nobody has listened**: they are held to numbers
    (`tools/gen/sounds.test.ts`: pitch, peak, no click at either end, no
    offset, the shutter's two clicks, the crumple thinning out) and, in
    the test VM (2026-11-25), to what the sound server was given and gave
    out: the alert recorded from its output measured as its recipe (peak
    -6.0 dB, loudest at 660 Hz, 255 ms); KWin's bell rung by a GTK
    window, libcanberra, the volume keys and the shell each opened our
    files. Whether they are pleasant, alike in loudness to the ear, or
    anything like a Mac's is unjudged: the recipes are a few lines each
    to tune by ear. Short of a Mac's: one alert where a Mac offers
    fourteen, no startup chime, no sound for a sent mail or a finished
    copy, none of the sounds apps bring; the pop plays at each step, a
    Mac's only when the key is let go.
24. **The first minutes: a new account is welcomed and the installer is
    an assistant of ours, both seen on KWin.** Since round 33 an account's first
    login ends as a Mac's setup does (`shell/Welcome.qml`): over the whole
    first screen, the desktop blurred behind it, a panel of glass says
    Welcome to Ambrosia under the mark, then Choose Your Look: Light,
    Dark and Auto, each a small picture of the desktop (Auto half of each),
    the chosen one ringed in the accent color and taken at once, behind
    the panel too. Return or Continue goes on, the arrows choose, Escape
    or Back returns a page; nothing under it takes a click. An account
    sees it once: the shell sets `welcome` in the settings when it finds
    none at all, and clears it at the end. `ambrosia welcome` shows it
    again. The live image's user is given settings, so the installer isn't
    covered. Seen on tenet (2026-11-25), opened by command: both pages,
    Return, the arrows turning the whole desktop and GTK 3's files dark
    and back, the end written to the settings. In the test VM
    (2026-11-25), as an account made a minute before and logged into for
    the first time: it came up by itself, and by the mouse alone Continue,
    the Dark picture (the desktop, KDE's scheme and GTK 3's files dark),
    Continue again, and the desktop. Short of a Mac's: one
    choice where a Mac asks a dozen (language, region, accessibility,
    an account online, Siri, the screen's time); no "hello" in many
    languages before it, no sound; the pictures are drawn, not the
    desktop itself in each look. An app that opens while it is up used to
    take the keyboard from it for good (seen in round 35); since round
    37 it and the installer take it back at once. The installer is the other half. Since
    round 37 it is an assistant of the shell's (`shell/Installer.qml`,
    opened by `ambrosia install`, which the live image's
    `ambrosia-install` runs), on the welcome's panel over the blurred
    desktop: Install Ambrosia; Connect to the Internet, only when there
    is none (the Wi-Fi networks in reach, a password, or a cable; it
    moves on by itself once connected); Choose a Disk (each as a tile);
    Create Your Account (name, account name following it, password
    twice); Select Your Time Zone (guessed, searchable); Ready to Install,
    which says what will be erased; a bar that fills with what it is
    doing under it; Ambrosia Is Installed and Restart, or what went wrong
    and Show Log. Return continues, Escape goes back, Tab moves between
    fields, the arrows choose. The computer is named after the account
    (`minas-ambrosia`), as a Mac names itself, and no longer asked for.
    The script does the asking of the system and all of the work
    (`ambrosia-install disks|online|wifi|join|timezone|timezones|run`);
    its old dialogs remain as `ambrosia-install --dialogs`, which it
    falls back to when the shell can't be asked. Seen from an image built that day
    (2026-11-25): the live image opened it by itself, and by the VM's
    keyboard alone it installed for real onto an empty disk in about
    three and a half minutes; the disk then started at our login screen
    as Mina Park, on Seoul's time, the new account was welcomed, and a
    terminal's prompt read `mina@minas-ambrosia`. Wi-Fi was not: no VM
    has any, so the list and joining were run against a stand-in
    `nmcli` only, and the page was seen on the Mac's sheets. Short of a
    Mac's: no language or keyboard to choose (English, US), no choice of
    part of a disk or of keeping what is on it, no disk password, no
    time left to say while it installs (the bar follows pacman's count
    of packages), the time zones are a list and not a map, and it
    installs in one pass where a Mac restarts into its setup.

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
| 37, 2026-11-25 | 24, the installer | `shell/Installer.qml` (a layer surface as the welcome's; pages as inline `Page`s, `Field` a focus scope round a TextInput, `Asked` a named field with its hint, `Choice` a list's row; the script's answers through `Process`es, the answers to `run` written to its input and `progress FRACTION words` lines read back), `Popups.installerOpen`, the shell's IPC `install` and `ambrosia install` (only where the live image's script is), `size.installer` tokens, the `drive` and `warning` icons. `iso/airootfs/usr/local/bin/ambrosia-install` reworked into subcommands, a progress filter over the root half's output (pacman's count of packages, each named as fetched and as installed), `AMBROSIA_INSTALL_PRETEND=1` and `--dialogs`; the launcher no longer opens a terminal. Sheets: `desktop-install` and eight more, one a page, on `parts/Installing.qml`, which answers for the script; the stand-in `Process` can now end with a code. | `make shell-shots`: nine pages, light and dark, driven by keys. Test VM (the installed system, the script in pretend mode): opened by `ambrosia install` and gone through by the VM's keyboard alone, Return, Tab and typing: the disk, the account (the account name followed the full name; Continue dimmed until the passwords matched), the time zones (598, the guessed one in view; typing "seo" chose Seoul), Ready to Install, the bar filling over half a minute, Ambrosia Is Installed; a run killed midway showed The Installation Couldn't Finish. `wifi` and `join` against a stand-in `nmcli`: strongest first, a name twice listed once, a colon in a name kept, hidden ones left out, an open network joined without a password, a refused one reported. The image (`sudo make iso`, packages r487) in a UEFI VM with an empty 40 GB disk: the live desktop came up with the assistant open; Return, the disk tile, "Mina Park", Tab, Tab, the password twice, Return, "seoul", Return, Ready to Install, Return; the bar reached "Installing the system…" at 45 s and Ambrosia Is Installed by 3.5 min. Booted from the disk: our login screen with Mina Park at 3:49 (Seoul), password, the welcome, Search to a terminal: `[mina@minas-ambrosia ~]$`, `Timezone=Asia/Seoul`, ambrosia-shell r487. That install is kept as `out/vm/fresh-1125.qcow2` (user mina, password nectar). Not seen: Wi-Fi for real, a BIOS computer, two disks, the failure page from a real failure, the dialogs' fallback. The keyboard's return after a window opens over the welcome (a later commit) was seen on that install: the log's `Window.active` went true, false, true as Konsole opened, and Return moved the welcome on. From packages r489 with the screen dimmed it did not come back, so a last resort was added (the window put up afresh after 300 ms) and seen working by itself. |
| 36, 2026-11-25 | 23, sounds | `design/sounds.ts` (seven recipes: layers of struck tones with partials, band-kept noise bursts, grains) and `tools/gen/targets/sounds.ts` (a seeded synthesizer, 48 kHz 16-bit WAVs, `index.theme` inheriting Ocean, the other names as links) into `dist/sounds/ambrosia`; `tools/gen/sounds.test.ts`. The session names the theme (`[Sounds] Theme` in the generated kdeglobals, GTK's `org.gnome.desktop.sound theme-name` in dconf) and has the volume pop off (`session/xdg/plasmaparc`). `session/sound` (`/usr/lib/ambrosia/sound NAME`, in ambrosia-theme: the theme chosen, what it inherits, freedesktop; `paplay` in the event role). Played by `shell/Screenshot.qml`, the Dock's Empty Trash and Files' `FileOps::trash`. Found on the way: the Dock's Empty Trash had never emptied anything (`kioclient empty-trash` is no command; now `ktrash6 --empty`). | `bun test` (9 tests of the waveforms). Test VM, the files copied in, a new login: the helper played our alert, crumple and a linked name, Ocean's for a sound we lack, nothing for an unknown one (the server's streams listed while they played); the alert recorded from the null sink's monitor measured peak -6.0 dB, 660 Hz, 255 ms; `strace` showed libcanberra (`canberra-gtk-play -i bell`) and KWin (a GTK 4 window's `beep()`) opening `ambrosia/stereo/bell.wav`; the volume key cached no sample by default and `ambrosia/stereo/audio-volume-change.wav` once switched on; `ambrosia screenshot screen` played the shutter; Empty Trash from the Dock's menu played the crumple and left the Trash empty (2 files to 0). From packages r484 there, a new login: the links are links, Files played the thump for a file moved to the Trash through its DBus `Trash` and the shell's fallback did with Files closed (a later commit, copied in), Settings' Sound showed Ambrosia as the alert sound with the feedback switch off, and F11 slid the windows off and back (round 35's script, from the package). Never heard: the VM has no sound card and nobody listened; on tenet the files are installed and nothing was played. |
| 35, 2026-11-25 | 15, Show Desktop's keys | `session/kwin-scripts/ambrosia_desktop`, a KWin script: a script is told of KWin's Show Desktop only window by window (`hiddenByShowDesktopChanged`), so at the first one it waits for KWin's pass to end (a `QTimer` of 0 ms), toggles KWin's off again and presses `Ambrosia Show Desktop` through kglobalaccel. `kwinrc` enables it and switches off KWin's two Show Desktop animations (`windowaperture`, `eyeonscreen`). keyd's `[main]` sends F11 as Super+Ctrl+Alt+D. | Test VM on packages r479 with the three files copied in: KWin's `Show Desktop` shortcut pressed by name, `org.kde.KWin.showDesktop true` over DBus and F11 at the VM's keyboard each slid the windows off with the wallpaper, menu bar and Dock in place (a picture mid-slide, one after) and brought them back; eight shortcut presses 150 ms apart and six DBus on/off pairs, then no KWin core dump and `showingDesktop` false. Not on tenet: its running KWin has neither the script nor the effect's Show Desktop until the next login. |
| 34, 2026-11-25 | 15, trackpad gestures | In `ambrosia_mission/contents/ui/main.qml`: three-finger swipes up and down beside the four-finger ones; `PinchGestureHandler`s for four fingers, which press shortcuts by name through kglobalaccel (`DBusCall`: Search's `_launch`, the windows effect's `Ambrosia Windows Aside` and `Ambrosia Windows Back`). In `ambrosia_windows/contents/code/main.js`: Show Desktop (`showDesktop`, `left`, `showWindows`; a held `set` Translation per window off its nearest edge, a twin animation to say when it is over, then minimized into `aside`; back by cancelling the hold, unminimizing quietly and sliding in), three shortcuts. `tools/fake-touchpad.py` now in the repo, with `swipe N DIR` and `pinch N in|out` | `bun test`, the Mission Control sheet. In the test VM as the new account, with `KWIN_EFFECTS_FORCE_ANIMATIONS=1` (KWin on software rendering loads no animation effect otherwise): swipes of 3 and 4 fingers each way (the desktop's id changing and changing back; `ambrosia_mission` among the active effects and gone again), spread (the screen's row 500 bare wallpaper), pinch (the windows where they were), pinch again (Search's panel), a new window while the desktop was shown (all back). Found on the way: KWin's own Show Desktop blackens our screen (so ours); the first version cancelled and started animations inside `animationEnded` and KWin crashed 3.5 s later in `AnimationEffect::postPaintScreen` (four core dumps): nothing there but minimizing now; a window closed mid-slide was held for good (`keepAlive: false`). Then the stress run of the gap's text: no new dump, `activeEffects` back to `blur`. From the r479 packages in the VM after a restart: spread, pinch and three fingers up again, no dump. On tenet the packages are in; its running KWin keeps the effects it loaded, so there they start with the next login (and it has no trackpad) |
| 33, 2026-11-25 | 24, the first minutes | `shell/Welcome.qml`, a layer surface over the first screen (the compositor's blur behind a veil, the keyboard its own while open): two pages on a glass panel, the looks as small drawn desktops (`Mini`, from the Theme's light and dark colors and the two Nectar pictures), `size.welcome` tokens; `Settings.welcome` (set where the shell finds no settings at all, so only a new account), `Popups.welcomeOpen`, the shell's IPC and `ambrosia welcome`; the live image's user service writes it empty settings; two sheets, `desktop-welcome` and `desktop-welcome-look` | `bun test`, `bun run build`, the two sheets in light and dark. On tenet, the shell copied over the installed one: opened by IPC, the panel 800 wide by measure, Return to the second page, → choosing Dark (the panel, the desktop, `settings.json` and GTK 3's import all dark within three seconds), ← Light again, Return ending it (`"welcome": false`, the wallpaper clear again). In the test VM from the r475 packages: a new account (`useradd`, SDDM logging it in) got the flag but no welcome: with no settings file the shell wrote its defaults and never called them loaded, so nothing that waits for that ran in an account's first session (the welcome, and telling apps of a change of look). `Settings.qml` now finishes loading in that branch; with it, the settings removed and the shell started again: the welcome by itself, 800 wide, then by clicks alone Continue, Dark (`settings.json`, `kdeglobals` and GTK 3's import dark), Continue (`"welcome": false`); the same first login again from the r476 packages. On tenet from r476: `ambrosia welcome`, the panel, Return twice, the desktop back and the settings as they were |
| 32, 2026-11-25 | 4, GTK apps' controls | `tools/gen/targets/gtkcontrols.ts`: one set of rules for both toolkits (GTK 4's colors as `--amb-*` variables for light and dark, GTK 3's written out per mode), the marks of a checkbox and a radio button as filled outlines GTK can recolor (`assets/*-symbolic.svg` beside each stylesheet), GTK 3's surfaces and selections; `gtk.ts` puts them before the traffic lights, and GTK 4's lights are redrawn on the button's image, named by class so the controls' rules don't pad them. `session/gtk-appearance` (in ambrosia-shell, `/usr/lib/ambrosia/`) and `Appearance.qml` running it; `tools/install.sh` copies the pictures; `tools/gen/gtk.test.ts` | `bun test` (8 new: closed rules, nothing GTK 3 can't read, every variable defined in both modes, the two GTK 3 files alike but for colors, every picture named is there, sizes from the tokens, the marks wound one way), `bun run build`, the shell loaded by a sheet. In the test VM (the 11-24 install, today's Arch), the stylesheets copied over the installed ones: `gtk3-widget-factory` (two pages, its menu, a context menu and the row under the pointer, read off the pixels: the accent, 5 in from the menu's edge), `gtk4-widget-factory` (the lights measured: 14 wide, 23 apart, 17 from the top), a libadwaita window in Python (rows with switches, a pop-up, a stepper, an entry; the menu open; the pop-up's list), each in light and dark; `gtk-appearance dark` and `light` by hand (the import and `settings.ini` change and change back); GTK's journal clean of CSS errors after two fixes (`transform` in GTK 3, an icon size of 0). Then from the packages (r471, the VM restarted): the shell changing to dark moved GTK 3's import and `settings.ini` by itself, a GTK 3 window opened after it dark (window #242321, read off the pixels; buttons 24 tall, the default one 64 wide, a switch 36), the libadwaita window and its menu dark; Firefox's settings page and its context menu as before. Found there: at the shell's start two runs of the helper could cross and leave the import dark and `settings.ini` light; the shell now waits half a second and runs the last (three starts, each right). `tools/px.py` (the runs of color along a line of a screenshot) and `tools/vm-try.sh pull` came out of this round. On tenet from r472: the shell's restart wrote `gtk-application-prefer-dark-theme=false` into `settings.ini` unasked; a GTK 3 window in Python measured as in the VM (buttons 24 tall, Done 64 wide in #127eee, a switch 36), and again after the shell was set to dark (window #242321, Done #3792fd), then light put back |
| 31, 2026-11-24 | 21, the emoji picker | `shell/EmojiPicker.qml` on the Overlay (kind "emoji": `Popups.toggleEmoji`, the shell's IPC, `ambrosia emoji`): a search field, the groups as a list of grid lines so only those in view are drawn, a strip of nine glyphs (new in `icons.js`), the ones chosen lately in Quickshell's state folder; `shell/emoji.js`, 1923 emoji with names and words, written by `tools/emoji.ts` from Unicode's emoji-test.txt (Emoji 18.0) and CLDR's English annotations; `size.emoji` tokens. `input/` (`ambrosia-input`, C on libwayland, a new package): KWin's input method for the session (`[Wayland] InputMethod` in the session's `kwinrc`), which commits what `ambrosia-input type TEXT` hands it over a socket, once the field in front has gone quiet. `session/org.ambrosia.emoji.desktop` (Super+Ctrl+Alt+Space) and keyd's ⌃⌘Space sending it; two sheets, `desktop-emoji` and `desktop-emoji-search` | `bun test`, `bun run build`, `make shell-shots` (the two sheets, light and dark); the search run over the whole list outside QML ("fire" 🔥 first, "flag jap" 🇯🇵, "thumbs up" 👍). In the test VM: the helper named in KWin by hand and `type` putting "😀 hi ❤️ 👨‍👩‍👧" into a Qt Quick field, the keyboard still typing after; then from the r467 packages after a restart: KWin starting it unasked, the picker by command and by ⌃⌘Space (keyd), "rocket" Return: 🚀 in the field, the arrows and Return: 👍. Found there: a choice was typed into the picker's own search field as it closed (the helper writes to the field that is active), so the field is one the input method doesn't see (read-only to Qt, its keys put in by hand). On tenet, live, the helper started in the running KWin by a notified setting: the picker photographed in light and dark, 🔥 by search, a flag by the Flags tab and a click, ❤️ into KWrite (saved and read back), 😃 into Konsole's prompt, 🎉 with nothing in front (pasted afterwards). Found there: one click's choice was lost though the helper had written it. Its log (`AMBROSIA_INPUT_DEBUG`) showed why: after the picker closes the app's field sends its state twice, 50 to 100 ms apart, and Qt drops text that arrives between. The helper now waits for the second round; twelve choices in a row, six by click and six by Return, all arrived. From the r468 packages: four more on tenet, and in the VM Firefox on a page with one text box taking 🚀 (read from its window's title). Not seen: a GTK app, Firefox on tenet, a second screen |
| 30, 2026-11-24 | 20, Open and Save | `files/src/portal.cpp` (`Portal`: the portal's `FileChooser` on the resident Files, `OpenFile`, `SaveFile`, `SaveFiles` answered late, each request an object with `Close`; filters read from and written back as `(sa(us))`; the last folder kept in `files.conf`), `App.openPanel`, `accepts` and `exists`; `FinderWindow`'s `panel` (what dims, what the button says and whether it can be pressed, `panelChoose`, Return and Escape, no menus or lights), `PanelBar.qml`, `PanelName.qml`, `PanelAlert.qml`, `PushButton.qml`; `--panel` to open a stand-in; `files/ambrosia.portal` and a D-Bus service file; the session's `xdg-desktop-portal/portals.conf`, three environment variables in `startambrosia`, a Firefox pref | `bun test`, `bun run build`; `files/tools/tenet.sh grab` of `--panel open` and `--panel save`. On tenet, live, a test build as the resident Files and requests sent with `busctl`: open with two filters (photographed in Documents and in a test folder, the text file dimmed, a click on it and Open doing nothing, the picture chosen: `0`, its URL and the filter), save under a name that exists (the question photographed; Escape, a new name typed: its URL; again with Replace: the old name's URL), Escape (`1`), the request's `Close` (`1`), a folder (Return: the folder's URL); an ordinary Files window still with its menus. In the VM (a copy of the 2026-11-24 install, packages r464, logged in afresh): the three variables in the session's environment, `kdialog --getopenfilename` and `--getsavefilename` answered through xdg-desktop-portal by the panel |
| 29, 2026-11-23 | 18, starting up and shutting down | `tools/gen/targets/plymouth.ts` (a Plymouth theme on the script plugin, generated: the mark, the bar's track and fill, a password field and its dot at 1x to 4x, and a script that sizes them by the screen's height, fills the bar from Plymouth's progress, shows the mark alone when shutting down and a field with dots for a disk's password), `size.boot`; `packaging/plymouth/boot-picture` (`/usr/lib/ambrosia/boot-picture [on\|off]`: sets the theme, adds the hook after `systemd` or `udev`, adds `splash` to systemd-boot's entries, syslinux's menu and `/etc/kernel/cmdline`, rebuilds the initramfs) and `plymouth-quit.conf` (Plymouth leaves its last frame up); the installer installing `plymouth` and running it; the live image's package, hook, `quiet splash` and `plymouthd.conf` | `bun test` (new `plymouth.test.ts`: every picture the script asks for exists at every scale), `bun run build`, the drawn sheet. In the test VM (`tools/vm-try.sh`, plymouth installed there, the theme and the script copied in): `boot-picture` run, off, on and on again (one `splash`, one hook); two restarts photographed every quarter second (the mark alone going down, the firmware's logo, the mark and the bar at 75% to full, a second of black, the login screen); `plymouth ask-for-password` showing the field, five dots for five keys, four after Backspace, the bar back after Return and the password handed over. The packages (r460) carry the theme, the script and the drop-in where they belong (`pacman -Qlp`) and are installed on tenet, where nothing was switched on. Then from an image built with it (`sudo make iso`, 2026-11-24): `tools/vm.sh live` photographed (systemd-boot's menu, the mark and the bar for six seconds, black, the desktop with the installer), `tools/vm.sh install` to the end, the installed system's first start (Plymouth's text fallback, see the gap), and its second start and shutdown from a copy with a shell (`tools/vm-try.sh` with `VM_TRY_DISK`): the mark both ways, `splash`, the hook and the theme all set by the installer, and a login into a working desktop on today's Arch (KDE 6.8.3) |
| 28, 2026-11-23 | 19, password prompts | `shell/Authorization.qml` (Quickshell's `PolkitAgent`: a request opens a confirmation, its answer goes to `flow.submit`, a failure shakes it, an end closes it) in `shell.qml`; `ConfirmDialog` learning `glyph`, `shown`, `hold` and the shake, `Popups` learning `cancel` (what to do when a confirmation is put away unanswered, by anything), `finish()` and `refused()`; `session/plasma-polkit-agent.conf` (Plasma's agent not started in our session); a stand-in agent and a sheet, `desktop-password` | `bun test`, `bun run build`, `make shell-shots` (new sheet `desktop-password`). On tenet, live, Plasma's agent stopped and the shell restarted: `pkexec true` started inside the session bringing up the prompt (photographed: the lock, polkit's sentence, "justin06lee", the field), Cancel ending pkexec with 126, Escape the same on a second one; no password typed there (it is Justin's account). After the r457 packages, installed in a throwaway copy of the test install and logged in afresh: Plasma's agent not started, `pkexec true` bringing up the prompt, `wrong` refused (`pam_unix(polkit-1:auth): authentication failure`, the dialog still up with its field emptied, photographed), `ambrosia` ending pkexec with 0. On tenet from the packages: the prompt again, Escape, 126. Not seen: the shake itself (a picture after it), dark, a prompt whose answer is shown, two prompts at once, a request ended by polkit while the dialog is up, a click beside it. |
| 27, 2026-11-23 | 17, the lock screen | `session/plasma-shell/org.ambrosia.desktop` (a Plasma shell package with only `contents/lockscreen`: `LockScreen.qml`, which gives the login screen's file the `sddm`, `userModel`, `sessionModel`, `keyboard` and `config` it expects and passes the password to the locker's `authenticator`, keeping PAM asking, as Plasma's does; `Login.qml`, a link to `packaging/sddm-theme/Main.qml`); that file's new `lockScreen` (no picture of its own, no power buttons); the session's `plasmashellrc` naming the package; `Wallpaper.tellLocker` (the first screen's wallpaper writes the picture, or the color, and how it fills into `kscreenlockerrc`); a stand-in for Plasma's key-state module and a sheet, `lock-screen`; `tools/vm-try.sh` (a throwaway copy of the test install with root SSH, typed at and photographed through QEMU) | `bun test`, `bun run build`, `make shell-shots` (new sheet `lock-screen`, light and dark, over a stand-in authenticator). On tenet: the package as a user copy opened by `kscreenlocker_greet --testing --shell org.ambrosia.desktop` and photographed (the clock, the account, the field, over the locker's own picture; nothing typed: it is Justin's account), nothing in the journal about a fallback; the shell restarted and `~/.config/kscreenlockerrc` read back with the desktop's picture. In a throwaway copy of the test install (same KDE, 6.8.2), with the new files copied in: the login screen still drawing and logging in; `loginctl lock-session` showing ours over the picture named in `kscreenlockerrc`; `wrong` refused (`pam_unix(kde:auth): authentication failure`, LockedHint yes), `ambrosia` letting in (LockedHint no, the locker gone), three locks in two boots; `tools/vm-try.sh` itself run once, every part. After the r454 packages, installed in another throwaway copy (all eight and our Quickshell) and logged in afresh: `kscreenlockerrc` written by the shell itself; a lock showing ours, `wrong` refused, `ambrosia` letting in; and round 26's Mission Control as packaged, loaded by the session with KWin's Overview off, opened by its shortcut and photographed with no errors in the journal. On tenet from the packages: the testing mode without `--shell` (the session's `plasmashellrc` names ours), over the desktop's picture. Not seen: dark, Caps Lock's mark, a picture of the user's own or a color, an account without a password, two screens, the grace period, Justin's own unlock on tenet. |
| 26, 2026-11-23 | 8, Mission Control and Spaces | `session/kwin-effects/ambrosia_mission`, a KWin scene effect in QML: `main.qml` (the effect, its two shortcuts and two swipes, its modes and the timing), `MissionScreen.qml` (one screen: the wallpaper and the bars as window thumbnails, the windows in KWin's own `ExpoLayout` with a shadow, a ring and a name, a drag to a desktop, the arrows), `SpacesBar.qml` and `WindowLabel.qml` (the strip and the name, pictures only), the shell's `Label.qml` by a link; on in the session's `kwinrc`, KWin's Overview off; keyd's `[control]` layer (⌃ with an arrow); `Apps.showWindows` and the Dock menu's Show All Windows; `size.mission` tokens; a sheet, `mission-control` | `bun test`, `bun run build`, `make shell-shots` (new sheet `mission-control`: the strip closed and open, a ringed window with its name). On tenet, live, from a copy of the effect loaded into the running KWin under another id (with numbers for the new tokens, which that KWin doesn't hold): opened by its shortcut over Files, Kate and Konsole; the ring and the name under the pointer; the strip opened by the pointer, + adding Desktop 2, Konsole dragged onto its picture and found there by KWin, a click on the picture going to it, KWin's Switch One Desktop to the Left coming back, the picture's button removing it (the window back on Desktop 1); → → Return going to a window; Esc, the shortcut again and a click on the Dock leaving; the one-app spread with two Konsole windows, one minimized, and a click bringing the minimized one back; the switch from one mode to the other while up; the motion both ways at 4 s; dark. The Dock menu's Show All Windows. keyd reads the new layer without complaint (`keyd check`). After the r451 packages: the installed effect loaded into the running KWin opens, but that KWin holds the tokens from before (`Theme.size.mission` isn't there: no ring, the strip unsized), so it was unloaded again and is to be seen as packaged after a login; a copy of the installed files with numbers for those tokens, and keyd switched on for the test: ⌃↑ opening and closing it, ⌃↓ the app's windows, Esc, ⌃→ and ⌃← between two desktops, pressed on a virtual keyboard keyd took for one. Not checked: the installed effect as it is (needs a login); the four-finger swipes (no trackpad); two screens; a full-screen window; Show All Windows for an app that isn't in front or has every window minimized; more windows than fit comfortably. |
| 25, 2026-11-23 | 14, icons on the desktop | `shell/DesktopIcons.qml` on the first screen's wallpaper (`Wallpaper.qml` loads it, with the room the menu bar and the Dock take): ~/Desktop watched by a `FolderListModel` and read with `stat` and `file`, laid out in columns from the right, choosing by click, ⌘/Shift and a dragged rectangle, opening, a menu, dragging out (`Drag.Automatic` with the URLs) and drops in (`kioclient move`); `shell/FileKinds.qml` (the icon for a kind of file, shared with the Dock's stack); `Session.trash` (was the Dock's); the desktop menu's Sort By and `desktopSort` in the settings; `size.desktop` tokens. | `bun test`, `bun run build`, `make shell-shots` (new sheet `desktop-icons`). On tenet, live: four test things on the Desktop shown, one chosen, a double click opening a text file in Kate, an icon's menu and its Move to Trash, New Folder appearing, Sort By Date Modified, an icon dragged onto the Dock's Trash, a rectangle dragged over three; the Downloads stack still opening. Not checked: ⌘-click, a drop from a window, the Dock at a side, more icons than one column holds, a second screen. |
| 24, 2026-11-23 | 10 and 22, ⌘H, ⌥⌘Esc and menus opened by a command | Hiding in the session's KWin effect (`ambrosia_windows`: Hide App, Hide Others, Show All and Show Without Motion as KWin shortcuts; windows minimized while the effect has the whole screen, so no Genie; a hidden app's other windows follow the one brought forward); the app menu's Hide, Hide Others, Show All (`Apps.hideFront` and the rest, `Apps.kwin`), and the Dock telling the effect before it brings back an app with every window put away; `ambrosia quit` and the `quit` key layer for apps without Ctrl+Q; desktop files for ⌥⌘Esc and that quit; keyd's ⌘H, ⌥⌘H and ⌥⌘Esc; `packaging/quickshell/popup-grab.patch` (a popup that takes the keyboard before the shell's first input; pkgrel 4). | `bun test`, `bun run build`, `make shell-shots` (new sheet `desktop-app-menu`). On tenet, live, with the Genie slowed to 6 s and KWin asked which effects were running: Hide on Konsole's two windows, back from the Dock and from Alt+Tab, Hide Others, Show All, the app menu's rows, a plain minimize as the control (the Genie ran); `ambrosia quit` closing Kate; the patched Quickshell installed and Force Quit opened by command straight after a shell restart, Down moving the choice. With keyd switched on for the test (and off again after), ⌘H and ⌥⌘H pressed on a keyboard-only virtual device hid Kate and then the others. Not checked: ⌥⌘Esc and the `quit` layer's ⌘Q by their keys (a desktop file's chord is taken up at the next login), the green light's menu before a click (it needs the installed frame, so a login too), dark, an app with a dialog open, an Xwayland app. |
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
