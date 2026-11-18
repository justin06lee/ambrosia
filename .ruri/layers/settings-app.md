# ambrosia — Settings App

One layer of ambrosia's stack, owning `settings/, docs/settings/, scratch/settings/dhcp-test.py, scratch/settings/wifi-sim.sh, scratch/settings/mac-sheets.sh, scratch/settings/bt-sim.sh, scratch/settings/mac-sheets2.sh, scratch/settings/mac-sheets3.sh, scratch/settings/mac-sheets7.sh, scratch/settings/fake-upower.py, scratch/settings/vmd.sh, scratch/settings/vmrun.sh, scratch/settings/fake-touchpad.py`. The whole stack, and how the layers connect, is in `.ruri/architecture.md`.
Don't edit this file: ruri writes it. `ruri layer settings-app` prints it with every line numbered, what git says changed in this layer lately and what sessions learned working here; once you have read it that way, put right what your work changed — `ruri layer settings-app add|set|drop <section> …`. Where it and the code disagree, the code is right.

Our System Settings look-alike: a Qt 6 QML window on the Ambrosia theme, the sidebar in macOS 26 order, with panes for General, About, Software Update, Sound, Wi-Fi, Bluetooth, Network, Battery, Lock Screen, Users & Passwords, Privacy, Displays, Appearance, Wallpaper, Desktop & Dock, Menu Bar, Notifications, Focus, Keyboard, Mouse and Trackpad. A C++20 core reads the system's services (hostnamed, PipeWire, NetworkManager, BlueZ, UPower, power-profiles-daemon, AccountsService, KWin's input devices); settings.json is shared with the shell. Panes not built yet open KDE's own modules via kcmshell6.

## Where to change what

- **the sidebar's panes (which exist, order, glyph, colour, keywords, page or KDE module):** settings/qml/Panes.qml, settings/qml/Sidebar.qml, settings/qml/glyphs.js
- **every size and colour, light and dark, measured from System Settings:** settings/qml/Look.qml, docs/settings/FRAME.md
- **the window: lights, toolbar with back/forward, page area:** settings/qml/SettingsWindow.qml, settings/qml/Toolbar.qml, settings/qml/TrafficLights.qml
- **shared sheets: the modal panel over the window (centred, rim, 24 corners, buttons under a rule; a sidebar of its own for Details…), the window under it (page and toolbar dimmed, sidebar faded, close grayed, all disabled), Done/OK in the accent style:** settings/qml/Sheet.qml, settings/qml/SettingsWindow.qml, settings/qml/Sidebar.qml, settings/qml/PushButton.qml
- **General and About:** settings/qml/GeneralPage.qml, settings/qml/AboutPage.qml, settings/src/about.cpp, settings/src/about.h
- **Software Update: checks, Update Now and its confirm sheet:** settings/qml/SoftwareUpdatePage.qml, settings/src/updates.cpp
- **Sound: output and input devices, volume, mute, balance, alert sound, input level meter:** settings/qml/SoundPage.qml, settings/src/sound.cpp, settings/qml/DeviceTable.qml, settings/qml/LevelMeter.qml
- **Battery, Energy and Lock Screen: charge chart, Low Power Mode, health and charging sheets, password delay:** settings/qml/BatteryPage.qml, settings/qml/LockScreenPage.qml, settings/src/power.cpp, settings/qml/BatteryChart.qml
- **Printers (CUPS), Accessibility (KWin, kaccessrc), Spotlight:** settings/src/printers.cpp, settings/src/access.cpp, settings/qml/SpotlightPage.qml
- **Users & Passwords: accounts, avatars, password change:** settings/qml/UsersPage.qml, settings/qml/PasswordPage.qml, settings/qml/UserPicture.qml, settings/src/accounts.cpp, settings/src/accounts.h
- **Privacy: per-permission pages and the apps listed under each:** settings/qml/PrivacyPage.qml, settings/qml/PrivacyAppsPage.qml, settings/src/privacy.cpp, settings/src/privacy.h
- **system data and actions (dark/accent, battery/mouse/trackpad present, KDE modules via kcmshell6):** settings/src/app.cpp
- **the controls (switch, check box, pop-up, slider, segmented, buttons) and their dev-only test page:** settings/qml/Switch.qml, settings/qml/CheckBox.qml, settings/qml/PopUpButton.qml, settings/qml/Slider.qml, settings/qml/Segmented.qml
- **Keyboard (repeat, delay, backlight), Mouse and Trackpad (KWin's devices of each kind, all set alike):** settings/qml/KeyboardPage.qml, settings/qml/MousePage.qml, settings/qml/TrackpadPage.qml, settings/src/keyboard.cpp, settings/src/mouse.cpp, settings/src/trackpad.cpp, settings/src/kwininput.cpp

## How it works

- **Open a pane:** shell Session.settings(pane) → kstart ambrosia-settings --pane X (X?anchor opens at a place in it: sound?input) → a running instance takes it over D-Bus org.ambrosia.settings Show(pane, token) → SettingsWindow selects the pane, or kcmshell6 opens the KDE module
- **Open a sheet:** a page's button (Bluetooth's ⓘ in DeviceRow, Battery's ⓘ through InfoButton) opens a Sheet over the window → Sheet dims the window behind it and draws the rim and corner → an action inside may open a second, smaller confirm Sheet (Forget This Device) → Done closes the sheet and the page keeps its state
- **Sound:** SoundPage → Sound singleton (sound.cpp: pulseaudio-qt sinks/sources and stream-restore; KConfig kdeglobals [Sounds] Theme and plasmaparc [General] AudioFeedback, which plasma-pa's kded reads) → PipeWire's pulse server; the meter's peak stream is open only while the Input side shows
- **Battery and Energy:** BatteryPage (BatteryChart draws the charge history) → Power singleton (power.cpp: UPower for the battery, power-profiles-daemon for the profile) → PowerDevil applies Low Power Mode; 'Only on Battery' switches the profile as the power source changes
- **Wi-Fi:** WiFiPage → WiFi singleton (wifi.cpp, NetworkManagerQt; the card not sharing a hotspot, or AMBROSIA_WIFI_DEVICE's) → NetworkManager; a secured join with no password asks the session's secret agent (plasma-nm's kded); a failed join deletes the connection it made

## Key files

- settings/src/main.cpp — options --pane, --appearance light|dark, --grab, --active (draw as focused, for shots); single instance; sets QT_NO_SYNTHESIZED_BOLD
- settings/src/sound.cpp — PulseAudio devices (any with nothing plugged in left out), volume, mute, balance, alert volume/device, sound theme, feedback, and the input peak meter
- settings/src/power.cpp — UPower battery and power-profiles-daemon reads and writes for the Battery, Energy and Lock Screen panes
- settings/src/accounts.cpp — AccountsService users, avatars and password changes
- settings/src/privacy.cpp — portal permission store: which apps may use each permission
- settings/qml/SoundPage.qml — the Sound pane: devices, volume, alert and feedback options
- settings/qml/BatteryPage.qml — the Battery pane: charge chart, Low Power Mode, Battery Health and Charging sheets
- settings/qml/Sheet.qml — the shared modal sheet over the window, with dimming, rim and corner
- settings/qml/PushButton.qml — push button: corners 7, a white face that takes what's under it, a primary accent style for Done, minimumWidth to match the Cancel beside it
- settings/qml/SoftwareUpdatePage.qml — the Software Update pane and its Update Now confirm sheet
- settings/qml/PrivacyAppsPage.qml — the per-permission sub-page listing the apps
- settings/src/about.h — declarations behind the About pane's system data
- settings/src/connectiondetails.cpp — saved connection settings read and applied for the Details… sheets

## Rules and traps

- No dead rows: a pane is listed only if it has a page here or an installed KDE module; Apple-only items (serial number, AppleCare, legal lines, startup chime, interface sound effects) are left out, not faked
- Privileged changes go through each service's own polkit (hostnamed, timedated, NetworkManager…), never a root helper of ours
- Zoom is vertical only, like System Settings: App::zoom runs a KWin script (setMaximize(v, false)); xdg-shell's maximize would fill the screen's width
- Pane tests on tenet must never switch off Wi‑Fi, its only network connection; put back any audio or network value a test changed
- Pane tests on tenet must remove any test VPN profile afterwards, since the VPN page switches a real WireGuard profile and could take the default route
- Date & Time and Language & Region tests change the clock and system locale, so they run only in the VM; on the real system the clock, timezone, NTP and locale stay untouched
- Update Now asks for an administrator's password: our polkit rule (packaging/polkit/10-ambrosia-packagekit.rules) sorts ahead of Arch's, which let wheel update with none
- pulseaudio-qt has no level monitor, so the input meter opens its own peak-detect stream in sound.cpp
- Clicks act through MouseArea, not TapHandler: Qt 6 hands a press an item above took to the handlers of every item beneath, so a TapHandler under a menu or sheet fires too. Only the window's background, lights and toolbar keep TapHandlers; menus are modal
- Sheets stack (SettingsWindow.sheets): only the top one takes keys and clicks; one under another draws inactive
- Battery/Energy are tested in the VM against scratch/settings/fake-upower.py, Trackpad against fake-touchpad.py (a uinput clickpad), never tenet's own

## What it talks to

- theme-targets — import Ambrosia (dist/qml Theme) for type and glyphs
- shell-and-session — MenuBar, ControlCenter and the Dock pin open it through Session.settings(pane)
- packaging-and-image — ambrosia-settings split package in packaging/PKGBUILD; ambrosia-desktop depends on it
