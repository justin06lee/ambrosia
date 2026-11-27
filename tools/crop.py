#!/usr/bin/env python3
"""A piece of a screenshot as its own PNG, optionally enlarged.

    tools/crop.py shot.png out.png X Y W H [times]

Cuts the W by H rectangle at X, Y (pixels, from the top left) and writes it,
each pixel `times` across if given (whole numbers: no smoothing, so edges
can be counted). For looking closely at one control without reading the
whole picture; `sips -c` only cuts from the middle. Reads 8-bit RGB or RGBA
PNGs with nothing but Python's own library."""
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
src, out, x, y, cw, ch = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
k = int(sys.argv[7]) if len(sys.argv) > 7 else 1
w, h, bpp, rows = load(src)
x = max(0, min(x, w - 1)); y = max(0, min(y, h - 1)); cw = min(cw, w - x); ch = min(ch, h - y)
body = bytearray()
for r in range(y, y + ch):
    line = bytearray()
    for c in range(x, x + cw):
        line += bytes(rows[r][c*bpp:c*bpp+3]) * k
    body += (b'\x00' + line) * k
def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
open(out, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', cw * k, ch * k, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(body), 9)) + chunk(b'IEND', b''))
print(f"{out}: {cw * k}x{ch * k}")
