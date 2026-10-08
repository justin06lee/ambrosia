#!/usr/bin/env sh
# Mirrors this checkout to ~/ambrosia on a machine on the makima mesh and
# runs a command there, e.g. `tools/remote.sh justin06lee@tenet make package`.
set -eu
host=$1
shift
root=$(cd "$(dirname "$0")/.." && pwd)
rsync -az --delete -e 'makima possess' --exclude node_modules --exclude /dist --exclude /out "$root/" "$host:ambrosia/"
[ $# -eq 0 ] || makima possess "$host" "cd ~/ambrosia && $*" </dev/null
