#!/usr/bin/env python3
"""Draw spritesheets for the ten data-driven bosses.

Same 5x5 grid of 96px frames as the hand-drawn bosses, so SheetAnimator does
not care which kind it is playing.

One parameterised creature rather than ten separate drawings. At 96px a boss
reads almost entirely off four things — overall silhouette, head shape, eye
count and palette — so those are the knobs. That is enough to make a tin robot,
a spider of hands and a melted crayon look like completely different things
while sharing one body of drawing code.

    python3 tools/build_boss_roster.py
"""

import math
import os

from PIL import Image, ImageDraw

F = 96
COLS, ROWS = 5, 5
ROW_FRAMES = [4, 4, 4, 2, 5]


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def shade(c, k):
    return mix(c, (0, 0, 0), k) if k > 0 else mix(c, (255, 255, 255), -k)


# id, body, accent, eye glow, shape, eyes, limbs, horns
ROSTER = [
    ("rocking_horse",  (150, 96, 60),  (232, 226, 220), (240, 90, 70),  "long",  2, "legs",  "mane"),
    ("tin_soldier",    (168, 172, 186),(196, 60, 62),   (255, 210, 90), "boxy",  2, "arms",  "hat"),
    ("music_box",      (190, 150, 210),(250, 240, 250), (170, 230, 255),"boxy",  1, "none",  "crank"),
    ("hand_spider",    (238, 206, 176),(200, 160, 130), (60, 40, 50),   "round", 6, "many",  "none"),
    ("crayon_wretch",  (220, 80, 60),  (250, 200, 80),  (255, 255, 255),"melt",  3, "arms",  "none"),
    ("balloon_animal", (240, 90, 140), (255, 180, 200), (40, 30, 40),   "round", 2, "legs",  "ears"),
    ("puzzle_hulk",    (90, 150, 200), (240, 230, 120), (255, 120, 120),"boxy",  4, "arms",  "none"),
    ("marionette",     (200, 180, 140),(120, 90, 70),   (230, 60, 60),  "long",  2, "many",  "strings"),
    ("piggy_bank",     (245, 170, 190),(250, 220, 230), (120, 60, 90),  "round", 2, "legs",  "slot"),
    ("night_light",    (250, 240, 190),(120, 140, 200), (255, 250, 210),"round", 1, "none",  "halo"),
]


def creature(d, cfg, bob, lean, open_amt, glow, collapse):
    body, accent, eyeglow, shape, eyes, limbs, horn = cfg
    cx = F // 2 + int(lean * 5)
    base = F - 12 + int(collapse * 10)
    if collapse >= 1.0:
        for i, (dx, r) in enumerate([(-16, 8), (-2, 6), (12, 9), (22, 5)]):
            d.ellipse([cx + dx - r, base - r // 2, cx + dx + r, base + r // 2],
                      fill=body if i % 2 else accent, outline=shade(body, 0.5))
        return

    top = 22 + int(bob)
    w = 26
    h = base - top

    # limbs first, behind the body
    if limbs == "legs":
        for s in (-1, 1):
            d.line([cx + s * 12, base - 14, cx + s * 18, base], fill=shade(body, 0.35), width=6)
    elif limbs == "arms":
        for s in (-1, 1):
            d.line([cx + s * (w - 4), top + 22, cx + s * (w + 10),
                    top + 30 + int(lean * s * 8)], fill=shade(body, 0.3), width=6)
    elif limbs == "many":
        for i in range(6):
            a = math.pi * (0.15 + 0.7 * (i / 5.0))
            ex = cx + int(math.cos(a) * (w + 22)) * (1 if i % 2 else -1)
            ey = base - int(math.sin(a) * 26)
            d.line([cx, base - 18, ex, ey], fill=shade(body, 0.4), width=4)

    # body
    if shape == "boxy":
        d.rectangle([cx - w, top, cx + w, base], fill=body, outline=shade(body, 0.55))
        d.rectangle([cx - w + 5, top + 5, cx + w - 5, top + 16], fill=shade(body, -0.25))
    elif shape == "long":
        d.ellipse([cx - w + 4, top, cx + w - 4, base], fill=body, outline=shade(body, 0.55))
        d.ellipse([cx - w - 2, top - 6, cx + w + 2, top + 30], fill=body,
                  outline=shade(body, 0.55))
    elif shape == "melt":
        d.ellipse([cx - w, top, cx + w, base - 8], fill=body, outline=shade(body, 0.55))
        for i in range(5):
            mx = cx - w + 10 * i + 4
            d.ellipse([mx - 6, base - 20, mx + 6, base + 4 + (i % 3) * 4],
                      fill=body, outline=shade(body, 0.55))
    else:  # round
        d.ellipse([cx - w, top, cx + w, base], fill=body, outline=shade(body, 0.55))

    # belly / plate
    d.ellipse([cx - w + 8, top + h // 2 - 4, cx + w - 8, base - 6],
              fill=shade(accent, 0.05))

    # horns / crown / extras
    if horn == "mane":
        for i in range(5):
            d.line([cx - 14 + i * 7, top - 2, cx - 20 + i * 7, top - 14],
                   fill=accent, width=3)
    elif horn == "hat":
        d.polygon([(cx - 16, top + 2), (cx + 16, top + 2), (cx, top - 20)], fill=accent)
    elif horn == "crank":
        d.line([cx + w, top + 14, cx + w + 14, top + 14], fill=shade(accent, 0.4), width=4)
        d.ellipse([cx + w + 10, top + 8, cx + w + 20, top + 20], fill=shade(accent, 0.4))
    elif horn == "ears":
        for s in (-1, 1):
            d.ellipse([cx + s * 16 - 8, top - 20, cx + s * 16 + 8, top + 6], fill=body,
                      outline=shade(body, 0.55))
    elif horn == "strings":
        for s in (-20, 0, 20):
            d.line([cx + s, 0, cx + s // 2, top + 4], fill=(230, 226, 216), width=1)
    elif horn == "slot":
        d.rectangle([cx - 12, top + 6, cx + 12, top + 11], fill=shade(body, 0.6))
    elif horn == "halo":
        d.ellipse([cx - 26, top - 22, cx + 26, top + 2], outline=accent, width=3)

    # eyes — the single biggest driver of how it reads
    g = mix(eyeglow, (255, 255, 255), glow * 0.5)
    r = 5 + int(glow * 2)
    if eyes == 1:
        d.ellipse([cx - 12, top + 16, cx + 12, top + 40], fill=(18, 16, 22))
        d.ellipse([cx - r * 2, top + 24 - r, cx + r * 2, top + 24 + r], fill=g)
    elif eyes == 6:
        for i in range(6):
            ex = cx - 18 + (i % 3) * 18
            ey = top + 14 + (i // 3) * 14
            d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=(18, 16, 22))
            d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=g)
    else:
        for i in range(eyes):
            ex = cx + int((i - (eyes - 1) / 2.0) * 17)
            ey = top + 22
            d.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], fill=(18, 16, 22))
            d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=g)

    # mouth: opens on the attack
    mw = 6 + int(open_amt * 16)
    mh = 2 + int(open_amt * 14)
    my = top + 46
    d.ellipse([cx - mw, my - mh // 2, cx + mw, my + mh], fill=(24, 14, 20))
    if open_amt > 0.45:
        step = max(4, (mw * 2) // 5)
        for tx in range(cx - mw + 2, cx + mw - 2, step):
            d.polygon([(tx, my - mh // 2), (tx + step - 1, my - mh // 2),
                       (tx + step // 2, my + mh // 2)], fill=(245, 242, 236))


def frame_params(row, col):
    n = max(1, ROW_FRAMES[row] - 1)
    t = col / n
    if row == 0:
        return dict(bob=math.sin(t * math.tau) * 2, lean=0.0, open_amt=0.0,
                    glow=0.2 + 0.2 * math.sin(t * math.tau), collapse=0.0)
    if row == 1:
        return dict(bob=-abs(math.sin(t * math.pi)) * 3, lean=math.sin(t * math.tau) * 0.8,
                    open_amt=0.1, glow=0.25, collapse=0.0)
    if row == 2:
        return dict(bob=-2 - 3 * t, lean=0.0, open_amt=min(1.0, t * 1.5),
                    glow=0.3 + 0.7 * t, collapse=0.0)
    if row == 3:
        return dict(bob=2.0, lean=-0.6 + 1.2 * col, open_amt=0.5, glow=0.8, collapse=0.0)
    return dict(bob=2 + col * 2, lean=col * 0.3, open_amt=0.4,
                glow=max(0.0, 0.6 - col * 0.2), collapse=1.0 if col >= 4 else col / 5.0)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "bosses")
    os.makedirs(out, exist_ok=True)
    for entry in ROSTER:
        name, cfg = entry[0], entry[1:]
        sheet = Image.new("RGBA", (F * COLS, F * ROWS), (0, 0, 0, 0))
        for row in range(ROWS):
            for col in range(ROW_FRAMES[row]):
                cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
                d = ImageDraw.Draw(cell)
                creature(d, cfg, **frame_params(row, col))
                if row == 3:
                    px = cell.load()
                    for y in range(F):
                        for x in range(F):
                            r, g, b, a = px[x, y]
                            if a:
                                px[x, y] = (*mix((r, g, b), (255, 255, 255), 0.55), a)
                sheet.alpha_composite(cell, (col * F, row * F))
        sheet.save(os.path.join(out, f"boss_{name}.png"))
        print(f"assets/bosses/boss_{name}.png")
    print(f"\n{len(ROSTER)} boss sheets")


if __name__ == "__main__":
    main()
