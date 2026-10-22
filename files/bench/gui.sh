#!/bin/sh
# Times whole windows, Files' and Dolphin's, from exec until the window says
# how many items the folder holds (probe.py, over AT-SPI), and their memory a
# second later. It runs on a headless KWin of its own at 2x with software GL,
# so no one's screen and no GPU is touched; warm cache, best and median, after
# one warm-up run each; never drops caches:
#   files/bench/gui.sh BUILD_DIR [FIXTURES_DIR] [SIZES]
# SIZES is any of 50, 100k and 1m; the default leaves 1m out, which is only
# for when 100k stayed well under the cap.
# On tenet, only with the lead's okay (tenet has no swap and hosts other
# people's services): files/tools/tenet.sh sh 'sh src/bench/gui.sh build'
set -eu
here=$(cd "$(dirname "$0")" && pwd)

if [ "${1:-}" = --inside ]; then
    build=$2 fixtures=$3 results=$4 sizes=$5
    summary() {
        sort -n | awk '{ v[NR] = $1 } END {
            if (NR == 0) printf "%8s %8s", "none", ""; else printf "%8d %8d", v[1], v[int((NR + 1) / 2)] }'
    }
    for size in $sizes; do
        case $size in
        50) count=50 runs=5 ;;
        100k) count=100000 runs=5 ;;
        1m) count=1000000 runs=3 ;;
        *) echo "unknown size $size" >>"$results"; continue ;;
        esac
        for app in "Files, list|$build/ambrosia-files --view list" \
                   "Files, icons|$build/ambrosia-files --view icon" \
                   "Dolphin|dolphin --new-window"; do
            # Stop at once if KWin has gone: nothing after it would mean anything.
            [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "KWin went away" >>"$results"; exit 1; }
            name=${app%%|*}
            out=$(python3 "$here/probe.py" $((runs + 1)) "$count" -- ${app#*|} "$fixtures/$size" | tail -n +2)
            listed=$(echo "$out" | grep listed_ms | sed 's/listed_ms=\([0-9]*\).*/\1/' | summary)
            rss=$(echo "$out" | grep rss_mb | sed 's/.*rss_mb=//' | summary)
            failed=$(echo "$out" | grep -c -v listed_ms || true)
            printf '%-5s %-13s listed, best/median ms: %s   RSS best/median MB: %s   failed runs: %s\n' \
                "$size" "$name" "$listed" "$rss" "$failed" >>"$results"
        done
        # The whole scope's peak so far: what decides whether 1m may run.
        peak=$(cat "/sys/fs/cgroup$(sed -n 's/^0:://p' /proc/self/cgroup)/memory.peak")
        echo "after $size: scope memory peak $((peak / 1048576)) MB of 4096" >>"$results"
    done
    exit 0
fi

build=$(cd "$1" && pwd)
fixtures=${2:-/var/tmp/files-bench}
sizes=${3:-50 100k}
mkdir -p "$fixtures"
[ -d "$fixtures/50" ] || nice -n 19 sh "$here/fixture.sh" many "$fixtures/50" 50
[ -d "$fixtures/100k" ] || nice -n 19 sh "$here/fixture.sh" many "$fixtures/100k" 100000
case $sizes in *1m*) [ -d "$fixtures/1m" ] || nice -n 19 sh "$here/fixture.sh" many "$fixtures/1m" 1000000 ;; esac
results=$(mktemp)
config=$(mktemp -d)
# Everything (KWin, the accessibility bus, the apps and their workers) shares
# one scope, held to 4 GB with no swap and 30 minutes: a runaway app is killed
# there instead of starving the machine. Dolphin's first-run settings go in a
# folder of their own, so nobody's are touched. This headless KWin has no
# effects handler and crashes when an app asks for an xdg-activation token, as
# normal launches do, so Qt apps (Files and Dolphin alike) skip that protocol.
systemd-run --scope --unit=files-probe --quiet --collect -p MemoryMax=4G -p MemorySwapMax=0 -p RuntimeMaxSec=1800 \
    env XDG_CONFIG_HOME="$config" XDG_RUNTIME_DIR="/run/user/$(id -u)" KWIN_COMPOSE=Q LIBGL_ALWAYS_SOFTWARE=1 \
    __GLX_VENDOR_LIBRARY_NAME=mesa __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
    QT_QPA_PLATFORM=wayland QT_WAYLAND_DISABLED_INTERFACES=xdg_activation_v1 LANG=en_US.UTF-8 nice -n 19 ionice -c3 \
    dbus-run-session -- kwin_wayland --virtual --width 1470 --height 956 --scale 2 --socket files-probe \
    --no-lockscreen --no-global-shortcuts --exit-with-session "sh $here/gui.sh --inside $build $fixtures $results '$sizes'" \
    >"$fixtures/gui-kwin.log" 2>&1 || true
cat "$results"
rm -rf "$results" "$config"
