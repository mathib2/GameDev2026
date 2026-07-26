#!/usr/bin/env python3
"""Draw one floor tilesheet per floor, so the four floors stop sharing a skin.

ENTER THE STRONGEST descends through a place that replicates real rooms almost
correctly: a playground, a gym, a steam room, an arena. Each gets its own
16px surface, five interchangeable variants, scattered by Room._paint_floor()
exactly like the original single sheet — same size, same frame count, so
nothing in the game changes except which PNG a floor loads.

The tonal doctrine from build_tiles.py still rules every sheet: the floor is
the one thing on screen that must never compete for attention. Dark, grimy,
low-contrast; every bright thing standing on it separates instantly. Each
floor's identity comes from its *material* — mat seams, court paint, grout,
cracked concrete — not from brightness or saturation.

    python3 tools/build_floor_tiles.py
"""

import os
import random

from PIL import Image, ImageDraw

T = 16
FRAMES = 5


def mix(a, b, t):
    """Blend two opaque colours. Tiles must stay fully opaque — a 4-tuple fill
    punches semi-transparent holes through the floor instead of shading it."""
    return tuple(int(round(a[i] * (1.0 - t) + b[i] * t)) for i in range(3))


def speckle(d, rng, colour, n):
    for _ in range(n):
        d.point((rng.randrange(T), rng.randrange(T)), fill=colour)


def corners(d, base, grime):
    # grime gathering in the corners, which is what stops a tiled floor
    # reading as a grid of identical squares
    for cx, cy in ((0, 0), (T - 1, 0), (0, T - 1), (T - 1, T - 1)):
        d.point((cx, cy), fill=mix(base, grime, 0.7))


# ── THE PLAYGROUND ── rubber safety mats, sun-faded, crumb speckle ─────────
PG = (44, 46, 40)          # dark worn rubber, a hint of green
PG_DK = (33, 35, 30)
PG_LT = (56, 58, 50)
PG_SEAM = (24, 26, 22)
PG_GRIME = (20, 22, 18)
PG_CHALK = (96, 94, 86)    # hopscotch chalk, nearly scrubbed out
PG_PAINT = (72, 66, 44)    # faded ground-game paint


def playground_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*PG, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # interlocking mat seams: an 8px grid, every mat slightly its own shade
    for y in (0, 8):
        d.line([0, y, T - 1, y], fill=PG_SEAM)
    for x in (0, 8):
        d.line([x, 0, x, T - 1], fill=PG_SEAM)
    for qx in (1, 9):
        for qy in (1, 9):
            if rng.random() < 0.5:
                d.rectangle([qx, qy, qx + 6, qy + 6],
                            fill=(*mix(PG, PG_DK if rng.random() < 0.5 else PG_LT, 0.35), 255))

    if variant == 1:
        # chalk line fragment — a game nobody finished
        y = rng.randrange(3, T - 3)
        x0 = rng.randrange(0, 6)
        d.line([x0, y, x0 + rng.randrange(5, 9), y], fill=mix(PG, PG_CHALK, 0.5))
    elif variant == 2:
        # worn patch where feet landed for years
        cx, cy = rng.randrange(4, T - 4), rng.randrange(4, T - 4)
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=mix(PG, PG_LT, 0.45))
        d.ellipse([cx - 2, cy - 1, cx + 2, cy + 1], fill=mix(PG, PG_LT, 0.7))
    elif variant == 3:
        # painted arc, faded to a suggestion
        cx, cy = rng.randrange(2, T - 2), rng.randrange(2, T - 2)
        d.arc([cx - 6, cy - 6, cx + 6, cy + 6], rng.randrange(0, 180),
              rng.randrange(180, 360), fill=mix(PG, PG_PAINT, 0.55))
    elif variant == 4:
        # a mat corner peeling up: dark wedge with a lit edge
        x, y = rng.choice(((1, 1), (9, 1), (1, 9), (9, 9)))
        d.line([x, y + 2, x + 2, y], fill=PG_DK)
        d.point((x + 1, y + 1), fill=mix(PG, PG_LT, 0.6))

    # rubber crumb: the speckle IS the material
    speckle(d, rng, mix(PG, PG_LT, 0.4), 5)
    speckle(d, rng, mix(PG, PG_GRIME, 0.5), 5)
    corners(d, PG, PG_GRIME)
    return img


# ── THE GYM ── varnished court boards, painted lines, scuffs ───────────────
GY = (62, 44, 32)          # warmer and redder than the old nursery boards
GY_DK = (46, 32, 24)
GY_LT = (80, 58, 42)
GY_SEAM = (32, 22, 17)
GY_GRIME = (26, 19, 15)
GY_PAINT_A = (86, 46, 40)  # court red, worn
GY_PAINT_B = (46, 52, 68)  # court blue, worn


def gym_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*GY, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # long boards: horizontal seams, staggered butt joints
    for y in (0, 8):
        d.line([0, y, T - 1, y], fill=GY_SEAM)
        d.line([0, y + 1, T - 1, y + 1], fill=GY_DK)
    for by, off in ((2, rng.randrange(0, T)), (10, rng.randrange(0, T))):
        d.line([off, by, off, by + 5], fill=GY_SEAM)

    # varnish sheen: one light grain line per board
    for by in (3, 11):
        x0 = rng.randrange(0, T - 6)
        d.line([x0, by + rng.randrange(0, 4), x0 + rng.randrange(3, 7),
                by + rng.randrange(0, 4)], fill=mix(GY, GY_LT, 0.5))

    if variant == 1:
        # court line crossing the tile — the two colours real courts layer
        paint = GY_PAINT_A if rng.random() < 0.6 else GY_PAINT_B
        if rng.random() < 0.5:
            y = rng.choice((4, 12))
            d.rectangle([0, y, T - 1, y + 1], fill=(*mix(GY, paint, 0.75), 255))
        else:
            x = rng.randrange(2, T - 3)
            d.rectangle([x, 0, x + 1, T - 1], fill=(*mix(GY, paint, 0.75), 255))
    elif variant == 2:
        # rubber scuff, the ghost of a shoe
        x, y = rng.randrange(2, T - 6), rng.randrange(2, T - 3)
        for i in range(rng.randrange(3, 5)):
            d.line([x + i, y, x + i + 2, y + 1], fill=GY_DK)
    elif variant == 3:
        # stain: something was spilled and only mopped once
        cx, cy = rng.randrange(4, T - 4), rng.randrange(4, T - 4)
        r = rng.randrange(2, 4)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=mix(GY, GY_GRIME, 0.45))
        d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1],
                  fill=mix(GY, GY_GRIME, 0.75))
    elif variant == 4:
        # knot in the wood, same as the boards this floor is imitating
        cx, cy = rng.randrange(4, T - 4), rng.randrange(3, T - 3)
        d.ellipse([cx - 2, cy - 1, cx + 2, cy + 1], fill=GY_DK)
        d.ellipse([cx - 1, cy, cx + 1, cy], fill=GY_SEAM)

    speckle(d, rng, mix(GY, GY_GRIME, 0.35), 4)
    speckle(d, rng, mix(GY, GY_LT, 0.3), 2)
    corners(d, GY, GY_GRIME)
    return img


# ── THE STEAM ROOM ── dark ceramic, grout, condensation ────────────────────
ST = (38, 50, 52)          # slate teal, wet
ST_DK = (28, 38, 40)
ST_LT = (52, 66, 68)
ST_GROUT = (20, 28, 30)
ST_GRIME = (18, 26, 26)
ST_SHEEN = (88, 112, 116)  # the wet highlight
ST_MOULD = (30, 42, 32)


def steam_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*ST, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # ceramic grid: grout every 8px both ways
    for y in (0, 8):
        d.line([0, y, T - 1, y], fill=ST_GROUT)
    for x in (0, 8):
        d.line([x, 0, x, T - 1], fill=ST_GROUT)
    # each ceramic square carries one wet sheen tick in its upper half
    for qx in (1, 9):
        for qy in (1, 9):
            if rng.random() < 0.7:
                sx = qx + rng.randrange(1, 4)
                sy = qy + rng.randrange(0, 3)
                d.line([sx, sy, sx + rng.randrange(1, 3), sy],
                       fill=mix(ST, ST_SHEEN, 0.5))

    if variant == 1:
        # drain: the tile everyone avoids standing on
        cx, cy = rng.choice(((4, 4), (12, 4), (4, 12), (12, 12)))
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=ST_DK)
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=ST_GROUT)
        for a in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            d.point(a, fill=(10, 16, 18))
    elif variant == 2:
        # condensation run: a droplet trail down the tile
        x = rng.randrange(2, T - 2)
        y0 = rng.randrange(0, 5)
        for y in range(y0, min(T - 1, y0 + rng.randrange(5, 9))):
            d.point((x, y), fill=mix(ST, ST_SHEEN, 0.35))
        d.point((x, min(T - 1, y0 + 8)), fill=mix(ST, ST_SHEEN, 0.7))
    elif variant == 3:
        # cracked ceramic square
        x, y = rng.randrange(3, T - 3), rng.randrange(2, 6)
        for _ in range(rng.randrange(4, 8)):
            d.point((x, y), fill=ST_GROUT)
            x += rng.choice((-1, 0, 1))
            y += 1
            if not (0 <= x < T and 0 <= y < T):
                break
    elif variant == 4:
        # mould creeping out of the grout lines
        for _ in range(3):
            gx = rng.choice((0, 8)) + rng.choice((0, 1))
            gy = rng.randrange(0, T)
            d.point((gx, gy), fill=ST_MOULD)
            d.point((min(T - 1, gx + 1), gy), fill=mix(ST, ST_MOULD, 0.6))

    speckle(d, rng, mix(ST, ST_GRIME, 0.4), 4)
    corners(d, ST, ST_GRIME)
    return img


# ── THE UNDERGROUND ARENA ── poured concrete, cracks, old chalk rings ──────
AR = (46, 42, 42)          # cold concrete with the warmth beaten out of it
AR_DK = (34, 31, 31)
AR_LT = (58, 54, 52)
AR_CRACK = (24, 22, 22)
AR_GRIME = (20, 18, 18)
AR_CHALK = (88, 84, 76)    # ring chalk, ground into the pores
AR_STAIN = (44, 28, 26)    # what fights leave behind


def arena_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*AR, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # poured slabs: seams only on the tile edge, barely there
    d.line([0, 0, T - 1, 0], fill=mix(AR, AR_CRACK, 0.5))
    d.line([0, 0, 0, T - 1], fill=mix(AR, AR_CRACK, 0.5))
    # trowel texture: faint long strokes
    for _ in range(3):
        x0 = rng.randrange(0, T - 7)
        y = rng.randrange(2, T - 2)
        d.line([x0, y, x0 + rng.randrange(4, 8), y], fill=mix(AR, AR_DK, 0.4))

    if variant == 1:
        # crack wandering the full tile
        x, y = rng.randrange(2, T - 2), 0
        while y < T:
            d.point((x, y), fill=AR_CRACK)
            if rng.random() < 0.3:
                d.point((min(T - 1, x + 1), y), fill=mix(AR, AR_CRACK, 0.6))
            x = max(1, min(T - 2, x + rng.choice((-1, 0, 0, 1))))
            y += 1
    elif variant == 2:
        # chalk ring fragment — the arena has been drawn and redrawn
        cx, cy = rng.randrange(0, T), rng.randrange(0, T)
        d.arc([cx - 9, cy - 9, cx + 9, cy + 9], rng.randrange(0, 360),
              rng.randrange(0, 360), fill=mix(AR, AR_CHALK, 0.5))
    elif variant == 3:
        # old stain, scrubbed to a shadow
        cx, cy = rng.randrange(4, T - 4), rng.randrange(4, T - 4)
        r = rng.randrange(2, 4)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=mix(AR, AR_STAIN, 0.5))
        d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1],
                  fill=mix(AR, AR_STAIN, 0.8))
        for _ in range(3):
            d.point((cx + rng.randrange(-r - 2, r + 3),
                     cy + rng.randrange(-r - 2, r + 3)),
                    fill=mix(AR, AR_STAIN, 0.45))
    elif variant == 4:
        # spalled pit: a chunk gone, aggregate showing
        cx, cy = rng.randrange(3, T - 3), rng.randrange(3, T - 3)
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=AR_DK)
        d.point((cx, cy), fill=AR_CRACK)
        d.point((cx - 1, cy - 1), fill=mix(AR, AR_LT, 0.5))

    speckle(d, rng, mix(AR, AR_GRIME, 0.4), 5)
    speckle(d, rng, mix(AR, AR_LT, 0.3), 3)
    corners(d, AR, AR_GRIME)
    return img


FLOORS = (
    ("tiles_floor_playground", playground_tile),
    ("tiles_floor_gym", gym_tile),
    ("tiles_floor_steam", steam_tile),
    ("tiles_floor_arena", arena_tile),
)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "environment")
    os.makedirs(out, exist_ok=True)
    rng = random.Random(20260725)   # fixed: art should not churn per run

    for name, tile in FLOORS:
        sheet = Image.new("RGBA", (T * FRAMES, T), (0, 0, 0, 0))
        for i in range(FRAMES):
            sheet.alpha_composite(tile(i, rng), (i * T, 0))
        sheet.save(os.path.join(out, f"{name}.png"))
        print(f"assets/environment/{name}.png  ({T * FRAMES}x{T}, {FRAMES} frames)")


if __name__ == "__main__":
    main()
