#!/usr/bin/env python3
"""Procedural CC0 audio for GHOST TRAIN. Deterministic. Needs numpy."""
import os, wave
import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
rng = np.random.default_rng(1337)

def n_(d): return int(round(d * SR))
def tt(d): return np.arange(n_(d)) / SR
def noise(n): return rng.standard_normal(n)

def filt(x, lo=None, hi=None):
    """Circular FFT band filter with soft edges (keeps loops periodic)."""
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo: m *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi: m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m, len(x))

def lp(x, hi): return filt(x, None, hi)
def hp(x, lo): return filt(x, lo, None)
def bp(x, lo, hi): return filt(x, lo, hi)

def pf(f, d):  # frequency with integer cycles over d
    return max(1, round(f * d)) / d

def sine(f, d, ph=0.0): return np.sin(2 * np.pi * f * tt(d) + ph)

def ex(n, tau): return np.exp(-np.arange(n) / SR / tau)

def fade(x, a=0.005, b=0.02):
    x = x.copy(); na, nb = int(a * SR), int(b * SR)
    if na: x[:na] *= np.linspace(0, 1, na)
    if nb: x[-nb:] *= np.linspace(1, 0, nb)
    return x

def smooth_rand(n, rate, d=None):
    """Periodic smooth random curve, ~rate points/sec, range 0..1."""
    k = max(2, int(round(rate * n / SR)))
    pts = rng.random(k)
    xs = np.arange(n) / n * k
    i = xs.astype(int) % k; fr = xs - np.floor(xs)
    fr = fr * fr * (3 - 2 * fr)
    return pts[i] * (1 - fr) + pts[(i + 1) % k] * fr

def put(buf, snd, pos, wrap=True):
    n = len(buf); idx = (pos + np.arange(len(snd)))
    if wrap: np.add.at(buf, idx % n, snd)
    else:
        ok = idx < n; buf[idx[ok]] += snd[ok]

def echo(x, delay=0.18, fb=0.4, taps=4, wrap=True):
    out = x.copy()
    for i in range(1, taps + 1):
        d = int(delay * i * SR); g = fb ** i
        out += g * (np.roll(x, d) if wrap else np.concatenate([np.zeros(d), x])[:len(x)])
    return out

def norm(x, db):
    x = x - np.mean(x)
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (db / 20)

def save(sub, name, x, db):
    p = os.path.join(ROOT, sub); os.makedirs(p, exist_ok=True)
    y = np.clip(norm(x, db), -1, 1)
    with wave.open(os.path.join(p, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((y * 32767).astype("<i2").tobytes())

def loop(name, x, sub="sounds"):
    x = x - np.mean(x); k = 120  # ramp first samples so end->start has no step
    x = x.copy(); x[:k] += (x[-1] - x[0]) * np.linspace(1, 0, k)
    save(sub, name + "_loop", x, -6)
def shot(name, x, sub="sounds"): save(sub, name, fade(x, 0.002, 0.01), -4)

# ---------- one-shot building blocks ----------
def thump(d, f0=90, f1=40, tau=0.08):
    n = n_(d); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * ex(n, tau)

def burst(d, lo, hi, tau):
    n = n_(d); return bp(noise(n), lo, hi) * ex(n, tau)

def click(d=0.02, f=2500): return burst(d, f * 0.5, f * 1.5, d / 4)

def ring(f, d, tau, ph=0.0):
    return sine(f, d, ph) * ex(n_(d), tau)

def creak(d, f0, f1, q=0.3, harm=3):
    n = n_(d); t = np.arange(n) / SR
    wob = smooth_rand(n, 12) - 0.5
    f = np.linspace(f0, f1, n) * (1 + 0.15 * wob)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(ph * k + k) / k for k in range(1, harm + 1))
    am = (0.4 + 0.6 * smooth_rand(n, 25)) ** 2
    x = x * am + 0.3 * lp(noise(n), 2000) * am
    e = np.minimum(1, np.minimum(t / 0.05, (d - t) / (d * 0.4)))
    return x * e

# ================= LOOPS =================
def engine():
    d = 4; n = n_(d); b = np.zeros(n)
    cyc = 8  # chuffs in 4 s -> 2 Hz; pairs for a 4-beat steam rhythm
    for i in range(cyc):
        p = int(i * n / cyc); a = 1.0 if i % 2 == 0 else 0.65
        put(b, a * burst(0.28, 150, 1800, 0.07) * 1.0, p)
        put(b, a * thump(0.25, 70, 38, 0.1) * 0.8, p)
    rum = lp(noise(n), 90) * 6 + sum(sine(pf(f, d), d) * 0.3 for f in (28, 42, 56))
    hiss = hp(noise(n), 3000) * 0.04
    return b + rum + hiss

def wheels():
    d = 3; n = n_(d); b = np.zeros(n); hits = 6
    for i in range(hits):
        p = int(i * n / hits)
        for k, off in enumerate((0, 0.13)):  # clack-clack
            g = 1 if k == 0 else 0.8
            put(b, g * (burst(0.12, 800, 3500, 0.02) + 0.7 * thump(0.12, 120, 60, 0.03) + 0.5 * ring(pf(310 + 40 * k, .12), .12, .03)), p + int(off * SR))
    return b + lp(noise(n), 250) * 0.4 + bp(noise(n), 300, 900) * 0.05

def wind():
    d = 8; n = n_(d)
    g1 = smooth_rand(n, 0.8) ** 1.5; g2 = smooth_rand(n, 1.7)
    a = bp(noise(n), 150, 700) * g1 * 2 + bp(noise(n), 500, 1800) * g2 * g1 * 0.9
    return a + lp(noise(n), 120) * 0.8

def rain():
    d = 6; n = n_(d)
    x = hp(lp(noise(n), 7000), 800) * 0.8 + lp(noise(n), 400) * 0.3
    drops = np.zeros(n)
    for _ in range(260):
        put(drops, rng.random() * click(0.01, rng.uniform(3000, 6000)) * 1.2, int(rng.integers(n)))
    return x + drops * 0.4

def static():
    d = 4; n = n_(d); t = tt(d)
    x = noise(n) * (0.4 + 0.6 * smooth_rand(n, 9)) + 0.3 * hp(noise(n), 4000)
    for f, r in ((pf(440, d), 3), (pf(1250, d), 5), (pf(2100, d), 2)):
        w = (smooth_rand(n, r) - 0.5) * 60
        x += 0.12 * np.sin(2 * np.pi * f * t + w) * smooth_rand(n, 1.5) ** 2
    cr = np.zeros(n)
    for _ in range(40): put(cr, rng.uniform(.5, 2) * click(0.004, 4000), int(rng.integers(n)))
    return bp(x, 200, 6000) + cr * 0.8

def generator():
    d = 3; n = n_(d); t = tt(d)
    x = sum(sine(50 * k, d, k) * a for k, a in ((1, 1), (2, .6), (3, .45), (4, .25), (6, .18), (8, .1)))
    x *= 1 + 0.1 * np.sin(2 * np.pi * (1 / d) * 4 * t)
    rat = np.zeros(n)
    for i in range(30): put(rat, 0.5 * burst(0.03, 600, 3000, 0.008), int(i * n / 30 + rng.integers(-300, 300)))
    return x * 0.5 + rat * 0.5 + lp(noise(n), 400) * 0.15

def drone():
    d = 12; n = n_(d); t = tt(d); x = np.zeros(n)
    for f, a in ((55, 1), (55.4, .9), (82.4, .5), (82.9, .4), (110.3, .25), (41.2, .6), (58.3, .15)):
        x += a * np.sin(2 * np.pi * pf(f, d) * t + rng.random() * 6) * (0.7 + 0.3 * np.sin(2 * np.pi * t / d * rng.integers(1, 4) + rng.random() * 6))
    x += lp(noise(n), 200) * 0.8
    return x

def whisper():
    d = 6; n = n_(d); x = np.zeros(n)
    base = bp(noise(n), 1200, 5000)
    syl = np.zeros(n)
    for _ in range(26):
        dur = rng.uniform(.06, .2); p = int(rng.integers(n)); m = n_(dur)
        put(syl, np.hanning(m) * rng.uniform(.4, 1), p)
    sl = bp(noise(n), 500, 1500) * smooth_rand(n, 6)
    return (base * syl * (0.3 + smooth_rand(n, 3)) + 0.3 * sl * syl) * 1.0 + hp(noise(n), 4000) * 0.01

def tunnel():
    d = 10; n = n_(d)
    x = lp(noise(n), 80) * 7 + lp(noise(n), 400) * smooth_rand(n, 0.5) * 0.7
    for sec in (1.3, 3.9, 4.6, 7.7, 9.1):
        f = rng.uniform(900, 1700)
        dr = (ring(f, .12, .02) + 0.3 * ring(f * 1.5, .12, .02)) * np.minimum(1, np.linspace(0, 1, n_(.12)) * 40)
        e = np.zeros(n); put(e, echo(np.pad(dr, (0, n_(1.8))), .27, .55, 5, False), int(sec * SR))
        x += e * 0.7
    return x

def forest():
    d = 12; n = n_(d)
    x = bp(noise(n), 120, 600) * smooth_rand(n, 0.4) ** 1.5 * 1.2 + lp(noise(n), 100) * 0.5
    for sec in (2.5, 7.0):
        c = creak(.6, rng.uniform(300, 500), rng.uniform(500, 800), harm=2) * .5; put(x, c, int(sec * SR))
    for sec in (5.0, 10.0):
        h = np.concatenate([ring(rng.choice([260, 300]), .35, .2) * np.hanning(n_(.35)), np.zeros(n_(.05)),
                            ring(220, .5, .25) * np.hanning(n_(.5))]) * 0.35
        put(x, echo(np.pad(h, (0, n_(1.5))), .4, .4, 3, False), int(sec * SR))
    return x

def heartbeat():
    d = 1.6; n = n_(d); x = np.zeros(n)
    put(x, thump(.3, 70, 38, .07), int(.05 * n_(1)))
    put(x, thump(.3, 62, 34, .08) * .75, int(.32 * SR))
    return x + lp(noise(n), 60) * 0.03

def signal_hum():
    d = 4; n = n_(d); t = tt(d); x = np.zeros(n)
    for f in (1320, 1327, 1810, 1822, 2410, 2395, 3050):
        trem = 0.5 + 0.5 * np.sin(2 * np.pi * round(rng.uniform(2, 7)) / d * t + rng.random() * 6)
        x += np.sin(2 * np.pi * pf(f, d) * t + rng.random() * 6) * trem * 0.3
    cr = np.zeros(n)
    for _ in range(50): put(cr, click(0.003, 5000) * rng.uniform(.3, 1), int(rng.integers(n)))
    return x + cr * 0.4 + hp(noise(n), 5000) * 0.02

# ================= ONE-SHOTS =================
def make_oneshots():
    # horn
    d = 2.5; n = n_(d)
    h = sum(sine(f, d) * a for f, a in ((392, 1), (493.9, .8), (587.3, .7), (784, .3))) * (1 + 0.01 * sine(5, d))
    h = h + lp(noise(n), 3000) * 0.15
    h *= np.minimum(1, np.arange(n) / SR / 0.15) * np.minimum(1, (d - tt(d)) / 1.0)
    shot("horn", h)
    shot("creak1", creak(1.2, 380, 720)); shot("creak2", creak(1.5, 650, 330, harm=4))
    shot("door_open", creak(.9, 300, 520, harm=3) + 0.2 * lp(noise(n_(.9)), 400) * ex(n_(.9), .5))
    shot("door_close", thump(.5, 110, 45, .09) + 0.6 * burst(.5, 100, 900, .06))
    dl = np.zeros(n_(.4))
    for p in (0, .07, .15, .2, .31): put(dl, burst(.07, 600, 3500, .015) + .5 * ring(900, .07, .02), int(p * SR), False)
    shot("door_locked", dl)
    for i in range(4):
        shot(f"step{i+1}", burst(.25, 300 + 60 * i, 4500 - 300 * i, .04 + .005 * i) + 0.5 * thump(.25, 100 - 6 * i, 50, .05) + 0.4 * hp(burst(.25, 2000, 6000, .02), 2000))
    for i in range(3):
        shot(f"step_wood{i+1}", thump(.25, 150 - 10 * i, 70, .04) + 0.6 * burst(.25, 200, 1400 + 150 * i, .03) + .3 * ring(220 + 30 * i, .25, .05))
    for i in range(2):
        shot(f"creature_step{i+1}", thump(.4, 70 - 8 * i, 30, .11) + .8 * burst(.4, 80, 700 + 200 * i, .08) + .3 * bp(noise(n_(.4)), 1500, 3000) * ex(n_(.4), .02))
    shot("clunk", ring(210, .5, .12) + .7 * ring(547, .5, .08) + .5 * ring(1130, .5, .05) + burst(.5, 1000, 5000, .01))
    lv = np.zeros(n_(.7))
    for i in range(5): put(lv, click(.02, 3000 + 100 * i), int((0.03 + .07 * i) * SR), False)
    put(lv, ring(160, .3, .08) + .6 * burst(.3, 200, 3000, .03), int(.4 * SR), False)
    shot("lever", lv)
    shot("switch", click(.15, 3200) * 1.0 + .5 * ring(1800, .15, .01))
    pk = ring(880, .2, .06) + .4 * ring(1320, .2, .04)
    shot("pickup", pk * np.minimum(1, np.arange(len(pk)) / 60))
    cr = np.zeros(n_(.9))
    for p in (0, .2, .4, .55, .75):
        put(cr, burst(.1, 800, 4000, .015) + ring(1700 + p * 300, .1, .03) + .5 * thump(.1, 200, 100, .02), int(p * SR), False)
    shot("craft", cr)
    shot("ui_click", click(.08, 2200) + .4 * ring(1100, .08, .015))
    shot("ui_hover", ring(1500, .05, .012) * .5 + click(.05, 3500) * .3)
    shot("hurt", thump(.4, 100, 40, .1) + .6 * bp(noise(n_(.4)), 200, 2500) * ex(n_(.4), .1))
    n = n_(.6); t = tt(.6); f = 440 + 440 * t / .6
    shot("heal", np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / .6) ** 1.5 + .3 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * np.sin(np.pi * t / .6))
    d = 2.0; t = tt(d)
    sc = sum(np.sin(2 * np.pi * f * t + rng.random() * 6) * a for f, a in ((110, 1), (116.5, .9), (164.8, .5), (233, .4), (311.1, .3), (329, .2)))
    sc = sc * np.sin(np.pi * t / d) ** 2 + .2 * lp(noise(n_(d)), 800) * np.sin(np.pi * t / d)
    shot("scare", sc)
    d = 2.0; b = np.zeros(n_(d)); t = tt(d)
    for r, a in ((1, 1), (2.76, .6), (5.4, .4), (8.93, .25), (1.52, .5)):
        b += a * np.sin(2 * np.pi * 330 * r * t) * np.exp(-t / (1.0 / (0.6 + r * 0.25)))
    shot("bell", b + .3 * burst(d, 1000, 5000, .01))
    r = (ring(1000, .3, .08) * (tt(.3) < .08) + ring(1400, .3, .08) * (tt(.3) >= .1) * (tt(.3) < .2)) + .3 * click(.3, 3000)
    shot("radio_blip", r * 1.0 + 0.1 * bp(noise(n_(.3)), 500, 3000) * (tt(.3) < .2))
    d = 1.5; n = n_(d); t = tt(d); f = 70 + 25 * np.sin(2 * np.pi * 0.9 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR; saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    g = lp(saw, 700) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 28 * t)) * .5) + .4 * bp(noise(n), 100, 600)
    shot("growl", g * np.sin(np.pi * t / d) ** .6)
    d = 1.8; n = n_(d); t = tt(d); f = 700 + 500 * np.sin(np.pi * t / d) ** 1.5 + 12 * np.sin(2 * np.pi * 6 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = np.sin(ph) + .3 * np.sin(2 * ph + 1) + .2 * np.sin(1.01 * ph * 1.5) + .15 * bp(noise(n), 1500, 4000)
    shot("hollow_cry", w * np.sin(np.pi * t / d) ** 1.5)
    shot("bang", ring(140, .6, .15) + .8 * ring(310, .6, .12) + .6 * ring(780, .6, .07) + burst(.6, 500, 6000, .015) * 1.5 + thump(.6, 100, 50, .05))
    d = 1.5; n = n_(d); t = tt(d)
    shot("valve", hp(lp(noise(n), 9000), 2500) * np.minimum(1, t / .08) * np.minimum(1, (d - t) / .8) * (1 + .3 * np.sin(2 * np.pi * 7 * t)) + .3 * lp(noise(n), 500) * np.minimum(1, t / .1) * np.minimum(1, (d - t) / .5))
    rp = np.zeros(n_(1.0))
    for i in range(8): put(rp, click(.02, 2800) + .4 * ring(1600, .02, .01), int((.05 + .11 * i) * SR), False)
    put(rp, ring(240, .15, .05) + burst(.15, 300, 2500, .03), int(.9 * SR - n_(.15)), False)
    shot("repair", rp)
    kb = ring(1760, .1, .1) * np.minimum(1, np.arange(n_(.1)) / 30); shot("keypad_beep", kb)
    d = .3; t = tt(d); sq = np.sign(np.sin(2 * np.pi * 80 * t)) + .5 * np.sign(np.sin(2 * np.pi * 120 * t))
    shot("error", lp(sq, 900) * np.minimum(1, (d - t) / .08))

# ================= MUSIC =================
def mnote(f, d_total, vel=1.0, tau=1.8):
    """music-box / detuned piano-ish tone with long decay."""
    n = n_(min(d_total, tau * 5)); t = np.arange(n) / SR; x = np.zeros(n)
    for k, a, dt in ((1, 1, 1.0), (2, .35, .6), (3, .15, .4), (4.02, .12, .25), (6.1, .06, .15)):
        x += a * np.sin(2 * np.pi * f * k * t + rng.random()) * np.exp(-t / (tau * dt))
        x += a * .5 * np.sin(2 * np.pi * f * 1.004 * k * t) * np.exp(-t / (tau * dt))  # detune
    x *= np.minimum(1, t / .004)
    return x * vel

def pad(freqs, d, tr=0.0, pan_lfo=None):
    t = tt(d); x = np.zeros(n_(d))
    for f in freqs:
        for dt in (-.25, 0, .3):
            ff = pf(f + dt, d)
            x += np.sin(2 * np.pi * ff * t + rng.random() * 6) + 0.3 * np.sin(2 * np.pi * 2 * ff * t + rng.random() * 6)
    return x

def note(m): return 440 * 2 ** ((m - 69) / 12)

def chord_pad(chords, d_each, total):
    n = n_(total); x = np.zeros(n); seg = n_(d_each)
    for i, ch in enumerate(chords):
        p = pad([note(m) for m in ch], d_each)
        w = np.sin(np.pi * np.arange(seg) / seg) ** 2  # overlapping hann-like swell
        put(x, p * w, i * seg - seg // 2)
    # normalize overlap: chords overlap by half so hann^2 sums to 1
    return x

def music_menu():
    d = 48; n = n_(d); x = np.zeros(n)
    # A minor: Am, F, C, Em ... each 6 s
    chords = [[45, 57, 60, 64], [41, 53, 57, 60], [48, 55, 60, 64], [40, 52, 55, 59]] * 2
    x += 0.5 * chord_pad(chords, 6, d) * 0.12
    x += 0.5 * sine(pf(55, d), d) * 0.5 + lp(noise(n), 150) * 0.15 * smooth_rand(n, .3)
    mel = [(0, 76), (3, 72), (4.5, 69), (6, 72), (9, 77), (10.5, 76), (12, 72), (15, 69), (18, 72), (19.5, 76), (21, 79), (24, 76), (27, 74), (28.5, 72), (30, 71), (33, 72), (36, 76), (37.5, 72), (39, 69), (42, 71), (44, 64), (45.5, 67)]
    for s, m in mel:
        nt = mnote(note(m), 8, .55, 1.6); put(x, echo(np.pad(nt, (0, n_(1))), .5, .35, 3, False), int(s * SR))
    return x

def music_chase():
    d = 16; n = n_(d); t = tt(d); x = np.zeros(n); beat = d / 32  # 0.5s
    pat = [33, 33, 45, 33, 33, 36, 33, 34]  # A1 ostinato with b2
    for i in range(32):
        m = pat[i % 8] + (0 if i < 16 else 0)
        f = note(m); nn = n_(beat * .9); tn = np.arange(nn) / SR
        saw = 2 * ((f * tn) % 1) - 1
        put(x, lp(saw, 500 + 400 * (i % 4 == 0)) * ex(nn, .18) * (1 if i % 4 == 0 else .7), int(i * beat * SR))
    for i in range(16):  # pulse kick
        put(x, thump(.3, 80, 38, .09) * .9, int(i * beat * 2 * SR))
    for i in range(32): put(x, burst(.08, 3000, 8000, .02) * .12, int((i + .5) * beat * SR))
    x += .15 * (sine(pf(110, d), d) * (0.5 + 0.5 * np.sin(2 * np.pi * 8 * t / d * 1)) + sine(pf(116.5, d), d) * .5)
    x += chord_pad([[45, 52, 57], [46, 53, 58], [45, 52, 57], [44, 51, 56]], 4, d) * .02
    return x

def music_ending():
    d = 32; n = n_(d); x = np.zeros(n)
    chords = [[48, 55, 64], [45, 52, 60, 64], [41, 53, 57, 65], [43, 55, 59, 62]] * 2
    x += chord_pad(chords, 4, d) * .1
    x += lp(sine(pf(65.4, d), d), 200) * .4
    mel = [(0, 76), (2, 79), (4, 72), (6, 76), (8, 77), (10, 76), (12, 72), (14, 74), (16, 79), (18, 81), (20, 77), (22, 72), (24, 74), (26, 71), (28, 72), (30.5, 67)]
    for s, m in mel:
        nt = mnote(note(m), 6, .45, 1.4); put(x, echo(np.pad(nt, (0, n_(1))), .45, .3, 3, False), int(s * SR))
    return x

def music_travel():
    d = 32; n = n_(d); x = np.zeros(n); t = tt(d)
    x += chord_pad([[38, 45, 50, 53], [37, 44, 50, 53], [38, 45, 49, 53], [36, 43, 48, 54]] * 2, 4, d) * .1
    x += sine(pf(36.7, d), d) * .5 * (.6 + .4 * np.sin(2 * np.pi * 2 * t / d))
    x += bp(noise(n), 200, 900) * smooth_rand(n, .25) * .25
    for s, m in ((6, 74), (14.5, 77), (23, 73)):
        nt = mnote(note(m), 6, .15, 2.2); put(x, echo(np.pad(nt, (0, n_(1.5))), .8, .4, 2, False), int(s * SR))
    return x

if __name__ == "__main__":
    loop("engine", engine()); loop("wheels", wheels()); loop("wind", wind()); loop("rain", rain())
    loop("static", static()); loop("generator", generator()); loop("drone", drone())
    loop("whisper", whisper()); loop("tunnel", tunnel()); loop("forest", forest())
    loop("heartbeat", heartbeat()); loop("signal_hum", signal_hum())
    make_oneshots()
    for nm, fn in (("menu_theme", music_menu), ("chase_theme", music_chase), ("ending_theme", music_ending), ("travel_theme", music_travel)):
        loop(nm, fn(), "music")
    print("audio done")
