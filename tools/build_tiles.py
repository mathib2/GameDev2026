#!/usr/bin/env python3
"""Draw the floor and wall tilesheets.

Tuned toward the Binding of Isaac look, which is mostly a *tonal* trick rather
than a style one: keep the room surface dark, grimy and low-contrast so that
every bright thing standing on it — the player, the toys, a pickup — separates
instantly. Isaac's floors are almost never the thing you look at.

What that means here, given this game is a toy box and not a basement:
  * floors are dark stained boards, not mid-tone wood
  * grime pools in the plank seams and the tile corners
  * walls are darker than the floor and carry a lit top edge, so the room
    reads as a box you are standing inside rather than a flat picture
  * variation lives in five interchangeable floor tiles, scattered randomly by
    Room._paint_floor(), so no tiling pattern is visible

    python3 tools/build_tiles.py
"""

import os
import random

from PIL import Image, ImageDraw

T = 16
FLOOR_FRAMES = 5
WALL_FRAMES = 2

# Dark stained nursery boards.
BOARD = (58, 44, 35)
BOARD_DK = (43, 32, 26)
BOARD_LT = (73, 56, 44)
SEAM = (31, 23, 19)
GRIME = (26, 20, 17)

WALL = (40, 30, 27)
WALL_DK = (22, 16, 15)
WALL_LT = (86, 66, 54)
WALL_TOP = (58, 44, 38)


def mix(a, b, t):
    """Blend two opaque colours.

    Tiles must stay fully opaque — drawing with a 4-tuple fill punches
    semi-transparent holes through the floor instead of shading it, which only
    shows up once something dark is rendered behind the room.
    """
    return tuple(int(round(a[i] * (1.0 - t) + b[i] * t)) for i in range(3))


def speckle(d, rng, colour, n):
    for _ in range(n):
        d.point((rng.randrange(T), rng.randrange(T)), fill=colour)


def floor_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*BOARD, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # plank seams — horizontal boards, seam every 8px
    for y in (0, 8):
        d.line([0, y, T - 1, y], fill=SEAM)
        d.line([0, y + 1, T - 1, y + 1], fill=BOARD_DK)

    # subtle grain along each board
    for by in (2, 10):
        for _ in range(3):
            x0 = rng.randrange(0, T - 5)
            y = by + rng.randrange(0, 5)
            d.line([x0, y, x0 + rng.randrange(2, 5), y], fill=BOARD_DK)

    if variant == 1:
        for _ in range(2):
            x0 = rng.randrange(1, T - 6)
            y = rng.randrange(2, T - 2)
            d.line([x0, y, x0 + rng.randrange(3, 6), y], fill=BOARD_LT)
    elif variant == 2:
        # hairline crack
        x, y = rng.randrange(3, T - 3), rng.randrange(2, 6)
        for _ in range(rng.randrange(4, 8)):
            d.point((x, y), fill=SEAM)
            x += rng.choice((-1, 0, 1))
            y += 1
            if not (0 <= x < T and 0 <= y < T):
                break
    elif variant == 3:
        # stain, darkest in the middle
        cx, cy = rng.randrange(4, T - 4), rng.randrange(4, T - 4)
        r = rng.randrange(2, 4)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=mix(BOARD, GRIME, 0.45))
        d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1],
                  fill=mix(BOARD, GRIME, 0.75))
    elif variant == 4:
        # knot in the wood
        cx, cy = rng.randrange(4, T - 4), rng.randrange(3, T - 3)
        d.ellipse([cx - 2, cy - 1, cx + 2, cy + 1], fill=BOARD_DK)
        d.ellipse([cx - 1, cy, cx + 1, cy], fill=SEAM)

    # grime gathering in the corners, which is what stops a tiled floor
    # reading as a grid of identical squares
    for cx, cy in ((0, 0), (T - 1, 0), (0, T - 1), (T - 1, T - 1)):
        d.point((cx, cy), fill=mix(BOARD, GRIME, 0.7))
    # kept sparse and low-contrast on purpose: the floor is the one thing on
    # screen that must never compete for attention
    speckle(d, rng, mix(BOARD, GRIME, 0.35), 4)
    speckle(d, rng, mix(BOARD, BOARD_LT, 0.3), 2)
    return img


def wall_tile(variant, rng):
    img = Image.new("RGBA", (T, T), (*WALL, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # lit top lip + deep shadow at the base: the whole reason the room reads
    # as having height instead of being a flat border
    d.rectangle([0, 0, T - 1, 2], fill=WALL_TOP)
    d.line([0, 0, T - 1, 0], fill=WALL_LT)
    d.rectangle([0, T - 3, T - 1, T - 1], fill=WALL_DK)

    # brick-ish courses
    d.line([0, 7, T - 1, 7], fill=WALL_DK)
    off = 0 if variant == 0 else 8
    d.line([off, 3, off, 6], fill=WALL_DK)
    d.line([(off + 8) % T, 8, (off + 8) % T, T - 4], fill=WALL_DK)

    speckle(d, rng, mix(WALL, WALL_DK, 0.5), 6)
    speckle(d, rng, mix(WALL, WALL_LT, 0.25), 2)
    return img


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "environment")
    os.makedirs(out, exist_ok=True)
    rng = random.Random(20260725)   # fixed: art should not churn per run

    sheet = Image.new("RGBA", (T * FLOOR_FRAMES, T), (0, 0, 0, 0))
    for i in range(FLOOR_FRAMES):
        sheet.alpha_composite(floor_tile(i, rng), (i * T, 0))
    sheet.save(os.path.join(out, "tiles_floor.png"))
    print(f"assets/environment/tiles_floor.png  ({T * FLOOR_FRAMES}x{T}, "
          f"{FLOOR_FRAMES} frames)")

    sheet = Image.new("RGBA", (T * WALL_FRAMES, T), (0, 0, 0, 0))
    for i in range(WALL_FRAMES):
        sheet.alpha_composite(wall_tile(i, rng), (i * T, 0))
    sheet.save(os.path.join(out, "tiles_wall.png"))
    print(f"assets/environment/tiles_wall.png  ({T * WALL_FRAMES}x{T}, "
          f"{WALL_FRAMES} frames)")


if __name__ == "__main__":
    main()
