#!/usr/bin/env python3
"""What a screenshot holds along one line, as text: runs of like colors.

    tools/px.py shot.png row Y X0 X1 [tolerance [shortest]]
    tools/px.py shot.png col X Y0 Y1 [tolerance [shortest]]

Prints `start:length#rrggbb` for each run (a channel may drift by
`tolerance`, 10 unless given; runs under `shortest` pixels are left out).
For measuring what a picture would only show: how wide a control is, how far
apart two are, which color a row took. Reads 8-bit RGB or RGBA PNGs with
nothing but Python's own library."""
import sys, zlib, struct
def load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i = 8; idat = b''
    while i < len(d):
        n, t = struct.unpack('>I4s', d[i:i+8]); body = d[i+8:i+8+n]; i += 12 + n
        if t == b'IHDR': w, h, depth, ctype, _, _, inter = struct.unpack('>IIBBBBB', body)
        elif t == b'IDAT': idat += body
    assert depth == 8 and inter == 0 and ctype in (2, 6), (depth, ctype, inter)
    bpp = 3 if ctype == 2 else 4
    raw = zlib.decompress(idat); stride = w * bpp; rows = []; prev = bytearray(stride); p = 0
    for _ in range(h):
        f = raw[p]; cur = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        if f == 1:
            for x in range(bpp, stride): cur[x] = (cur[x] + cur[x-bpp]) & 255
        elif f == 2:
            for x in range(stride): cur[x] = (cur[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride): cur[x] = (cur[x] + (((cur[x-bpp] if x >= bpp else 0) + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = cur[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2 * c)
                cur[x] = (cur[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(cur); prev = cur
    return w, h, bpp, rows
w, h, bpp, rows = load(sys.argv[1])
px = lambda x, y: tuple(rows[y][x*bpp:x*bpp+3])
kind, a, b, c = sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
tol = int(sys.argv[6]) if len(sys.argv) > 6 else 10
pts = [(x, a) for x in range(b, c)] if kind == 'row' else [(a, y) for y in range(b, c)]
out = []; start = 0; ref = px(*pts[0])
for i, pt in enumerate(pts[1:], 1):
    v = px(*pt)
    if max(abs(v[j] - ref[j]) for j in range(3)) > tol:
        out.append((start, i - start, ref)); start = i; ref = v
out.append((start, len(pts) - start, ref))
base = b
print(' '.join(f"{base+s}:{n}#{r:02x}{g:02x}{bl:02x}" for s, n, (r, g, bl) in out if n >= (int(sys.argv[7]) if len(sys.argv) > 7 else 1)))
