#!/usr/bin/env python3
"""Draw the floor-native enemies: two toys per floor below the Playground.

The original ten toys are Playground things and still roam everywhere, but
each floor keeps a pair the others never see, drawn from the floor's own
material world:

    THE GYM        kettlebell (charger)    jump_rope (hopper)
    THE STEAM ROOM steam_valve (shockwave) soap_bar (sprinter)
    THE ARENA      punching_bag (creeper)  ring_bell (shooter)
    ????           static_mite (patrol)    redacted (builder)

Same grid as every enemy sheet — 32px frames, 5 columns x 5 rows:
idle 4 · walk 4 · attack 4 · hurt 2 · death 5. Hurt rows are blown out to
near-white by the harness, same as the bosses.

    python3 tools/build_floor_enemies.py
"""

import math
import os

from PIL import Image, ImageDraw

F = 32
ROW_FRAMES = [4, 4, 4, 2, 5]


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


# ── THE GYM ────────────────────────────────────────────────────────────────
IRON = (78, 80, 92)
IRON_DK = (48, 50, 60)
IRON_LT = (120, 122, 136)
ROPE = (196, 92, 88)
ROPE_DK = (140, 56, 54)
WOOD = (176, 124, 72)


def kettlebell(d, row, col, t):
    lean = 0
    squash = 0
    if row == 0:
        lean = int(math.sin(t * math.tau) * 1.5)
    elif row == 1:
        lean = int(math.sin(t * math.tau) * 3)
    elif row == 2:
        # telegraph: rock back, then hurl forward
        lean = -4 if t < 0.4 else int(6 * t)
        squash = 1 if t >= 0.4 else 0
    elif row == 4:
        squash = int(t * 4)
        if t >= 0.9:
            # split clean in half
            d.pieslice([4, 12, 20, 28], 90, 270, fill=IRON, outline=IRON_DK)
            d.pieslice([14, 14, 30, 30], 270, 450, fill=IRON_DK, outline=IRON_DK)
            return
    cx = 16 + lean
    cy = 20 + squash
    r = 9
    d.ellipse([cx - r, cy - r + squash, cx + r, cy + r], fill=IRON, outline=IRON_DK)
    d.ellipse([cx - r + 2, cy - r + 2 + squash, cx - 1, cy - 1], fill=IRON_LT)
    d.arc([cx - 6, cy - r - 7, cx + 6, cy - r + 4], 180, 360, fill=IRON_DK, width=3)
    # the face: angry brows, pinprick eyes
    d.line([cx - 6, cy - 4, cx - 2, cy - 2], fill=IRON_DK, width=2)
    d.line([cx + 6, cy - 4, cx + 2, cy - 2], fill=IRON_DK, width=2)
    for sx in (-4, 4):
        d.ellipse([cx + sx - 1, cy - 1, cx + sx + 1, cy + 1], fill=(240, 240, 244))


def jump_rope(d, row, col, t):
    hop = 0
    if row in (0, 1):
        hop = int(abs(math.sin(t * math.pi)) * (2 if row == 0 else 5))
    elif row == 2:
        hop = int(abs(math.sin(t * math.pi)) * 8)
    cy = 22 - hop
    if row == 4:
        # unravels: the loop opens into a dying squiggle
        pts = []
        for i in range(9):
            x = 4 + i * 3
            y = 22 + int(math.sin(i * 1.4 + t * 6) * (4 - t * 3.5))
            pts.append((x, y))
        d.line(pts, fill=ROPE, width=2)
        if t >= 0.9:
            return
        d.rectangle([2, 18, 5, 26], fill=WOOD, outline=ROPE_DK)
        return
    # handles: two wooden grips, the rope arcing between and overhead
    for hx in (7, 25):
        d.rectangle([hx - 2, cy - 2, hx + 2, cy + 8], fill=WOOD, outline=ROPE_DK)
    swing = math.sin(t * math.tau) * (6 if row != 2 else 10)
    d.arc([6, cy - 14 - int(abs(swing)), 26, cy + 4], 180, 360, fill=ROPE, width=2)
    d.arc([6, cy - 2, 26, cy + 10 + int(abs(swing) * 0.5)], 0, 180, fill=ROPE_DK, width=2)
    # the knot in the middle is the creature
    d.ellipse([13, cy - 3, 19, cy + 3], fill=ROPE, outline=ROPE_DK)
    for sx in (-1, 2):
        d.point((16 + sx, cy - 1), fill=(250, 246, 240))


# ── THE STEAM ROOM ─────────────────────────────────────────────────────────
BRASS2 = (188, 152, 72)
BRASS2_DK = (128, 100, 46)
PIPE = (110, 116, 122)
PIPE_DK = (70, 74, 80)
STEAM2 = (222, 232, 234)
SOAP = (214, 226, 234)
SOAP_DK = (150, 172, 188)
SOAP_LT = (244, 250, 252)


def steam_valve(d, row, col, t):
    if row == 4 and t >= 0.7:
        d.rectangle([12, 20, 20, 30], fill=PIPE, outline=PIPE_DK)
        d.ellipse([18 + int(t * 6), 24, 26 + int(t * 6), 30], outline=BRASS2_DK, width=2)
        for i in range(4):
            a = t * 8 + i * 1.6
            px = 16 + int(math.cos(a) * 8)
            py = 16 + int(math.sin(a) * 6)
            d.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(*STEAM2, 140))
        return
    # steam first, so it sits behind the metal
    if row == 2:
        n = 2 + int(t * 5)
        for i in range(n):
            a = i / max(1, n - 1) * math.tau
            px = 16 + int(math.cos(a) * (7 + t * 6))
            py = 14 + int(math.sin(a) * (6 + t * 5))
            r = 2 + (i % 2)
            d.ellipse([px - r, py - r, px + r, py + r], fill=(*STEAM2, 170))
    elif row in (0, 1):
        py = 8 - int(t * 6)
        d.ellipse([19, py, 23, py + 4], fill=(*STEAM2, 120 + int(60 * (1 - t))))
    # pipe stub out of the floor
    d.rectangle([12, 18, 20, 30], fill=PIPE, outline=PIPE_DK)
    d.line([12, 22, 20, 22], fill=PIPE_DK)
    # the wheel, spokes turning with the frame
    d.ellipse([8, 8, 24, 22], outline=BRASS2, width=2)
    d.ellipse([9, 9, 23, 21], outline=BRASS2_DK, width=1)
    ang = t * math.pi + (0.4 if row == 2 else 0.0)
    for k in range(3):
        a = ang + k * math.tau / 3.0
        d.line([16 + math.cos(a) * 6, 15 + math.sin(a) * 5,
                16 - math.cos(a) * 6, 15 - math.sin(a) * 5], fill=BRASS2, width=2)
    d.ellipse([14, 13, 18, 17], fill=BRASS2, outline=BRASS2_DK)


def soap_bar(d, row, col, t):
    tilt = 0
    if row == 1:
        tilt = int(math.sin(t * math.tau) * 3)
    elif row == 2:
        tilt = int(6 * (t - 0.5))
    if row == 4:
        # dissolves into its own bubbles
        n = 6 - int(t * 5)
        if n > 0:
            w = int(18 * (1 - t * 0.7))
            d.rounded_rectangle([16 - w // 2, 22 - int(4 * (1 - t)), 16 + w // 2, 27],
                                4, fill=SOAP, outline=SOAP_DK)
        for i in range(3 + int(t * 6)):
            a = i * 2.1 + t * 3
            px = 16 + int(math.cos(a) * (6 + t * 8))
            py = 18 - int(t * 10) + int(math.sin(a) * 4)
            d.ellipse([px - 2, py - 2, px + 2, py + 2], outline=SOAP_LT)
        return
    cy = 22
    d.rounded_rectangle([6 + tilt, cy - 5, 26 + tilt, cy + 5], 5,
                        fill=SOAP, outline=SOAP_DK)
    d.line([9 + tilt, cy - 3, 17 + tilt, cy - 3], fill=SOAP_LT, width=2)
    for sx in (-4, 3):
        d.ellipse([16 + sx + tilt - 1, cy - 1, 16 + sx + tilt + 1, cy + 1],
                  fill=PIPE_DK)
    # it is always mid-lather
    for i in range(2 + (1 if row == 2 else 0)):
        px = 10 + i * 7 + tilt
        py = cy - 8 - int(abs(math.sin(t * math.tau + i)) * 3)
        d.ellipse([px - 2, py - 2, px + 2, py + 2], outline=SOAP_LT)


# ── THE UNDERGROUND ARENA ──────────────────────────────────────────────────
BAG = (162, 54, 52)
BAG_DK = (110, 32, 32)
BAG_LT = (200, 90, 84)
CHAIN = (150, 150, 162)
BELL_GOLD = (208, 168, 76)
BELL_DK = (142, 110, 48)
BELL_LT = (238, 210, 128)


def punching_bag(d, row, col, t):
    lean = 0
    if row in (0, 1):
        lean = int(math.sin(t * math.tau) * (2 if row == 0 else 4))
    elif row == 2:
        lean = -5 if t < 0.4 else int(8 * t)
    if row == 4:
        # tips over; sand runs out
        ang = t * 1.2
        x0 = 16 - int(math.sin(ang) * 10)
        d.rounded_rectangle([x0 - 6, 24 - int(14 * (1 - t)), x0 + 6, 30], 5,
                            fill=BAG, outline=BAG_DK)
        for i in range(int(t * 8)):
            d.point((x0 + 6 + i * 2, 28 + (i % 3)), fill=(210, 190, 140))
        return
    top = 6
    d.line([16, 2, 16 + lean // 2, top], fill=CHAIN, width=2)
    d.point((16, 3), fill=(220, 220, 230))
    d.rounded_rectangle([16 + lean - 6, top, 16 + lean + 6, 30], 5,
                        fill=BAG, outline=BAG_DK)
    d.line([16 + lean - 4, top + 4, 16 + lean + 4, top + 4], fill=BAG_DK)
    d.line([16 + lean - 4, 26, 16 + lean + 4, 26], fill=BAG_DK)
    d.line([16 + lean - 2, top + 2, 16 + lean - 2, 28], fill=BAG_LT, width=1)
    # a face someone drew on it in chalk, long ago
    for sx in (-3, 3):
        d.line([16 + lean + sx - 1, 14, 16 + lean + sx + 1, 16], fill=(236, 230, 220))
        d.line([16 + lean + sx + 1, 14, 16 + lean + sx - 1, 16], fill=(236, 230, 220))
    d.line([16 + lean - 2, 20, 16 + lean + 2, 20], fill=(236, 230, 220))


def ring_bell(d, row, col, t):
    tilt = 0
    if row == 2:
        tilt = int(math.sin(t * math.tau * 2) * 3)
        # the sound, drawn: arcs leaving the rim
        for k in range(1 + int(t * 2)):
            rr = 10 + k * 4 + int(t * 4)
            d.arc([16 - rr, 14 - rr // 2, 16 + rr, 14 + rr], 200, 340,
                  fill=(246, 240, 220), width=1)
    if row == 4:
        # the dome cracks off its post
        dx = int(t * 8)
        d.rectangle([13, 22, 19, 30], fill=(120, 90, 60), outline=(80, 58, 38))
        d.pieslice([4 + dx, 10 + int(t * 8), 24 + dx, 28 + int(t * 8)], 180, 360,
                   fill=BELL_GOLD, outline=BELL_DK)
        if t > 0.5:
            d.line([10 + dx, 16 + int(t * 8), 16 + dx, 22 + int(t * 8)],
                   fill=BELL_DK, width=1)
        return
    # post, then dome, then clapper
    d.rectangle([13, 22, 19, 30], fill=(120, 90, 60), outline=(80, 58, 38))
    d.pieslice([5 + tilt, 6, 27 + tilt, 26], 180, 360, fill=BELL_GOLD,
               outline=BELL_DK)
    d.arc([8 + tilt, 9, 24 + tilt, 23], 200, 300, fill=BELL_LT, width=2)
    d.rectangle([5 + tilt, 15, 27 + tilt, 17], fill=BELL_DK)
    d.ellipse([14 + tilt, 16, 18 + tilt, 20], fill=BELL_DK)
    for sx in (-4, 4):
        d.point((16 + tilt + sx, 12), fill=(30, 24, 18))


# ── ???? ───────────────────────────────────────────────────────────────────
NOISE_W = (238, 238, 242)
NOISE_G = (140, 140, 148)
NOISE_D = (52, 52, 58)
INKBAR = (0, 0, 0)


def static_mite(d, row, col, t):
    if row == 4:
        # scatters into pixels and stops being
        for i in range(14 - int(t * 12)):
            a = i * 1.7 + t
            px = 16 + int(math.cos(a) * (3 + t * 10))
            py = 20 + int(math.sin(a) * (2 + t * 8))
            d.point((px, py), fill=(NOISE_W, NOISE_G, NOISE_D)[i % 3])
        return
    jx = (0, 1, -1, 0)[col % 4] * (2 if row == 2 else 1)
    jy = (0, -1, 0, 1)[col % 4]
    grow = 2 if row == 2 and t > 0.5 else 0
    cx, cy = 16 + jx, 20 + jy
    w, h = 6 + grow, 4 + grow
    # a blob of broken picture
    seeds = [(-4, -2), (-2, 1), (0, -3), (2, 2), (4, -1), (-3, 3), (3, -3),
             (1, 0), (-1, -1), (5, 1), (-5, 0), (0, 3)]
    for i, (sx, sy) in enumerate(seeds):
        px, py = cx + sx, cy + sy
        if abs(sx) <= w and abs(sy) <= h:
            c = (NOISE_W, NOISE_G, NOISE_D, INKBAR)[(i + col) % 4]
            d.rectangle([px, py, px + 1, py + 1], fill=c)
    for sx in (-2, 2):
        d.point((cx + sx, cy - 1), fill=NOISE_W)


def redacted(d, row, col, t):
    if row == 4:
        # the bar breaks into shorter bars, which is all it ever was
        for i, (dx, w) in enumerate(((-9, 6), (-1, 5), (6, 7))):
            if t * 4 > i + 1:
                continue
            d.rectangle([16 + dx, 22 + int(t * 5), 16 + dx + w, 25 + int(t * 5)],
                        fill=INKBAR)
        return
    step = int(math.sin(t * math.tau) * 2) if row == 1 else 0
    cy = 18 + (1 if row == 2 and t > 0.5 else 0)
    # stub legs, walking in pairs
    for i, lx in enumerate((8, 13, 19, 24)):
        ly = cy + 6 + (step if i % 2 else -step)
        d.line([lx, cy + 4, lx, ly + 2], fill=NOISE_D, width=1)
    # the bar is the body. There is nothing else to draw, and that is the toy.
    d.rectangle([6, cy - 4, 26, cy + 4], fill=INKBAR)
    if row == 2 and t > 0.4:
        # it opens, slightly. White. Nothing else is visible in there.
        d.rectangle([10, cy - 1, 22, cy + 1], fill=NOISE_W)
    for sx in (-5, 5):
        d.point((16 + sx, cy - 2), fill=NOISE_W)
    d.point((7, cy - 4), fill=NOISE_G)
    d.point((25, cy + 4), fill=NOISE_G)


# ── harness ────────────────────────────────────────────────────────────────
def build(fn):
    sheet = Image.new("RGBA", (F * 5, F * 5), (0, 0, 0, 0))
    for row in range(5):
        for col in range(ROW_FRAMES[row]):
            n = max(1, ROW_FRAMES[row] - 1)
            cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            d = ImageDraw.Draw(cell, "RGBA")
            fn(d, row, col, col / n)
            if row == 3:
                px = cell.load()
                for y in range(F):
                    for x in range(F):
                        r, g, b, a = px[x, y]
                        if a:
                            px[x, y] = (*mix((r, g, b), (255, 255, 255), 0.6), a)
            sheet.alpha_composite(cell, (col * F, row * F))
    return sheet


ENEMIES = (
    ("enemy_kettlebell", kettlebell),
    ("enemy_jump_rope", jump_rope),
    ("enemy_steam_valve", steam_valve),
    ("enemy_soap_bar", soap_bar),
    ("enemy_punching_bag", punching_bag),
    ("enemy_ring_bell", ring_bell),
    ("enemy_static_mite", static_mite),
    ("enemy_redacted", redacted),
)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "enemies")
    os.makedirs(out, exist_ok=True)
    for name, fn in ENEMIES:
        build(fn).save(os.path.join(out, f"{name}.png"))
        print(f"assets/enemies/{name}.png  ({F * 5}x{F * 5}, 5x5 grid)")


if __name__ == "__main__":
    main()
