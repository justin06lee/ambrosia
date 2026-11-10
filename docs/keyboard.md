# The Mac-first keyboard

Super is Command. `design/DECISIONS.md` ("Mac-first keyboard") says why and
`design/DESIGN.md` ("Keyboard") what the hands should find; this is what
ships, how it works, and what it doesn't do yet.

## How it works

[keyd](https://github.com/rvaiya/keyd) sits between the keyboards and
everything else (KWin, the login screen, the console), so one layer covers
every app and toolkit. ambrosia-desktop depends on it and carries its config;
the installer enables `keyd.service`. On a system installed before this:
`sudo systemctl enable --now keyd`. **Linux-first is the same switch the other
way** (`sudo systemctl disable --now keyd`): with keyd off nothing is
remapped and nothing else here runs.

- **⌘ held is Ctrl** for the app. `⌘C` reaches it as the `Ctrl+C` its menus
  document, `⇧⌘Z` as `Ctrl+Shift+Z`, a ⌘-click as a Ctrl-click, in any app,
  with nothing to list per app. The menu bar draws an app's `Ctrl` as ⌘ for
  the same reason, and Files binds `Ctrl` where Finder has ⌘.
- **Ctrl, Shift and the right Alt (AltGr) are untouched.** `Ctrl+C` still
  interrupts in a terminal.
- **What ⌘ does that isn't Ctrl is written out** in `/etc/keyd/ambrosia.conf`
  (the layers) and `/usr/share/keyd/ambrosia/` (the system's shortcuts, which
  every layer includes). The tables below are those files.
- **Terminals and Files get their own bindings while they have the keyboard.**
  The shell (`shell/KeyLayer.qml`) knows the focused app; when its kind
  changes it writes one word (`terminal`, `files`, `default`) to the pipe
  `/run/ambrosia-keys`. `ambrosia-keys.service` reads it and runs
  `keyd bind reset …` with the bindings filed under that word in
  `/etc/ambrosia/keys/` or `/usr/share/ambrosia/keys/`. keyd's own socket
  gives whoever can reach it the whole keyboard, so no account is put in the
  `keyd` group: the service runs as a throwaway user that is, and takes
  nothing from the pipe but the name of a file root wrote.

## What ⌘ does

Everywhere:

| Keys | Does | Sent on as |
|---|---|---|
| ⌘ + any key not below | the app's Ctrl shortcut: ⌘C ⌘V ⌘X ⌘Z ⇧⌘Z ⌘A ⌘S ⌘F ⌘N ⌘T ⌘W ⌘Q ⌘, … | Ctrl + the key |
| ⌘Space | Search | Super+Space (the shell's shortcut) |
| ⌘Tab, ⇧⌘Tab | switch windows, forward and back; ` steps back while it's up | Alt+Tab, Alt held until ⌘ is let go (KWin's switcher) |
| ⌘` , ⇧⌘` | the app's next window, and the one before | Alt+` |
| ⌘M, ⌘H | minimize the window | Super+PgDn (KWin's Minimize) |
| ⇧⌘3, ⇧⌘4, ⇧⌘5 | picture of the screen, of a part, the screenshot tool | Shift+Print, Super+Shift+Print, Print (Spectacle) |
| ⇧⌘[ , ⇧⌘] | the tab before, the tab after | Ctrl+PgUp, Ctrl+PgDn |
| ⌃⌘F | full screen | Super+Ctrl+F (`session/org.ambrosia.fullscreen.desktop`) |
| ⌃⌘Q | lock the screen | Super+L |
| ⌃⌘Space | emoji | Super+. |
| ⌥⌘Esc | force a window's app to quit (click the window) | Super+Ctrl+Esc (KWin's Kill Window) |

In every app but a terminal:

| Keys | Does | Sent on as |
|---|---|---|
| ⌘← ⌘→ | start and end of the line (with ⇧, select to it) | Home, End |
| ⌘↑ ⌘↓ | start and end of the document; a web page's top and bottom | Ctrl+Home, Ctrl+End |
| ⌘[ ⌘] | back, forward | Alt+←, Alt+→ |
| ⌥← ⌥→ | by word (with ⇧, select) | Ctrl+←, Ctrl+→ |
| ⌥⌫ ⌥⌦ | delete the word before, after | Ctrl+Backspace, Ctrl+Delete |

In a terminal (any app whose desktop file says `TerminalEmulator`):

| Keys | Does | Sent on as |
|---|---|---|
| ⌘ + a key | the terminal's own shortcut: ⌘C copy, ⌘V paste, ⌘T tab, ⌘N window, ⌘W close, ⌘F find, ⌘K clear, ⌘Q quit, ⌘+ larger | Ctrl+Shift + the key |
| ⌘- | smaller text | Ctrl+- |
| ⌘⌫ | clear the line typed so far | Ctrl+U |
| ⌘← ⌘→ | start and end of the line | Home, End |
| ⌥← ⌥→ | by word | Ctrl+←, Ctrl+→ |
| ⌥⌫, ⌥⌦ | delete the word before, after | Alt+Backspace, Alt+D |
| ⌥ + anything else | the shell's Meta, as Terminal's "Use Option as Meta key" | Alt + the key |

In Files, ⌘ with the arrows and the brackets is Files' own (⌘↑ enclosing
folder, ⌘↓ open, ⌘[ back, ⌘] forward): they go on as plain Ctrl.

## An app of your own

- **Which layer an app gets**: `~/.config/ambrosia/keys.json` names it by
  the app's desktop file id, as `{ "org.wezfurlong.wezterm": "terminal",
  "org.kde.kate": "default" }`. Read at once, no restart.
- **A new set of bindings**: a file in `/etc/ambrosia/keys/` named for it,
  one keyd binding a line (`cmd.r = f5`, `cmd.t = C-S-t`), the same file name
  as an app's layer in `keys.json`. A file there with a shipped name
  (`terminal`, `files`) replaces the shipped one.
- **The layers themselves**: `/etc/keyd/ambrosia.conf`, then
  `sudo keyd reload` (`keyd check` reads it for mistakes first). It says how
  to put ⌘ beside the space bar on a PC keyboard.

## What it doesn't do

- **⌘Q and ⌘W are the app's Ctrl+Q and Ctrl+W.** An app with no such
  shortcut ignores them (most Electron apps have no Ctrl+Q); the Mac's
  quit-anything would have to come from the shell. Files, like Finder, has
  no Quit.
- **⌘Tab walks windows, not apps**, and ⌘H minimizes one window rather than
  hiding the app: both are KWin's own actions, the nearest it has.
- **⌘⌫ deletes a word, not the line**: it is the app's Ctrl+Backspace, so
  that in Files it still moves to the Trash. The Mac's would take two
  keystrokes (select to the line's start, delete), which in a list is a
  different, destructive thing.
- **The exceptions are by key position on a US keyboard** (`m`, `h`, `[`,
  `` ` ``…), keyd's way. The rule itself, ⌘ as Ctrl, follows any layout.
- **Shortcuts on Super are out of reach of ⌘**: KWin's Super+arrows (tiling),
  Super+L, Super+W and the rest answer only to what the tables above send.
  Other sessions on the same machine (Plasma) get the same keyboard.
- **⌘C in Konsole with nothing selected does nothing**, as in the Mac's
  Terminal. Konsole's Copy is off until there is a selection, and Konsole
  hands a Ctrl+Shift chord it has no use for to the shell as the plain
  control character (⌘C interrupted the job, ⌘U would clear the line). The
  session's Konsole profile (`session/konsole/Ambrosia.profile`, the default
  through `/etc/xdg/ambrosia/konsolerc`) uses a key table of ours
  (`ambrosia.keytab`: Konsole's own, plus Ctrl+Shift with any letter doing
  nothing). A profile of your own gets the same by choosing the "Ambrosia"
  key bindings in its Keyboard page.
- **Some ⌘ chords are Konsole's own**, not Terminal's: ⌘D is Select Mode
  (Esc leaves it), ⌘A, ⌘I and ⌘R watch the tab for activity, silence and
  the prompt, ⌘P prints, ⌘E and ⌘Z maximize and zoom a split view.
- **A terminal the desktop doesn't know as one** (no `TerminalEmulator` in
  its desktop file, or run inside another app) gets ⌘C as Ctrl+C, an
  interrupt. Name it in `keys.json`.
- **The per-app half needs the shell.** At the login screen, on a console,
  or with the shell down, ⌘ is the plain layer. After `keyd reload` or a keyd
  restart the focused app's bindings come back with the next switch of app.
- **Not asked at install yet**: Mac-first is simply on. The question
  (DECISIONS) belongs to onboarding and the switch to Settings › Keyboard.
- **A laptop's trackpad keeps resting while you type**: keys reach libinput
  from keyd's virtual keyboard, which a quirk
  (`/usr/share/libinput/50-ambrosia-keyd.quirks`) marks as the built-in one.
  libinput reports the quirk on keyd's keyboard; not tried on a laptop.

## Checked

In the test VM (2026-11-10), from a fresh install: keyd up with this config;
what it sends for each row of the tables read back with `keyd monitor`, in
the plain layer, a terminal's and Files'; the shell switching the three as
Konsole, Kate and Files took the keyboard; ⌘Space, ⌘Tab held, ⌘M, ⌃⌘F both
ways, ⌃⌘Q, ⌃⌘Space and ⇧⌘4 doing what the tables say; a line copied in Kate
with ⌘A ⌘C and pasted into Konsole with ⌘V. Not driven there: ⌘`, ⇧⌘3 and
⇧⌘5, ⌥⌘Esc's click, ⌘Q, copying a Konsole selection (it needs a mouse drag),
a keyboard that isn't US.
