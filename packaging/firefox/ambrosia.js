// Ambrosia's defaults for Firefox. Firefox draws its own titlebar buttons
// (it no longer uses GTK's), so it takes the system's titlebar instead:
// KWin frames it with Ambrosia's traffic lights. Customize › Title Bar
// switches it back.
pref("browser.tabs.inTitlebar", 0);
// Open and Save through the desktop portal: Files' panels, not GTK's dialog.
pref("widget.use-xdg-desktop-portal.file-picker", 1);
