#!/usr/bin/env python3
"""Sanity-check generated WAV/PNG assets."""
import glob, os, struct, wave
import numpy as np
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
tot = 0
for f in sorted(glob.glob(base + "/*/*.wav")):
    w = wave.open(f); p = w.getparams()
    x = np.frombuffer(w.readframes(p.nframes), "<i2").astype(float) / 32767
    assert (p.nchannels, p.sampwidth, p.framerate) == (1, 2, 22050), f
    tot += os.path.getsize(f); ex = ""
    if f.endswith("_loop.wav"):
        ex = f" jump={abs(x[0]-x[-1]):.4f} avgstep={np.abs(np.diff(x)).mean():.4f}"
    print(os.path.basename(f), round(p.nframes / 22050, 2), f"peak={abs(x).max():.2f}", os.path.getsize(f) // 1024, "K" + ex)
for f in sorted(glob.glob(base + "/**/*.png", recursive=True)):
    d = open(f, "rb").read(); assert d[:8] == b"\x89PNG\r\n\x1a\n", f
    wd, ht, bd, ct = struct.unpack(">IIBB", d[16:26]); tot += os.path.getsize(f)
    print(os.path.relpath(f, base), wd, ht, "ctype", ct, os.path.getsize(f), "B")
print("TOTAL", tot)
