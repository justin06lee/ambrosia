#!/bin/sh
# Draws the sheets in tools/qmlshot/sheets, light and dark, into out/shots/:
#
#   sh tools/qmlshot/shots.sh [sheet...]     (all of them, or the ones named)
#
# Run from the repo's root, after qmlshot is built (`make shell-shots` does
# both). Before drawing, the shell is staged where the sheets import it from:
# links to its files beside a qmldir that says which of them are singletons,
# as Quickshell works out for itself; and the desktop pictures are drawn
# from their SVGs, as the package build does with rsvg-convert.
set -eu

build=out/build/qmlshot
shot=$build/qmlshot
[ -x "$shot" ] || { echo "shots: $shot isn't built (make shell-shots)" >&2; exit 1; }

rm -rf "$build/shell"
mkdir -p "$build/shell" "$build/wallpapers" out/shots
for file in shell/*; do
    ln -s "$PWD/$file" "$build/shell/"
done
for file in shell/*.qml; do
    name=$(basename "$file" .qml)
    # Types only: shell.qml is the shell's start, not one.
    case "$name" in
    [ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) ;;
    *) continue ;;
    esac
    if grep -q '^pragma Singleton' "$file"; then
        echo "singleton $name 1.0 $name.qml"
    else
        echo "$name 1.0 $name.qml"
    fi
done > "$build/shell/qmldir"

for name in nectar-day nectar-night; do
    if [ ! "$build/wallpapers/$name.png" -nt "assets/wallpapers/$name.svg" ]; then
        echo "shots: drawing the desktop picture $name"
        "$shot" --svg "assets/wallpapers/$name.svg" "$build/wallpapers/$name.png" 2880 1800
    fi
done

if [ $# -gt 0 ]; then
    sheets=
    for name in "$@"; do
        sheets="$sheets tools/qmlshot/sheets/$name.qml"
    done
else
    sheets=$(ls tools/qmlshot/sheets/*.qml)
fi
total=$(echo $sheets | wc -w | tr -d ' ')
echo "shots: $total sheets, light and dark"
count=0
for sheet in $sheets; do
    count=$((count + 1))
    name=$(basename "$sheet" .qml)
    for mode in light dark; do
        dark=
        [ "$mode" = dark ] && dark=--dark
        # Qt says so on every run where Inter isn't installed (a Mac).
        "$shot" "$sheet" "out/shots/shell-$name-$mode.png" --import dist/qml --import tools/qmlshot/stubs \
            --wallpapers "$build/wallpapers" $dark 2>&1 | grep -v 'qt.qpa.fonts' >&2 || true
        [ -s "out/shots/shell-$name-$mode.png" ] || { echo "shots: $name ($mode) wasn't drawn" >&2; exit 1; }
    done
    echo "[$count/$total] out/shots/shell-$name-light.png out/shots/shell-$name-dark.png"
done
echo "shots: done"
