## Shell and Session

- **Stopped:** done, nothing half-done. Inter Variable comes first in design/tokens.ts, and QT_NO_SYNTHESIZED_BOLD=1 is in the session's font environment; tenet runs it in r208. Measurements and crops are in out/parity/font-order/ (untracked).
- **Next:** the Lead and midna to decide on the GL recommendation: a Mesa-only `__EGL_VENDOR_LIBRARY_FILENAMES` for apps (not KWin) when no monitor is plugged into an NVIDIA port. It isn't shipped. Files' resident process picks up the bold fix at its next restart.
- **Traps:** RSS overstates font savings (shared page cache; PSS and USS don't move). Qt fakes bold over variable fonts' Bold unless QT_NO_SYNTHESIZED_BOLD is set. On tenet's locked screen, QML grabToImage never fires; use QT_QPA_PLATFORM=offscreen or `ambrosia-files --grab`.

## Files app

- **Stopped:** search as Finder's is on master (2026-11-10): This Computer scope, a plain query matches names or contents, results in Name / Kind / Date Last Opened. Contents are read in-process (`src/contents.cpp`) with O_NOATIME, the home's document folders for This Computer, 20 s at most. Checked on tenet's screen, light and dark (Searching “Look”: Plans.zip by name, README.md by contents, README's atime unchanged).
- **Next:** the right-click menu with Tags (colours + Tags…), undo for tags, the tag colour editor, tags changed while Files is off; then the untested items (login autostart, Quick Look full screen and in the Trash, ⌘I on several items). The Lead still has to decide whether #13 counts RSS or USS.
- **Traps:** never run rg (or anything that reads every file) over the whole home on tenet: over two hours at 80-85% I/O pressure. tenet's screen locks while idle: hold `kde-inhibit --screenSaver` (unit files-inhibit) during takes, or keys go to the lock screen. done.sh deletes /var/tmp/files-shots/*.png: copy shots off first. Thumbnails stall while tenet's disk is busy (run warm.sh before takes); offscreen grabs drop MultiEffect and tenet.sh grab crashes KWin past ~1 s.
