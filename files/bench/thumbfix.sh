#!/bin/sh
# thumbfix.sh DIR [pics|kinds]: the thumbnail benchmark's fixtures (plan targets #9, #10), under DIR
# (with "pics", only Pics/, for the demo; with "kinds", only Kinds/):
#   jpeg-exif/  8 × 24 MP noisy JPEGs (6000×4000, ~7 MB) with a 160×107 EXIF thumbnail
#   jpeg-plain/ the same 8 without one
#   many/       60 × 12 MP JPEGs without one, for scrolling a cold folder
#   Pics/       a mixed folder for the views: photos, PNG, WebP, GIF, SVG, PDF, text
#   Kinds/      videos (one opening on a second of black), fonts, office documents, audio with and without covers
# Writes about 0.35 GB; run it capped (nice, idle I/O), as tenet.sh does.
set -e
D=${1:?usage: thumbfix.sh DIR [pics]}
P=$D/Pics
mkdir -p "$P"
ff() { ffmpeg -loglevel error -y "$@"; }
# A 24 MP photo's worth of noise (each seed differs), and its EXIF thumbnail.
photo() { ff -f lavfi -i "testsrc2=s=6000x4000:r=1,noise=alls=24:allf=t+u:all_seed=$2" -frames:v 1 -q:v 3 "$1"; }
exifthumb() { ff -i "$1" -vf scale=160:-1 -q:v 4 "${1%.jpg}-thumb.jpg"; exiv2 -it "$1" && rm "${1%.jpg}-thumb.jpg"; }
if [ "$2" = kinds ]; then
    K=$D/Kinds; mkdir -p "$K"; here=$(dirname "$0")
    ff -f lavfi -i "color=black:s=1280x720:d=1:r=25" -loop 1 -t 5 -i /usr/share/sddm/themes/maldives/background.jpg -filter_complex \
        "[1]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,zoompan=z='1+0.002*on':d=1:s=1280x720:fps=25,setsar=1,format=yuv420p[p];[0]setsar=1,format=yuv420p[b];[b][p]concat=n=2:v=1[v]" \
        -map "[v]" -c:v libx264 -crf 26 "$K/Harbour.mp4"
    ff -f lavfi -i "gradients=s=960x540:speed=0.04:d=6:c0=0x0f766e:c1=0xfbbf24:c2=0xbe185d:n=3" -c:v libx264 -crf 26 -pix_fmt yuv420p "$K/Dusk.mov"
    ff -f lavfi -i "testsrc2=s=854x480:d=5" -c:v libx264 -crf 28 -pix_fmt yuv420p "$K/Test Pattern.m4v"
    for f in /usr/share/fonts/noto/NotoSerif-Regular.ttf /usr/share/fonts/TTF/JetBrainsMono-Regular.ttf /usr/share/fonts/inter/InterVariable.ttf; do
        [ -f "$f" ] && cp "$f" "$K/"
    done
    ff -f lavfi -i "mandelbrot=s=600x600:start_scale=0.15" -frames:v 1 -q:v 3 "$D/cover.jpg"
    ff -f lavfi -i "sine=f=440:d=8" -i "$D/cover.jpg" -map 0 -map 1 -c:a libmp3lame -q:a 7 -c:v copy -id3v2_version 3 \
        -metadata title="Harbour Lights" -metadata artist="The Ridge" -metadata:s:v comment="Cover (front)" "$K/Harbour Lights.mp3"
    ff -f lavfi -i "sine=f=330:d=6" -c:a libmp3lame -q:a 7 "$K/Tone.mp3"
    ff -f lavfi -i "sine=f=550:d=6" -i "$D/cover.jpg" -map 0 -map 1 -c:a aac -b:a 96k -c:v copy -disposition:v:0 attached_pic "$K/Field Recording.m4a"
    ff -f lavfi -i "sine=f=660:d=6" -i "$D/cover.jpg" -map 0 -map 1 -c:a flac -c:v copy -disposition:v:0 attached_pic "$K/Album.flac"
    ff -f lavfi -i "anoisesrc=d=4:a=0.1" "$K/Voice Memo.wav"
    cat > "$D/minutes.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="181" height="256"><rect width="181" height="256" fill="#fff"/>
<text x="18" y="34" font-family="sans-serif" font-size="13" font-weight="700">Minutes, 14 October</text>
<g fill="#888"><rect x="18" y="50" width="120" height="3"/><rect x="18" y="62" width="145" height="3"/><rect x="18" y="70" width="140" height="3"/>
<rect x="18" y="78" width="132" height="3"/><rect x="18" y="86" width="90" height="3"/><rect x="18" y="104" width="60" height="5"/>
<rect x="18" y="118" width="140" height="3"/></g></svg>
SVG
    rsvg-convert "$D/minutes.svg" -o "$D/minutes.png"
    python3 "$here/officefix.py" "$K" "$D/minutes.png"
    ls -la "$K"
    exit 0
fi
if [ "$2" != pics ]; then
    mkdir -p "$D/jpeg-exif" "$D/jpeg-plain" "$D/many"
    for i in 1 2 3 4 5 6 7 8; do
        [ -f "$D/jpeg-plain/plain-$i.jpg" ] || photo "$D/jpeg-plain/plain-$i.jpg" $i
        [ -f "$D/jpeg-exif/exif-$i.jpg" ] || { cp "$D/jpeg-plain/plain-$i.jpg" "$D/jpeg-exif/exif-$i.jpg"; exifthumb "$D/jpeg-exif/exif-$i.jpg"; }
    done
    [ -f "$D/many/IMG_0060.jpg" ] ||
        ff -f lavfi -i "testsrc2=s=4000x3000:r=1,noise=alls=24:allf=t+u,hue=H=t/5" -frames:v 60 -q:v 3 "$D/many/IMG_%04d.jpg"
fi

[ -f /usr/share/sddm/themes/maldives/background.jpg ] && cp /usr/share/sddm/themes/maldives/background.jpg "$P/Maldives.jpg"
[ -f /usr/share/wallpapers/Next/contents/images/1440x2960.png ] && cp /usr/share/wallpapers/Next/contents/images/1440x2960.png "$P/Next.png"
photo "$P/Test Card.jpg" 1 && exifthumb "$P/Test Card.jpg"
ff -f lavfi -i "mandelbrot=s=1600x1200:end_pts=40:start_scale=0.5" -ss 30 -frames:v 1 -q:v 3 "$P/Mandelbrot.jpg"
ff -f lavfi -i "gradients=s=1200x900:c0=0xff7a59:c1=0x5b6cff:x0=0:y0=0:x1=1200:y1=900:seed=3" -frames:v 1 "$P/Gradient.webp"
ff -f lavfi -i "cellauto=s=320x240:rule=110,scale=640:480:flags=neighbor" -frames:v 24 "$P/Cells.gif"
ff -f lavfi -i "life=s=600x600:mold=10:r=1:ratio=0.3:death_color=#1d3557:life_color=#e9c46a" -ss 20 -frames:v 1 "$P/Life.png"
cat > "$D/page.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="612" height="792" viewBox="0 0 612 792">
  <rect width="612" height="792" fill="#fff"/>
  <rect x="56" y="64" width="500" height="150" rx="8" fill="#2a6df4"/>
  <text x="76" y="150" font-family="sans-serif" font-size="44" font-weight="700" fill="#fff">Field Report</text>
  <text x="76" y="190" font-family="sans-serif" font-size="18" fill="#dce6ff">Autumn survey, plots 1–12</text>
  <g font-family="serif" font-size="15" fill="#333">
    <text x="56" y="260">The survey covered twelve plots along the north ridge between</text>
    <text x="56" y="284">September and October. Each plot was visited three times.</text>
    <text x="56" y="308">Canopy cover, soil moisture and seedling counts were taken</text>
    <text x="56" y="332">at fixed points marked on the first visit.</text>
  </g>
  <rect x="56" y="370" width="230" height="160" fill="#f2c14e"/>
  <rect x="326" y="370" width="230" height="160" fill="#4caf7d"/>
  <g font-family="serif" font-size="15" fill="#333">
    <text x="56" y="580">Moisture fell on every plot after the second visit, most on</text>
    <text x="56" y="604">the exposed east side. Seedling counts held steady.</text>
  </g>
</svg>
EOF
rsvg-convert -f pdf -o "$P/Field Report.pdf" "$D/page.svg"
cp "$D/page.svg" "$P/Cover.svg"
cat > "$P/Notes.txt" <<'EOF'
Packing list for the coast

- rain shell, wool layer, two pairs of socks
- headlamp and spare batteries
- map of the north ridge (the 1:25k one)
- thermos, oats, coffee

Ferry leaves at 07:40 from pier 3. Last boat back
is 18:15 on weekdays, 17:30 on Sunday.

Ask at the harbour office about the tide tables
before walking out to the point.
EOF
cat > "$P/README.md" <<'EOF'
# Pictures

Photos from the autumn trip, sorted by day.
Originals are on the backup drive; these are
the edited copies.

## Days
1. Arrival and the harbour
2. North ridge survey
3. The point at low tide
EOF
ls -la "$P"
