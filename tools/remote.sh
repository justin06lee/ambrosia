#!/usr/bin/env sh
# Mirrors this checkout to ~/ambrosia on a machine on the makima mesh and
# runs a command there, e.g. `tools/remote.sh justin06lee@tenet make package`.
# AMBROSIA_RSH swaps the transport, e.g. AMBROSIA_RSH=ssh while makima is down.
set -eu
host=$1
shift
root=$(cd "$(dirname "$0")/.." && pwd)
rsh=${AMBROSIA_RSH:-makima possess}
rsync -az --delete -e "$rsh" --exclude node_modules --exclude /dist --exclude /out "$root/" "$host:ambrosia/"
[ $# -eq 0 ] || $rsh "$host" "cd ~/ambrosia && $*" </dev/null
