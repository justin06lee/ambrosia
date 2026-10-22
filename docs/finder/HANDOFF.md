## Shell and Session

- **Stopped:** done, nothing half-done. Inter Variable comes first in design/tokens.ts, and QT_NO_SYNTHESIZED_BOLD=1 is in the session's font environment; tenet runs it in r208. Measurements and crops are in out/parity/font-order/ (untracked).
- **Next:** the Lead and midna to decide on the GL recommendation: a Mesa-only `__EGL_VENDOR_LIBRARY_FILENAMES` for apps (not KWin) when no monitor is plugged into an NVIDIA port. It isn't shipped. Files' resident process picks up the bold fix at its next restart.
- **Traps:** RSS overstates font savings (shared page cache; PSS and USS don't move). Qt fakes bold over variable fonts' Bold unless QT_NO_SYNTHESIZED_BOLD is set. On tenet's locked screen, QML grabToImage never fires; use QT_QPA_PLATFORM=offscreen or `ambrosia-files --grab`.

## Files app

- **Stopped:** steps 1–4 and midna's three parity gaps are on master and installed on tenet as r205. The list and icon views running on under the toolbar are committed on `feat/files-under-toolbar` (03f8dd2, pushed, not merged). tenet is locked, nothing of Files' is running, and the parity fixtures are deleted.
- **Next:** on that branch, check that a drag on the toolbar still moves the window, record the light and dark clips (`/var/tmp/files-rec/under.sh NAME light|dark [BIN]`), merge and have Packaging publish; then step 5, search (This Mac scope, contents search, Name/Kind/Date Last Opened columns; notes in scratch/search/NOTES.md). The Lead still has to decide whether #13 counts RSS or USS.
- **Traps:** thumbnails stall while tenet's disk is busy (idle-I/O reads, pause above 30% pressure), so run warm.sh before takes; offscreen grabs drop MultiEffect and tenet.sh grab crashes KWin past ~1 s; check `ps` for other agents' windows before recording.
