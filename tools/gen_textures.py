#!/usr/bin/env python3
"""Tileable 64x64 PS1-style horror textures. Deterministic. Needs numpy."""
import os, struct, zlib
import numpy as np

S = 64
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
rng = np.random.default_rng(2024)

def write_png(path, rgb):
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].astype(np.uint8).tobytes() for y in range(h))
    def ch(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + ch(b"IDAT", zlib.compress(raw, 9)) + ch(b"IEND", b""))

def vnoise(cells):
    """Periodic value noise 0..1, S x S, `cells` lattice cells per side."""
    g = rng.random((cells, cells))
    xs = np.arange(S) / S * cells
    i = xs.astype(int); f = xs - i; f = f * f * (3 - 2 * f)
    j = (i + 1) % cells
    a = g[np.ix_(i, i)]; b = g[np.ix_(i, j)]
    c = g[np.ix_(j, i)]; d = g[np.ix_(j, j)]
    fx = f[None, :]; fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(base=4, octs=4):
    t = np.zeros((S, S)); a = 1; tot = 0
    for o in range(octs):
        t += a * vnoise(base * 2 ** o); tot += a; a *= .5
    return t / tot

def grain(p=1.0): return (rng.random((S, S)) < p).astype(float) * rng.random((S, S))

def ramp(v, cols, levels=None):
    """Map 0..1 to a posterised palette."""
    cols = np.array(cols, float); n = len(cols) if levels is None else levels
    q = np.clip((v * n).astype(int), 0, n - 1)
    idx = (q * (len(cols) - 1) / max(n - 1, 1)).round().astype(int)
    return cols[idx]

def shade(img, f): return np.clip(img * f[..., None], 0, 255)

def dither(v, amt=0.08): return np.clip(v + (rng.random(v.shape) - .5) * amt, 0, .999)

def wood():
    x = np.arange(S)[None, :]
    v = fbm(4, 3); warp = vnoise(4) * 4
    g = (np.sin((x + warp * 3 + v * 6) / S * 2 * np.pi * 6) + 1) / 2
    v = dither(.6 * g + .4 * v)
    img = ramp(v, [(38, 26, 18), (58, 40, 26), (78, 55, 36), (96, 70, 46)], 5)
    img[rng.random((S, S)) < .02] = (24, 16, 10)
    return img

def planks():
    img = wood(); h = S // 4
    for i in range(4):
        y0 = i * h
        sh = int(rng.integers(0, S)); img[y0:y0 + h] = np.roll(img[y0:y0 + h], sh, axis=1)
        img[y0:y0 + h] *= (.85 + .3 * rng.random())
        img[y0] = (18, 12, 9); img[(y0 + 1) % S] *= .75
        for _ in range(2):
            nx = int(rng.integers(S)); img[y0 + 3, nx] = (20, 20, 22); img[y0 + 3, (nx + 1) % S] = (110, 100, 90)
    return np.clip(img, 0, 255)

def metal():
    v = dither(fbm(8, 3) * .5 + .3 + grain(.3) * .1)
    img = ramp(v, [(30, 33, 38), (44, 48, 54), (58, 62, 68), (74, 78, 84)], 4)
    half = S // 2
    for y in (0, half):
        img[y] = (16, 18, 22); img[(y + 1) % S] = (78, 82, 90)
    for x in (0, half):
        img[:, x] = (16, 18, 22); img[:, (x + 1) % S] = (78, 82, 90)
    for cy in (6, half - 6, half + 6, S - 6):
        for cx in (6, half - 6, half + 6, S - 6):
            img[cy - 1:cy + 2, cx - 1:cx + 2] = (22, 24, 28)
            img[cy - 1, cx - 1] = (96, 100, 108); img[cy, cx] = (62, 66, 72); img[cy + 1, cx + 1] = (14, 14, 18)
    return img

def rust():
    v = dither(fbm(4, 4) * .8 + grain(.5) * .25, .12)
    img = ramp(v, [(40, 24, 18), (74, 38, 22), (104, 54, 28), (126, 70, 36), (58, 52, 50)], 6)
    m = vnoise(6) > .72; img[m] = (70, 66, 62)
    return img

def brick():
    img = np.zeros((S, S, 3)); img[:] = (30, 28, 28); bh, bw = 8, 16
    for r in range(S // bh):
        off = (r % 2) * bw // 2
        for c in range(S // bw):
            x0 = c * bw + off
            col = np.array([92, 44, 36]) * (.65 + .6 * rng.random())
            for y in range(r * bh + 1, r * bh + bh):
                for x in range(x0 + 1, x0 + bw):
                    img[y % S, x % S] = col * (.9 + .2 * rng.random())
    return shade(img, .75 + .5 * fbm(8, 2))

def concrete():
    v = dither(fbm(6, 4) * .8 + grain(.6) * .2, .1)
    img = ramp(v, [(52, 54, 56), (66, 68, 70), (80, 82, 82), (94, 96, 96)], 5)
    for _ in range(3):
        x, y = int(rng.integers(S)), int(rng.integers(S))
        for _ in range(14):
            img[y % S, x % S] = (28, 30, 32); x += int(rng.integers(-1, 2)); y += 1
    return img

def dirt():
    v = dither(fbm(5, 4) * .7 + grain(.8) * .3, .15)
    img = ramp(v, [(30, 22, 16), (48, 36, 26), (64, 49, 35), (82, 64, 46)], 5)
    for _ in range(40): img[rng.integers(S), rng.integers(S)] = (96, 90, 82)
    return img

def grass():
    img = ramp(dither(fbm(6, 3), .1), [(20, 26, 16), (30, 38, 20), (44, 50, 26)], 4)
    for _ in range(260):
        x, y = int(rng.integers(S)), int(rng.integers(S)); L = int(rng.integers(2, 6))
        c = [(70, 74, 38), (88, 80, 44), (40, 52, 28), (16, 20, 12)][int(rng.integers(4))]
        for k in range(L): img[(y - k) % S, (x + (k // 3)) % S] = c
    return img

def bark():
    x = np.arange(S)[None, :]; w = vnoise(4) * 5
    v = fbm(4, 3); ridge = np.abs(np.sin((x + w * 4 + v * 5) / S * np.pi * 8))
    v = dither(ridge * .7 + v * .3, .08)
    img = ramp(v, [(16, 12, 10), (34, 26, 20), (54, 42, 32), (72, 58, 44)], 5)
    return shade(img, .8 + .4 * vnoise(8))

def fabric():
    y = np.arange(S)[:, None]; x = np.arange(S)[None, :]
    weave = ((x // 2 + y // 2) % 2).astype(float)
    v = dither(.5 * fbm(4, 3) + .25 * weave + .2 * grain(.5), .08)
    img = ramp(v, [(40, 10, 14), (68, 16, 20), (92, 24, 26), (112, 36, 34)], 5)
    for _ in range(18): img[rng.integers(S), rng.integers(S)] = (30, 24, 22)
    img[vnoise(5) > .75] = (62, 42, 36)
    return img

def gravel():
    img = np.zeros((S, S, 3)); img[:] = (30, 30, 32)
    for _ in range(150):
        cx, cy = int(rng.integers(S)), int(rng.integers(S)); r = int(rng.integers(2, 5))
        b = float(rng.integers(55, 120)); col = np.array([b, b * .97, b * .92])
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    img[(cy + dy) % S, (cx + dx) % S] = col * (1 - .25 * ((dx + dy) / (2 * r + 1)))
    return img

def roof():
    img = np.zeros((S, S, 3)); rh, sw = 8, 16
    for r in range(S // rh):
        off = (r % 2) * sw // 2
        for c in range(S // sw):
            col = np.array([54, 46, 44]) * (.7 + .6 * rng.random())
            for y in range(r * rh, r * rh + rh):
                k = .55 + .45 * ((y - r * rh) / rh)
                for x in range(c * sw + off, c * sw + off + sw):
                    img[y % S, x % S] = col * k * (.9 + .2 * rng.random())
            img[r * rh:r * rh + rh, (c * sw + off) % S] = (14, 12, 12)
        img[(r * rh + rh - 1) % S] = (12, 10, 10)
    return shade(img, .8 + .4 * fbm(6, 2))

def plaster():
    v = dither(fbm(3, 4) * .85 + grain(.4) * .1, .08)
    img = ramp(v, [(74, 70, 60), (90, 86, 74), (104, 100, 86), (116, 112, 98)], 5)
    st = fbm(3, 3) > .62; img[st] = img[st] * np.array([.7, .62, .45])
    for _ in range(5):
        x = int(rng.integers(S)); y0 = int(rng.integers(S))
        for k in range(int(rng.integers(8, 24))): img[(y0 + k) % S, x] *= .65
    return img

def stone():
    img = np.zeros((S, S, 3)); img[:] = (22, 22, 26)
    for (y0, y1) in [(0, 20), (20, 44), (44, 64)]:
        x = int(rng.integers(0, 10))
        while x < S + 10:
            w = int(rng.integers(14, 26)); col = np.array([70, 72, 76]) * (.65 + .5 * rng.random())
            for y in range(y0 + 1, y1):
                for xx in range(x + 1, x + w): img[y, xx % S] = col * (.85 + .3 * rng.random())
            x += w
    return shade(img, .75 + .5 * fbm(6, 3))

def leaves():
    img = ramp(dither(fbm(8, 3), .15), [(8, 14, 12), (14, 26, 20), (22, 40, 28)], 4)
    for _ in range(320):
        x, y = int(rng.integers(S)), int(rng.integers(S)); ang = rng.random() * np.pi; L = int(rng.integers(3, 7))
        c = [(30, 58, 38), (18, 36, 26), (42, 70, 46), (10, 18, 14)][int(rng.integers(4))]
        for k in range(L):
            for s in (-1, 0, 1):
                if s == 0 or k % 2 == 0:
                    img[int(y + k * np.sin(ang) + s * np.cos(ang)) % S, int(x + k * np.cos(ang) - s * np.sin(ang)) % S] = c
    return img

def paper():
    v = dither(fbm(4, 4) * .8 + grain(.6) * .15, .1)
    img = ramp(v, [(118, 104, 70), (136, 122, 84), (152, 138, 98), (164, 150, 110)], 5)
    st = vnoise(4) > .7; img[st] = img[st] * np.array([.78, .66, .5])
    for y in range(6, S, 8): img[y] *= np.array([.8, .82, .9])
    return img

def tiles():
    img = np.zeros((S, S, 3)); T = 16; v = fbm(6, 3)
    for ty in range(S // T):
        for tx in range(S // T):
            b = 150 + 30 * rng.random()
            for y in range(T):
                for x in range(T):
                    gy, gx = ty * T + y, tx * T + x
                    c = np.array([b, b, b * .95]) * (.55 + .5 * v[gy, gx])
                    if x == 0 or y == 0: c = np.array([40, 44, 44])
                    elif x == 1 or y == 1: c = c * 1.1
                    img[gy, gx] = c
    for _ in range(6):
        x = int(rng.integers(S)); y0 = int(rng.integers(S))
        for k in range(int(rng.integers(6, 18))): img[(y0 + k) % S, x] *= .6
    return img

def asphalt():
    v = dither(fbm(6, 3) * .6 + grain(.9) * .4, .15)
    img = ramp(v, [(22, 22, 26), (34, 34, 38), (48, 48, 52), (66, 66, 70)], 5)
    for _ in range(3):
        x, y = int(rng.integers(S)), int(rng.integers(S))
        for _ in range(20):
            img[y % S, x % S] = (12, 12, 14); x += 1; y += int(rng.integers(-1, 2))
    return img

TEX = dict(wood=wood, planks=planks, metal=metal, rust=rust, brick=brick, concrete=concrete, dirt=dirt,
           grass=grass, bark=bark, fabric=fabric, gravel=gravel, roof=roof, plaster=plaster, stone=stone,
           leaves=leaves, paper=paper, tiles=tiles, asphalt=asphalt)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, fn in TEX.items():
        write_png(os.path.join(OUT, n + ".png"), np.clip(fn(), 0, 255))
    print("textures done:", len(TEX))
