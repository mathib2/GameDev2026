#!/usr/bin/env python3
"""Draw the toy-chest spritesheet.

Not everything the game needs exists in a pack. The chest is two 24x24 frames
side by side — closed, then open — which `chest.gd` flips between by setting
`frame`. Kept procedural so the palette can be retuned in one place.

    python3 tools/build_props.py
"""

import os

from PIL import Image, ImageDraw

CELL = 24


def chest(open_lid, wood, wood_dark, wood_light, metal, metal_dark, inner):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # soft contact shadow so it sits on the floor instead of floating
    d.ellipse([3, CELL - 6, CELL - 4, CELL - 2], fill=(0, 0, 0, 70))

    body_top = 10 if not open_lid else 11
    # body
    d.rectangle([3, body_top, CELL - 4, CELL - 4], fill=wood)
    d.rectangle([3, body_top, CELL - 4, CELL - 4], outline=wood_dark)
    # plank seams
    for x in (8, 13, 18):
        d.line([x, body_top + 1, x, CELL - 5], fill=wood_dark)
    # metal band across the body
    d.rectangle([3, CELL - 9, CELL - 4, CELL - 7], fill=metal)
    d.line([3, CELL - 9, CELL - 4, CELL - 9], fill=metal_dark)

    if open_lid:
        # dark interior + a hint of glow, lid tipped back behind the body
        d.rectangle([4, body_top - 4, CELL - 5, body_top + 1], fill=inner)
        d.rectangle([2, 3, CELL - 3, body_top - 4], fill=wood_dark)
        d.rectangle([2, 3, CELL - 3, body_top - 4], outline=metal_dark)
        d.line([2, 5, CELL - 3, 5], fill=wood_light)
    else:
        # domed lid
        d.pieslice([3, 3, CELL - 4, body_top + 5], 180, 360, fill=wood)
        d.pieslice([3, 3, CELL - 4, body_top + 5], 180, 360, outline=wood_dark)
        d.line([5, 7, CELL - 7, 6], fill=wood_light)
        # clasp
        d.rectangle([CELL // 2 - 2, body_top - 3, CELL // 2 + 1, body_top + 2],
                    fill=metal, outline=metal_dark)

    return img


def shrine(lit):
    """A little plinth with an orb on it.

    Drawn in greyscale on purpose: skill_shrine.gd modulates it per skill, so
    one sprite covers all five instead of five near-identical PNGs.
    """
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone = (150, 148, 156)
    stone_dk = (92, 90, 100)
    stone_lt = (198, 196, 204)

    d.ellipse([3, CELL - 7, CELL - 4, CELL - 2], fill=(0, 0, 0, 70))
    # plinth: wider base, narrow column, flared top
    d.rectangle([5, CELL - 7, CELL - 6, CELL - 3], fill=stone, outline=stone_dk)
    d.rectangle([8, 13, CELL - 9, CELL - 6], fill=stone, outline=stone_dk)
    d.rectangle([6, 10, CELL - 7, 13], fill=stone_lt, outline=stone_dk)

    # orb
    if lit:
        d.ellipse([6, 2, CELL - 7, 12], fill=(255, 255, 255))
        d.ellipse([8, 4, CELL - 9, 10], fill=(255, 255, 255))
    else:
        d.ellipse([7, 3, CELL - 8, 11], fill=stone_lt, outline=stone_dk)
        d.ellipse([9, 5, 12, 8], fill=(255, 255, 255))
    return img


def crate():
    """The destructible crate — 24x24.

    Worth the attention despite being scenery: a room holds up to sixteen of
    them, so they occupy more screen area than anything except the floor. The
    old one was five flat colours and read as a beige square. This one gets
    plank seams, a lit top edge, a shaded underside, corner brackets and a
    contact shadow, which is what makes it sit *on* the floor rather than
    float against it.
    """
    S = 24
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    wood = (156, 106, 58)
    wood_dk = (96, 60, 30)
    wood_lt = (206, 152, 92)
    wood_hi = (232, 190, 138)
    edge = (54, 32, 18)
    brass = (198, 158, 74)

    d.ellipse([2, S - 5, S - 3, S - 1], fill=(0, 0, 0, 80))
    d.rectangle([2, 3, S - 3, S - 3], fill=wood, outline=edge)

    # three planks, each lit along its top and shaded along its base
    for i in range(3):
        y = 4 + i * 6
        d.rectangle([3, y, S - 4, y + 5], fill=wood)
        d.line([3, y, S - 4, y], fill=wood_lt)
        d.line([3, y + 5, S - 4, y + 5], fill=wood_dk)
        # grain
        d.line([6 + i * 3, y + 2, 11 + i * 3, y + 2], fill=wood_dk)
        d.line([13 - i * 2, y + 3, 17 - i * 2, y + 3], fill=wood_lt)

    # diagonal brace catches the light
    d.line([4, S - 5, S - 5, 5], fill=wood_lt, width=2)
    d.line([5, S - 5, S - 4, 6], fill=wood_hi)

    # corner brackets
    for cx, cy in ((3, 4), (S - 7, 4), (3, S - 8), (S - 7, S - 8)):
        d.rectangle([cx, cy, cx + 3, cy + 3], fill=brass, outline=wood_dk)
    # lit top lip, dark base
    d.line([2, 3, S - 3, 3], fill=wood_hi)
    d.line([2, S - 3, S - 3, S - 3], fill=edge)
    return img


PALETTES = {
    "chest": dict(wood=(150, 96, 48), wood_dark=(84, 50, 24),
                  wood_light=(206, 150, 92), metal=(214, 178, 74),
                  metal_dark=(126, 96, 30), inner=(38, 26, 20)),
    "chest_gold": dict(wood=(226, 176, 56), wood_dark=(138, 96, 20),
                       wood_light=(255, 226, 140), metal=(246, 236, 200),
                       metal_dark=(150, 122, 40), inner=(60, 42, 12)),
}


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "environment")
    os.makedirs(out, exist_ok=True)
    for name, pal in PALETTES.items():
        sheet = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
        sheet.alpha_composite(chest(False, **pal), (0, 0))
        sheet.alpha_composite(chest(True, **pal), (CELL, 0))
        path = os.path.join(out, f"prop_{name}.png")
        sheet.save(path)
        print(f"assets/environment/prop_{name}.png  ({CELL * 2}x{CELL}, 2 frames)")

    sheet = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
    sheet.alpha_composite(shrine(False), (0, 0))
    sheet.alpha_composite(shrine(True), (CELL, 0))
    sheet.save(os.path.join(out, "prop_shrine.png"))
    print(f"assets/environment/prop_shrine.png  ({CELL * 2}x{CELL}, 2 frames)")

    crate().save(os.path.join(out, "prop_crate.png"))
    print("assets/environment/prop_crate.png  (24x24)")


if __name__ == "__main__":
    main()
