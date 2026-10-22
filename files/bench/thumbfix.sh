#!/bin/sh
# thumbfix.sh DIR: the thumbnail benchmark's fixtures (plan targets #9, #10), under DIR:
#   jpeg-exif/  8 × 24 MP noisy JPEGs (6000×4000, ~7 MB) with a 160×107 EXIF thumbnail
#   jpeg-plain/ the same 8 without one
#   many/       60 × 12 MP JPEGs without one, for scrolling a cold folder
#   Pics/       a mixed folder for the views: photos, PNG, WebP, GIF, SVG, PDF, text
# Writes about 0.35 GB; run it capped (nice, idle I/O), as tenet.sh does.
set -e
D=${1:?usage: thumbfix.sh DIR}
mkdir -p "$D/jpeg-exif" "$D/jpeg-plain" "$D/many" "$D/Pics"
ff() { ffmpeg -loglevel error -y "$@"; }
# Noise makes the files the size of real photos; each frame differs.
for i in 1 2 3 4 5 6 7 8; do
    [ -f "$D/jpeg-plain/plain-$i.jpg" ] && continue
    ff -f lavfi -i "testsrc2=s=6000x4000:r=1,noise=alls=24:allf=t+u:all_seed=$i" -frames:v 1 -q:v 3 "$D/jpeg-plain/plain-$i.jpg"
done
for i in 1 2 3 4 5 6 7 8; do
    out=$D/jpeg-exif/exif-$i.jpg
    [ -f "$out" ] && continue
    cp "$D/jpeg-plain/plain-$i.jpg" "$out"
    ff -i "$out" -vf scale=160:-1 -q:v 4 "$D/jpeg-exif/exif-$i-thumb.jpg"
    exiv2 -it "$out" && rm "$D/jpeg-exif/exif-$i-thumb.jpg"
done
[ -f "$D/many/IMG_0060.jpg" ] ||
    ff -f lavfi -i "testsrc2=s=4000x3000:r=1,noise=alls=24:allf=t+u,hue=H=t/5" -frames:v 60 -q:v 3 "$D/many/IMG_%04d.jpg"

P=$D/Pics
[ -f /usr/share/sddm/themes/maldives/background.jpg ] && cp /usr/share/sddm/themes/maldives/background.jpg "$P/Maldives.jpg"
[ -f /usr/share/wallpapers/Next/contents/images/1440x2960.png ] && cp /usr/share/wallpapers/Next/contents/images/1440x2960.png "$P/Next.png"
cp "$D/jpeg-exif/exif-1.jpg" "$P/Test Card.jpg"
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
