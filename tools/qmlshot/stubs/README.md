# Stand-ins for Quickshell and Plasma

The shell's QML imports Quickshell and Plasma's task manager, which exist
only on the Linux desktop. So that the shell's own files (`shell/*.qml`,
unchanged) can be loaded and drawn by `qmlshot` anywhere Qt Quick runs, the
modules here and the types in `../stubs.h` answer to the same names. `make
shell-shots` puts this folder on the import path.

They are stand-ins, not the real thing. What that means for a picture:

| The shell asks for | Here it is |
|---|---|
| `PanelWindow`, `PopupWindow` | An item on the sheet's screen (`Quickshell.screens[0].shotHost`), held to the edges it anchors to and stacked by its layer. Masks, exclusive zones and keyboard modes are kept and ignored. |
| `BackgroundEffect.blurRegion` | A blur of what the sheet names as lying under the windows (`shotBackdrop`, the wallpaper), cut to the region's shape. KWin's blur is a different one and blurs other windows too. |
| `Quickshell.iconPath` | An icon of the generated Ambrosia theme, or nothing: Breeze isn't here, so files' kinds and other apps' icons come out blank. |
| `Quickshell.execDetached` | Starts nothing; what it was asked to start is listed in `Quickshell.shotDetached`, for a sheet to look at. |
| `Process` | Never started. A sheet answers for a command with `Quickshell.shotRun = command => "what it printed"`; unanswered, it never ends. |
| `FileView` | Never opened. Holds `Quickshell.shotFiles["name.json"]` or nothing; says it loaded; writes nowhere. So Settings are their defaults until a sheet sets them. |
| `org.kde.taskmanager` | The pinned apps, then the ids in `Apps.tasks.shotRunning`; `shotActive` is in front, `shotAttention` and `shotStarting` as named. One row an app, no groups. |
| `DesktopEntries` | The table of apps in `stubs.cpp`. |
| An app's menus (`DBusMenuSource`) | `Quickshell.shotMenus["<app id>"]`: rows as titles, `"-"`, or `{ text, children, enabled, shortcut }`. |
| Apps' status items (`SystemTray`) | None until a sheet sets `SystemTray.shotItems`: `{ id, icon: a picture's URL, status, hasMenu, menu }`, the menu a `DBusMenuSource` of the sheet's. |
| `NotificationServer` | Nothing arrives until a sheet calls `NotificationStore.server.shotNotify({ appName, summary, body, … })`. |
| Wi-Fi, Bluetooth, sound, battery, players | Fixed, plausible values (see each module); some take a sheet's own through a `shot…` property. |
| `SystemClock` | 9:41 on 18 November 2026, always. |

A sheet also gets `shotPointer`: `move`, `press`, `release`, `click`, `type`
and `key` reach the hidden window as a real mouse's and keyboard's would, so
a menu can be opened by pressing its title and a tooltip by resting on an
icon.

## What a picture from here doesn't tell you

- **That Quickshell agrees.** A property these have and Quickshell lacks
  loads here and fails there. The stand-ins are written from what the
  shell already uses; check anything new against Quickshell's own docs.
- **Text metrics.** A Mac has no Inter, so text is in its own font.
- **Glass.** The tint and edge are the shell's; the blur under them is not
  KWin's.
- **Window-relative places.** Every stand-in window is in one scene, so
  `mapToItem(null, …)` gives a place on the screen, not in the window as
  it does for real. Shell code should map to its own window's
  `contentItem`, which is the same thing on the desktop and right here.
- **Anything that needs the session**: focus moving between windows, key
  grabs, DBus, what KWin does with layers and popups.
