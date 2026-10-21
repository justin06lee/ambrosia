#!/bin/sh
# Makes the folders Files is measured and compared on, identically on the Mac
# (for Finder references) and on Linux:
#   fixture.sh ui DIR        a small folder that looks like a real one
#   fixture.sh many DIR N    N empty files with mixed names and extensions
set -eu
mode=$1 dir=$2

# A file of a given size, modified at a given time ([[CC]YY]MMDDhhmm).
file() { head -c "$2" /dev/zero >"$dir/$1"; touch -t "$3" "$dir/$1"; }
folder() { mkdir -p "$dir/$1"; touch -t "$2" "$dir/$1"; }

case $mode in
ui)
    mkdir -p "$dir"
    folder "Archive" 202609141022
    folder "Music" 202608020915
    folder "Photos" 202610190811
    folder "Projects" 202610201744
    file "Invoice 0412.pdf" 84213 202610030930
    file "Meeting Notes.txt" 3120 202610211105
    file "Moodboard.png" 1824420 202610121614
    file "Plans.zip" 5248112 202609280847
    file "README.md" 1430 202610190912
    file "Sunset.jpg" 2411872 202610051931
    file "Theme Song.mp3" 4718592 202607221303
    file "build.sh" 612 202610201752
    # Folders with something in them, so they aren't shown as empty.
    file "Projects/Ambrosia.txt" 2048 202610201744
    file "Photos/Beach.jpg" 1048576 202610190811
    file "Music/Track 1.mp3" 3145728 202608020915
    file "Archive/Old.zip" 524288 202609141022
    touch -t 202610201744 "$dir/Projects"
    touch -t 202610190811 "$dir/Photos"
    touch -t 202608020915 "$dir/Music"
    touch -t 202609141022 "$dir/Archive"
    ;;
many)
    n=$3
    mkdir -p "$dir"
    # One process makes them all: a shell loop of 1M touches takes minutes.
    awk -v d="$dir" -v n="$n" 'BEGIN {
        split("jpg png txt pdf mp4 rs md zip", ext, " ");
        split("a b c d e f g h", tag, " ");
        for (i = 0; i < n; i++) {
            f = sprintf("%s/file_%07d_%s.%s", d, i, tag[i % 8 + 1], ext[i % 8 + 1]);
            printf "" > f; close(f);
        }
    }'
    ;;
*)
    echo "usage: fixture.sh ui DIR | many DIR N" >&2
    exit 2
    ;;
esac
