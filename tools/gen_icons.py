#!/usr/bin/env python3
"""32x32 pixel-art item icons + 128x128 app icon. Deterministic. Needs numpy."""
import os, struct, zlib, math
import numpy as np

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")

def write_png(path, a):
    h, w, _ = a.shape
    raw = b"".join(b"\x00" + a[y].astype(np.uint8).tobytes() for y in range(h))
    def ch(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + ch(b"IDAT", zlib.compress(raw, 9)) + ch(b"IEND", b""))

def C(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OUTLINE = C("14110f")
STEEL, STEEL_L, STEEL_D = C("8a9098"), C("b4bac2"), C("565c66")
WOOD, WOOD_L, WOOD_D = C("7a5232"), C("9a6c44"), C("4e3220")
RED, RED_L, RED_D = C("9a2a24"), C("c24a3c"), C("62161a")
BRASS, BRASS_L, BRASS_D = C("b08a3a"), C("d8b45a"), C("6e5424")
GREY, GREY_D = C("6b6b6b"), C("3c3c40")
WHITE, CREAM = C("e4dfd2"), C("cdbf96")
GREEN, GREEN_D = C("3f7a4a"), C("24472c")
YEL = C("e8c64a")

class Canvas:
    def __init__(self, n=32): self.n = n; self.a = np.zeros((n, n, 4), np.uint8)
    def px(self, x, y, c):
        if 0 <= x < self.n and 0 <= y < self.n: self.a[int(y), int(x)] = c
    def rect(self, x0, y0, x1, y1, c):  # inclusive
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): self.px(x, y, c)
    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) or 1
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
            for dx in range(w):
                for dy in range(w): self.px(x + dx, y + dy, c)
    def circle(self, cx, cy, r, c, fill=True, thick=1):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                d = math.hypot(x - cx, y - cy)
                if (fill and d <= r) or (not fill and r - thick < d <= r): self.px(x, y, c)
    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= y + .5 < y1) or (y1 <= y + .5 < y0):
                    xs.append(x0 + (y + .5 - y0) / (y1 - y0) * (x1 - x0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1]))): self.px(x, y, c)
    def outline(self):
        al = self.a[..., 3] > 0; out = self.a.copy()
        for y in range(self.n):
            for x in range(self.n):
                if not al[y, x]:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < self.n and 0 <= yy < self.n and al[yy, xx]: out[y, x] = OUTLINE; break
        self.a = out
    def gear(self, cx, cy, ro, ri, teeth, c, hole=2, hc=None, hl=None):
        for y in range(int(cy - ro - 1), int(cy + ro + 2)):
            for x in range(int(cx - ro - 1), int(cx + ro + 2)):
                dx, dy = x - cx, y - cy; d = math.hypot(dx, dy)
                ang = math.atan2(dy, dx); tooth = math.cos(ang * teeth) > -.15
                if d <= (ro if tooth else ri) and d >= hole: self.px(x, y, c)
        if hl: self.circle(cx - 1, cy - 1, ri - 1, hl, False)

def tool_handle(cv, x0, y0, x1, y1, w=3, c=WOOD, l=WOOD_L):
    cv.line(x0, y0, x1, y1, c, w); cv.line(x0, y0, x1, y1, l, 1)

def ic_flashlight(cv, glow=False):
    cv.poly([(6, 22), (10, 26), (26, 12), (22, 8)], C("3c4048"))
    cv.poly([(14, 17), (18, 21), (24, 15), (20, 11)], C("5a606a"))
    cv.line(11, 21, 17, 15, C("7a808a"))
    cv.poly([(21, 7), (25, 11), (29, 7), (25, 3)], STEEL_D)  # head
    cv.line(22, 6, 26, 2, STEEL_L)
    cv.line(23, 8, 27, 8, C("f0e6a0"), 1)
    cv.px(26, 6, C("fff6c0"))
    if glow:
        for p in ((30, 2), (29, 5), (31, 4), (27, 1), (30, 8)): cv.px(*p, YEL)
        cv.rect(2, 4, 8, 4, YEL); cv.rect(5, 1, 5, 7, YEL)  # plus
def ic_flashlight_plus(cv): ic_flashlight(cv, True)

def ic_hammer(cv):
    tool_handle(cv, 8, 27, 22, 10, 3)
    cv.rect(9, 3, 25, 9, STEEL_D); cv.rect(9, 3, 25, 5, STEEL); cv.rect(9, 3, 24, 3, STEEL_L)
    cv.poly([(25, 3), (29, 5), (29, 9), (25, 9)], STEEL_D)
def ic_wrench(cv):
    cv.line(9, 24, 21, 12, STEEL, 4); cv.line(9, 24, 21, 12, STEEL_L, 1)
    cv.circle(23, 9, 6, STEEL); cv.circle(25, 7, 3, (0, 0, 0, 0)); cv.poly([(24, 3), (30, 3), (28, 9), (24, 7)], (0, 0, 0, 0))
    cv.circle(7, 26, 3, STEEL_D)
def ic_screwdriver(cv):
    cv.line(6, 26, 17, 15, RED, 5); cv.line(6, 26, 17, 15, RED_L, 1)
    cv.line(17, 15, 27, 5, STEEL, 2); cv.line(17, 15, 27, 5, STEEL_L, 1); cv.rect(26, 3, 28, 6, STEEL_D)
def ic_crowbar(cv):
    cv.line(6, 5, 24, 26, STEEL_D, 3); cv.line(6, 5, 24, 26, STEEL, 1)
    cv.poly([(24, 24), (28, 28), (30, 22), (27, 21)], STEEL_D); cv.line(4, 3, 8, 8, STEEL, 2)
    cv.px(3, 3, STEEL_L)
def ic_pliers(cv):
    cv.line(8, 6, 20, 20, STEEL, 3); cv.line(22, 6, 10, 20, STEEL_D, 3)
    cv.line(9, 22, 6, 29, RED, 3); cv.line(21, 22, 25, 29, RED, 3); cv.line(9, 22, 6, 29, RED_L, 1)
    cv.circle(15, 13, 2, STEEL_L); cv.px(15, 13, STEEL_D)
def ic_medkit(cv):
    cv.rect(3, 9, 28, 26, RED); cv.rect(3, 9, 28, 11, RED_L); cv.rect(3, 24, 28, 26, RED_D)
    cv.rect(11, 5, 20, 8, GREY); cv.rect(13, 6, 18, 8, (0, 0, 0, 0))
    cv.rect(14, 13, 17, 23, WHITE); cv.rect(10, 16, 21, 20, WHITE)
def ic_bandage(cv):
    cv.circle(14, 16, 10, CREAM); cv.circle(14, 16, 4, (0, 0, 0, 0)); cv.circle(14, 16, 10, WHITE, False)
    cv.circle(14, 16, 7, C("b4a67c"), False)
    cv.poly([(22, 18), (30, 20), (30, 25), (20, 24)], CREAM); cv.line(23, 20, 29, 22, C("b4a67c"))
    cv.rect(12, 9, 13, 10, C("a63a34"))
def ic_med_supplies(cv):
    cv.rect(9, 10, 22, 28, C("c26a2a")); cv.rect(9, 10, 12, 28, C("e08a3a")); cv.rect(20, 10, 22, 28, C("7a3c14"))
    cv.rect(8, 5, 23, 10, WHITE); cv.rect(8, 9, 23, 10, C("9a9488"))
    cv.rect(12, 15, 19, 22, WHITE); cv.rect(15, 16, 16, 21, RED); cv.rect(13, 18, 18, 19, RED)
def ic_cloth(cv):
    cv.poly([(4, 8), (16, 5), (28, 9), (26, 18), (29, 26), (15, 28), (5, 25), (7, 16)], C("8a826e"))
    cv.poly([(6, 9), (16, 7), (22, 9), (14, 13), (8, 15)], C("a89f88"))
    cv.line(8, 20, 24, 22, C("6a634f")); cv.line(10, 24, 22, 26, C("6a634f"))
def ic_scrap(cv):
    cv.poly([(4, 24), (10, 10), (15, 22), (12, 28)], STEEL); cv.poly([(10, 10), (15, 22), (12, 20)], STEEL_L)
    cv.poly([(15, 27), (19, 12), (27, 8), (25, 20), (22, 27)], STEEL_D); cv.poly([(19, 12), (27, 8), (22, 15)], STEEL)
    cv.poly([(17, 28), (28, 24), (29, 28)], C("7a4a30"))
def ic_wires(cv):
    for r, c in ((10, C("a63a34")), (7, C("2e5a9a")), (4, C("c0a030"))):
        cv.circle(14, 16, r, c, False, 2)
    cv.line(22, 16, 29, 10, C("a63a34"), 2); cv.line(20, 20, 29, 26, C("2e5a9a"), 2)
    cv.px(30, 9, BRASS_L); cv.px(30, 27, BRASS_L)
def ic_engine_part(cv):
    cv.rect(10, 4, 21, 8, STEEL_L); cv.rect(10, 8, 21, 10, STEEL_D); cv.rect(10, 12, 21, 14, STEEL_D)
    cv.rect(11, 10, 20, 12, STEEL); cv.rect(11, 14, 20, 22, STEEL)
    cv.rect(11, 14, 13, 22, STEEL_L); cv.rect(14, 4, 17, 8, STEEL)
    cv.rect(14, 22, 17, 25, STEEL_D); cv.circle(15, 27, 3, BRASS); cv.circle(15, 27, 1, BRASS_D)
def ic_battery(cv):
    cv.rect(6, 9, 25, 27, C("3a3f46")); cv.rect(6, 9, 25, 14, C("c8a63a")); cv.rect(6, 9, 25, 10, YEL)
    cv.rect(9, 5, 13, 8, GREY); cv.rect(19, 5, 23, 8, GREY)
    cv.rect(9, 17, 22, 24, C("52585f")); cv.rect(13, 20, 18, 21, YEL); cv.rect(15, 18, 16, 23, YEL)
def ic_fuel(cv):
    cv.rect(5, 8, 24, 28, RED); cv.rect(5, 8, 8, 28, RED_L); cv.rect(21, 8, 24, 28, RED_D)
    cv.rect(8, 11, 21, 25, RED); cv.line(8, 11, 21, 25, RED_D); cv.line(8, 25, 21, 11, RED_D)
    cv.rect(18, 4, 28, 8, RED); cv.rect(24, 3, 28, 6, GREY); cv.rect(12, 5, 14, 7, GREY_D)
    cv.rect(5, 8, 24, 9, RED_L)
def ic_fuse(cv):
    cv.rect(6, 12, 25, 20, C("9ab4b8")); cv.rect(7, 13, 24, 15, C("cfe0e0"))
    cv.rect(2, 11, 6, 21, BRASS); cv.rect(25, 11, 29, 21, BRASS); cv.rect(2, 11, 6, 13, BRASS_L); cv.rect(25, 11, 29, 13, BRASS_L)
    cv.line(7, 17, 24, 17, C("3c3c40")); cv.px(15, 17, (0, 0, 0, 0)); cv.px(16, 17, (0, 0, 0, 0))
def ic_bolts(cv):
    for (x, y) in ((6, 6), (15, 14), (5, 19)):
        cv.poly([(x, y + 2), (x + 3, y), (x + 8, y), (x + 11, y + 2), (x + 8, y + 5), (x + 3, y + 5)], STEEL)
        cv.rect(x + 3, y, x + 7, y + 1, STEEL_L); cv.rect(x + 3, y + 5, x + 7, y + 8, STEEL_D)
        cv.rect(x + 4, y + 5, x + 6, y + 8, STEEL_D)
        for k in range(y + 6, y + 9, 2): cv.line(x + 3, k, x + 7, k, C("2a2e34"))
    cv.circle(26, 24, 4, STEEL); cv.circle(26, 24, 2, (0, 0, 0, 0))
def ic_components(cv):
    cv.gear(16, 16, 12, 9, 8, STEEL, 3, hl=STEEL_L)
    cv.circle(16, 16, 3, (0, 0, 0, 0))
def ic_electronics(cv):
    cv.rect(3, 5, 28, 27, GREEN); cv.rect(3, 5, 28, 6, C("5a9a62")); cv.rect(3, 26, 28, 27, GREEN_D)
    for y in (10, 15, 20): cv.line(6, y, 14, y, C("9ac48a"))
    cv.line(14, 10, 14, 15, C("9ac48a")); cv.line(14, 20, 22, 20, C("9ac48a"))
    cv.rect(16, 9, 25, 15, C("22262c")); [cv.px(x, 8, GREY) for x in (17, 19, 21, 23)]; [cv.px(x, 16, GREY) for x in (17, 19, 21, 23)]
    cv.rect(6, 22, 8, 24, C("c26a2a")); cv.rect(11, 22, 12, 25, BRASS); cv.rect(24, 21, 26, 25, C("2e5a9a"))
def ic_spare_part(cv):
    cv.poly([(3, 6), (18, 6), (18, 11), (9, 11), (9, 26), (3, 26)], STEEL); cv.rect(3, 6, 18, 7, STEEL_L)
    cv.circle(6, 9, 1, STEEL_D); cv.circle(6, 22, 1, STEEL_D)
    cv.gear(21, 20, 8, 6, 6, BRASS, 2, hl=BRASS_L)
def ic_repair_kit(cv):
    cv.rect(3, 12, 28, 27, C("a63a34")); cv.rect(3, 12, 28, 14, RED_L); cv.rect(3, 24, 28, 27, RED_D)
    cv.rect(10, 5, 21, 11, GREY); cv.rect(12, 7, 19, 11, (0, 0, 0, 0))
    cv.rect(3, 19, 28, 20, C("2c2c30")); cv.rect(14, 18, 17, 22, BRASS); cv.rect(15, 19, 16, 21, BRASS_L)
    cv.rect(6, 15, 7, 17, STEEL_L); cv.rect(24, 15, 25, 17, STEEL_L)
def key(cv, bow, shade, light, dark):
    cv.circle(9, 9, 6, shade); cv.circle(9, 9, 3, (0, 0, 0, 0)); cv.circle(8, 8, 6, light, False)
    cv.line(13, 13, 27, 27, shade, 3); cv.line(13, 13, 27, 27, light, 1)
    cv.rect(23, 25, 28, 27, shade); cv.rect(19, 23, 22, 25, shade); cv.rect(26, 22, 28, 24, dark)
def ic_key_warehouse(cv): key(cv, 0, BRASS, BRASS_L, BRASS_D)
def ic_key_records(cv): key(cv, 0, C("a8b0b8"), C("d8dee4"), C("5a626c"))
def ic_map(cv):
    cv.poly([(3, 8), (11, 5), (11, 25), (3, 28)], C("b9a874")); cv.poly([(11, 5), (21, 8), (21, 28), (11, 25)], C("cdbf90"))
    cv.poly([(21, 8), (29, 5), (29, 25), (21, 28)], C("b0a070"))
    cv.line(6, 22, 10, 16, C("a63a34")); cv.line(13, 20, 18, 12, C("7a6a44")); cv.line(24, 12, 27, 20, C("7a6a44"))
    cv.px(17, 11, C("a63a34")); cv.px(18, 12, C("a63a34")); cv.px(16, 12, C("a63a34")); cv.px(17, 13, C("a63a34"))
def ic_radio(cv):
    cv.rect(3, 12, 27, 28, C("6a4a2e")); cv.rect(3, 12, 27, 14, WOOD_L); cv.rect(3, 26, 27, 28, WOOD_D)
    cv.rect(6, 16, 16, 24, C("c8b070")); cv.line(7, 20, 15, 20, C("3c3c40")); cv.px(11, 18, RED); cv.px(11, 19, RED)
    cv.circle(21, 17, 3, GREY); cv.circle(21, 17, 1, GREY_D); cv.circle(21, 24, 2, GREY); cv.px(21, 24, GREY_D)
    cv.line(23, 12, 29, 2, STEEL_L); cv.px(29, 1, STEEL_L)
def ic_switch_lever(cv):
    cv.rect(4, 22, 27, 28, C("4a4e56")); cv.rect(4, 22, 27, 23, STEEL); cv.rect(13, 18, 18, 22, STEEL_D)
    cv.line(15, 20, 21, 7, STEEL, 3); cv.line(15, 20, 21, 7, STEEL_L, 1); cv.circle(22, 5, 3, RED); cv.px(21, 4, RED_L)
def ic_switch_rod(cv):
    cv.line(5, 26, 26, 5, STEEL, 4); cv.line(5, 26, 26, 5, STEEL_L, 1)
    cv.rect(3, 25, 7, 29, STEEL_D); cv.rect(25, 3, 29, 7, STEEL_D)
    cv.rect(13, 16, 16, 19, BRASS)
def ic_valve_wheel(cv):
    cv.circle(16, 16, 12, RED, False, 3); cv.circle(16, 16, 12, RED_L, False, 1)
    cv.line(4, 16, 28, 16, RED, 2); cv.line(16, 4, 16, 28, RED, 2)
    cv.line(7, 7, 25, 25, RED, 2); cv.line(25, 7, 7, 25, RED, 2)
    cv.circle(16, 16, 3, RED_D); cv.px(15, 15, RED_L)
def ic_gate_gear(cv):
    cv.gear(16, 16, 14, 11, 10, C("4a4a52"), 4, hl=C("6a6a74"))
    cv.circle(16, 16, 7, C("3a3a42"), False, 2); cv.circle(16, 16, 4, (0, 0, 0, 0)); cv.circle(16, 16, 5, C("7a4a30"), False)

ICONS = dict(flashlight=ic_flashlight, flashlight_plus=ic_flashlight_plus, hammer=ic_hammer, wrench=ic_wrench,
             screwdriver=ic_screwdriver, crowbar=ic_crowbar, pliers=ic_pliers, medkit=ic_medkit, bandage=ic_bandage,
             med_supplies=ic_med_supplies, cloth=ic_cloth, scrap=ic_scrap, wires=ic_wires, engine_part=ic_engine_part,
             battery=ic_battery, fuel=ic_fuel, fuse=ic_fuse, bolts=ic_bolts, components=ic_components,
             electronics=ic_electronics, spare_part=ic_spare_part, repair_kit=ic_repair_kit, key_warehouse=ic_key_warehouse,
             key_records=ic_key_records, map=ic_map, radio=ic_radio, switch_lever=ic_switch_lever,
             switch_rod=ic_switch_rod, valve_wheel=ic_valve_wheel, gate_gear=ic_gate_gear)

def app_icon():
    n = 128; cv = Canvas(n)
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - 64, y - 60) / 90; v = max(0, 1 - d)
            cv.a[y, x] = (int(10 + 22 * v), int(12 + 24 * v), int(20 + 34 * v), 255)
    glow = np.zeros((n, n))
    for y in range(n):
        for x in range(n):
            glow[y, x] = max(0, 1 - math.hypot(x - 64, y - 52) / 46) ** 2
    cv.a[..., 0] = np.clip(cv.a[..., 0] + glow * 190, 0, 255); cv.a[..., 1] = np.clip(cv.a[..., 1] + glow * 160, 0, 255)
    cv.a[..., 2] = np.clip(cv.a[..., 2] + glow * 50, 0, 255)
    K, K2, K3 = C("0a0a0e"), C("181a22"), C("262a34")
    cv.rect(0, 112, 127, 127, C("07070a"))
    for x in range(4, 128, 12): cv.rect(x, 112, x + 5, 116, C("1a1612"))  # ties
    cv.rect(0, 112, 127, 113, C("3a3e48"))
    cv.rect(40, 14, 52, 38, K); cv.rect(38, 10, 54, 16, K)  # funnel
    cv.rect(24, 36, 104, 108, K2); cv.rect(24, 36, 40, 108, K); cv.rect(88, 36, 104, 108, K)  # boiler front
    cv.circle(64, 52, 30, K2); cv.circle(64, 52, 30, K3, False, 3)
    cv.poly([(56, 10), (72, 10), (76, 34), (52, 34)], K) if False else None
    cv.circle(64, 52, 14, C("f0d060")); cv.circle(64, 52, 9, C("fff4b0")); cv.circle(64, 52, 4, C("ffffff"))
    cv.rect(46, 84, 82, 94, K3); cv.rect(30, 98, 98, 110, K3); cv.line(34, 88, 94, 88, K, 2)  # buffer beam/plate
    cv.rect(26, 100, 36, 108, C("8a2a24")); cv.rect(92, 100, 102, 108, C("8a2a24"))  # lamps
    cv.poly([(24, 108), (104, 108), (112, 124), (16, 124)], K)  # cowcatcher
    for x in range(22, 108, 8): cv.line(x, 110, 64 + (x - 64) * 1.3, 124, K3)
    cv.outline()
    return cv.a

if __name__ == "__main__":
    for name, fn in ICONS.items():
        cv = Canvas(32); fn(cv); cv.outline(); write_png(os.path.join(ASSETS, "icons", name + ".png"), cv.a)
    write_png(os.path.join(ASSETS, "icon.png"), app_icon())
    print("icons done:", len(ICONS))
