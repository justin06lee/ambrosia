#!/bin/sh
# Times Files on the benchmark folders (warm cache, best of 5) next to the
# kernel floor for the same folders, and prints the plan's table rows:
#   files/bench/run.sh BUILD_DIR [FIXTURES_DIR]
# Run it on the machine being measured (tenet: files/tools/tenet.sh sh
# 'sh src/bench/run.sh build'). Makes the fixtures if they're missing; never
# drops caches.
set -eu
build=$1
fixtures=${2:-/var/tmp/files-bench}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$fixtures"
[ -d "$fixtures/100k" ] || nice -n 19 sh "$here/fixture.sh" many "$fixtures/100k" 100000
[ -d "$fixtures/1m" ] || nice -n 19 sh "$here/fixture.sh" many "$fixtures/1m" 1000000
floors=$(mktemp -d)
cc -O2 -o "$floors/dents" "$here/floors/dents.c"

best() { sort -n | head -1; }
for size in 100k 1m; do
    dir=$fixtures/$size
    names=$(for i in 1 2 3; do nice -n 19 "$floors/dents" "$dir" 1048576 0; done | sed 's/.*total_ms=//' | best)
    statx=$(for i in 1 2 3; do nice -n 19 "$floors/dents" "$dir" 1048576 2; done | sed 's/.*total_ms=//' | best)
    runs=$(for i in 1 2 3 4 5; do QT_QPA_PLATFORM=offscreen nice -n 19 "$build/ambrosia-files" --bench "$dir" 2>/dev/null; done)
    first=$(echo "$runs" | sed 's/first_ms=\([0-9.]*\).*/\1/' | best)
    load=$(echo "$runs" | sed 's/.*load_ms=//' | best)
    printf '%-5s files: first rows %7.1f ms, complete %7.1f ms   floor: names %6.1f ms, +statx %6.1f ms (one thread)\n' \
        "$size" "$first" "$load" "$names" "$statx"
done
rm -rf "$floors"
