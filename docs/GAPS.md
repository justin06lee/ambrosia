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
5. **Glass: each pane its own material and a bent rim, seen on KWin.**
   Since round 38 glass is a KWin effect of ours (`glass/effect`, in
   ambrosia-glass) in KWin's blur's place. Every pane of the shell says
   where it is, how round, and of which material (a `GlassPane` in
   `shell/Glass.qml` and where the shell draws glass by hand; the
   `ambrosia_glass_v1` protocol carries it with the frame it belongs to),
   and the effect blurs and saturates behind each as the design's table
   says: the menu bar thin, the Dock and banners regular, menus and Search
   thick, the control center a light untinted blur with each module's own
   glass over it, which KWin's one setting could not do. Edges are drawn
   smooth to the pane's own corner. Measured in the test VM against a
   wallpaper of one hard edge (`tools/blur.py`): the bar blurs as a Gaussian
   of 19.8 px (the token says 20), the Dock 27.6 (28), Search and menus
   35.6 to 36.6 (36), the control center's backdrop 10.2 (10); over a flat
   color each lands on the color its saturation and tint compute to, to the
   last digit; the same in dark and at a 2x scale. Other apps that only ask
   for a blur get regular, and their menus thick (Konsole's: 36.4). On
   tenet's own card (NVIDIA, OpenGL ES) in a KWin of its own
   (`tools/glass-try.sh`): 20.0 and 27.6. Since round 39 a pane's rim
   bends what shows through it, the design's refraction: within 14 px of
   the edge the picture is taken from further out, 7.7 px at the edge
   itself and less inward by the square of the way, red a hair less than
   green and blue a hair more. Seen in the VM as numbers: at the control
   center's edge over a hard line the picture 4 px in is the one 3.9 px
   further out, and from 12 px in nothing has moved. To the eye it is
   slight behind the control center's light blur and nothing at all
   behind the Dock's heavy one, where a shift of a few pixels changes a
   level or none: the design's numbers, drawn as given, do not make a rim
   anyone would notice, and whether glass should clear toward its edge (as
   a Mac's does) is a question for the design. Since round 40 KWin's own
   windows name a pane too (⌘Tab's strip thick, the tiling preview clear),
   and Mission Control, which draws the bar and the Dock as pictures the
   compositor's glass can't get behind, puts the wallpaper behind each of
   their panes itself, blurred as the pane's material asks: seen in the VM,
   the Dock 27.2 and the bar 19.8 there, as on the desktop. Since round 41
   Files' and Settings' floating sidebars are glass too (regular): the
   window is open to the desktop under the sidebar and nowhere else, the
   sidebar's own color lies over what shows through at four parts in five,
   and only the window in front is see-through, as a Mac's is; behind
   another window, or where the compositor has no such effect, the sidebar
   is solid as before. Columns that scroll in under Files' sidebar show
   through it in the desktop's place. Seen in the VM: 28.4 through Files'
   sidebar over a hard edge. How much shows through was set by eye: this
   Mac's own Finder could not be measured in front without taking the
   keyboard from whoever is at it. Left: a banner's or the Dock's glass in
   Mission Control shows the wallpaper only, not the windows spread over it. The effect is built for one KWin
   version: a newer KWin leaves it out (it says so in the journal) and the
   session's own blur stands in, one strength for everything, until
   ambrosia-glass is rebuilt. Not seen: tenet's live session, which loads it
   at the next login.

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
   Since round 74 a window of ours opens where it was last left and as
   large, as a Mac's does: Files' windows, Settings, Notes, Calculator,
   Activity Monitor, Font Book and Disk Utility (`kit/placing.h`). Wayland
   tells an app neither where its window is nor lets it say, so the place
   is KWin's to keep: the app names itself and each window by the
   session-management protocol (`xdg_session_manager_v1`, in KWin since
   6.5 and Qt since 6.10) and KWin puts a window of that name back where
   the last one stood, maximized or full screen if it was. Seen in the
   test VM: Calculator, moved and quit, opened where it had been; Files'
   two windows came back to their places after a log out. Since round 75
   a TextEdit document and a PDF in Preview open where that document's
   window last was, as large (the window is named for the document, one
   of 256 names), and the documents open when the session ends are open
   again at the next login, as a Mac's are when it logs back in with
   "Reopen windows" on: Plasma starts the apps that were open again, and
   TextEdit and Preview, asked to close while the session manager says it
   is on its way out (`kit/resume.h`), write down what each window showed
   and open it at their next start. Short of a Mac's: a picture's window
   in Preview is fitted to the picture each time and left to KWin's
   placing, as are a new TextEdit document, every app's Settings window
   and About panel and every app that isn't ours; a second window of an
   app opens where the second one last was, not stepped down from the
   first; a document never saved isn't brought back (it asks to be saved
   at log out, as before); what was selected or scrolled to isn't kept
   (a PDF's page is, since round 59); the places are in KWin's cache
   (`~/.cache/kwinsession.kcache`) and go with it, and a computer turned
   off without a log out (`systemctl reboot`, the power cut) brings the
   windows back without their places. Naming a window is a
   private part of Qt, used only by the Qt it was built with: after a Qt
   update windows open by KWin's placing until the packages are rebuilt.
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
    those are by itself (`docs/keyboard.md`). Since round 42 our own
    menus name their chords beside the rows as a Mac's do (Hide ⌘H, Hide
    Others ⌥⌘H, Quit ⌘Q, Force Quit… ⌥⌘⎋, Lock Screen ⌃⌘Q, Minimize ⌘M,
    Enter Full Screen ⌃⌘F, and since round 45 Log Out ⇧⌘Q, which asks
    first as the menu's row does): only chords that do the row's thing;
    the Go menu's rows have none. Since round 53 the menu named for the
    app is a Mac's for any app that has the rows: About (the app's name),
    Settings… with ⌘, and Quit are the app's own, found in its menus by
    what they say (KDE's "Configure Kate…", "About Kate", "Quit";
    "Preferences", "Options…"), shown there by a Mac's names and left out
    where the app had them; Help is the last title, after Window; ⌘, opens
    a KDE app's settings. Seen in the test VM (2026-11-27) on Kate and
    Konsole: the three rows, each doing the app's own thing, the key, and
    Files' menus as they were. Short of a Mac's: no Services; an app that names
    the rows some other way keeps them where they are; only the rows right
    under a title are looked at. Since round 55 our own six apps each
    publish a menu under their own name, which the bar shows as the app
    menu's rows: About (a Mac's About panel: the icon, the name, the
    version, two lines, measured from macOS 27's), and in Files Empty
    Trash… on ⇧⌘⌫, which asks first and is grey while the Trash is empty.
    A window with no menus of its own (the panel, an alert) keeps its
    app's menus in the bar. Seen in the test VM (2026-11-27). Short of a
    Mac's: the panel opens centered, not a Mac's third of the way down; the
    menus shown for a panel are its app's other window's, so File > Close
    there closes that window. The panel's yellow light is dim since
    round 65, as a Mac's: Wayland gives a window no way to say it can't
    be minimized, so a KWin rule says it for any window with the
    panel's zero-width title (`session/xdg/kwinrulesrc`; a user's own
    rules file replaces ours). Since round 56 Files has Settings… on ⌘,
    (gap 26), in a Settings window every app of ours can fill in
    (`kit/PreferencesWindow.qml`); TextEdit has its own since round 57
    (gap 25) and Preview since round 59 (a Mac's Calculator and Activity
    Monitor have none). Settings… chosen again from the menu
    brings a Settings window that is behind forward (a KWin script of
    ours, `ambrosia_forward`: KWin refuses an app that has no key press
    to show for it). And a window
    of ours stays lit under anything of the shell's own (the app menu,
    Window, a status item's menu, the control center), as a Mac's front
    window does: the bar holds the app's own-name menu open meanwhile, and
    the app takes that as a yes or no.
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
    margin; no Fill, Arrange or Return to Previous Size. Since round 73
    a click on the green light makes the window full screen, as a Mac's
    (KWin's frame and our own apps' lights alike; with ⌥ held it zooms,
    which a double click on the title bar still does), and over a
    full-screen window the menu bar and the Dock are away and come back
    when the pointer reaches the top or the bottom of the screen; the way
    out is ⌃⌘F, Exit Full Screen in the Window menu, or the green light
    where the app draws its own. Short of a Mac's there: full screen is
    not a Space of its own with a slide to it; the bar comes down over
    the window's top instead of pushing its title bar down, and a framed
    window (Terminal, Firefox) shows no lights while full; a GTK app's
    own green light still zooms; System Settings zooms, as a Mac's. (Until
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
    Since round 76 the questions before Log Out, Restart and Shut Down
    are a Mac's (`shell/Session.qml`, `shell/ConfirmDialog.qml`): its
    words ("Are you sure you want to quit all applications and log out
    now?"), a line that counts a minute down and then goes ahead by
    itself, and the checkbox "Reopen windows when logging back in". The
    checkbox is Plasma's setting (ksmserverrc's `loginMode`, written as
    it stands on the way out): off, Plasma starts none of the apps that
    were open, and Files, TextEdit and Preview keep none of their
    windows for the next login (`kit/resume.h`'s `kitReopens`). Seen in
    the test VM. The question's layout is ours, not measured from a
    Mac's (asking this Mac to log out to look at it was not done).
    An app that won't close (a document asking about unsaved changes)
    no longer loses its work to the log out: KWin, ten seconds in, says
    which apps are still open and that it will log out anyway in two
    minutes, and did; the shell now lets that notification go a hundred
    seconds after it came, which KWin takes as Cancel Logout, and the
    notification says so ("Log out is waiting… called off in 2 minutes
    if they stay open"), as a Mac's log out times out. Its Cancel Logout
    and Log Out Anyway buttons work as before. Short of a Mac's: the
    apps that did close stay closed, and nothing says afterwards that
    the log out timed out.
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
    Close cancelling. Since round 67 our own apps ask on a Mac's small
    Save sheet instead (`kit/SavePanel.qml`: Save As and Where over the
    middle of the window, an app's own pop-ups between two rules, Cancel
    and Save; a name already taken is asked about on the sheet; ⌘D is
    the Desktop; where each app last saved is kept): TextEdit's Save
    (with its File Format, or a plain document's encoding) and Export as
    PDF, Notes' Export as PDF. Its arrow button and "Other…" under Where
    hand over to Files' panel, whose answer is the answer. In the test VM, from the packages and through the
    portal itself: `kdialog`'s open and save (a Qt app) brought the panel
    up, and got back the file whose name was typed and chosen with
    Return, and the name typed to save under. Not seen: Firefox or a GTK
    app asking, several files at once, a Save over the app's own window
    (the requests had no window behind them). Short of a Mac's: it is a window of Files
    beside the app's, not a sheet on it (the menu bar says Files while it
    has the keyboard, the app's window can still be used); the small
    Save sheet is our own apps' only (any other app gets the whole
    panel), has no Tags, opens out into a second window rather than
    growing, and TextEdit's File Format there offers one format; the Save As row sits right of the
    sidebar where a Mac's is above it; no Tags field, and what an app
    adds to its panel (a format, an encoding: the portal's "choices") is
    left out; a path bar where a Mac has a location pop-up; only folders
    on this computer can be saved into; the panel's size isn't kept. An
    app that brings its own dialog never asks: Kate's Open and Save
    (KDE's own, for its encoding box) and anything else built on KDE's
    file widget stay KDE's, in our controls.
21. **Print, colors, fonts, emoji: the emoji picker, the Colors and Fonts panels and the Print panel are ours, seen on KWin.**
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
    Since round 69 Settings' Wallpaper pane asks for a custom color in
    that Colors panel too (it was the last Qt dialog in our apps).
    Since round 63 our apps show a Colors panel and a Fonts panel of our
    own (`kit/ColorPanel.qml`, `kit/FontPanel.qml`), measured from macOS
    27's: Colors with the wheel, the sliders (gray, RGB, CMYK, HSB, with
    figures and the hex), lists of named colors, the pencils, the well,
    thirty places to keep colors in (kept for every app) and an
    eyedropper that takes a color off the screen (KWin's picker); Fonts
    with the families under their letters, each after a tile saying Aa in
    it, the family's typefaces each written as it looks, the size, and a
    search. TextEdit has Show Fonts (⌘T) and Show Colors (⇧⌘C) for the
    selection, and the panels follow the selection; its Settings'
    Change… and Preview's background color use them. Each choice applies
    at once, as on a Mac. Short of a Mac's: no colors from a picture, no
    opacity, no color spaces, no pencil names, no dragging of a color to
    a swatch (a click keeps one, the other button empties it); Fonts has
    no collections, text effects or preview; both sit in the session's
    frame (a Mac's panels have smaller lights; its Fonts panel has no bar
    of its own); the look in front and in Light is ours, not measured
    (the Mac's were measured behind other windows, in Dark).
    Since round 64 our apps print: File ▸ Print… (⌘P) in TextEdit,
    Notes and Preview raises a Print panel of ours over the window, as a
    Mac's sheet (`kit/PrintPanel.qml`): the pages as they will print
    down its left, the printer, copies, all pages or a range, the paper
    and which way up, and PDF (the app's Export as PDF, and Open in
    Preview), Cancel and Print. The printers and each one's papers are
    CUPS's, and the job goes to it as a PDF the app makes for the paper
    chosen (`kit/printing.cpp`); a PDF open in Preview goes as it is,
    fitted to the paper. The printer and paper chosen are kept for next
    time. What CUPS says when it refuses a job shows in the panel.
    Short of a Mac's: no presets, no pages picked one by one, no
    scaling, two-sided, color or layout choices (a printer's own
    defaults hold), no header and footer, no ink levels; a PDF opened
    with a password doesn't print; a printer found on the network and
    never added prints only where CUPS can make its queue for the while
    (it could not in the test VM, where `lp` failed the same way); the
    light look is ours, not measured. A KDE or GTK app's print dialog is
    still its toolkit's, in our controls.
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

25. **The apps a Mac comes with.** Ours: Files, Settings, Calculator
    (round 48), Preview (round 49: `preview-app/`, ambrosia-preview, in
    Gwenview's and Okular's place and the default for pictures and PDFs)
    since round 50 TextEdit (`textedit/`, ambrosia-textedit, in
    Kate's place and the default for plain text and RTF) and, since round
    51, Activity Monitor (`activity-monitor/`, ambrosia-activity-monitor),
    since round 58 Font Book (`fontbook/`, ambrosia-fontbook, the default
    for font files) and, since round 60, Disk Utility (`disk-utility/`,
    ambrosia-disk-utility, the default for disk images).
    Calculator is a Mac's basic one by measure, dark
    in either appearance, 230 by 408 with round keys 47 across, the
    operators orange, the sum shown as it is typed with × and ÷ before +
    and −, the result under the sum that gave it, a percentage a share of
    what it is added to; every key on the keyboard too, ⌘C and ⌘V, its
    menus in the menu bar. Short of a Mac's: no Scientific, Programmer or
    Convert, no history at the side, no brackets, and the two round
    buttons at the top of a Mac's window are left out rather than drawn
    dead. Preview is measured from macOS 27's (a picture and a PDF, in
    Dark): the toolbar 52 tall with its capsules 36, the sidebar 205 wide
    and flush with thumbnails 159 across, a picture opened at its own size
    with 26 of ground above and below, a PDF's pages 10 apart at actual
    size. It opens pictures (several of one launch together, down the
    sidebar) and PDFs (a window each; one with a password asks for it);
    zooms by the toolbar, ⌘+ ⌘− ⌘0 ⌘9 or a pinch, a
    picture that was fitted following the window; turns a page or picture
    (⌘L, ⌘R); shows a PDF's table of contents; searches a PDF's text as it
    is typed, with Return and ⌘G through what it found; selects text by a
    drag and copies it, or a picture, with ⌘C; and asks with Files' Open
    panel when started with nothing (⌘O too). Since round 68 File >
    Export… writes what is shown as another kind of file on the Save
    sheet (Format: JPEG, PDF, PNG, TIFF where Qt can write it; a picture
    as it is turned, a PDF's page in front at 150 to the inch) and
    Export as PDF… as a PDF. Short of a Mac's: the document itself is
    never written (a turn isn't saved; Export has no quality slider,
    file size, HEIC or resolution, and takes one page of a PDF; no Markup,
    highlighting, signatures, cropping or color adjustment, and none of
    their toolbar buttons); no inspector or Share; what a search found is
    marked on the pages and counted in the field, not listed in the
    sidebar; a selection stays on one page; a PDF's links aren't
    followed; no Contact Sheet, single or two-page view, full screen or
    Go to Page; a page zoomed past about five times goes soft; an
    animated GIF shows its first frame; its light colors aren't measured
    (that Mac stays in Dark). Since round 59 Preview has its Settings
    (Preview > Settings…, ⌘,), a Mac's window by measure, 500 wide, with
    what ours can do: the window's background color, pictures opened
    together in one window or each in its own, a PDF's 100% as a point
    for a pixel or the size of its printout, and a PDF opening on the
    page it was left at. Short of a Mac's there: no annotations' name,
    no scale for pictures, no page layouts, no logical page numbers, no
    3D. TextEdit is measured from macOS 27's (a
    plain and a rich document, in Dark): a title bar 32.5 tall with the
    document's icon and name ("Edited" after it once it is), plain text
    right under it in the fixed-width font, rich text under the format bar
    (bold, italic, underline, strikethrough; text color and highlight;
    family, style and size; alignment; lists; line spacing; each control
    where a Mac has it) and the ruler (a mark a centimetre or half inch,
    the paragraph's indents and tab stops as markers that drag, a click
    for a new stop, a stop dragged off to remove it). It reads and writes
    RTF as Cocoa does (`textedit/qml/rtf.mjs`: fonts by family or
    PostScript name, sizes, the styles, colors, alignment, indents,
    spacing, tab stops, lists in levels, Windows and Mac code pages and
    the East Asian ones through ICU, the window's size), so a document
    goes to a Mac and back; plain text as UTF-8. ⌘N, ⌘O, ⌘S with Files'
    Save panel for a new document, a sheet before changes are lost (on
    close and on ⌘Q, each document in turn), ⌘B ⌘I ⌘U, ⌘+ ⌘−, ⌘{ ⌘| ⌘},
    ⇧⌘T between plain and rich, ⌘F with a Find bar that counts and
    replaces, Return, Tab and ⇧Tab in a list as on a Mac, a format chosen
    with nothing selected held for what is typed next, Export as PDF,
    undo throughout, a point a pixel so 12-point text is a Mac's size. In
    Dark a document's colors show with their lightness turned over and
    their hue kept, as a Mac's TextEdit shows them (black text white, a
    pale highlight a deep one under white text), the file keeping the
    true ones; a switch of appearance re-colors an open document.
    Short of a Mac's: no pictures or attachments (.rtfd), tables, links
    or styles (an RTF's are passed over on reading, a table's cells
    coming through as text between tabs); only RTF and plain text (no
    .doc, .docx, .odt or HTML, which opens as its source); a document is
    saved when asked, not by itself, and has no versions; it prints
    since round 64 (gap 21) but has no page setup or header and footer;
    no page view, no spelling, substitutions
    or smart quotes, no font panel, kerning, baseline or outline, no
    Other… for line spacing, no ✓, ⁃ or custom list markers (they read as
    the nearest we have), tab stops are all left ones, no title-bar menu
    to rename or move a document, no tabs; selected text takes the
    text's own color, losing its colors while selected; the mapping of
    colors in Dark is a plain turn of lightness, not Apple's own curve,
    which wasn't measured; the Find bar is from memory, not
    measured (opening a Mac's would have taken the keyboard); the light
    colors aren't measured. Since round 57 it has its Settings
    (TextEdit > Settings…, ⌘,), a Mac's window by measure with what ours
    does: a new document's format, window size and fonts, the ruler, RTF
    shown as code, ".txt" added on saving, and the encoding of plain
    text; a Mac's document properties, spelling and HTML options are
    left out, and "Wrap to page" is not there (Change… opens our Fonts
    panel since round 63). Activity Monitor is measured from macOS 27's
    (each tab, a chosen row, a process's inspector and the quit alert, in
    Dark): the toolbar 52 tall with Quit and Inspect in one capsule, the
    views' pop-down, the five tabs 74 each and the search; the processes
    in rows 24 tall, every other one a shade lighter, under headings that
    sort and whose rules drag; and under them the box in three panes. It
    reads the kernel every five seconds (one, two or five by the View
    menu): each process's share of a processor, processor time, threads,
    wake-ups, its own memory, what it read and wrote, what its TCP
    connections sent and received, whether it holds the computer awake,
    and an energy impact made of its processor share and wake-ups as a
    Mac makes one; the kernel's own threads are one row, kernel_task; a
    process running an app's file has the app's name and icon. The panes
    show the processor's shares with its load drawn, memory (used, cached,
    swap, and apps', wired and compressed) with its pressure drawn, the
    energy all take, the disks' and the network's traffic with a graph of
    counts or of bytes. A view lists all processes, mine, the system's,
    other users', active, inactive or the selected ones; the search keeps
    those whose names hold what is typed. Quit (⌥⌘Q) asks in a Mac's
    words, Quit or Force Quit, and for another user's process an
    administrator's password; Inspect (⌘I, Return, two clicks) opens a
    window on the process: the file it runs (shown in Files by the
    arrow), its parent (a link to the parent's inspector), group and
    user, its memory, its counts and its open files. Short of a Mac's:
    no Kind, % GPU or GPU Time, Ports, 12 hr Power or App Nap columns
    (nothing here counts them; a GPU's per-process time could be read
    from DRM's fdinfo and isn't yet) and no Columns menu to choose among
    those there are; the network columns count TCP only (UDP, so most of
    HTTP/3, isn't credited to a process: the kernel says only what each
    TCP connection carried) and only for the user's own processes, and
    what a connection carried between two readings before closing is
    lost; other users' processes say nothing of their disk bytes; the
    energy tab lists processes, not apps with their helpers folded in,
    and has no battery pane on a laptop; memory pressure is drawn as the
    share of memory in use, not Apple's own measure; no All Processes,
    Hierarchically, Windowed or GPU Processes or Applications in Last 12
    Hours; no Sample, spindump or diagnostics, no Send Signal, no CPU
    Usage, CPU History or GPU History windows, no graph in the Dock;
    one process chosen at a time; the inspector leaves out Sample,
    hangs, ports, Mach messages and system calls, and grows from its
    middle on its files tab, not downward; the password prompt names
    the command (`kill`), not Activity Monitor; closing the window ends
    the app (a Mac's stays in the Dock); the light colors and the
    front window's look aren't measured. Terminal is Konsole dressed as
    one since round 52: it goes by the name Terminal in the Dock, the menu
    bar and Search; its windows open 120 by 30 in macOS 27 Terminal's own
    default profiles, Clear Dark in Dark and Clear Light in Light (their
    stored colors, all sixteen and the text's, the background letting a
    little through), in the fixed-width font at a Mac's 12 points with a
    gray block that doesn't blink; no toolbar; the title a Mac's has (the
    user, then the program), without Konsole's name after it; its menus
    Shell, Edit and View as Terminal names and orders them; tabs once
    there are two, sharing the window's width. Short of a Mac's: it is
    still Konsole (its Settings menu and dialogs, split views, plugins
    and bookmarks are KDE's, in our widget style; since round 53 its
    chords read as a Mac's, ⌘N and ⌘T, and its settings are the app
    menu's Settings… on ⌘,); ⌘Q closes one window, as Konsole has it; bold
    colored text takes the bright color as well as the bold face; no
    selection color of the profile's; the font is JetBrains Mono, not SF
    Mono, and its lines stand a point taller; no title's folder icon and
    no size in the title; no Clear's glass (a plain blur at 95%); no marks,
    no inspector, no window groups; a user's Konsole settings from before
    keep their own profile if they named one. Archive Utility is Files
    since round 54: opening an archive, in Files or from any app, expands
    it beside itself (the one item it holds, or a folder named for the
    archive; a taken name gets a number), with no window but the progress
    window when it is long, where it can be stopped; zip, tar and its
    compressed kinds, 7z, rar, cpio, a lone gzipped file. Since round 66
    a zip closed with a password (AES or the classic kind) is asked
    about (since round 68 by an alert of ours with a password field),
    asked again when the password is wrong, and expanded. Short
    of a Mac's: a 7z or rar with a password is refused (libarchive opens
    neither); a
    zip's names in an old non-UTF-8 encoding come out wrong; no settings
    (where to put things, what to do with the archive after). Font Book
    is measured from macOS 27's (the three views, a typeface's page, the
    info pane and a font file's preview, in Dark): 1000 by 650 with the
    sidebar 150 wide down its side (All Fonts, My Fonts, the languages
    the user reads, collections, Fixed Width), the toolbar's view switch,
    size slider with the info button, and search; typefaces as cards 115
    square with the letters that stand for each in its own face (Aa, or
    its own script's), as samples one under another, or as a list under
    Typeface, Styles and Format that opens to a typeface's styles; a
    typeface's page with its styles' pop-up, its alphabet and every
    character it draws in boxes, or a sample of each style; the info pane
    with what it can write, its names, copyright, license, embedding,
    format, glyph count, file and version, read from the files. A font
    file opens in a preview 500 by 432 with Install, which copies it into
    the user's fonts; File > Add Fonts to Current User… and a drop on the
    window do the same; a user's typeface is removed to the Trash after
    asking, the system's are locked. Collections are made, named, filled
    from a typeface's menu, and deleted; search takes every word in
    names and styles; letters typed choose a typeface; the views, sizes,
    place, info pane and collections are kept. Short of a Mac's: no
    Activate and Deactivate, no downloadable fonts, no duplicates or
    validation, no Export or Print, no custom sample text, no filter bar,
    no smart collections of one's own (Fixed Width is the only one), no
    tabs or second window; "Designed For" isn't told apart from "Also
    Supported" (one list, fontconfig's); the repertoire lists characters,
    not glyphs without one; fixed-size bitmap fonts aren't listed; a
    typeface is dragged nowhere (collections fill from the menu); the
    sizes at the slider's ends, the chosen card's look, the front
    window's colors and all the light ones are ours, not measured;
    closing the window ends the app. Disk Utility is measured from macOS
    27's (a volume's page and a disk's, both listings, the Erase and First
    Aid sheets and the Info window, in Dark): 1099 by 518 with the sidebar
    256 wide (Internal, External, Disk Images; only volumes, or every
    device with its volumes under it, by the View button or ⌘1 and ⌘2), a
    toolbar 66 tall of round buttons over their names, and the page: the
    disk's picture, its name and kind, its capacity in a box, a bar of
    what is on it (used and free for a volume, its partitions in colors
    for a disk) with a legend, and the table of two columns. It reads
    UDisks2 and does everything through it: Mount and Unmount, Eject (the
    mark in the sidebar, ⌘E: an image is detached, a drive powered off),
    First Aid (asks, unmounts, checks, repairs if it must, mounts again,
    with what it did under Show Details), Erase (a name and a format, and
    for a whole disk a scheme, GUID or Master Boot Record; the new volume
    is mounted), Get Info (⌘I: a window of rows as a Mac's), File > Open
    Disk Image… (⌥⌘O, or opening an ISO or raw image from Files: its
    volumes are mounted), and an encrypted (LUKS) volume asks for its
    password on Mount and is locked again on Unmount. Since round 66 a
    volume is renamed where it stands in the sidebar (Return, a click on
    the name of the one chosen, or Rename in File and the shortcut menu:
    it is unmounted, named and mounted again, so it is found under its
    new name; a name is cut to what its file system carries, FAT's in
    capitals) and File > New Image > Blank Image… (⌘N) makes a disk
    image on a Mac's small Save sheet (Save As and Where, with any other
    folder from Files' panel, over the volume's name, the size as typed
    ("100 MB", "1.5 GB"), the format and the partition map): a file of
    that size whose blocks are taken as they are written, opened, given
    its volume and mounted; a file of that name is asked about first, one
    that is open is refused, and a prompt dismissed leaves no file. What the system
    runs from can be looked at and nothing else, and so a disk that LVM,
    a RAID, a ZFS pool or a mounted Btrfs set stands on. Short of a Mac's: no
    Volume (+ and −), Partition or Restore, and their buttons are left
    out rather than drawn dead; no image from a folder or from a disk, no
    converting or resizing one, no RAID; a new image is a raw file named
    `.img` (no encryption, no sparse bundle), its Save sheet is 60 wider
    than a Mac's small one and has no Tags; Erase has no Security Options
    and makes no encrypted volume;
    First Aid checks volumes only (not a disk's partition map) and not the
    volume the system runs from, which a Mac checks live; opening a disk
    image asks for an administrator's password (UDisks2's rule for loop
    devices since 2025, left as it is) and shows Disk Utility's window,
    where a Mac mounts it silently; a volume's name is its label
    ("Untitled" without one), APFS's containers and snapshots have no
    like here (a Btrfs volume's subvolumes aren't shown), LVM's volumes
    stand alone among the internal ones; S.M.A.R.T. says Verified,
    Failing or Not Supported from UDisks2's flag alone; the disks'
    pictures are ours, three kinds (inside, plugged in, image); the front
    window's colors and all the light ones are ours, not measured;
    closing the window ends the app, as a Mac's does. **Notes**
    (round 61, `notes/`) is ours: the folders, the list of a folder's
    notes under Pinned and the dates, and the note, with a title, headings,
    monostyled text, bulleted, dashed and numbered lists, checklists,
    block quotes and bold, italic, underlined and struck text; each note
    is a Markdown file under `~/.local/share/ambrosia/notes`, written as
    it is typed; Recently Deleted keeps a note thirty days. Since round
    62 ⌘F finds in the note (a bar over it, with Replace), a note is
    dragged onto a folder, a note made, changed or removed by another
    program shows at once, and monostyled text keeps its bold. Short of
    a Mac's: no tables, pictures, attachments, scans, links or drawings;
    no highlight colors; no gallery view, tags, smart folders, folders
    inside folders, locked or shared notes, no note in a window of its
    own; nothing is synced; a file another program changes in place
    (not by way of a new file, as editors save) is seen when the window
    next comes forward; a paste from another app comes in as text alone;
    the Find bar is TextEdit's, not measured (a Mac's can't be opened
    from behind); the front window's colors and all the light ones are
    ours, and Notes' Settings window was not measured; closing the
    window ends the app, where a Mac's stays in the Dock. Stand-ins,
    in Breeze's dress, under a Mac's name since round 54 where it has
    one for them (`session/mac-names`): Spectacle as Screenshot, Info
    Center as System Information; Ark keeps its name, for looking inside
    an archive; Discover (App Store) and Firefox (Safari) keep theirs.
    Nothing yet for
    Calendar, Reminders, Music,
    Photos, Mail. Which to build and which to dress is the
    largest open piece of work on this list.
26. **Files.** Since round 68 what Files says or asks with no window
    to say it on (a name that can't be used, an archive that couldn't be
    expanded, a zip's password, Empty Trash's question, a disk that
    couldn't be ejected) is a Mac's alert (`kit/AlertWindow.qml`: a card
    260 wide, the app's icon, the words, one wide button or two side by
    side), not Qt's message box with its warning sign; since round 69 it
    stands on the middle of Files' window in front and holds it still
    (the middle of the screen with no window), where a Mac's is a sheet
    on the very window it is about.
    Since round 43 the shortcut menu has Open With (the apps
    for the kind, with their icons), Compress, Make Alias and, on empty
    space, Sort By, which the View menu has too. Left
    (`docs/finder/PLAN.md`, "Still short of Finder"): Share and Quick
    Actions in the menu. Since round 72 a zip being made (Compress) is in
    the progress window as an expansion is, "Compressing “Big”" with how
    much is done and how long is left, and can be stopped, which leaves
    nothing behind; and the View menu has Finder's Hide Sidebar (⌃⌘S: the
    lights then stand at the toolbar's start), Show Path Bar (⌥⌘P) and
    Show Status Bar (⌘/: "120 items, 30.63 GB available", or "1 of 120
    selected"), each for every window and kept. The path bar no longer
    shows until asked for, as on a Mac (a search shows it all the same);
    the status bar is not measured from Finder's (the Mac at hand shows
    none) and has no size slider in icon view. Since round 65 a window has tabs, as Finder's:
    File ▸ New Tab (⌘T), ⌘W for the tab in front and ⇧⌘W for the window,
    ⌃Tab and ⇧⌃Tab (or ⇧⌘] and ⇧⌘[) to step through them, a folder
    opened with ⌘ held or by Open in New Tab, a sidebar place clicked
    with ⌘; the bar under the toolbar (measured from macOS 27's) with a
    close button under the pointer, a plus at its end, tabs dragged
    along it, a tab's own menu (Close Other Tabs, Move Tab to New
    Window), and files held over a tab or dropped on it. Each tab keeps
    its folder, view, history, selection and search. Short of Finder's:
    no Merge All Windows, a tab can't be dragged out of its window or
    into another, no Show All Tabs. Since round 74 the windows open when
    the session ends are there again at the next login, each with its
    tabs, the tab in front, every tab's view, and where it stood (gap 6),
    as Finder's are: Files writes them down as they change
    (`~/.local/state/ambrosia/files-windows.json`) and opens them when
    it starts. A window the user closes is forgotten; a tab whose
    folder is gone (a disk taken out) is left out, a search comes back
    as the folder it was begun in, and where each tab had been (Back,
    the selection) isn't kept. Plasma, which starts the apps that were
    open again at login, is told to leave Files out
    (`session/xdg/ksmserverrc`). Seen in the test VM. Quick Look's full screen is black with its bar away
    until the pointer moves since round 46. Folders are spring-loaded
    since round 47: a drag held over one opens it, and the window is back
    where it was once the drag ends. A sidebar tag's menu
    renames and deletes it since round 44. Opening an archive expands it
    since round 54 (gap 25). Files no longer leaves when a job ends with
    no window open (it did after a drop on the Dock's Trash, taking that
    drop's Undo with it). Empty Trash… is in the app menu since round 55
    (gap 10). Since round 56 Files has its Settings (Files > Settings…,
    ⌘,), laid out as macOS 27's Finder Settings by measure: General (what
    a new window shows, which ⌘N now follows), Sidebar (which items show:
    Movies, Music and Pictures can be added, any other taken out; the
    open windows follow at once) and Advanced (the warning before an
    extension changes, with Finder's Keep and Use buttons; the warning
    before the Trash is emptied; items leaving the Trash after 30 days;
    folders on top when sorting by name; where a search looks first).
    Only what Files does is there. Short of Finder's: no Tags tab, no
    desktop items, no "show all filename extensions" (Files always shows
    them); the 30 days are counted when Files starts and every six hours.
27. **Settings.** What each pane leaves out is in `docs/settings/PLAN.md`
    and `CONTEXT.md` (Next, 7): the trackpad's gesture tabs, scanners,
    VoiceOver, and the sheets still of our own design.

### Feel

28. **Scrolling: a trackpad's momentum and rubber band in every Qt app
    and the shell, seen in the test VM by a made-up trackpad.** Since round 70 a list in
    Files (its Open and Save panels too), Settings, TextEdit, Notes,
    Preview, Font Book, Disk Utility and Activity Monitor follows two
    fingers, glides on when they lift (its speed falling to 0.998 of itself
    each millisecond), gives like rubber when pulled past an end (a pull of
    x in a view d long shows as `(1 − 1 / (x·0.55 / d + 1)) · d`) and
    springs home, and a glide that reaches an end runs over it and comes
    back: DESIGN's numbers (Input). `kit/scrolling.h` does it, one filter
    in each app: Qt Quick on Wayland follows a trackpad and stops dead with
    the fingers (the compositor sends no momentum and Qt makes none), and
    our lists all stopped at their ends. The list under the pointer that
    can scroll the way the fingers went keeps the gesture to its end; the
    scroll bar shows for as long as the list moves. A mouse's wheel is as it
    was. Since round 71 the same reaches what isn't ours: the widget style
    installs it in every Qt app that draws with it (a KDE settings module's
    list, Discover's), and the shell has it by a QML module
    (`org.ambrosia.scrolling`: the emoji picker, Notification Center, a
    stack's grid). A Qt Widgets view scrolls by its scroll bar and can't be
    pulled past its end, but it glides: Terminal's scrollback runs on after
    a flick with the same fading speed. Firefox gives and glides by itself
    (seen: a page pulled down at its top). Left: GTK apps glide their own
    way and glow at an end where a Mac gives; two fingers
    at rest don't stop a glide as on a Mac (Qt hears nothing of fingers
    that don't move: the pointer moving, a click, a key or the next scroll
    stops it); a list that fits its view doesn't give at all. No real
    trackpad has been tried: the glide and the rubber are DESIGN's and the
    spring home is by eye (home in about half a second), none of it
    measured against a Mac's.
29. **Text.** Inter stands in for San Francisco by decision; how it sets
    (weight at small sizes, emoji, the system's CJK faces) has only been
    compared in Settings and Files. No Chinese, Japanese or Korean font
    comes with ambrosia-desktop: their text shows as boxes anywhere (seen
    in TextEdit, round 50) until noto-fonts-cjk or the like is installed.
    A Mac's fonts by name (Helvetica, Times, Menlo) are fontconfig's
    nearest: Inter, Noto Serif, JetBrains Mono.

## Closed

Nothing since the list began. What was built before it (the menu bar, Search,
the Dock, the control center, Notification Center, the window frame, the
login screen, the keyboard, Files, Settings) is in `CONTEXT.md`.

## Rounds

| Round | Gap | What was built | Checked how |
|---|---|---|---|
| 76, 2026-11-28 | 18, the questions before logging out, restarting and shutting down | `Session.askLogOut`, `askRestart`, `askShutDown` (the Ambrosia menu's three rows and ⇧⌘Q) raise the confirm card with `countdown: { seconds: 60, text(left) }` and `check: { text, of, property }` (the boolean it shows and sets, read live: `Session` is made when first used, and its reading of the setting lands after the question is up), two new things `ConfirmDialog.qml` knows: a `Timer` counts `secondsLeft` down while the card shows and presses the button at 0; a 14 box with our check, centered under the words. `Session.reopen` is read from `kreadconfig6 --file ksmserverrc --group General --key loginMode` as the shell starts and written by `shutdownCall` in the same `sh` as the call to `org.kde.Shutdown`, before it. `kitReopens()` and `kitKeeping()` in `kit/resume.h` (the same key, read by `QSettings`); TextEdit's and Preview's `App::leaving` use `kitKeeping`; Files' `App::left` keeps a window the session closes only if windows are to reopen, and writes the file at once then. `NotificationStore.stillOpen` knows KWin's "did not close" notification (the hint `x-kde-eventId` = `cancellogout`, or its Cancel Logout action), `summaryOf` and `bodyOf` give the banner and the center our words for it, and the `callOff` timer dismisses it after 100 s | In the test VM, shell files and dev builds over r605: the question as drawn, the box showing the setting as the shell starts (off after an unchecked log out) and following a click; unchecked, after ⇧⌘Q and a login no app, no Files window and no document came back and `loginMode` read `emptySession`; checked again, Files' window, `long.txt` and `Pages.pdf` came back in place; left alone, the question logged out by itself after its minute. A TextEdit document with a letter typed and not saved held the log out up: the notification with our words came 12 s in, Cancel Logout (pointer rested on it, then pressed) called it off, and left alone it was called off by itself between 100 and 110 s, the session still there at 135 s (before this change the same case logged out at two minutes and the letter was gone). From the packages (r608): the question with its box, unchecked by a click; after ⇧⌘Q and a login neither Files' window nor the PDF open before came back, and `loginMode` read `emptySession`. `bun test`, `bun run build` |
| 75, 2026-11-28 | 6, documents come back at login and open where they were | `kit/resume.h` (a header alone): `kitLeaving()` asks Plasma's session manager over D-Bus (`org.kde.ksmserver /KSMServer isShuttingDown`, 300 ms at most, never starting it), which says yes from before the windows are closed at a log out, restart or shut down (polled through a log out in the test VM: yes 0.4 s before the apps were gone); `kitKeepWindow(app, urls)` adds a window to `~/.local/state/ambrosia/<app>-windows.json` and `kitTakeKept(app)` reads and removes it, leaving out files that are gone. TextEdit's and Preview's `App::leaving`, `keep`, `takeKept`; `Main.qml` in each keeps a window closed while leaving and opens the kept ones at the start beside what it was started for. `kitFrameName(url)` in `kit/placing.h` (FNV-1a into 256 names): `App::frameFor`, the `frameName` of a TextEdit document's window and of a PDF's in Preview. Files asks `kitLeaving()` too: a window closed by anything but the user or the session's end (the Dock's Quit) is forgotten at once | In the test VM, dev builds over r602: two text files in TextEdit moved to (100, 600) and (1200, 100), a PDF in Preview to (950, 40), a picture beside them; after ⇧⌘Q and a login all four were open again, the three named ones where they had been, with Files' two windows and Notes; the kept files were gone from the state folder. Closed by ⌘W and by KWin with no log out under way, nothing was kept and TextEdit started with Untitled; `long.txt` opened again at (100, 600). A Files window closed by KWin outside a log out left `files-windows.json` at once, and both windows came through a log out. From the packages (r605): `long.txt` at (140, 640) and `Pages.pdf` at (930, 60) were open there again after ⇧⌘Q and a login, with Files' windows. Not tried: a document with unsaved changes at log out; a kept document deleted before the next login. `bun test`, `bun run build` |
| 74, 2026-11-28 | 6, windows open where they were left; 26, Files' windows and tabs at login | `kit/placing.h` (a header alone): `KitPlacing placing(argc, argv, "<app id>")` before the application object adds `-session <app id>` to what Qt reads, so Qt asks KWin for that session by `xdg_session_manager_v1` (only the first process of an app does: it holds a `flock` on `$XDG_RUNTIME_DIR/<app id>.placing.lock`, because a second asking would have KWin take the session from the first, and our apps' second launches only hand over and leave); `kitPlacing(&app)` installs a filter that, as a window's platform surface is made (before its `xdg_toplevel`), reads its `frameName` property and gives Qt's private `QNativeInterface::Private::QWaylandWindow::setSessionRestoreId` the first free of that name, `name-2`, `name-3` (two live windows of one name end the app by the protocol), told back in `framedAs`; it does nothing off Wayland, without Qt's private headers (`Qt6::GuiPrivate`, looked for quietly in each CMakeLists), or under a Qt of another major.minor than it was built with. `frameName: "main"` on the windows of Settings, Notes, Calculator, Activity Monitor, Font Book and Disk Utility. Files: `App::makeWindow` names windows `window`, `App::remember` (called by `FinderWindow.keepWatch`: url, view, columnRoot, tabAt, tabs) writes `files-windows.json` 400 ms later from each window's `kept()`, `App::restore` at the start of the process opens them (`takeKept`), dropping tabs `stillThere` refuses; `FinderWindow.shut()` marks a window closed by the user (the light, ⌘W, the menu), and one closed otherwise (the session ending) stays in the file until a new window opens or two minutes pass; a launch naming no folder opens a window only if none came back. `session/xdg/ksmserverrc`: `excludeApps=org.ambrosia.files.desktop` | In the test VM, dev builds on r599: Calculator moved to (300, 500) by a KWin script and killed opened there again; Files with two windows, one of two tabs (a list and columns), moved to (60, 60) and (900, 500): the same two, tabs, views and places, after `systemctl --user restart ambrosia-files` and after ⇧⌘Q and a login (a third window came with Plasma's own restore until Files was excluded from it); a window closed by ⌘W wasn't in the file; one closed by KWin stayed in it and left it when the next window opened, which took its name and place; a window searching in a folder was kept as the folder, and not opened once the folder was deleted. From the packages (r602): Notes moved to (150, 120) and quit opened there again, Calculator at (300, 500) as left; Files' two windows, moved, were at (60, 60) and (900, 500) after ⇧⌘Q and a login, with Plasma's restore starting Notes again and not Files. After `systemctl reboot` with the windows open (no log out) Files' windows and tabs came back but stepped from the middle: KWin had not kept their places on its way down. `bun test`, `bun run build` |
| 73, 2026-11-28 | 12, the green light enters full screen | `decoration/src/button.cpp`: the zoom light's click is taken from KDecoration's maximize (`disconnect` of `clicked` from the decoration) and goes to `zoomOrFill`: the frame's parent is KWin's window, whose `fullScreen` property (the one scripts use) is toggled; with Option down at the release (`mouseReleaseEvent`), or with no such property, `requestToggleMaximization`. Each app's `TrafficLights.qml` (Files, TextEdit, Notes, Preview, Font Book, Disk Utility, Activity Monitor): `showFullScreen`/`showNormal`, the zoom with `Qt.AltModifier` from the tap; their Window menus gain Enter/Exit Full Screen; Files' frame is square while `full`. Shell: `Apps.activeFullScreen` and `fullScreenOn(screen)` (TaskManager's `IsFullScreen` and `ScreenGeometry` of the window in front); `MenuBar.qml` and `Dock.qml` hide as they do when told to hide always, on the Overlay layer, while it holds (the bar gives up its exclusive zone then: kept, it pushed the window 28 down); the shell's own Window menu says Exit Full Screen | In the test VM, the frame, the shell's files and dev builds of Files and TextEdit over r596: Konsole's green light filled the screen (0,0 1920 by 1200), the pointer at the top brought the menu bar with Terminal's menus and at the bottom the Dock; ⌃⌘F gave the window's size back; ⌥-click zoomed it (0,28 1920 by 1082). Files' green light: the whole screen, every corner pixel the content's color, the light again gave 920 by 580 back, ⌥-click zoomed. TextEdit the same; Window ▸ Enter Full Screen from the bar brought down over it filled the screen and the row again gave it back. From the packages (r599, 2026-11-28): Konsole's green light filled the screen, the bar came down at the top, ⌃⌘F gave its size back; Files' light filled the screen and gave 920 by 580 back. Not seen: two screens, the Dock at a side, a menu bar set to hide always or never, Light |
| 72, 2026-11-28 | 26, Files: Compress's progress; Hide Sidebar, the path bar and the status bar | `CompressJob` in `files/src/expand.cpp` (a `KJob` beside `ExpandJob`: the items walked on a thread into a `KZip`, folders written as entries so an empty one is kept, hidden files in, links as links, a file a megabyte at a time so its bytes count and a stop lands partway; `KZip` writes to a file with no name until it is whole, then it takes the zip's name), which `FileOps::compress` hands to the jobs model as "Archive Utility"; `Prefs.sidebar`, `pathBar` and `statusBar` (files.conf; the path bar now off until asked for), `FinderWindow.sidebarShown`, `pathBarShown`, `statusBarShown` and `footer`, a `TrafficLights` of the window's own for when the sidebar is away, `StatusBar.qml` with `App::roomOn` (QStorageInfo, two places past a gigabyte); View ▸ Hide Sidebar, Show Path Bar, Show Status Bar; `packaging/keyd/command-control` names ⌃⌘S (Meta+Ctrl+S; unnamed it would be ⌘S) | In the test VM, dev build: a new window had no path bar; ⌥⌘P and ⌘/ brought the path bar and under it "1 of 120 selected, 30.63 GB available", both kept in files.conf; ⌃⌘S (through keyd with the new layer file) took the sidebar away, lights and toolbar at the left, and brought it back; Compress 9 Items on 900 MB showed "Compressing 9 items, 689.1 MB of 900 MB, About 5 seconds" and made Archive.zip holding the empty folder, the hidden file and the link as a link; stopped partway a second one left nothing; a third (1.8 GB) became Archive 2.zip. From the packages (r596, 2026-11-28): ⌥⌘P, ⌘/ and ⌃⌘S (the packaged key layer) showed both bars and took the sidebar away, and again put all three back; Compress made a zip of a folder's 120 files |
| 71, 2026-11-28 | 28, scrolling in apps that aren't ours and the shell | `kitScrolling` installs once an app whoever asks (a property on the application object), only on Qt's Wayland platform (so never in KWin itself), and `AMBROSIA_SCROLLING=off` is read there. `Style::polish(QApplication *)` calls it: every Qt app drawing with our style. `style/scrolling/` is a QML module, `org.ambrosia.scrolling` (built with the style, in ambrosia-style, which now needs qt6-declarative): importing it installs the filter, queued to the application's thread (QML loads plugins on another); the shell loads `shell/Scrolling.qml`, which imports it, through a `Loader`, so a system without the module still has a shell. `KitWidgetScrolling` in `kit/scrolling.h`: for a `QWidgetWindow`, the window's `QScrollBar`s are noted at the fingers' first move (found by class name and properties: no QtWidgets needed), and at the lift each one that moved is carried on by the fading speed times what it moved for a pixel of the fingers' way; it stops at the bar's end, or when anything else moves the bar | In the test VM, the style, the module and the shell's files from a dev build over r590, the trace on for the session: the emoji picker's grid glided from a flick and stood pulled down at its top; with the module moved away the shell came up all the same, saying it isn't installed; Konsole after `seq 1 3000`: a flick carried its scroll bar 167 lines on over 2.3 s (0.3 of a line a pixel); KDE's Shortcuts module (`kcmshell6 kcm_keys`): its list glided and stood pulled down with its scroll bar short; Files with both its own call and the style's: one list took the fingers and went as far as before. Firefox, untouched, gave at a page's top. From the packages (r593, 2026-11-28): the shell had the module loaded and the emoji picker's grid glided; Konsole's scroll bar ran 184 lines on after a flick |
| 70, 2026-11-28 | 28, scrolling | `kit/scrolling.h`: `kitScrolling(&app)` in the `main()` of eight apps installs one event filter for the app. A wheel event with a phase (a trackpad's; Qt sends a wheel's without) is taken at the window while a list has the gesture, and otherwise as Qt hands it to the first `QQuickFlickable` under the pointer with room to scroll the fingers' way, which then keeps the gesture; no Flickable sees a trackpad's event itself. The list's `contentX`/`contentY` are set on whole pixels: following the fingers (past an end by DESIGN's rubber), then from a `QAbstractAnimation` the glide (`p + v(1 − e^(−kt))/k`, k = −ln 0.998 a millisecond, over at 12 px/s) and the spring (critically damped, 0.012/ms; a glide crosses an end with 0.55 of its speed). Qt's beginning and end come twice over (an event per direction) and the second is dropped. All by properties, no Qt Quick class, so a plugin without Qt Quick could carry it. Qt's scroll bars are set `active` through the list's `QQuickScrollBarAttached`; Settings' pages have a `scrolling` property for their own thumbs. `AMBROSIA_SCROLLING=trace` logs it, `=off` leaves Qt's. `tools/fake-touchpad.py` gained `pull`, `flick` and `across` | In the test VM, dev builds, by the made-up trackpad with the trace on: Activity Monitor's table pulled 300 down at its top stood about 110 low with its scroll bar showing and went home when the fingers lifted; a flick glided 1.7 s to rest, a hard one ran 40 past the end and was back in 0.55 s; Files' list (ends −85 to 1848: its top margin counted), icons, a column and the gallery's strip sideways each glided, the list's stripes carrying on above its rows in a pull; with the pointer on the column view's preview nothing moved; the pointer moved 30 during a glide stopped it; a wheel still scrolled; Settings' sidebar, and in a window made 420 tall General and About (its own thumb showing in a pull past the end); TextEdit's 400 lines both ways; Preview's PDF down, and across and down when zoomed in; a long note in Notes. From the packages (r590, 2026-11-28): Files' list glided from a flick and a hard flick up ran past its top and came home; Activity Monitor's table glided to its end. Not seen: a real trackpad, Font Book and Disk Utility (built only), Light, two lists one inside the other going the same way |
| 69, 2026-11-28 | 21, the last Qt dialog; 26, Files' alerts over their window | Settings' `WallpaperPage.qml` plus tile calls `Colors.show(color, apply, window)` (the kit's `ColorPanel.qml`, `Colors.qml` and `screencolor.h` join Settings' module; `Preferences::chooseWallpaperColor` and its `QColorDialog` are gone); `App::tell` in Files gives the alert the focused window as `transientParent` | In the test VM, dev builds: the plus tile raised the Colors panel over Settings, a pencil clicked made the wallpaper that gray at once (the pane said Custom Color), ⌘W closed the panel and Nectar was put back; Files' Empty Trash question and a failed expansion each came up centered on the Files window in front. From the packages (r587, 2026-11-28): the plus tile's Colors panel set a gray wallpaper and Nectar was put back; Empty Trash's question stood on the Files window and emptied the Trash. Not tried: the eyedropper from Settings, an alert while a second Files window is in front of the one it is about |
| 68, 2026-11-28 | 25, Preview's Export; 26, Files' alerts | `App::exportAs` and `exportFormats` in Preview (a picture read with its turn and written by `QImageWriter` through a `QSaveFile`, JPEG flattened on white at quality 90; a PDF's page drawn by `QPdfDocument` at 150 to the inch on white; a picture as a PDF of one page its size; a PDF as a PDF copied), `PreviewWindow.exportAs`, File ▸ Export… and Export as PDF… on `Saving.show` (the name's label is the job's `prompt`, "Export As:"); `kit/AlertWindow.qml` (measured from macOS 27's alert shown behind everything by a throwaway AppKit program, with one button, with two and a secure field: 260 wide, words from 21, field 228 by 24, buttons 28 tall, 110 each 8 apart, Cancel at the left; the icon's place from Disk Utility's; its shadow drawn inside a larger see-through window so an app needs nothing else), raised from C++ by `kit/alert.h` (`kitAlert(engine, module, what, then)`); Files' `App::tell` behind `FileOps::alert`, the zip's password, Empty Trash's question and `places.cpp`'s alert (Qt's box only when no alert can be made) | In the test VM, dev builds. Files: a file that is no archive (the alert with Files' icon, OK by Return), a locked zip (Archive Utility's icon, the field, a wrong password asked again, the right one expanded), ⇧⌘⌫ (Cancel by Escape kept the Trash, Empty Trash emptied it). Preview: a PNG exported as JPEG through the Format pop-up (a JFIF of the same size) and as a PDF of one page; a PDF's page as a PNG of 1275 by 1650. From the packages (r584, 2026-11-28): a locked zip asked by the alert and expanded; Preview's Export as PDF wrote its file. Not tried: TIFF, a turned picture, a failed export's alert, an alert in Light, two alerts at once |
| 67, 2026-11-28 | 20, the small Save sheet | `kit/SavePanel.qml` and `kit/Saving.qml` (`Saving.show({ name, extension, rows, filter, save, cancel }, window)`: a frameless dialog of the window's, made anew each time, which KWin puts over its middle, as the Print panel; measured from macOS 27's small Save sheet shown behind everything by a throwaway AppKit program: 370 wide, corners 16, 145 tall bare and with an app's rows between two rules; the replace question on the panel itself; the last folder per app in `~/.config/ambrosia/save.conf`), `kit/saving.h` and `saving.cpp` (the `Places` singleton: the folders at hand, whether a name is taken, Files' whole panel by `QFileDialog` through the portal, the panel's shadow); TextEdit's `save` and `exportPdf` and Notes' `exportPdf` use it, their own `chooseSave` and `choosePdf` are gone | In the test VM, dev builds: TextEdit ⌘S on a new rich document (the sheet over the window's middle, File Format under a rule; Return saved `Untitled.rtf` in Documents and the title took the name), the same name again (asked on the sheet; Escape went back to it, another name saved; Replace not pressed), the arrow button (Files' panel with the name typed in it; its Save saved and named the window), a plain document (Plain Text Encoding; ⌘D chose the Desktop; saved with `.txt`), closing an edited new document, Save, then Escape (the document stayed), Export as PDF (the bare sheet, 145 tall; a PDF of one page), Notes' Export as PDF (saved; each app's last folder kept apart). From the packages (r581, 2026-11-28): TextEdit's ⌘S sheet saved a new document under a typed name and Notes' Export as PDF wrote its file. Not tried: Light, a folder that can't be written to, a name that is a folder, Other… under Where, two documents' sheets at once |
| 66, 2026-11-28 | 25, Disk Utility: Rename and a new blank image; Archive Utility's password | `Disks::rename` (Unmount, `Filesystem.SetLabel`, Mount again whatever came of it) and `Disks::newImage` (the file by `QFile::resize`, `LoopSetup`, then what Erase does, now shared as `Disks::make`; the loop device and the file are taken away when it comes to nothing), `Disks::roomIn`; `disks.mjs`: `parseSize`, `leastImage`, `imageFile`, `imageTrouble`, `imageSchemes`, `can().rename`; `Sidebar.qml`: one field over the row whose name is changed (outside the rows, which are built again at every read of the disks), Return or a slow click on the chosen name starts it; `Sheets.qml` mode `image`, the Save sheet measured from macOS 27's small one (a throwaway AppKit program showing an `NSSavePanel` sheet with a form in it behind everything: 370 wide, fields 26 tall from 99, names ending at 93, rules over and under the form, buttons 79 by 26); `App::places`, `chooseFolder`, `exists`; File ▸ New Image ▸ Blank Image… ⌘N, File ▸ Rename, Rename in the sidebar's menu; `--sheet image` and `rename` for grabs | `bun test` (the sizes, the file's name, what stands in the way, what may be renamed). In the test VM, a dev build: an ext4 image of 100 MB on a GUID map made in Documents, mounted and owned by the user; renamed in the sidebar (mount point follows); a FAT image with no map (name in capitals) renamed; an ExFAT one on a map made with no second password and renamed; a rename refused while a shell stood in the volume (said so, still mounted); a size too small said under the form with Save off; a name already open refused, one that exists asked about (Cancel returns to the sheet as left, Replace goes on); the password prompt dismissed left no file; Where set from Files' folder panel; Tab from field to field selecting each; the system's volume not renamed; the File menu's rows read. Archive Utility's password: `ExpandJob` takes one (`archive_read_add_passphrase`) and fails `locked` when a zip wants one it wasn't given or the right one; `FileOps::expandOne` asks (a `QInputDialog`, password echo) and tries again. In the VM, a dev build of Files: an AES-256 zip of a file and a folder (bsdtar's) asked, a wrong password asked again, the right one expanded both; a classic-encrypted zip of one file likewise; Cancel left nothing and said nothing; a plain zip as before. From the packages (r578, 2026-11-28): a 30 MB ext4 image made by ⌘N with the fields reached by Tab, its volume renamed in the sidebar and ejected by ⌘E; an AES zip asked for its password and expanded. Not tried: Btrfs, XFS or NTFS images (their tools aren't in the VM), an image larger than the room left, a real disk's volume, Light (a forced-Light grab draws the pop-ups in the session's Dark) |
| 65, 2026-11-28 | 26, Files' tabs; 10, the About panel's light | `files/qml/TabBar.qml` (the strip, one MouseArea for every tab so a press lives through the tabs being drawn anew, `preventStealing` so a drag along the bar isn't the window's move; a DropArea that brings a tab forward after 0.7 s and hands a drop to `dropOn`), in `FinderWindow.qml` the tabs as snapshots (`tabs`, `tabAt`, `tabState`, `takeTab`, `showTab`, `newTab`, `closeTab`, `moveTab`, `tabToWindow`, `tabMenu`): the window's own properties are the tab in front, the others are kept as they were left and their folder read again when shown; `open(row, modifiers)` from every pane; `Finder.tabStrip` pushes the view and the scope bar down; File ▸ New Tab, Close Tab/Close Window, View ▸ Show Tab Bar (⇧⌘T), Window ▸ Show Previous/Next Tab, Move Tab to New Window; `SearchField` hands ⌃Tab on. `session/xdg/kwinrulesrc`: a rule by the About panel's zero-width title that forbids minimizing it, which dims its yellow light | `bun test` (173), `bun run build`. Measured from macOS 27.2.1 in Dark: the system's window tab bar on tabbed windows of a program of our own, behind everything: capsule 28 tall from 8 in under a 52 toolbar, the tab in front 24 tall 2 in, hairlines 16 tall, names in 11 centered, the plus on a disc 28 across 8 from the right, 8 of ground under the capsule. VM, dev build: ⌘T made a second tab and the bar; ⌘↓ into Documents named the tab; ⇧⌘[ ⇧⌘] ⌃Tab ⇧⌃Tab stepped; a selection was still there on return; the plus, a tab dragged from third to first (the window stayed where it was once the bar kept its drags), the tab's menu, Move Tab to New Window, ⌘W closing the tab then the bar gone with one tab, ⇧⌘T showing it for one; ⌘-click on a sidebar place and Open in New Tab; a file held over a tab brought it forward and the drop moved it into that folder; icons, columns, gallery and a search's scope bar under the strip; a search still there after ⌃Tab away from its field and back; the close button; Light. VM, from the packages (r574): ⌘T and ⇧⌘O made a Documents tab, ⇧⌘[ and ⌃Tab stepped between the two; About Files from the app menu came up with its yellow and green lights gray and the red one lit. Not seen: 2x, a tab on a disk that was ejected, twenty tabs |
| 64, 2026-11-28 | 21, printing | `kit/PrintPanel.qml` and `kit/Printing.qml` (`Printing.show({ title, make(file, size), save }, window)`, or `{ title, file }` for a PDF as it is: a frameless dialog of the window's, made anew each time, which KWin puts over its middle), `kit/printing.h` and `printing.cpp` (the `Cups` singleton: printers by `cupsGetDests2`, a printer's papers and the sending by CUPS's destination calls, off the main thread; the pages' pictures `image://printing/ID/PAGE` drawn by Qt's PDF library; scratch files in a folder gone with the app; the shadow by the app's own `makeShadow`); File ▸ Print… ⌘P in TextEdit (`EditorWindow.printOut`), Notes (`NotesWindow.printOut`) and Preview (`PreviewWindow.printOut`; `App::picturesPdf` puts pictures on pages); `Editor::exportPdf` takes the paper's size in both editors and lays the text out for the page itself, so Qt no longer numbers the pages (it did in every exported PDF); the three packages depend on `libcups`, TextEdit's and Notes' on `qt6-webengine` for the PDF library | `bun test` (173), `bun run build`. Measured from macOS 27.2.1 in Dark: AppKit's print sheet on a window of a program of our own, behind everything: 780 by 373 with corners of 16, the pages 190 wide from 20 in a column 247 wide, boxes 493 wide from 267 with rows 43.5 apart, fields 60.5 by 24, buttons 70 by 24 with corners of 6 at 330 down, the capsule 30 tall 14 above a page's foot; one page reads "All Pages", more "All 2 Pages". VM, dev builds, against a cups-pdf queue and an `ippeveprinter` added by address: ⌘P in TextEdit raised the panel centered over the document, six pages drawn; US Letter then Landscape made the pages anew each time (792 by 612); a range of 2 to 3 dimmed the others and the job came out as two pages; two copies of a three-page PDF from Preview came out as six pages; a picture took the turned paper whole; a note printed from Notes; Open in Preview opened the PDF under the note's name; PDF went to the app's Export as PDF; the IPP printer listed its five papers only and a job sent as A4 arrived as A4; a queue rejecting jobs said so in the panel; ⌘W and a click on the window behind did nothing, ⌘. and Escape closed it; Printers & Scanners Settings… opened Settings there; seen in Light and Dark. VM, from the packages (r571): ⌘P in TextEdit, the printer's menu with its check mark, the PDF printer chosen, three copies of pages 1 to 2 came out as six A4 pages and the printer was kept for next time; Preview's and Notes' panels came up on ⌘P; nothing logged. Not seen: a real printer, a printer found and never added (the VM's CUPS could not make its queue: `lp` failed too), two documents with a panel each, a locked PDF, 2x |
| 63, 2026-11-28 | 21, the Colors and Fonts panels | `kit/ColorPanel.qml` and `kit/Colors.qml` (`Colors.show(color, apply, window)`: one panel for the app, each color chosen told at once; the wheel by a conical and a radial gradient, bars painted by a Canvas, slider rows that stay while the color changes under a held knob; the way, the kind of sliders, the list and the kept colors in `~/.config/ambrosia/colors.conf` for every app), `kit/screencolor.h` (the eyedropper: KWin's `org.kde.kwin.ColorPicker.pick`), `kit/FontPanel.qml` and `kit/Fonts.qml` (`Fonts.show(source, font, apply, window)`; a name the system only answers to is shown as the family standing in for it); TextEdit: Format ▸ Font ▸ Show Fonts ⌘T and Show Colors ⇧⌘C, `EditorWindow.applyFont`, `applyColor`, `tellPanels`; its Settings' Change…; Preview's Settings' background color. Both panels belong to the window that asked (they stay over it) and claim ⌘W before shortcuts are looked at: as a Shortcut the key went to the document's Close in turn | `bun test` (173), `bun run build`. Measured from macOS 27.2.1 in Dark: NSColorPanel in five of its ways and NSFontPanel, raised behind every window by a program of our own (no app of Justin's opened): 266 wide, ways on 44 by 25 fills, the wheel 177 across, bars 21 tall and 46 apart with figures 48 by 22, the well 32 by 28, swatches 17 square 19 apart, the list's rows 20, pencils 40 apart; Fonts 470 by 270, family rows 32 with tiles 26, typeface rows 30, the bar 38. VM, dev builds: ⇧⌘C in TextEdit raised the panel over the document; a click on the wheel colored the selected word; the sliders page showed its red, green and blue with the hex; the lists and the pencils drew as the Mac's; the eyedropper took the wallpaper's purple; a click on an empty swatch kept it (read back from `colors.conf`) and Preview's panel showed it too; in Preview's Settings a pencil chosen was the window's ground at once, Reset put it back; ⌘T opened Fonts on Inter Variable for Helvetica with Regular chosen; JetBrains Mono, Light Italic and 24 typed each changed the selection (the format bar said so); Settings' Change… kept Inter Display 14; ⌘W closed each panel and not the document, with a field focused too. VM, from the packages (r568): ⌘T, a family chosen, then ⌘B pressed with the panel in front made the selection bold and the panel moved to Bold; ⌘W closed the panel alone; ⇧⌘C and a pencil colored the selection. Not seen: the panels in Light, two documents taking the panel in turn, the CMYK and gray sliders used, a search in either panel, a color typed as figures |
| 62, 2026-11-28 | 25, Notes' leftovers | `notes/qml/FindBar.qml` over the note (`NotePane`), `Editor::find`, `count`, `replace`, `replaceAll`; Edit ▸ Find with a Mac's seven items and keys (Note List Search… ⌥⌘F, Find… ⌘F, Find and Replace… ⇧⌘F, Find Next ⌘G, Find Previous ⇧⌘G, Use Selection for Find ⌘E, Jump to Selection ⌘J; the names and keys read from macOS 27's menu); a row of the list dragged onto a folder of the sidebar (`NotesWindow.dragged`, `Sidebar.folderAt`; onto Recently Deleted deletes, out of it recovers); `Store` watches its directories and says `changed`, `NotesWindow.sync` compares each file's time with what it listed (also when the window comes forward) and reads only what differs, the note being typed in staying as it is here; a monostyled paragraph with marks is a `<code>…</code>` line (Markdown reads marks inside it; between fences it would not), one test more | `bun test` (173), `bun run build`. VM, dev build: ⌘F and a word chose it in the note and said "1 found"; ⇧⌘F, a replacement and Return changed it in the file; a letter found six times, ⌘G stepped, All replaced all six and one ⌘Z put them back; Escape closed the bar from the field and from the note; ⇧⌘M on a bold italic line wrote `<code>x***marked***</code>` and it read back monostyled, bold and italic after a restart; a file written into another folder from outside raised that folder's count at once, the open note's file replaced from outside showed its new text, its file removed took the row away and opened the next; a note dragged onto Work moved there (its file too), the folder ringed and the note's name beside the pointer on the way, a drag let go elsewhere moved nothing; the folder's right-click menu renamed it, a fixed folder's has New Folder alone. VM, from the packages (r565): ⌘F through the packaged keyboard layer found a word ("1 found"); a note made from outside was counted in its folder at once; a note dragged onto a folder moved there. Not seen: a drag onto Recently Deleted, a file changed in place, the bar in Light, a Mac's own Find bar |
| 61, 2026-11-28 | 25, Notes | `notes/` (ambrosia-notes, `org.ambrosia.notes`, package of its own, pinned to a new user's Dock): `qml/notes.mjs` (a note as paragraphs of one kind each; the file, Markdown with a line a paragraph under its dates, read back exactly as written; a note's name and the line under it; the list's sections; folders; searching; 22 tests in `notes.test.ts`), `src/editor.cpp` (keeps the TextEdit's document a note: each paragraph's kind, level, check and quote in its format, every character dressed as its kind after any change, the marks beside the text told to QML, which draws them; paragraphs to and from the clipboard; a PDF), `src/store.cpp` (folders as directories, a note a file, written whole or not at all), `NotesWindow`, `Toolbar`, `Sidebar`, `NoteList`, `NotePane`, `FormatMenu`, `SettingsWindow`, `Look.qml` (the Mac's measures); the kit's Settings window has no strip of tabs when it has one page; icon `notes` in `design/icons.ts`; `packaging/keyd/command-shift` passes ⇧⌘H and ⇧⌘M on to the app (they fell to ⌘H and ⌘M and reached nothing) | bun: 172 tests. macOS 27.2.1 Notes in Dark, behind other windows, by frames and runs of color only (no note was read): columns 228, 280 and the rest under a bar of 52, round buttons 36, sidebar rows 32, list headings 40 and rows 56, the Format menu 178 wide. VM, dev build over a store of sample notes: the window's rows, name, count and marks land where the Mac's do (row text 14 and 30 down, list fill 10 in); typing is written half a second later; ⌘N then a title, Return and body; "- " starts a dashed list and Return in an empty item ends it; ⇧⌘L makes a checklist and a click ticks a ring; Numbered List from the Format menu; searching finds one note of ten; ⇧⌘N makes a folder and names it in place; Delete in the list moves a note to Recently Deleted with its date and folder, Recover puts it back; Pin Note; deleting a folder with a note in it asks first; ⌘, opens Settings; ⌘B types bold; every Format chord (⇧⌘T H J B M 7 8 9 L U and ⌘') changes the line, read back from the file; ⌘Q. Light by an off-screen grab. VM from the packages (r561, then r562 with the fix): Notes starts on no notes at all and says so; ⌘N, a title and a dashed list; ⌘] and ⌘[ move an item a level in and out; ⇧⌘H through the packaged keyboard layer; two lines pasted from outside come in as two paragraphs of text; a whole note copied into a new one keeps every paragraph's kind; B and I from the Format menu; Export as PDF writes the note (read back with pdftotext); Move to from the list's menu moved nothing at first (inside the submenu's items `menu` was the item's own property, not the list's menu): fixed, and seen moving a note to a folder and back with its own folder grayed; Preview's Settings still has its tabs. tenet: r562 installed, locked, nothing run there. Not seen: a store of thousands of notes, a note changed on disk by another program, the Sidebar's Rename and Delete from its menu (by key and in place they were), 2x |
| 60, 2026-11-28 | 25, Disk Utility | `disk-utility/` (ambrosia-disk-utility, `org.ambrosia.diskutility`, package of its own; the default for ISO and raw disk images in `session/xdg/mimeapps.list`): `src/disks.cpp` (UDisks2 over the system bus read into plain maps; Mount, Unmount, Lock, Unlock, Check, Repair, Format, CreatePartitionAndFormat, LoopSetup, Loop.Delete, PowerOff and Eject, each UDisks2's own method with polkit asking when its rules say so), `qml/disks.mjs` (the disks and their volumes, the sidebar both ways, a page's words, bar and table, what each button may do, the Info rows, a name each file system can carry; 23 tests in `disks.test.ts`), `DiskUtilityWindow`, `Toolbar`, `Sidebar`, `DiskPage`, `DiskIcon`, `Sheets` (Erase, the First Aid alert, the password, the sheet that stays while a job runs), `InfoWindow`, `Look.qml` (the measures); its icon in `design/icons.ts`. | `bun test` (150), `bun run build`. Measured from macOS 27's Disk Utility in Dark, in the background: a volume's page and a disk's, Show Only Volumes and Show All Devices, the Erase sheet, the First Aid alert and the Info window (the Erase and First Aid sheets were opened on an external volume and cancelled by name). VM, dev build: the system's volume with everything but Info gray; a blank 300 MB image opened (the shell's password prompt for the loop device), shown as an uninitialized disk; Erase with GUID and ext4 made "Untitled", mounted and chosen, the steps under Show Details; First Aid asked, unmounted, verified and mounted again; Get Info's window; Unmount and Mount; every device listed with the disk's page (EFI and the system's volume along the bar); the eject mark detached the image; an encrypted image listed locked, a wrong password told, the right one mounted it under its own name as "ext4 (Encrypted)", Unmount locked it again; a loop disk with a device-mapper target on it had Erase, Mount, First Aid and its eject mark gray; Light by an off-screen grab. VM, from the packages (r558, which bring dosfstools and exfatprogs): the image opened as Files opens one (the default app), its volume mounted and chosen, the menus in the menu bar and the icon in the Dock; Erase as MS-DOS (FAT) made `PHOTOS2026X` of "Photos2026x", First Aid passed on it, Erase as ExFAT, ⌘E detached the image, ⌘Q quit. Not seen: a real USB disk or card (power off, a busy volume's refusal), a failing check and Repair, Master Boot Record, an optical disc, LVM, NVMe's S.M.A.R.T., erasing a system device's other partition (polkit's administrator prompt), the legend past three parts, a disk under LVM, RAID, ZFS or a Btrfs set (their protection is tested in `disks.test.ts` only), 2x |
| 59, 2026-11-28 | 25 and 10, Preview's Settings; a key that opened the wrong thing | `preview-app/qml/SettingsWindow.qml` (the kit's window at 500: General, Images, PDF, rows placed by the Mac's measures), `qml/Prefs.qml` (`~/.config/ambrosia/preview.conf`: ground, separate, printout, lastPage and where each PDF was left), read by `PreviewWindow` (the ground), `Main` (`View.groups(…, separately)`), `PdfView` (⌘0 through `View.printScale`; the page it was left at); `kit/PrefRadio.qml`, `kit/PreferencesWindow.qml` (`wide`, two more glyphs); **`kit/firstshortcut.h`**, called first thing in all seven apps: Qt's platform menu items keep -1 for "no shortcut", which is also the number of an app's first shortcut, so the menu item that took it was never struck off when its window closed and another item built in its place answered the key | Measured from macOS 27's Preview Settings in Dark, in the background (three tabs). VM, dev build: the window on ⌘, with each tab as the Mac's; a PDF left on page 3 reopened there; ⌘0 gave a page 612 wide with "1 point equals 1 screen pixel" and a wider one as printed; two pictures opened in two windows with "each file in its own window"; a color picked for the background showed in every window at once, Reset put it back. The fault: in a PDF window opened after the first was closed, ⌘, opened About on every other press; with the fix, Settings three times of three. VM, from the packages (r554): Preview's Settings on ⌘,; a PDF closed and opened again, then ⌘, twice from it: Settings both times; the same in TextEdit with a second document: Settings both times, never About; Font Book starts. Not seen: the same sequence in Files (same cause, same fix), a real screen's density, the color panel in Light, 2x |
| 58, 2026-11-28 | 25, Font Book | `fontbook/`: `src/library.cpp` (the `Library`: fontconfig's list through a configuration of its own, families with their styles, what each can write and its languages; FreeType for a file's names, glyph count and embedding; install into `~/.local/share/fonts`, remove to the Trash, a watcher on the folder; `Repertoire`, a model of every character a face draws), `qml/fontbook.mjs` (the sidebar's places, what each lists, search, the letters and line that stand for a typeface by script, the info pane's rows, collections; 31 tests), the window (`FontBookWindow`, `Sidebar`, `Toolbar` with `Segments` and `SizeSlider`, `GridPane`, `SamplesPane`, `ListPane`, `TypefacePage`, `InfoPane`), `FontFileWindow` (a font file's preview with Install), menus and About from the kit; `design/icons.ts` (Font Book's icon, a font file's page); `packaging/PKGBUILD` (ambrosia-fontbook); `session/xdg/mimeapps.list` (font files open in it); `kit/PrefPopup.qml` (`below`: a long menu drops under its button) | Measured from macOS 27's Font Book in Dark, in the background (the three views, a page, the info pane with its four parts open, a font file's preview). VM, dev build: the grid, samples and list as the Mac's; a card chosen and opened to its page; the styles' menu; the page's samples with the info pane; a typeface opened to its styles in the list; a font file (Amiri Bold) opened to its preview, installed (the file in `~/.local/share/fonts`, its page shown in its own face, its names read), found under My Fonts, removed after the alert (the file in the Trash); a collection made by ⌘N, named, filled from a card's menu, listed and kept; search; Light; a narrow window with the sidebar hidden. From the packages (r551) in the VM: it is the default for font files, a font opened through KDE's opener came up in its preview, installed and showed its page, was removed to the Trash; the About panel; its icon in the Dock. Outside a desktop session `xdg-open` knows a `.ttf` only as what `file` calls it and hands it to the browser: `font/sfnt` is now among Font Book's kinds. Not seen: a font with several files removed, a `.ttc`, a Type 1 font, a second language in the sidebar, a drop of files on the window, a double click on a font in Files, 2x |
| 57, 2026-11-28 | 25 and 10, TextEdit's Settings; a window brought forward from the menu | `textedit/qml/SettingsWindow.qml` (a Mac's by measure: 439 wide, the box with its two tabs astride its top edge, bold headings, Restore All Defaults; only what our TextEdit does, so the box ends sooner) over `textedit/qml/Prefs.qml` (a singleton over `~/.config/ambrosia/textedit.conf`, QML's own `Settings`): a new document's format, its window's width in characters and height in lines (`Prefs.windowSize`: the Mac's measured sizes at 96 by 30, in proportion otherwise), the plain and rich fonts (Change… opens the platform's font panel), the ruler, RTF shown as its code, ".txt" added to a plain document's name, the encoding plain text is read and written in (`App.read`/`App.write`: UTF-8, UTF-16 with its mark, Latin 1, or the file's own). TextEdit > Settings… and ⌘,. `session/kwin-scripts/ambrosia_forward`: a window KWin marks as wanting attention is activated when the active window is its own app's | Mac: TextEdit's Settings captured in Dark, both tabs (439 by 676; box 22 in from 65; tabs 24 tall; rows read off the pictures to a point). Test VM, dev build copied in, script loaded by hand: the window as the Mac's; Plain text and a width of 60 gave a new plain window 434 wide; RTF as code showed Notes.rtf's code; saved as UTF-16 the file began ff fe; Change… opened the font panel and "Hack 10" was taken; the ruler gone from a new rich document; Restore All Defaults put all back; ⌘, brought the window forward from behind a document, and so did Settings… from the menu once the script was loaded (not before). From the packages (r548, the VM restarted): both scripts loaded at login, and Settings… from the menu brought the window over a document. The ⌘Tab switcher says Terminal for Konsole (a leftover of round 54, seen now) |
| 56, 2026-11-28 | 26 and 10, Files' Settings; a lit window under the shell's menus | `kit/PreferencesWindow.qml` (a Mac's Settings window: a strip of tabs, each a glyph over its name, the page under it, as tall as the page asks), `kit/Preferences.qml` (shows the app's one, `Preferences.show("Files", "SettingsWindow")`), `kit/PrefCheck.qml` and `kit/PrefPopup.qml` (its menu is the platform's, drawn by our widget style, with the current row over the button). `files/src/prefs.cpp` (`Prefs`, over `~/.config/ambrosia/files.conf`; the 30 days are KDE's own `ktrashrc`), `files/qml/SettingsWindow.qml` (General, Sidebar, Advanced). Read by: `Places::sections` (which items; Movies, Music, Pictures are new), `foldermodel.cpp` (folders on top when by name), `FileOps::emptyTrash` and `sweepTrash` (run by `App` a minute after start, every six hours, and when turned on), `FinderWindow` (⌘N, the extension warning on rename through `PanelAlert`'s new second action, the search's first scope). `session/kwin-scripts/ambrosia_anchor`: a window nobody else can resize keeps its top left corner when it resizes itself (KWin 6.8 grows it around its middle), moved up only to stay above the Dock. `shell/MenuBar.qml` holds a `QsMenuOpener` on the app's own-name menu while anything is open over the screen; each app's `MenuBar.qml` sets `shellOpen` from it | Mac: Finder Settings measured in Dark (377 wide; bar 32, strip to 88, tabs 48 tall with corners of 8; checkboxes 16 at 28, 26 apart; the Sidebar tab's 14 at 41, 28 apart, titles 32.5 under and 22.5 over; pop-ups 24 tall). Test VM, dev build of Files and the shell's `MenuBar.qml` copied in: ⌘, opened the window; each tab, the window keeping its corner with the script loaded (without it the top moved up 230); a new window's folder set to Documents and ⌘N opening it; Movies added and Recents taken out, an open window's sidebar following; folders on top in a mixed folder; `hi.txt` renamed to `tt.md` asked, Return kept `.txt` under the new name, "Use .md" changed it; a search starting in the folder; the Trash emptied by ⇧⌘⌫ without asking once the warning was off (first press); an item whose record said 40 days ago swept, two fresh ones kept. Lights: lit under the app menu and a status item's menu, gray again with Calculator in front, after each of five ways of opening and closing. From the packages (r545, the VM restarted): the script loaded at login, ⌘, opened the window, the corner held across the three tabs, the pop-up's current row came up over the button. Not seen: Light, 2x, a disk plugged in with "External disks" off, the other five apps' lit windows (same lines, built by the packages) |
| 55, 2026-11-27 | 10, our apps' app menu and About | `kit/AboutWindow.qml` and `kit/About.qml` (a singleton that shows the one panel), one source compiled into each of the six apps (`../kit` in each `CMakeLists.txt`, by `QT_RESOURCE_ALIAS`); each app's `MenuBar.qml` starts with a menu titled with the app's name holding About. `shell/AppMenu.qml`: a top-level menu whose title is the app's name is `lifted.own`; `MenuBar.appNameMenu` shows its rows first, and it is no title of the bar's. `shell/Apps.qml`: a window with no menus takes those of another window of its app. Files: `FileOps.emptyTrash` (asks, `KIO::emptyTrash`, the sound) and `trashEmpty` (KIO's `trashrc`, watched) | Mac: the panel measured from macOS 27 TextEdit's (284 by 204, icon box 66 at 39, baselines 126.5, 147, 168, 181). Test VM, dev builds of the six apps and the shell's files copied in: TextEdit's, Files', System Settings' and Activity Monitor's app menus (no second title of the app's name), About TextEdit and About Activity Monitor (measured against the Mac's: 284 wide, baselines within a point), the bar keeping TextEdit's menus with the panel in front; Empty Trash… asked, emptied the Trash, and was grey after; ⇧⌘⌫ through keyd opened the same confirmation (twice before that it did nothing, with keyd sending the right keys: not explained, focus suspected). Calculator's panel came out light under a dark frame from the first packages (it alone never tells the theme the appearance): the panel reads the system's appearance itself now, seen dark, and light after a live switch. From the packages (r542), after a fresh login in the VM: Calculator's menu and its panel in Dark, Preview's menu. Installed on tenet. Not seen: the panel at 2x |
| 54, 2026-11-27 | 25, Archive Utility and the stand-ins' names | `files/src/expand.cpp` (`ExpandJob`, a KJob over libarchive on a thread: the archive's kinds named one by one, entries put under a hidden work folder beside the archive with paths made safe (no `..`, no absolute, nothing through a link), `__MACOSX` dropped, then the one item or the folder given a free name under a lock; bytes read reported, stopped by a flag); `FileOps.expand`, `App.Expand` on DBus, `App.expands` (the kind's app is ours), `ambrosia-files --unarchive`, `FinderWindow.open`; `files/org.ambrosia.archive.desktop` (NoDisplay, the archive kinds) and `session/xdg/mimeapps.list`; the archiver icon answers to `org.ambrosia.archive`. `files/src/main.cpp`: `setQuitLockEnabled(false)`, so the resident Files outlives its jobs. `session/startambrosia` makes renamed copies of the stand-ins' own desktop entries at login from `session/mac-names` into `~/.cache/ambrosia/xdg/applications`, first in `XDG_DATA_DIRS` (the shipped copy of Konsole's entry is gone) | Test VM, dev build of Files copied in. By command (`--unarchive`): one item, the same three times (`notes.txt`, `notes 2.txt`, `notes 3.txt`), several (`many`, `many 2`), a tarball's folder, a lone `.gz`, a Mac's zip without `__MACOSX`, 7z, an entry with `../..` and one written through a link both refused, no work folder left, Files still running after. In the window: a double-click put the item beside the archive, selected; a fake zip and an encrypted one each gave an alert; 900 MB showed the progress window (Archive Utility, amount, time left), Stop left nothing, unstopped made `big 2.bin`; Open With lists Archive Utility (default) and Ark; `kioclient exec` expanded one. From the packages (r537), after a fresh login in the VM: the three renamed entries made in `~/.cache/ambrosia/xdg/applications` (actions' names untouched), Search finding Screenshot and System Information, Terminal still Terminal; an encrypted zip refused in our words; `many.zip` into `many`; Open With with the archiver's icon. Installed on tenet. Not seen: rar, cpio, lha, cab, xar; a zip with non-UTF-8 names; a read-only folder; a full disk |
| 53, 2026-11-27 | 10, the app menu | `packaging/quickshell/dbusmenu-source.patch` (pkgrel 6): `DBusMenuItem.loadedChildren`, a menu's rows as the app has sent them, read without opening it (a `QsMenuOpener` tells the app its menu opens, and our own apps count theirs). `shell/AppMenu.qml` finds the app's About, settings and Quit among the rows right under its titles (`lifted`); `MenuBar.appNameMenu` shows them as About (name), Settings… (with the app's own shortcut) and Quit, each choosing the app's row; `MenuView` leaves those rows out of the app's menus (`lifted`, handed over by `Overlay.qml` from its own bar) and draws a terminal's shortcuts by the terminal's keyboard (`Apps.keyLayer`, from `KeyLayer.qml`: Ctrl+Shift as ⌘, a Ctrl without Shift as ⌃). The app's Help is drawn after our Window (`appHelp`); the arrow keys walk Go before Window, as drawn. `tools/gen/targets/kde.ts`: kdeglobals `[Shortcuts] Preferences=Ctrl+,`; `session/xdg/konsolerc` keeps Konsole's on Ctrl+Shift+, | Mac, the stand-in shell (`make shell-shots`, sample menus with Quit, Configure Kate… and About Kate added): the app menu and File without Quit, light and dark. Test VM, new Quickshell and the shell's files copied in: Konsole's app menu (About Terminal, Settings… ⌘,, Quit), Shell's chords ⌘N ⌘T ⌘W, Settings and Help without the lifted rows, the bar's order; Settings… and ⌘, (through keyd) opened Konsole's settings; Kate: the same rows, ⌘, opened its settings, About Kate its About, Quit Kate ended it; Files: ⌘N and its menus unchanged. From the packages (r537, Quickshell pkgrel 6), after a fresh login in the VM: Terminal's app menu and the bar's order. Installed on tenet. Not seen: a GTK or plain Qt app's rows, two screens, a status item's menu while a terminal is in front |
| 52, 2026-11-27 | 25, Terminal | Konsole dressed, not replaced: `session/konsole/ClearDark.profile` and `ClearLight.profile` with their `.colorscheme`s (macOS 27 Terminal's two default profiles, read from its stored settings with `defaults export com.apple.Terminal`: 120 by 30, every color, 95% and 93% backgrounds), `session/xdg/konsolerc` (the profile follows the system's appearance; a new window takes the profile's size; tabs when there are two, sharing the width), `session/konsole/konsoleui.rc` and `sessionui.rc` (Konsole 26.08's own, taken out of its library, with the menus as Terminal's and both toolbars hidden; installed where their higher number makes Konsole take them), `session/applications/org.kde.konsole.desktop` (the name Terminal, from `/usr/share/ambrosia/xdg`, which `startambrosia` now puts first among the data folders), a step in `startambrosia` dropping Konsole's remembered toolbars once, and in the frame (`decoration/src/decoration.cpp`) a title without the app's own name after its last dash, for every app that adds it (Konsole, Kate, Firefox) | This Mac's Terminal measured in the background (a script printing the sixteen colors and a line of letters; its cell 7 by 15 points) and its profiles decoded. Test VM, the files copied in: the colors, size and title format; the menus in the menu bar once the two layout files were taken (a comment holding the word "version" before the attribute made KDE's reader pass the file over; a menu named `file` kept KDE's title File until it said `noMerge`, and one named anything else went after View). From the r532 packages there, logged in afresh: Search found Terminal by that name, Return opened it 120 by 30 with no toolbar, the title "mina — bash", the sixteen colors as the profile has them, the menu bar reading Terminal, Shell, Edit, View, Settings, Help; the system switched to Light with the window open, which turned to Clear Light at once, and back. Not seen: a second tab, the blur through the background, a user with Konsole settings of their own from before (the remembered toolbars are dropped at the next login), a remote title, 2x, the title trimmed on Kate or Firefox (the rule was compiled and seen on Konsole only) |
| 51, 2026-11-27 | 25, Activity Monitor | `activity-monitor/`: `src/sampler.cpp` (the `Sampler`: /proc/PID's stat, statm, each thread's status, io and fd, kept between readings to make rates; the kernel's threads folded into kernel_task; names past the kernel's 15 letters from the file run or the first argument; the launcher's apps by the file each runs, through KService, for a name and icon; every TCP connection's counters from the kernel's socket diagnostics over netlink, credited to the process whose open files hold the socket; logind's blocking inhibitors; /proc/stat, meminfo with zram, pressure, diskstats for whole disks, net/dev; one process in full and its open files for the inspector; `kill`, or `pkexec kill` for another user's), `qml/monitor.mjs` (the tabs' columns, a Mac's ways of writing bytes, counts, processor time and bit rates, which processes a view keeps, the search, the order, the processor's shares, memory's parts and pressure, rates and graph tops; `monitor.test.ts`, 7 tests), `qml/MonitorWindow.qml` with `Toolbar`, `Tabs`, `Table` (a screenful of rows that show whichever process stands at each place, so a reading changes words without the view moving), `Panel`, `StatRows`, `Graph` (a Canvas: stacked, filled, mirrored), `Alert`, `MenuBar`, `InspectorWindow.qml` and `Main.qml` (one window, an inspector per process, one process over the bus). ambrosia-activity-monitor in the packages and in ambrosia-desktop; `org.ambrosia.activitymonitor` and the other system monitors' names on a new icon (a dark screen with a trace) | This Mac's Activity Monitor measured in the background, its tabs, a row's selection, the inspector and the quit alert reached by accessibility scripting without bringing it forward (`screencapture -l`, `tools/px.py`), then quit as it was found. `bun test` (95), `bun run build`. Off-screen grabs on tenet in Dark and Light. Test VM, a build moved in: each tab's columns and panel with live numbers; a row chosen and still chosen across tabs and sorts; Process Name sorted both ways; "kwin" in the search (two rows), Escape; the views' pop-down and All Processes (root's rows, kernel_task with 85 threads); arrows moving the choice, Return and ⌘I opening the inspector (Memory, Statistics, Open Files and Ports with the window taller); a 30 MB download over loopback credited as it ran (python3 7.7 MB sent, curl 7.7 MB received, the packets beside); a `sleep` of the user's quit from the alert (gone); root's `sleep` quit (the alert naming root, the shell's password prompt, the account's password, gone); the View menu in the menu bar with its shortcuts; a heading's rule dragged wider; the window at its narrowest (the search a round button, the title gone, the wheel scrolling); the disk graph switched from IO to Data and the colored numbers with it; a second launch (still one process); ⌥⌘Q and Force Quit on another `sleep` (systemd logged it killed by signal 9); the inspector's arrow (Files opened on /usr/bin with the program chosen). Found and fixed there: a column for energy stayed empty (what the Sampler hands QML is its list seen through a window, and a value written to it didn't stay: the window now copies it into an array of its own); Inter's letters ran the inspector's names into their values (the values now begin past the longest name); a cell of the tab before asked for a column that was gone. From the r529 packages there, logged in afresh: Search found Activity Monitor by name under its new icon, Return opened it, the Dock showed its tile lit and the menu bar its menus. Not seen: a 2x screen, a trackpad, a laptop (no battery there), a machine short of memory (the pressure's yellow and red), zram or zswap, UDP-heavy traffic, more than a few hundred processes, the table moved sideways in a narrow window (the wheel there only goes up and down), the front window's look against a Mac's (measured behind others) |
| 50, 2026-11-27 | 25, TextEdit | `textedit/`: `qml/rtf.mjs` (RTF read into a plain model of paragraphs and runs and written from one, in Cocoa's dialect: its font and color tables with the expanded one beside, `\'hh` bytes by each font's code page, `\u`, lists from the list table and written back with their markers as text for readers without lists, `\vieww`; `rtf.test.ts`, 11 tests under bun on RTF made by this Mac's `textutil`, kept in `textedit/samples`), `src/editor.cpp` (the model into a QTextDocument and back; the format at the cursor for the bar and ruler; changes to the selection's characters and paragraphs; a format chosen with nothing selected applied to what is typed next as one undo step; lists; find and replace; a PDF), `src/app.cpp` (files read and written whole, the font families without fontconfig's per-weight doubles, the Open and Save panels, one process over the bus), `qml/EditorWindow.qml` with `FormatBar`, `Ruler`, `FindBar`, `Alert`, `MenuBar`, the bar's controls (`Segments`, `PopUp`, `SizeField`, `ColorWell`) and `Main.qml` (a window per document; a new one nothing was typed in gives way to the first opened). `QT_FONT_DPI=72` in `main.cpp` makes a point a pixel. ambrosia-textedit in the packages in Kate's place, the default for text and RTF (`session/xdg/mimeapps.list`), in the Dock's default with a migration, `org.ambrosia.textedit` on the text editor's icon. Also: Files' scroll thumbs no longer show under the pointer when there is nothing to scroll | This Mac's TextEdit measured in the background (a plain and a rich document; `screencapture -l`, `tools/px.py`): bars, every control's place in the format bar, the ruler's marks and markers. `bun test` (88). Test VM, a build moved in: Cocoa's sample opened (bold, italic, underline, strike, red, a highlight, super and subscript, centred, right, justified with indents, a nested bulleted and a numbered list); typing at the end in the font the text ended in; ⌘B on and off between words; a word double-clicked and made italic, red, highlighted from the bar, which read Times, Italic, 24, centred back; the size and font menus; a numbered list and 1.5 spacing from the pop-ups; ⌘S, and the saved file read by this Mac's `textutil` with every style, color, list and indent as set; Find (19 found, Return through them), Replace and All, ⌘Z taking All back at once; ⌘N, typing, ⌘W, the sheet, Save… with Files' Save panel naming it, the file written and the window gone; a .txt in the fixed-width font, ⇧⌘T to rich and back with the sheet; Export as PDF from the File menu (a Letter page, an inch of margin once Qt's own 2 cm were taken off, read with Quick Look here); the indent markers dragged, a tab stop added by a click and dragged off; Return, Tab and ⇧Tab in a list and Return ending it; the right-click menu; the light appearance; in Dark a yellow highlight from a file shown deep under white text, a green one set from the well, the file saved with the true colors, and the system switched to Light and back with the document open (pale highlights under black text, then deep again); a file that isn't there (the sheet, then gone); Shift-JIS bytes decoded (two characters, boxes: no Japanese font there); a 1.6 MB, 20,000-line text opened in about a second and typed at its end; ⌘Q with a changed document (the sheet, ⌘D, gone, the file as it was). Found and fixed there: text typed after the last paragraph took the first font, not the last; a highlight at a paragraph's start painted the whole paragraph after reopening (Qt Quick paints a paragraph's own character background across it); a pale highlight couldn't be read under Dark's white text, which brought the color mapping. From the r526 packages there, logged in afresh: the Dock's Kate pin now TextEdit's (the migration) and opening it, a text file double-clicked in Files opening in it with its tile lit, Search finding TextEdit by name. Not seen: a 2x screen (the half points), a trackpad, a Mac opening a file with lists made here in TextEdit itself (`textutil` read one), East Asian text drawn (no font there), drag and drop of text, a very long rich document, the Open panel's filter, the inch ruler against a Mac's (measured in centimetres) |
| 49, 2026-11-27 | 25, Preview | `preview-app/`: `src/document.cpp` (a PDF through Qt's PDF library: page sizes, outline, a search that goes through the pages a few milliseconds at a time, text between two points with each moved onto the nearest line), `src/pages.cpp` (pages drawn off the main thread as `image://page/…`), `qml/view.mjs` (zoom steps, fitting, the pages' layout, the window a document opens in; `view.test.ts`, 10 tests under bun), `qml/PreviewWindow.qml` with `Toolbar`, `Sidebar`, `PdfView`, `ImageView`, `MenuBar`, and `Main.qml` (a window per document, one process); ambrosia-preview in the packages, in Gwenview's and Okular's place, the default for pictures and PDFs (`session/xdg/mimeapps.list`), in the Dock's default with a migration. Found on the way: a key that is both a window's `Shortcut` and a menu item's was acted on only every second press (Settings, Calculator); every such `Shortcut` now acts when handed over as ambiguous too | This Mac's Preview measured in the background (`screencapture -l`, `tools/px.py`, the new `tools/crop.py`). Test VM, a build moved in: a 3-page PDF (window 913 wide as the Mac's, sidebar, page at 612, dark colors as measured), a 65-page and a 477-page manual (contents, a click on an entry, "color" found 1,761 times in about two seconds, Return through them), zoom in, a page turned, the sidebar's menu, a drag from the margin selecting a line and ⌘C read back by `wl-paste`, a locked PDF (wrong then right password), three pictures together (arrows between them, 100% for one that fits, zoom, turn, ⌘C as an image), a file that isn't a picture, a second launch handing over, ⌘O through Files' panel, the toolbar's double click zooming the window and back. The Calculator's ⌘C four times in a row after the fix (every second failed before). From the r521 packages, logged in afresh: the Dock's Gwenview pin had become Preview's (the picture icon), a PDF double-clicked in Files opened in `/usr/bin/ambrosia-preview` with the menu bar saying Preview and the tile lit, the packaged Calculator copied three times running, Search found Preview by its name, Return on it with nothing to open brought Files' Open panel up in Pictures, and Escape there left no Preview running; Dark chosen in Settings turned an open Preview window dark at once, to the colors measured. Not seen: a pinch (no trackpad; a wheel with ⌘ held was tried and taken out: a Mac's Preview has none), 2x scale, HEIF or a camera's turned JPEG, a picture past 8192 pixels, resizing by the edges, the Zoom light, a picture opened from Firefox or another app |
| 48, 2026-11-27 | 25, Calculator | `calculator/`: `qml/calc.mjs` (the arithmetic as a module: what has been typed as a row of numbers and operators, `press`, `evaluate` with × and ÷ first and a percentage's two meanings, `format` to fifteen figures with thousands apart, copy and paste), `calc.test.ts` (13 tests under bun), `qml/CalculatorWindow.qml` (frameless, its own corners and lights, the display fitting its figures, twenty keys from one list), `Key.qml` (the three faces, the delete and sign glyphs drawn), `MenuBar.qml`, `src/` (the shadow as Settings makes it, the clipboard, `--grab` and `--keys`). A package, ambrosia-calculator, which ambrosia-desktop asks for in KCalc's place | Sizes from this Mac's Calculator (macOS 27.2.1), opened in the background and its window captured: 230 by 408, the corner 15, keys 47 across and 54 apart from 10.5 and 133.5, the lights' first center at 26 and 27, the figure "0" 22 high ending 12 from the right edge, the faces' grays (it was behind another window, so its orange was not seen: ours is the theme's). `bun test`. Test VM, a build moved in: opened by its command, 12 × 3 Return on the keyboard (36 under a small 12×3), 5 + 8 = by clicks on the keys, ⌘C, AC, ⌘V (13 again), Delete, the File menu in the menu bar; with Konsole in front the keys and lights gray. From the r518 packages there, logged in afresh: Search finding Calculator first for "calcul" (KCalc, still installed there, under it), Return opening it, 200 + 10% Return giving 220 under 200+10%, ⌘Q closing it; and round 47 from the package: a file dragged over Photos, held, and dropped on the opened folder's empty space (the file in Photos, the window back in its folder). On tenet r518 is in, ambrosia-calculator with it; KCalc is still installed there (`pacman -Rns kcalc` removes it). Not seen: a 2x scale, its Dock tile, on tenet's screen |
| 47, 2026-11-27 | 26, spring-loaded folders | `FinderWindow.qml`: `springOver` (what takes drops says which folder the drag rests on), a half-second wait, two blinks (`springDim`), `springOpen` (the folder in this window; in columns the next column, by `browse`), `springEnd` (the history, place and first column as the drag found them) at a drop, a drag given up, or 250 ms after the drag left everything that takes drops; a `DropArea` under the whole window so the toolbar counts as inside. `ListPane`, `IconPane`, `ColumnPane`, `SidebarList`, `PathBar` report to it; `Finder.springDelay`, `springBlink`. `tools/chord.py` (keys pressed together on a keyboard keyd takes) | Test VM, a build moved in, drags by a virtual pointer held down: list view, a file over Photos (opened), over Inner in it (opened), dropped: the file in `Photos/Inner`, the window back in Try with Back and Forward dimmed; a file over the sidebar's Documents (opened) and dropped on its empty space (the file in Documents); a file sprung into Photos and carried to the menu bar (back in Try while still held, nothing moved); columns: Photos as a second column, Inner as a third, the pointer over the toolbar for two seconds (still open), out of the window (one column again: the journal's order was left, 250 ms, end). Found on the way: in columns a sprung folder restarted the columns, and the toolbar counted as outside. Not seen: the icon view, the path bar, a drag from another app, the blink itself |
| 45, 2026-11-27 | 10, ⇧⌘Q | `session/org.ambrosia.logout.desktop` (Super+Ctrl+Alt+Shift+Q runs `ambrosia log-out`), keyd's ⇧⌘Q sending it (it had been the app's Ctrl+Shift+Q, which quits Firefox), the shell's IPC `logOut` and `Session.askLogOut` (the Ambrosia menu's question, now in one place), the row's ⇧⌘Q | Test VM from the r513 packages, logged in afresh: `ambrosia log-out` bringing up the question; Super+Ctrl+Alt+Shift+Q pressed directly, and ⇧⌘Q on a keyboard-only virtual device through keyd, each bringing it up; Escape putting it away. The same packages gave rounds 42 to 44 and 46 their look from a package: the Ambrosia menu with its chords, Files' shortcut menu with Open With. On tenet r513 is in; the chord is held from the next login. Not done: logging out by it |
| 46, 2026-11-25 | 26, Quick Look's full screen | `files/qml/QuickLook.qml`: in full screen the panel is black with no rim, a picture takes the whole screen, text keeps its page in the middle, anything else its small layout in the middle in light letters; the bar's things sit on a dark strip that fades away, with the pointer, two seconds after the pointer last moved | Test VM, a build moved in: a picture (the whole screen, the strip and its circles over it), then a text file: black either side of an 806-wide page, the bar there just after a move, gone 3.5 s later, back on the next move, Escape back to the panel. Found on the way: fading the bar redrew the window, Qt sent a hover again at the same place and that woke it (only a pointer that has moved wakes it now). Not seen: a folder or an app in full screen, dark, two screens |
| 44, 2026-11-25 | 26, Files' tags | A sidebar tag's menu: Rename (a field over the name, `SidebarList.qml`) and Delete Tag… (asked on the alert card, `PanelAlert.question`); `Tags.rename`, `Tags.removeTag` (the list, and each item the index has under the tag). The shortcut menu is modal and its rows, the pop-up menus' and the tag editor's are `MouseArea`s | Test VM, a build moved in, two files tagged Red by hand: Rename to Rose (both files' `user.xdg.tags` read Rose, the sidebar and `tags.json` too, the window still in its folder); Delete Tag…, Escape (still there), again and Delete Tag (gone from the list and from both files). Found on the way: a click on a menu row also reached the sidebar row under it (the window went to the Orange tag): hence the mouse areas, seen fixed. Not seen: a tag shown in the window as it is renamed or deleted, a name already taken, dark |
| 43, 2026-11-25 | 26, Files' shortcut menu | `files/qml/ContextMenu.qml`: rows with a `submenu` (another menu beside the row, opened by the pointer after a moment or by →), an `icon` and a check mark; placed by its rows' heights. `App.appsFor` and `App.openWith` (KDE's apps for a kind; no app named opens KDE's chooser), `FileOps.compress` (KZip on a thread, a hidden name until whole) and `FileOps.makeAlias` (a link, recorded for Undo), `FinderWindow.sortBy`; a link's Kind is Alias. The File menu's Make Alias and Compress, the View menu's Sort By | Test VM, a build moved in: a picture's Open With showing Gwenview (default), Firefox and Other…, Gwenview chosen and running with the file; by the keyboard alone a text file's Open With (↓ ↓ → ↓ Return: KWrite running with it; ← back and ↓ on to the next row, the submenu gone); Other… bringing up KDE's Choose Application; Make Alias (`picture.png alias`, a link, Kind Alias); Compress on a folder (`Photos.zip` holding its picture and its hidden file); Sort By on empty space (Size: the largest first, the header following) and in the menu bar's View menu through the shell. Found on the way: a menu opened after a taller one was placed by the taller one's height (fixed). Not seen: a zip of something large, several items at once, Undo of an alias, dark, on tenet |
| 42, 2026-11-25 | 10, our menus' shortcuts | `shell/MenuBar.qml`: the Ambrosia menu's, the app menu's and the Window menu's rows carry the chord that does them on the Mac-first keyboard (`shortcut`, which `MenuView` already drew for apps' rows) | `make shell-shots` for the three menus' sheets, light and dark, looked at: the chords right-aligned in the secondary color, the menus wider by them. Not on KWin: nothing changed but the rows' text |
| 41, 2026-11-25 | 5, glass sidebars | Files' and Settings' floating sidebars as panes of regular glass. `GlassPane` learns `available` (whether the compositor offers the protocol; asked on a queue of its own and waited for, so a window knows before its first frame). The effect offers the protocol only while it is loaded (`GlassProtocol::announce`: the global is removed as the effect goes and made again as it comes), where it used to stay up for good. In each app: `Backing.qml` (the window's color as a shape with a hole a pixel inside the sidebar's outline; closed while Files' columns have scrolled in under the sidebar), the frame see-through only while `available`, and `Sidebar.qml`'s panel: the shadow cut away under the panel, a `GlassPane`, the sidebar's color at 82% in light and 80% in dark over it (`sidebarGlass` in `Finder.qml` and `Look.qml`), fading to solid when the window isn't in front. ambrosia-files and ambrosia-settings depend on ambrosia-glass | `bun test`, `bun run build`, a shell sheet on the stand-in. Test VM, the three binaries and the effect moved in and KWin started again. Files over one hard edge: 28.4 through the sidebar, the black side and the white side each the color the tint computes to. With Konsole in front: solid `#191915`; clicked again: glass. The effect unloaded: solid at once; loaded again: glass (before the effect's fix it stayed see-through with nothing blurred behind). Columns six folders deep: the hole closed, the columns blurred under the sidebar's color. Resized by a KWin script: the hole where the sidebar went. Over the day wallpaper, both apps side by side in dark and in light (the one in front tinted by the wallpaper from yellow at the top to lilac at the bottom, the other solid). No crash of KWin or either app. From the r503 packages there, after a restart: 28.8 through Files' sidebar in light, each side the color the tint computes to, no crash. On tenet the packages are in: its running KWin has no such effect, so there the sidebars stay solid until the next login. Not seen: a 2x scale, an Open or Save panel, Settings under a sheet, on tenet |
| 40, 2026-11-25 | 5, glass in KWin's own pictures | KWin's own windows can't speak the protocol: `BlurBehind` (`decoration/qml`) takes a `material` and writes the item's outline and material as a property of its window (`ambrosia_glass_pane`), which the effect reads as a pane (the smooth corner, the rim); ⌘Tab's strip names thick, the tiling preview clear. The effect answers QML inside KWin for a window's panes (`Panes.panesOf(window)`, the singleton of `org.ambrosia.glass.kwin`, registered when the effect first loads). Mission Control's `FixtureGlass.qml` asks it for the bar's, the Dock's and a banner's panes and puts the wallpaper's picture behind each, blurred by `MultiEffect` to the material (a measured table: `blurMax` is no plain multiple of the Gaussian it gives), saturated, cut to the pane's corner, not fading at the screen's edge; it is loaded by name, so where the glass effect was never loaded Mission Control is as before | Test VM, the files moved in and KWin started again. Mission Control over one hard edge: the Dock 27.2 (28), the bar 19.8 (20), and the same the moment it is left (28.1). `MultiEffect` measured there, twelve strips in one picture: 64 gives 20.7, 96 gives 27.4, 128 gives 32.5 and more gives no more. ⌘Tab held over a window's edge by a virtual keyboard: the strip's glass a slow ramp across the edge, as thick's would be (too narrow a strip for a number). A window dragged to the screen's edge and held: the preview shown. No crash. From the r500 packages there, after a restart: the effect loaded and KWin's blur not, the desktop's Dock 27.3 and bar 19.7, Mission Control's 28.7 and 19.7, ⌘Tab's strip up as dark glass over a window, nothing in KWin's journal and no crash. On tenet the packages are in and the shell runs; its KWin takes them at the next login. Not seen: a banner in Mission Control; the preview over anything but white; on tenet |
| 39, 2026-11-25 | 5, the rim | In the effect's last pass (`glass/effect/shaders/onscreen.frag`): inside a pane's rim (`glass.refraction.edge`, 14 px) the blurred picture is read further out along the outline's normal (straight off a side, along a corner's radius), by `strength` times the rim's width at the edge and less inward by the square; red and blue by `dispersion` less and more. What lies past the pane's own edge is its edge drawn out: the effect keeps only the pane's own background, so nothing outside it can go stale. Only panes: another app's blur region is left a blur | Test VM, the effect's file moved in and KWin started again: the same two screens photographed before and after. The control center over a line 7 px inside its left edge: the four pixels at the edge hold the edge's value, the picture 4 px in went from 128 to 116 (the value 3.9 px further out was 114), 7 px in from 142 to 132 (1.9 px out: 131), 12 px in unchanged; red a level over green and blue through the rim. The Dock's rim over a line: a level's difference at most. Its corner enlarged: smooth. Panes opened and closed four times round, KWin up, the materials' middles unchanged (19.5, 28.1, 35.2). Not from packages yet (built with the next round's); not on tenet's card |
| 38, 2026-11-25 | 5, glass | `glass/`: a protocol (`protocol/ambrosia-glass-v1.xml`: a surface's panes, each a rounded rectangle with a material, an opacity and what clips it, applied with the surface's commit), a KWin effect forked from KWin 6.8's blur (`effect/`, GPL-2.0-or-later: a window's blur as a list of sheets, each with its own blur strength, saturation, outline and opacity; the grain drawn in the last pass; it unloads KWin's blur once it is up and says blur can still be had), and a QML module (`qml/`, `org.ambrosia.glass`: `GlassPane`, which follows its item's place, clip, fading and showing, and sends the panes just before each frame). The materials reach the effect through `dist/glass/tokens.h`; `tools/gen/kawase.ts` runs KWin's blur passes over an edge to find the halvings and offset that blur as the design's Gaussian does. `shell/Glass.qml` takes a material's name and holds the pane; the menu bar, the control center (a backdrop pane, and one a module), and the welcome's and installer's veils name theirs. The session's `kwinrc` switches the effect on and leaves KWin's blur on behind it. A new package, ambrosia-glass. `tools/blur.py` makes the test wallpaper and measures a blur from a screenshot; `tools/glass-try.sh` runs the effect on a headless KWin of its own | `bun test` (the blur settings against the tokens, the materials' order against the protocol), `bun run build`, `make shell-shots` (36 sheets on a stand-in `GlassPane`). Test VM (KWin 6.8.2 as on tenet, drawn in software), the effect and module copied in: each material measured against one hard edge and one flat color (the numbers are in gap 5), light and dark, at 1x and 2x; a banner, a menu, Search, the control center, Notification Center, the welcome; a window dragged under the Dock and away (the glass followed both ways); Mission Control and back; the lock screen and back; the effect unloaded and loaded six times with panes opening; the display's scale changed six times; a plain blur-region client and Konsole's menu. Found there: KWin keeps "blur can be had" as one flag, which its own blur took down as ours unloaded it, so Qt apps stopped asking (ours puts it up again); a Wayland menu doesn't say it is one (a popup with a blur is taken for one). One KWin crash, traced to the test itself: the effect's file overwritten in place while KWin had it loaded. A build for KWin 6.8.2 offered to KWin 6.8.3: refused with a line in the journal, KWin's blur left on. On tenet: `tools/glass-try.sh` on its NVIDIA card, 20.0 and 27.6. From the r495 packages in the VM: the effect loaded and KWin's blur gone at login, the bar 19.5, the Dock 28.1, Search 35.6, no crash. On tenet from the same packages: the shell started again on the running KWin's own blur and the Dock looked as before (its panes do nothing where the compositor has no such effect). Not seen: tenet's live session with the effect (its KWin loads it at the next login) |
| after 37, 2026-11-25 | the shell, when it crashes | `session/ambrosia-shell.service` sets `QS_DISABLE_CRASH_HANDLER=1`; `packaging/quickshell/PKGBUILD` builds without the handler (`CRASH_HANDLER=OFF`, pkgrel 5; the option it had passed, `CRASH_REPORTER`, no longer exists). Found when the shell crashed once in the test VM during a `pacman -S` (in KDE's icon code; not repeated in two more tries): it came back under Quickshell's "has crashed, file a bug" window and could no longer be the notification server. | Test VM, the variable in a drop-in: `kill -SEGV` twice; each time no window, the desktop back within seconds, `NRestarts` one higher, `org.freedesktop.Notifications` owned by the new shell, a core in `coredumpctl`. From packages r492 and Quickshell pkgrel 5 there: the same once more (`NRestarts` 0 to 1, one process, the notification server's name with it), and the welcome kept the keyboard as Konsole opened over it. |
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
