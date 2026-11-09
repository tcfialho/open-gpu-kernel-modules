#!/usr/bin/env python3
"""Sai (rc=0) quando nenhum teclado/mouse/touchpad gera evento por IDLE segundos. Roda como root."""
import glob, os, select, sys, time
IDLE = int(sys.argv[1]) if len(sys.argv) > 1 else 600
fds = []
for p in glob.glob("/dev/input/event*"):
    try: fds.append(os.open(p, os.O_RDONLY | os.O_NONBLOCK))
    except OSError: pass
last = time.time()
while True:
    left = IDLE - (time.time() - last)
    if left <= 0: print(f"ocioso {IDLE}s", flush=True); sys.exit(0)
    r, _, _ = select.select(fds, [], [], left)
    for fd in r:
        try:
            while os.read(fd, 4096): pass
        except BlockingIOError: pass
        last = time.time()
