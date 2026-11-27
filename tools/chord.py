#!/usr/bin/env python3
# chord.py KEY…: presses the keys together on a keyboard-only virtual device
# (which keyd takes for a keyboard): chord.py leftmeta leftshift q
import sys, time
from evdev import UInput, ecodes as e
keys = [getattr(e, "KEY_" + k.upper()) for k in sys.argv[1:]]
ui = UInput({e.EV_KEY: list(range(1, 128))}, name="chord keyboard")
time.sleep(1.2)
for k in keys:
    ui.write(e.EV_KEY, k, 1); ui.syn(); time.sleep(0.05)
time.sleep(0.1)
for k in reversed(keys):
    ui.write(e.EV_KEY, k, 0); ui.syn(); time.sleep(0.05)
time.sleep(0.3)
ui.close()
