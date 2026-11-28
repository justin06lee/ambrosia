#!/usr/bin/env python3
# fake-touchpad.py — in the test VM as root: a uinput clickpad ("Ambrosia Test Touchpad", 100 x 66 mm,
# multi-touch) so KWin has a touchpad for Settings' Trackpad pane, as fake-upower.py stands in for a battery.
# It stays up reading /run/fake-touchpad (a FIFO), one command a line:
#   tap [N]      a tap with N fingers (1)            click [N]   a press of the pad with N fingers resting
#   corner       a press in the bottom right corner  scroll DY   two fingers moved DY units (down > 0)
#   pull DY MS   two fingers moved DY units and held there MS milliseconds before they lift
#   flick DY     two fingers moved DY units fast and lifted while still moving
#   across DX    two fingers moved DX units sideways (right > 0)
#   swipe N DIR  N fingers (3 or 4) moved a third of the pad left, right, up or down
#   pinch N DIR  N fingers drawn together (in) or spread apart (out)
# Run it as a unit: systemd-run --unit=fake-touchpad python3 /root/fake-touchpad.py
import os, time
from evdev import UInput, AbsInfo, ecodes as e

W, H, RES = 1200, 800, 12
cap = {
    e.EV_KEY: [e.BTN_LEFT, e.BTN_TOOL_FINGER, e.BTN_TOUCH, e.BTN_TOOL_DOUBLETAP, e.BTN_TOOL_TRIPLETAP, e.BTN_TOOL_QUADTAP],
    e.EV_ABS: [
        (e.ABS_X, AbsInfo(0, 0, W, 0, 0, RES)), (e.ABS_Y, AbsInfo(0, 0, H, 0, 0, RES)),
        (e.ABS_MT_SLOT, AbsInfo(0, 0, 4, 0, 0, 0)),
        (e.ABS_MT_POSITION_X, AbsInfo(0, 0, W, 0, 0, RES)), (e.ABS_MT_POSITION_Y, AbsInfo(0, 0, H, 0, 0, RES)),
        (e.ABS_MT_TRACKING_ID, AbsInfo(0, 0, 65535, 0, 0, 0)),
    ],
}
ui = UInput(cap, name="Ambrosia Test Touchpad", vendor=0x1d6b, product=0x0a0b, input_props=[e.INPUT_PROP_POINTER, e.INPUT_PROP_BUTTONPAD])
TOOL = {1: e.BTN_TOOL_FINGER, 2: e.BTN_TOOL_DOUBLETAP, 3: e.BTN_TOOL_TRIPLETAP, 4: e.BTN_TOOL_QUADTAP}
next_id = 1

def down(points):
    global next_id
    for slot, (x, y) in enumerate(points):
        ui.write(e.EV_ABS, e.ABS_MT_SLOT, slot)
        ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, next_id); next_id += 1
        ui.write(e.EV_ABS, e.ABS_MT_POSITION_X, x); ui.write(e.EV_ABS, e.ABS_MT_POSITION_Y, y)
    ui.write(e.EV_ABS, e.ABS_X, points[0][0]); ui.write(e.EV_ABS, e.ABS_Y, points[0][1])
    ui.write(e.EV_KEY, e.BTN_TOUCH, 1); ui.write(e.EV_KEY, TOOL[len(points)], 1); ui.syn()

def move(points):
    for slot, (x, y) in enumerate(points):
        ui.write(e.EV_ABS, e.ABS_MT_SLOT, slot)
        ui.write(e.EV_ABS, e.ABS_MT_POSITION_X, x); ui.write(e.EV_ABS, e.ABS_MT_POSITION_Y, y)
    ui.write(e.EV_ABS, e.ABS_X, points[0][0]); ui.write(e.EV_ABS, e.ABS_Y, points[0][1]); ui.syn()

def up(n):
    for slot in range(n):
        ui.write(e.EV_ABS, e.ABS_MT_SLOT, slot); ui.write(e.EV_ABS, e.ABS_MT_TRACKING_ID, -1)
    ui.write(e.EV_KEY, e.BTN_TOUCH, 0); ui.write(e.EV_KEY, TOOL[n], 0); ui.syn()

def fingers(n, y=350):
    return [(500 + 180 * i, y) for i in range(n)]

def glide(start, end, steps=30):
    """Fingers down at `start`, moved evenly to `end`, and lifted."""
    down(start); time.sleep(0.08)
    for i in range(1, steps + 1):
        move([(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps)) for (x0, y0), (x1, y1) in zip(start, end)])
        time.sleep(0.012)
    time.sleep(0.05); up(len(start))

def ring(n, radius):
    """N fingers round the pad's middle: three across the top, the thumb below."""
    import math
    angles = [200, 250, 290, 340, 90][:n - 1] + [90]
    return [(round(W / 2 + radius * math.cos(math.radians(a))), round(H / 2 + radius * math.sin(math.radians(a)))) for a in angles]

def press(points):
    down(points); time.sleep(0.25)
    ui.write(e.EV_KEY, e.BTN_LEFT, 1); ui.syn(); time.sleep(0.12)
    ui.write(e.EV_KEY, e.BTN_LEFT, 0); ui.syn(); time.sleep(0.12)
    up(len(points))

fifo = "/run/fake-touchpad"
if not os.path.exists(fifo):
    os.mkfifo(fifo)
while True:
    with open(fifo) as f:
        for line in f:
            cmd = line.split()
            if not cmd: continue
            n = int(cmd[1]) if len(cmd) > 1 else 1
            if cmd[0] == "tap":
                down(fingers(n)); time.sleep(0.06); up(n)
            elif cmd[0] == "click":
                press(fingers(n))
            elif cmd[0] == "corner":
                press([(W - 80, H - 40)])
            elif cmd[0] == "swipe":
                dx, dy = {"left": (-400, 0), "right": (400, 0), "up": (0, -270), "down": (0, 270)}[cmd[2]]
                pts = [(420 + 130 * i, 400) for i in range(n)]
                glide(pts, [(x + dx, y + dy) for x, y in pts])
            elif cmd[0] == "pinch":
                small, large = ring(n, 110), ring(n, 330)
                glide(large, small) if cmd[2] == "in" else glide(small, large)
            elif cmd[0] == "scroll":
                pts = fingers(2, 300); down(pts); time.sleep(0.1)
                for i in range(1, 21):
                    move([(x, y + n * i // 20) for x, y in pts]); time.sleep(0.015)
                time.sleep(0.05); up(2)
            elif cmd[0] == "pull":
                pts = fingers(2, 400 - n // 2); down(pts); time.sleep(0.1)
                for i in range(1, 21):
                    move([(x, y + n * i // 20) for x, y in pts]); time.sleep(0.015)
                time.sleep(int(cmd[2]) / 1000 if len(cmd) > 2 else 1); up(2)
            elif cmd[0] == "flick":
                pts = fingers(2, 400 - n // 2); down(pts); time.sleep(0.1)
                for i in range(1, 11):
                    move([(x, y + n * i // 10) for x, y in pts]); time.sleep(0.01)
                up(2)
            elif cmd[0] == "across":
                pts = [(600 - n // 2 + 180 * i, 400) for i in range(2)]; down(pts); time.sleep(0.1)
                for i in range(1, 21):
                    move([(x + n * i // 20, y) for x, y in pts]); time.sleep(0.015)
                time.sleep(0.05); up(2)
            time.sleep(0.4)
