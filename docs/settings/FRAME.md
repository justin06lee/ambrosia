# Settings — the window frame (milestone 1)

The frame every pane sits in, measured from System Settings on macOS 26.6.2
(Justin's MacBook Air, dark mode) through the accessibility API, read-only.
Frames are in points, relative to the window's top-left. The raw dumps are
`out/settings/mac/panes/NN-<pane>.jsonl` (one AX node per line, `f` =
x, y, w, h) beside a 2x screenshot of each pane, on the Mac only.

## Window

- 723 × 744 by default; the same rounded window corner as our frames.
- No titlebar: the traffic lights sit in the sidebar panel, boxes 16 at
  x 18 / 41 / 64, y 18 (lights 14, centres at y 26: centred in the 52 toolbar,
  as far from the panel's edge as from the top).
- Toolbar band 52 tall over the content; the content scrolls under it.

## Sidebar

- A floating glass panel at (8, 8), 215 × 728, rounded (Files' sidebar glass).
- Search field at (18, 61), 195 × 28, a capsule: magnifier at x 26, "Search"
  placeholder, 13 pt. Typing filters the list by pane name and keywords.
- List from y 98. Rows 32 tall; the selection is a rounded rect over the
  cell, x 18, 195 wide. Each row: a 20 pt coloured rounded-square icon with a
  white glyph at x 24, then the name at x 49, 13 pt. Groups are 13 pt apart
  (one row pitch plus 13), with no rule between them.
- Our list, in macOS 26's order, keeping what maps (PLAN.md's table):
  1. Wi‑Fi, Bluetooth, Network, Battery (Energy without a battery)
  2. General, Accessibility, Appearance, Desktop & Dock, Displays, Menu Bar,
     Spotlight, Wallpaper
  3. Notifications, Sound, Focus
  4. Lock Screen, Privacy & Security, Login Password, Users & Groups
  5. Keyboard, Mouse, Trackpad, Printers & Scanners (Mouse and Trackpad only
     when such a device exists)
  macOS 26 calls Control Center "Menu Bar"; its VPN pane is folded into
  Network here. Apple Account, Family and iCloud at the top are left out.

## Toolbar

- Back / forward: a glass capsule at (231, 8), 73 × 36, two 36 × 36 segments
  with chevrons; forward is a menu button in macOS (history).
- The pane's name at x 316, centred in the 52 band, about 15 pt semibold.
  A pane that opens with a header box (General) leaves it out until the
  box's own title has scrolled under the toolbar.
- The zoom light is live (green while key) and shows a plus on hover, not
  the full-screen triangles: it fills the screen's height and keeps the width.

## Content

- Scroll area x 223 – 723. Groups ("boxes") are x 243, 460 wide (20 margin),
  radius about 10, filled a step off the window, 10 apart: in light the
  window is white and the boxes #f7f7f7 with #ebebeb hairlines; in dark
  #272724, #2d2d2b and #373735 (light measured 2026-10-28 in daytime Auto
  mode, `out/settings/mac/light/`).
- Inside a box: 10 pt padding; rows separated by a hairline from x 253 to 693.
  Control rows pitch about 38.5 (label 13 pt, centred); navigation rows 42
  plus the hairline, with a 20 pt icon at x 253, the label at x 283 and a
  chevron at the right.
- Section headings: 13 pt bold at x 253, 26 above their box; 30 from the box
  above.
- A pane's header box (General and other parents): 164 tall, a 52 pt icon
  centred, the name about 22 pt bold, a one-line description in secondary
  text, centred, at most 397 wide.
- Controls sit right-aligned at x 693:
  - switch 36 × 16 (on = accent);
  - pop-up button 24 tall: the value then an up/down chevron capsule;
  - slider: thin track, 20 × 16 white capsule knob, optional tick marks below,
    speaker glyphs at the ends for volume;
  - segmented control 24 tall across the box (440), corners 6 (not a
    capsule), the selected segment filled with the accent;
  - help button: a 24 pt circle with "?", bottom right, 20 below the last box.
- Descriptions under a label: 11 pt secondary.

- Pop-ups have no face: the value in plain text, then 12.5 on a 20 × 20 circle
  with the up/down chevrons, 3.5 from the right (remeasured 2026-10-30 on
  Sound's Alert sound and Wi-Fi's Other…; the first pass had 16 × 20, 4). Switch knob 20 × 12, 2 in; slider
  track 6, knob 20 × 16. Faces: #e4e4e4 light, #3d3d3b dark. The window's
  corner radius is 26, the sidebar panel's 18. The sidebar selection is the
  accent while the window is key, grey (#464646 dark) when it isn't.

## Panes not built yet

Every pane in the list is real from the start: one we haven't built yet opens
its KDE System Settings module (kcmshell6) in its own window, a working control
rather than an empty page, until our pane replaces it. KDE's systemsettings
stays installed until the last one does (PLAN.md).
