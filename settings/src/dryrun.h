#pragma once

#include <QtGlobal>

// With AMBROSIA_SETTINGS_DRYRUN set, what changes the running system (an
// upgrade, the clock, a service) says what it would do and doesn't: for testing
// the pages on a machine that must not change.
inline bool dryRun(const char *what)
{
    if (!qEnvironmentVariableIsSet("AMBROSIA_SETTINGS_DRYRUN"))
        return false;
    qWarning("Settings: dry run: %s", what);
    return true;
}
