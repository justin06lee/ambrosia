## Shell and Session

- **Stopped:** done, nothing half-done. Inter Variable comes first in design/tokens.ts, and QT_NO_SYNTHESIZED_BOLD=1 is in the session's font environment; tenet runs it in r208. Measurements and crops are in out/parity/font-order/ (untracked).
- **Next:** the Lead and midna to decide on the GL recommendation: a Mesa-only `__EGL_VENDOR_LIBRARY_FILENAMES` for apps (not KWin) when no monitor is plugged into an NVIDIA port. It isn't shipped. Files' resident process picks up the bold fix at its next restart.
- **Traps:** RSS overstates font savings (shared page cache; PSS and USS don't move). Qt fakes bold over variable fonts' Bold unless QT_NO_SYNTHESIZED_BOLD is set. On tenet's locked screen, QML grabToImage never fires; use QT_QPA_PLATFORM=offscreen or `ambrosia-files --grab`.
