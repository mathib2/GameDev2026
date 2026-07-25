#!/usr/bin/env python3
"""Turn the VladPenn weapon pack into STUFFED's toy-plastic weapon art.

The pack is a modern-military set — assault rifles, snipers, SMGs. The
silhouettes are excellent and read clearly at 16px, but the gunmetal palette
fights a game about haunted toys. So we keep the shapes and throw away the
colour: every sprite is reduced to luminance and re-mapped through a plastic
ramp (deep shadow -> body -> highlight -> specular), which is what makes a
moulded toy look moulded. A grey AK becomes a bright orange spud gun.

Sprites that already fit the toy box (the wooden club, the banana, the glow
swords, the medkit) pass through with their original colours.

Run from the repo root:
    python3 tools/build_weapon_assets.py <pack.png>

Depends on tools/extract_pack.py for the island-splitting.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_pack import load_sprites  # noqa: E402

ICON = 16
# Rifles are 3-4x wider than they are tall. Squashing one into a 16px square
# turns it into a smear, so long weapons get a wider canvas instead — nothing
# in the game requires a square icon, pedestals just draw the texture.
WIDE = (32, 16)

# Plastic ramps: darkest -> lightest.
#
# Six stops, not four. Four was enough to read as "plastic" but it is exactly
# what makes a sprite look 8-bit — flat bands with nothing between them. Real
# 16-bit era art leans on having enough intermediate tones to imply a curved
# surface. Each ramp now runs near-black outline -> shadow -> midtone -> body
# -> highlight -> specular, which is what gives a 16px gun a rounded barrel
# instead of a stripe.
PALETTES = {
    "blue":   [(0x06, 0x10, 0x2c), (0x10, 0x28, 0x5c), (0x1e, 0x53, 0xb0),
               (0x36, 0x7c, 0xd8), (0x6e, 0xb0, 0xf6), (0xd8, 0xee, 0xff)],
    "red":    [(0x2c, 0x06, 0x10), (0x5c, 0x0f, 0x1e), (0xa8, 0x1e, 0x30),
               (0xd8, 0x3c, 0x4c), (0xf2, 0x76, 0x80), (0xff, 0xdc, 0xe0)],
    "yellow": [(0x2e, 0x1e, 0x04), (0x5e, 0x40, 0x0c), (0xb0, 0x7c, 0x14),
               (0xe0, 0xa8, 0x24), (0xf7, 0xd8, 0x62), (0xff, 0xf8, 0xd8)],
    "green":  [(0x06, 0x24, 0x0c), (0x10, 0x4a, 0x1c), (0x1e, 0x78, 0x2e),
               (0x30, 0xa8, 0x44), (0x6e, 0xd8, 0x80), (0xdc, 0xfa, 0xe2)],
    "orange": [(0x2e, 0x12, 0x04), (0x60, 0x28, 0x0a), (0xb4, 0x4c, 0x10),
               (0xe0, 0x74, 0x1c), (0xf7, 0xac, 0x54), (0xff, 0xe8, 0xcc)],
    "cyan":   [(0x04, 0x24, 0x28), (0x0e, 0x4a, 0x50), (0x18, 0x7a, 0x84),
               (0x28, 0xac, 0xb8), (0x60, 0xe0, 0xe8), (0xdc, 0xfa, 0xfc)],
    "purple": [(0x1a, 0x06, 0x2e), (0x36, 0x12, 0x5c), (0x5e, 0x24, 0x9c),
               (0x8c, 0x44, 0xd8), (0xb8, 0x80, 0xf6), (0xec, 0xdc, 0xff)],
    "pink":   [(0x2e, 0x08, 0x1e), (0x60, 0x14, 0x40), (0xa8, 0x28, 0x6e),
               (0xd8, 0x4c, 0x9c), (0xf4, 0x88, 0xc6), (0xff, 0xe0, 0xf2)],
    "steel":  [(0x0c, 0x0e, 0x14), (0x24, 0x28, 0x34), (0x46, 0x4e, 0x60),
               (0x6e, 0x78, 0x8c), (0x9e, 0xa8, 0xbc), (0xe2, 0xe8, 0xf2)],
}

# (pack sprite index, output path, palette or None to keep colours, canvas)
PICKS = [
    # ── weapons ──────────────────────────────────────────────────────────
    (77, "assets/items/wpn_water_pistol.png",   "blue",   None),
    (80, "assets/items/wpn_cap_revolver.png",   "red",    None),
    (79, "assets/items/wpn_spud_gun.png",       "orange", None),
    (71, "assets/items/wpn_bubble_blaster.png", "cyan",   None),
    (60, "assets/items/wpn_dart_rifle.png",     "yellow", WIDE),
    (70, "assets/items/wpn_glow_sword.png",     None,     WIDE),
    (48, "assets/items/wpn_club.png",           None,     None),
    (83, "assets/items/wpn_banana.png",         None,     None),
    # ── artifacts ────────────────────────────────────────────────────────
    (44, "assets/items/item_first_aid.png",     None,     None),
    (45, "assets/items/item_gutshot.png",       "green",  None),
    (0,  "assets/items/item_growth_spurt.png",  "purple", None),
    (51, "assets/items/item_loose_screw.png",   "cyan",   None),
    (47, "assets/items/item_sandbox_spade.png", "yellow", None),
    (5,  "assets/items/item_walkie_talkie.png", "pink",   None),
    (6,  "assets/items/item_bad_marble.png",    "purple", None),
    (27, "assets/items/item_letter_opener.png", "red",    None),
    # ── projectiles ──────────────────────────────────────────────────────
    (15, "assets/effects/fx_cork.png",          None,     (8, 8)),
    (53, "assets/effects/fx_pellet.png",        "cyan",   (8, 8)),
    (54, "assets/effects/fx_dart.png",          "yellow", (8, 8)),
    (23, "assets/effects/fx_spark.png",         None,     (8, 8)),
    (64, "assets/effects/fx_popper.png",        "pink",   (16, 8)),
    # ── replacing the original procedural guns ───────────────────────────
    # These three shipped as 2-3 colour blobs — flat, unreadable at 16px, and
    # the reason the toy gun looked bad. Same silhouette-plus-plastic-ramp
    # treatment as the rest of the roster so the whole weapon set matches.
    (81, "assets/items/wpn_toy_gun.png",        "yellow", None),
    (74, "assets/items/wpn_nail_gun.png",       "steel",  None),
    (82, "assets/items/wpn_shotgun.png",        "orange", WIDE),
    # ── decor ────────────────────────────────────────────────────────────
    (46, "assets/environment/prop_books.png",   None,     None),
]


def plastic(img, ramp):
    """Repaint a sprite as moulded plastic, adding shading it did not have.

    A pure luminance remap cannot make art look better than its source: if the
    original only contains four distinct tones, the output has four tones no
    matter how many stops the ramp has, and it still reads as flat 8-bit.

    So this *synthesises* form instead of only recolouring it, from three
    cues stacked on the source luminance:

      * a top-down light, so the upper half of every shape is brighter — the
        single strongest cue that a surface is round rather than flat
      * darkened rim pixels wherever a pixel touches transparency, which reads
        as a moulded edge and stops the sprite dissolving into the background
      * a specular kick on upper-left rim pixels, the highlight you get on
        shiny plastic

    The result uses the whole ramp, which is what actually separates a 16-bit
    looking sprite from an 8-bit one.
    """
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dst = out.load()

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] > 8

    # vertical extent of the actual artwork, so the light is relative to the
    # sprite rather than to its (often generously padded) canvas
    ys = [y for y in range(h) for x in range(w) if solid(x, y)]
    if not ys:
        return out
    y0, y1 = min(ys), max(ys)
    span = max(1, y1 - y0)

    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a <= 8:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            lum = min(1.0, lum ** 0.8 * 1.1)

            # top-down light: +0.22 at the top of the sprite, -0.14 at the base
            t = (y - y0) / span
            lum += 0.22 - 0.36 * t

            # rim handling
            open_up = not solid(x, y - 1)
            open_left = not solid(x - 1, y)
            open_down = not solid(x, y + 1)
            open_right = not solid(x + 1, y)
            if open_down or open_right:
                lum -= 0.30            # shaded underside
            if open_up or open_left:
                lum += 0.26            # lit top edge
            if open_up and open_left:
                lum += 0.16            # specular corner

            lum = max(0.0, min(0.999, lum))
            dst[x, y] = (*ramp[int(lum * len(ramp))], a)
    return out


def fit(img, canvas_size):
    """Centre a sprite on a transparent canvas, shrinking only if it must.

    Downscaling pixel art is destructive, so we only do it when the sprite
    genuinely overflows — and then by a whole-number factor where possible,
    which decimates cleanly instead of smearing.
    """
    cw, ch = canvas_size or (ICON, ICON)
    if img.width > cw or img.height > ch:
        f = min(cw / img.width, ch / img.height)
        inv = 1.0 / f
        # prefer an exact 1/2, 1/3 … decimation over an arbitrary ratio
        if abs(inv - round(inv)) < 0.34 and round(inv) >= 2:
            f = 1.0 / round(inv)
        img = img.resize((max(1, int(img.width * f)), max(1, int(img.height * f))),
                         Image.NEAREST)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((cw - img.width) // 2, (ch - img.height) // 2))
    return canvas


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: build_weapon_assets.py <pack.png>")
    _, sprites = load_sprites(sys.argv[1])

    for idx, path, pal, canvas in PICKS:
        if idx >= len(sprites):
            print(f"!! sprite {idx} out of range ({len(sprites)})", file=sys.stderr)
            continue
        img = sprites[idx][1]
        if pal:
            img = plastic(img, PALETTES[pal])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fit(img, canvas).save(path)
        print(f"{path}  <- sprite {idx} ({pal or 'original'})")

    print(f"\n{len(PICKS)} assets written", file=sys.stderr)


if __name__ == "__main__":
    main()
