#!/usr/bin/env python3
"""Times a file manager from the outside, the same way for every app: from
exec until its window says how many items the folder holds, read over AT-SPI
(Dolphin's status bar; Files' "N items", what Finder's status bar says), and
its memory a second later.

    probe.py RUNS EXPECTED -- COMMAND...

Prints one line per run, "listed_ms=… rss_mb=…" (or "timeout"). Needs a
session with a compositor and an AT-SPI bus: files/bench/gui.sh runs it in a
headless KWin.
"""
import os
import re
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, GLib  # noqa: E402

runs = int(sys.argv[1])
expected = int(sys.argv[2])
command = sys.argv[sys.argv.index("--") + 1:]
timeout_s = 30 + expected // 10000

Atspi.init()
loop = GLib.MainLoop()
state = {"done": None}

# "100,000" and "100 000" both read as 100000; any other number doesn't match.
grouping = re.compile(r"(?<=\d)[,.\u00a0\u202f ](?=\d{3}\b)")
wanted = re.compile(rf"(?<![\d]){expected}(?![\d])")


# The new name rides with the event; asking the app for it would block on an
# app busy loading, and pile events up on the bus.
def text_of(event):
    data = event.any_data
    if hasattr(data, "get_value"):
        data = data.get_value()
    return data if isinstance(data, str) else ""


def heard(event, *_):
    if state["done"] is None and wanted.search(grouping.sub("", text_of(event))):
        state["done"] = time.monotonic()
        loop.quit()


listener = Atspi.EventListener.new(heard)
listener.register("object:property-change:accessible-name")


def rss_mb(pid):
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) / 1024
    except OSError:
        pass
    return float("nan")


env = dict(os.environ, QT_LINUX_ACCESSIBILITY_ALWAYS_ON="1")
for _ in range(runs):
    state["done"] = None
    start = time.monotonic()
    # PROBE_DEBUG=1 keeps the app's own output, to see why one fails.
    quiet = None if os.environ.get("PROBE_DEBUG") else subprocess.DEVNULL
    app = subprocess.Popen(command, env=env, stdout=quiet, stderr=quiet, start_new_session=True)
    # Both stay until removed below, so neither can end a later run.
    sources = [GLib.timeout_add_seconds(timeout_s, lambda: loop.quit() or True),
               GLib.timeout_add(100, lambda: app.poll() is None or loop.quit() or True)]
    loop.run()
    for source in sources:
        GLib.source_remove(source)
    if state["done"] is None:
        print("exited" if app.poll() is not None else "timeout", flush=True)
    else:
        settle = time.monotonic() + 1
        while time.monotonic() < settle:
            GLib.MainContext.default().iteration(False)
            time.sleep(0.01)
        print(f"listed_ms={(state['done'] - start) * 1000:.0f} rss_mb={rss_mb(app.pid):.0f}", flush=True)
    # The app may be gone already (the run failed): then so is its group.
    try:
        os.killpg(app.pid, signal.SIGTERM)
        app.wait(10)
    except ProcessLookupError:
        pass
    except subprocess.TimeoutExpired:
        os.killpg(app.pid, signal.SIGKILL)
        app.wait()
    time.sleep(1)
