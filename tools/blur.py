#!/usr/bin/env python3
"""How soft glass makes what is behind it, measured from a screenshot.

    tools/blur.py picture OUT.png X [WIDTH HEIGHT]
    tools/blur.py measure SHOT.png row Y X0 X1
    tools/blur.py measure SHOT.png col X Y0 Y1

`picture` writes a wallpaper that is black left of X and white right of it
(1920x1200 unless given). Put it behind a pane and photograph the screen.
`measure` reads the line from X0 to X1 (both inside the pane, the edge
between them, flat at both ends) and prints how wide the edge's rise from
10% to 90% is, and the standard deviation of the Gaussian that would soften
it as much (rise / 2.5631): the number a material's `blur` is, in the
picture's pixels (twice the token at a 2x scale).

One edge on the whole screen, not stripes: a wide blur reaches the next
stripe, and the rise then reads narrow. Nothing but Python's own library."""
import struct
import sys
import zlib


def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)


def picture(path, x, w=1920, h=1200):
    row = b'\x00' + b'\x00\x00\x00' * x + b'\xff\xff\xff' * (w - x)
    head = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)
    with open(path, 'wb') as out:
        out.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', head) + chunk(b'IDAT', zlib.compress(row * h, 6)) + chunk(b'IEND', b''))


def load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i = 8
    idat = b''
    while i < len(d):
        n, t = struct.unpack('>I4s', d[i:i + 8])
        body = d[i + 8:i + 8 + n]
        i += 12 + n
        if t == b'IHDR':
            w, h, depth, ctype, _, _, inter = struct.unpack('>IIBBBBB', body)
        elif t == b'IDAT':
            idat += body
    assert depth == 8 and inter == 0 and ctype in (2, 6), (depth, ctype, inter)
    bpp = 3 if ctype == 2 else 4
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        cur = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for x in range(bpp, stride):
                cur[x] = (cur[x] + cur[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                cur[x] = (cur[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                cur[x] = (cur[x] + (((cur[x - bpp] if x >= bpp else 0) + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = cur[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                cur[x] = (cur[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(cur)
        prev = cur
    return bpp, rows


def measure(path, kind, at, start, end):
    bpp, rows = load(path)

    def light(x, y):
        return sum(rows[y][x * bpp:x * bpp + 3]) / 3

    line = [light(i, at) if kind == 'row' else light(at, i) for i in range(start, end)]
    if line[0] > line[-1]:
        line.reverse()
    low = sum(line[:5]) / 5
    high = sum(line[-5:]) / 5
    if high - low < 8:
        sys.exit(f"no edge on that line: it runs from {low:.0f} to {high:.0f}")

    def reach(share):
        level = low + (high - low) * share
        for i in range(1, len(line)):
            if line[i - 1] < level <= line[i]:
                return i - 1 + (level - line[i - 1]) / (line[i] - line[i - 1])
        sys.exit("the line doesn't rise from its one end to its other")

    rise = reach(0.9) - reach(0.1)
    print(f"from {low:.0f} to {high:.0f}: rises over {rise:.1f} px, a Gaussian of {rise / 2.5631:.1f}")


if len(sys.argv) >= 4 and sys.argv[1] == 'picture':
    picture(sys.argv[2], *map(int, sys.argv[3:6]))
elif len(sys.argv) == 7 and sys.argv[1] == 'measure' and sys.argv[3] in ('row', 'col'):
    measure(sys.argv[2], sys.argv[3], *map(int, sys.argv[4:7]))
else:
    sys.exit(__doc__)
