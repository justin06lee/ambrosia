#!/bin/sh
# Drives and photographs the session that is logged in on tenet, from the
# Mac, to look at a change on real KWin and Quickshell.
#   tools/live.sh u <cmd>        run as the user, with the session's bus and display
#   tools/live.sh run <cmd>      start an app as the session would (its whole
#                                environment, kdedefaults included)
#   tools/live.sh r <cmd>        run as root
#   tools/live.sh ui <args>      /root/ui.py: a virtual pointer and keyboard
#                                (click X Y | rclick X Y | move X Y | key alt+tab |
#                                kdown K | kup K | type "text" | sleep S)
#   tools/live.sh shot <name>    photograph the screen into out/live/<name>.png
#   tools/live.sh crop <name> x y w h [max]   cut a piece out, as <name>-c.png
#   tools/live.sh js '<script>'  run a KWin script; P("…") prints back here
#   tools/live.sh keys           switch KWin's own shortcuts back on (see CONTEXT.md, Gotchas)
# Coordinates are the output's pixels. AMBROSIA_HOST is the machine (tenet).
set -eu
host=${AMBROSIA_HOST:-tenet}
root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/out/live
session='export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland LC_ALL=C.UTF-8;'
cmd=${1:?usage: tools/live.sh u|run|r|ui|shot|crop|js|keys …}
shift
case $cmd in
u) ssh -o BatchMode=yes "justin06lee@$host" "$session $*" ;;
run) ssh -o BatchMode=yes "justin06lee@$host" "$session systemd-run --user --quiet --collect $*" ;;
r) ssh -o BatchMode=yes "root@$host" "$*" ;;
ui) ssh -o BatchMode=yes "root@$host" "python3 /root/ui.py $*" ;;
shot)
  mkdir -p "$out"
  ssh -o BatchMode=yes "justin06lee@$host" "$session rm -f /tmp/live-$1.png; spectacle --background --nonotify --fullscreen --output /tmp/live-$1.png 2>/dev/null"
  scp -q "justin06lee@$host:/tmp/live-$1.png" "$out/$1.png" ;;
crop)
  "$root/out/build/qmlshot/qmlshot" --crop "$out/$1.png" "$out/$1-c.png" "$2" "$3" "$4" "$5"
  sips -Z "${6:-1100}" "$out/$1-c.png" >/dev/null ;;
js)
  # KWin prints a script's output to the journal: P() marks ours.
  printf 'function P(s) { print("LIVEJS " + s); }\n%s\n' "$1" | ssh -o BatchMode=yes "justin06lee@$host" "$session"'
    cat > /tmp/live-$$.js; since=$(date "+%F %T")
    n=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/live-$$.js live$$)
    qdbus6 org.kde.KWin /Scripting/Script$n org.kde.kwin.Script.run >/dev/null; sleep 0.4
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript live$$ >/dev/null
    journalctl --user --since "$since" --no-pager -o cat _COMM=kwin_wayland | sed -n "s/^.*LIVEJS //p"; rm -f /tmp/live-$$.js' ;;
keys)
  # Marks every KWin shortcut present again in the global-shortcut daemon,
  # with the keys it has on file (flag 2: set present, keep the keys).
  ssh -o BatchMode=yes "justin06lee@$host" "$session"'
    qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames | while IFS= read -r name; do
      [ -n "$name" ] || continue
      busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setShortcutKeys "asa(ai)u" 4 kwin "$name" KWin "$name" 0 2 >/dev/null
    done
    echo "KWin shortcuts active: $(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.isActive)"' ;;
*) echo "tools/live.sh: no such command: $cmd" >&2; exit 2 ;;
esac
