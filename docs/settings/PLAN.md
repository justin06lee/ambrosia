# Settings app and traffic lights on every window — plan

Justin's ask, 2026-10-28 (via midna): Settings fully done, matching macOS System
Settings, every control working against the real system, nothing faked; and the
traffic lights on every window, not only Files. Reference: Justin's MacBook Air
(macOS 26.6.2). Taste note #18: quiet confidence, faithful, nothing added.

## What is there today

- **Window frames.** KWin already draws our Aurorae theme (AmbrosiaLight/Dark)
  on every app that lets the compositor decorate it: Konsole, Kate, KCalc and
  System Settings all get the lights (checked on tenet's KWin 6.8, see
  `out/settings/frames-before.png`). Its known faults: square bottom corners,
  glyphs on the hovered button only (macOS shows all three when the group is
  hovered), 1x bitmaps that go soft at 2x.
- **Apps that draw their own titlebar get none.** Firefox (GTK, client-side
  decorations) shows its own lone ✕ on the right. GTK has no button layout
  set and no titlebutton styling from us. Every libadwaita/GTK4 app would do the
  same, and Chromium/Electron apps draw their own too.
- **Settings.** The shell's System Settings… and every "… Settings…" item open
  KDE's systemsettings (`shell/Session.qml`). There is no Settings app of ours.

## Traffic lights on every window

1. **Our own KWin decoration plugin** (C++, KDecoration3) replaces the Aurorae
   theme. It draws the lights as vectors from the tokens (same sizes, spacing,
   colours and glyphs as Files), shows all three glyphs when the group is
   hovered, darkens on press, greys inactive windows, and rounds all four
   corners: KDecoration3 6.8 has `setBorderRadius`, so KWin clips the app's
   content too. Shadow and edge from the tokens as now.
2. **GTK and client-side apps.** Our generated GTK 3 and GTK 4 CSS styles the
   titlebuttons as the same lights (incl. backdrop grey), and the session sets
   the button layout to `close,minimize,maximize:` (GTK settings.ini in
   `/etc/xdg/ambrosia`, and the settings portal for GTK 4/Flatpak). Firefox
   gets a default pref so it draws GTK's buttons, which then pick up our CSS.
   Chromium/Electron aren't installed on tenet yet; they draw their own
   titlebar too and are handled when one ships.
3. Files and Settings keep drawing their own lights in their toolbars.

## Settings app

Same stack as Files: Qt 6 Quick/QML on the Ambrosia Theme, a C++20 core, KF6
client libraries. Lives in `settings/`, ships as `ambrosia-settings`,
`org.ambrosia.settings`. Privileged changes go through each service's own
polkit (NetworkManager, timedated, localed, hostnamed, accounts-daemon,
PackageKit, CUPS, systemd), so there is no root helper of ours.

Sidebar in macOS 26's order, keeping only what maps:

| Pane | Backend |
|---|---|
| Wi-Fi | NetworkManager (NetworkManagerQt): on/off, join (incl. hidden), known networks, forget, auto-join, details (IP, DNS, proxies) |
| Bluetooth | BlueZ (BluezQt): on/off, pair, connect, disconnect, forget, device battery |
| Network | NetworkManagerQt: Ethernet, Wi-Fi, VPN connections NM holds; TCP/IP, DNS, proxies per service |
| Notifications | our shell's notification server: per-app allow, style, sound, badges, previews |
| Sound | PipeWire (PulseAudioQt): output/input device, volume, balance, input level, alert sound, feedback on volume change |
| Focus | shell: Do Not Disturb, schedules, allowed apps |
| General › About | hostnamed, os-release, /proc, DRM, upower |
| General › Software Update | PackageKit (alpm): check, download, install with polkit |
| General › Storage | statvfs + background size of Applications/Documents/Trash/System; Empty Trash automatically (trashrc) |
| General › Date & Time | timedated (NTP, time zone, set time); 24-hour clock in the menu bar |
| General › Language & Region | localed + plasma-localerc (languages, region, formats, first weekday, measurement) |
| General › Login Items | ~/.config/autostart |
| General › Sharing | hostnamed (computer name); Remote Login = sshd via systemd |
| Appearance | shell + Theme: Light/Dark/Auto, accent, highlight, sidebar icon size, scroll bars, click in the scroll bar to |
| Accessibility | KWin zoom, animation speed (reduce motion), reduce transparency / increase contrast (Theme), cursor size, sticky/slow keys |
| Control Center | shell: each module's Show in Menu Bar / Show in Control Center, menu bar autohide |
| Spotlight | our Search on Super+Space: only the result kinds it has |
| Privacy & Security | xdg-desktop-portal permission store (camera, mic, screen recording grants for portal apps); disk encryption status |
| Desktop & Dock | shell (size, magnification, position, autohide, indicators, recent apps), KWin (minimize effect, double-click title bar, hot corners), default web browser (mimeapps.list and kdeglobals: xdg-settings fails on Plasma 6) |
| Displays | libkscreen (resolution as Larger Text…More Space, refresh, rotation, arrangement, mirroring, main display, HDR where supported), brightness (PowerDevil, incl. DDC), Night Shift (KWin Night Light) |
| Wallpaper | shell: our wallpapers (incl. day/night), photos and folders, fill/fit |
| Battery (Energy on machines with no battery) | upower (level, health, history), PowerDevil, power-profiles-daemon for Low Power Mode |
| Lock Screen | PowerDevil (display off after), kscreenlocker (require password after) |
| Login Password | PAM passwd |
| Users & Groups | AccountsService: list, add, delete, admin, picture |
| Keyboard | kcminputrc (repeat, delay), kxkbrc (input sources, modifier keys), kglobalaccel (shortcuts), keyboard backlight where upower has one |
| Mouse, Trackpad | KWin InputDevice (libinput): speed, natural scrolling, primary button, secondary click, tap to click; double-click speed (kdeglobals). Shown when such a device exists |
| Printers & Scanners | CUPS (libcups/IPP): driverless printers found on the network, add, remove, default, paper size, queue |

**Left out**, because Linux has no counterpart: Apple Account, Family, iCloud,
Apple Intelligence & Siri, Screen Time, Game Center, Wallet & Apple Pay,
Internet Accounts, Headphones, Game Controllers, CDs & DVDs, Classroom,
Passwords (no system-wide AutoFill; browsers keep their own), Screen Saver
(KDE 6 has none), Touch ID (no fingerprint stack yet), Time Machine,
AirDrop & Handoff, AppleCare, Startup Disk, Transfer or Reset, Device
Management, Stage Manager, Widgets, True Tone, Location Services (no geoclue),
Firewall (none shipped), Wake for network access, Power Nap, start up after
power failure, scanners (no SANE).

**Packages to add to ambrosia-desktop:** power-profiles-daemon (Low Power
Mode), cups + avahi + nss-mdns (Printers).

**Shell changes it needs:** the shell's settings move from Quickshell's state
dir to `~/.config/ambrosia/settings.json`, which both read and the shell
watches; the shell honours the new Dock, Control Center, Notifications, Focus
and Appearance keys; every Settings… menu item opens our pane.

## Measurements

Option lists and wording from the pane bundles' string tables (text only, no
Apple art). Window, sidebar, row and control frames from the accessibility API
on a live System Settings window, queued for when the Mac has been idle more
than 10 minutes; Justin's screen is never taken over while he is at it.

## Order of work

1. Traffic lights: the decoration plugin, then GTK and Firefox.
2. Settings app frame: window, sidebar and its search, pane chrome (grouped
   lists, switches, pop-ups, sliders) measured from the Mac; packaging; shell
   wiring. KDE's systemsettings stays installed until every pane is in.
3. Wi-Fi, Bluetooth, Network, Sound, Displays.
4. Appearance, Wallpaper, Desktop & Dock, Control Center, Notifications, Focus.
5. General: About, Software Update, Storage, Date & Time, Language & Region,
   Login Items, Sharing.
6. Battery/Energy, Lock Screen, Login Password, Users & Groups, Privacy &
   Security.
7. Keyboard, Mouse, Trackpad, Printers & Scanners, Accessibility, Spotlight.

Each step: built and tested on tenet (real session) and in the VM image,
light and dark side-by-sides with the Mac's pane, then published.
