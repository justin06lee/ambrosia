#!/usr/bin/env sh
# Tries the glass effect on this computer's own graphics card without
# touching the desktop you're logged into: builds glass/ from this checkout,
# runs it and the checkout's shell on a headless KWin of its own, and
# photographs that. tools/glass-try.sh out.png [width height]
#
# The wallpaper is black left of the middle and white right of it, so the
# picture can be measured: tools/blur.py measure out.png row 5 X0 X1 for the
# menu bar (thin), a row just inside the Dock's top for the Dock (regular).
# Prints the card KWin drew with and the effects it loaded: ambrosia_glass
# should be among them and blur should not.
set -eu
out=$(realpath "$1")
w=${2:-1920} h=${3:-1200}
root=$(cd "$(dirname "$0")/.." && pwd)
build=${GLASS_BUILD:-/tmp/ambrosia-glass-try/build}
N=$(dirname "$build")/nest

[ -f "$root/dist/glass/tokens.h" ] || { echo "glass-try: no dist/glass/tokens.h, run bun tools/gen/index.ts first" >&2; exit 1; }
cmake -S "$root/glass" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null
cmake --build "$build" | tail -n 1

rm -rf "$N"
mkdir -p "$N/config/ambrosia" "$N/plugins/kwin/effects/plugins" "$N/qml/org/ambrosia/glass" "$N/wallpapers"
cp "$build/ambrosia_glass.so" "$N/plugins/kwin/effects/plugins/"
cp "$build/libambrosiaglass.so" "$root/glass/qml/qmldir" "$N/qml/org/ambrosia/glass/"
# The shell finds its wallpapers beside itself: the test picture under
# both names. -L: the shell borrows files by symlink.
cp -rL "$root/shell" "$N/shell"
python3 "$root/tools/blur.py" picture "$N/wallpapers/nectar-day.png" $((w / 2)) "$w" "$h"
cp "$N/wallpapers/nectar-day.png" "$N/wallpapers/nectar-night.png"
printf '[Plugins]\nambrosia_glassEnabled=true\nblurEnabled=true\n' >"$N/config/kwinrc"
printf '{ "welcome": false }\n' >"$N/config/ambrosia/settings.json"

export XDG_CONFIG_HOME="$N/config" XDG_SESSION_DESKTOP=ambrosia XDG_CONFIG_DIRS=/etc/xdg/ambrosia:/etc/xdg
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export QT_PLUGIN_PATH="$N/plugins" QML_IMPORT_PATH="$N/qml"
cat >"$N/inner.sh" <<INNER
quickshell --path "$N/shell" >"$N/shell.log" 2>&1 &
sleep \${AMBROSIA_SHOT_DELAY:-5}
qdbus6 org.kde.KWin /KWin supportInformation 2>/dev/null | grep "OpenGL renderer string\|OpenGL version string" >"$N/info.txt"
printf 'effects: ' >>"$N/info.txt"
qdbus6 org.kde.KWin /Effects loadedEffects 2>/dev/null | tr '\n' ' ' >>"$N/info.txt"
spectacle --background --nonotify --fullscreen --output "$out"
INNER
dbus-run-session -- kwin_wayland --virtual --width "$w" --height "$h" \
  --socket ambrosia-glass-try --no-lockscreen --no-global-shortcuts --exit-with-session "sh $N/inner.sh" >"$N/kwin.log" 2>&1 || true
cat "$N/info.txt"
echo
grep -i "glass\|shader" "$N/kwin.log" | head -n 8 || true
[ -f "$out" ] && echo "glass-try: $out" || { echo "glass-try: no picture; see $N/kwin.log" >&2; exit 1; }
