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

# Plastic ramps: darkest -> lightest. Four stops is enough to read as moulded
# plastic; more just muddies at 16px.
PALETTES = {
    "blue":   [(0x10, 0x28, 0x5c), (0x1e, 0x53, 0xb0), (0x46, 0x93, 0xf0), (0xc4, 0xe4, 0xff)],
    "red":    [(0x5c, 0x0f, 0x1e), (0xc0, 0x24, 0x38), (0xf2, 0x5d, 0x60), (0xff, 0xd2, 0xd8)],
    "yellow": [(0x5e, 0x40, 0x0c), (0xd0, 0x94, 0x1c), (0xf7, 0xcf, 0x4a), (0xff, 0xf4, 0xc8)],
    "green":  [(0x10, 0x4a, 0x1c), (0x24, 0x8f, 0x38), (0x5c, 0xd0, 0x6e), (0xd4, 0xf7, 0xd8)],
    "orange": [(0x60, 0x28, 0x0a), (0xd4, 0x60, 0x18), (0xf7, 0x9c, 0x40), (0xff, 0xe2, 0xbc)],
    "cyan":   [(0x0e, 0x4a, 0x50), (0x1c, 0x91, 0x9c), (0x4c, 0xd8, 0xe0), (0xd0, 0xf8, 0xfa)],
    "purple": [(0x36, 0x12, 0x5c), (0x74, 0x2c, 0xc0), (0xac, 0x6c, 0xf0), (0xe6, 0xd2, 0xff)],
    "pink":   [(0x60, 0x14, 0x40), (0xc8, 0x34, 0x86), (0xf4, 0x74, 0xbc), (0xff, 0xd8, 0xee)],
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
    # ── decor ────────────────────────────────────────────────────────────
    (46, "assets/environment/prop_books.png",   None,     None),
]


def plastic(img, ramp):
    """Re-map a sprite through a plastic ramp, keeping its alpha and shading."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if a <= 8:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            # bias upward: military art is dark, toys are bright
            lum = min(1.0, lum ** 0.78 * 1.18)
            idx = min(len(ramp) - 1, int(lum * len(ramp)))
            dst[x, y] = (*ramp[idx], a)
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
