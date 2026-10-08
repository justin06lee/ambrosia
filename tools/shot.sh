#!/usr/bin/env sh
# Photographs the shell on a headless KWin, without touching the desktop
# you're logged into: tools/shot.sh out.png [width height scale].
# AMBROSIA_SHELL runs a checkout's shell/ instead of the installed one.
set -eu
out=$(realpath "$1")
w=${2:-1470} h=${3:-956} scale=${4:-2}
shell=${AMBROSIA_SHELL:-/usr/share/ambrosia/shell}
export XDG_SESSION_DESKTOP=ambrosia XDG_CONFIG_DIRS=/etc/xdg/ambrosia:/etc/xdg
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
inner=$(mktemp)
cat >"$inner" <<INNER
quickshell --path "$shell" >"$out.log" 2>&1 &
sleep \${AMBROSIA_SHOT_DELAY:-4}
spectacle --background --nonotify --fullscreen --output "$out"
INNER
dbus-run-session -- kwin_wayland --virtual --width "$w" --height "$h" --scale "$scale" \
  --socket ambrosia-shot --no-lockscreen --no-global-shortcuts --exit-with-session "sh $inner"
rm -f "$inner"
