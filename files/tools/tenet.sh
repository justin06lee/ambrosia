#!/bin/sh
# Builds and photographs Files on an Arch machine (tenet by default) over
# SSH, without touching the desktop anyone is logged into:
#   files/tools/tenet.sh build
#   files/tools/tenet.sh grab NAME [ambrosia-files args...]   -> out/parity/files/ours/NAME.png
#   files/tools/tenet.sh sh 'command'
# Everything runs at low priority; the build lives in /root/ambrosia-files.
# Builds are held to 6 GB in a scope of their own with two jobs: tenet has
# no swap and hosts other people's services, which an uncapped build starves.
set -eu
host=${FILES_HOST:-root@192.168.1.172}
here=$(cd "$(dirname "$0")/.." && pwd)
out=$(cd "$here/.." && pwd)/out/parity/files/ours
dir=/root/ambrosia-files
remote() { ssh -o BatchMode=yes "$host" "$@" </dev/null; }

case ${1:-} in
build)
    remote "mkdir -p $dir/src"
    rsync -az --delete --exclude /tools/__pycache__ -e "ssh -o BatchMode=yes" "$here/" "$host:$dir/src/"
    remote "cd $dir && { [ -f build/build.ninja ] || cmake -S src -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null; } && systemd-run --scope --quiet --collect -p MemoryMax=6G -p MemorySwapMax=0 nice -n 19 ionice -c3 cmake --build build -j2 2>&1 | grep -E 'error|warning: unused|FAILED|ninja: ' | head -60"
    ;;
grab)
    # On a headless KWin of its own, compositing in software, with Mesa's
    # software OpenGL for the app: the same renderer as on a desktop, and
    # the GPU (busy with other work on tenet) is never touched.
    name=$2
    shift 2
    mkdir -p "$out"
    remote "mkdir -p $dir/shots && { [ -d /tmp/ambrosia-files/Tour ] || sh $dir/src/bench/fixture.sh ui /tmp/ambrosia-files/Tour; }
        printf '%s\n' 'cd $dir && QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1 LANG=en_US.UTF-8 build/ambrosia-files --grab $dir/shots/$name.png --size 920x580 $*' > /tmp/files-grab.sh
        XDG_RUNTIME_DIR=/run/user/0 KWIN_COMPOSE=Q LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa \
        __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json timeout 60 nice -n 19 \
        dbus-run-session -- kwin_wayland --virtual --width 1470 --height 956 --scale 2 --socket files-grab \
        --no-lockscreen --no-global-shortcuts --exit-with-session 'sh /tmp/files-grab.sh' 2>&1 \
        | grep -E 'qrc:|Files:|rror' | grep -v -E 'kwin_|libinput|xkb' | head -20"
    scp -q -o BatchMode=yes "$host:$dir/shots/$name.png" "$out/$name.png"
    echo "$out/$name.png"
    ;;
sh)
    remote "cd $dir && $2"
    ;;
*)
    sed -n '2,7p' "$0"
    exit 2
    ;;
esac
