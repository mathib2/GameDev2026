#!/usr/bin/env python3
"""Draw the player spritesheet: 6x6 grid of 48px frames.

    row 0 idle   (4)   row 3 hurt  (2)
    row 1 walk   (6)   row 4 death (6)
    row 2 attack (4)   row 5 dodge (4)

The previous sprite read as square because it was built from stacked
rectangles of roughly equal width — no taper, no limb separation, and a face
too small to see. The fixes here are all silhouette work, because at 48px
silhouette is essentially all the player can perceive:

  * shoulders wider than the waist, so the outline has a V in it
  * limbs drawn as tapered tubes with a joint, not bars, so arms bend
  * a bicep bulge on the upper arm that swells when he swings
  * a face big enough to have a brow, eyes and a moustache — the brow is what
    makes him read as angry rather than blank
  * every frame moves *something*: even idle breathes and shifts weight

    python3 tools/build_player.py
"""

import math
import os

from PIL import Image, ImageDraw

F = 48
COLS, ROWS = 6, 6
ROW_FRAMES = [4, 6, 4, 2, 6, 4]

OUT = (26, 18, 22)
SKIN = (232, 178, 136)
SKIN_SH = (188, 134, 98)
SKIN_LT = (252, 208, 170)
HAIR = (88, 54, 34)
HAIR_LT = (126, 80, 48)
VEST = (238, 236, 230)
VEST_SH = (196, 192, 188)
SHORT = (56, 80, 128)
SHORT_SH = (36, 54, 90)
BOOT = (72, 50, 36)
BOOT_SH = (48, 32, 22)


def tube(d, a, b, w, colour, shade=None):
    """A limb: thick line with rounded caps, plus a shade line underneath."""
    if shade:
        d.line([a[0], a[1] + 1, b[0], b[1] + 1], fill=shade, width=w)
    d.line([a, b], fill=colour, width=w)
    r = w // 2
    for p in (a, b):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colour)


def draw_player(d, bob=0.0, lean=0.0, arm_f=0.0, arm_b=0.0, legs=0.0,
                punch=0.0, crouch=0.0, roll=0.0, down=0.0, flex=0.0):
    """One frame. All arguments are poses in roughly -1..1."""
    cx = F // 2
    # ground the feet, then let everything above move
    hip_y = 34 - int(crouch * 4) + int(down * 10)
    y = int(bob) + int(down * 8)
    lx = int(lean * 3)

    if down >= 1.0:
        # dead: a heap on the floor
        d.ellipse([cx - 15, 38, cx + 15, 45], fill=SHORT, outline=OUT)
        d.ellipse([cx - 6, 33, cx + 9, 43], fill=VEST, outline=OUT)
        d.ellipse([cx + 6, 32, cx + 17, 41], fill=SKIN, outline=OUT)
        d.ellipse([cx + 8, 31, cx + 16, 36], fill=HAIR)
        return

    if roll > 0.0:
        # dodge: a ball, angle driven by roll
        ang = roll * math.tau
        r = 11
        d.ellipse([cx - r, 24 - r + 8, cx + r, 24 + r + 8], fill=SHORT, outline=OUT)
        # a limb sticking out so the tumble is legible
        ex = cx + int(math.cos(ang) * 9)
        ey = 32 + int(math.sin(ang) * 9)
        tube(d, (cx, 32), (ex, ey), 5, SKIN, SKIN_SH)
        hx = cx + int(math.cos(ang + math.pi) * 8)
        hy = 32 + int(math.sin(ang + math.pi) * 8)
        d.ellipse([hx - 6, hy - 6, hx + 6, hy + 6], fill=SKIN, outline=OUT)
        d.ellipse([hx - 6, hy - 7, hx + 6, hy], fill=HAIR)
        return

    # ── legs ────────────────────────────────────────────────────────────────
    swing = int(legs * 6)
    for side, sw in ((-1, swing), (1, -swing)):
        kx = cx + side * 4 + lx // 2
        fx = kx + sw
        tube(d, (kx, hip_y), (fx, 44), 6, SKIN, SKIN_SH)
        # boot
        d.rectangle([fx - 4, 43, fx + 4, 46], fill=BOOT, outline=OUT)
        d.line([fx - 4, 43, fx + 4, 43], fill=BOOT_SH)

    # shorts: wider than the legs, so the hips read
    d.polygon([(cx - 9 + lx, hip_y - 7), (cx + 9 + lx, hip_y - 7),
               (cx + 8 + lx, hip_y + 3), (cx - 8 + lx, hip_y + 3)],
              fill=SHORT, outline=OUT)
    d.line([cx + lx, hip_y - 6, cx + lx, hip_y + 2], fill=SHORT_SH)

    # ── back arm ────────────────────────────────────────────────────────────
    sh_y = hip_y - 15 + y
    bax = cx - 9 + lx
    bex = bax - 4 + int(arm_b * 7)
    bey = sh_y + 9 + int(abs(arm_b) * 2)
    tube(d, (bax, sh_y + 2), (bex, bey), 5, SKIN_SH)

    # ── torso: wide shoulders tapering to the waist ─────────────────────────
    sw_half = 12 + int(flex * 2)
    d.polygon([(cx - sw_half + lx, sh_y), (cx + sw_half + lx, sh_y),
               (cx + 8 + lx, hip_y - 5), (cx - 8 + lx, hip_y - 5)],
              fill=VEST, outline=OUT)
    # vest straps + chest shading
    d.line([cx - 5 + lx, sh_y, cx - 4 + lx, hip_y - 6], fill=VEST_SH)
    d.line([cx + 5 + lx, sh_y, cx + 4 + lx, hip_y - 6], fill=VEST_SH)
    d.arc([cx - 7 + lx, sh_y + 2, cx + 7 + lx, sh_y + 10], 200, 340, fill=VEST_SH)
    # bare shoulders over the vest
    for side in (-1, 1):
        ox = cx + side * (sw_half - 2) + lx
        d.ellipse([ox - 4, sh_y - 1, ox + 4, sh_y + 7], fill=SKIN, outline=OUT)

    # ── front arm, with a bicep that swells on the swing ────────────────────
    fax = cx + 9 + lx
    reach = int(punch * 13)
    fex = fax + 3 + reach
    fey = sh_y + 8 - int(punch * 5) + int(arm_f * 5)
    mid = ((fax + fex) // 2, (sh_y + 3 + fey) // 2)
    tube(d, (fax, sh_y + 2), mid, 6 + int(flex * 2), SKIN, SKIN_SH)   # upper
    tube(d, mid, (fex, fey), 5, SKIN, SKIN_SH)                        # fore
    # bicep highlight
    d.ellipse([mid[0] - 3, mid[1] - 5, mid[0] + 2, mid[1] - 1], fill=SKIN_LT)
    # fist
    d.ellipse([fex - 4, fey - 4, fex + 4, fey + 4], fill=SKIN, outline=OUT)

    # ── head ────────────────────────────────────────────────────────────────
    hy = sh_y - 12
    hx = cx + lx + int(lean * 2)
    d.ellipse([hx - 9, hy - 2, hx + 9, hy + 15], fill=SKIN, outline=OUT)
    # jaw shadow
    d.arc([hx - 8, hy + 3, hx + 8, hy + 15], 20, 160, fill=SKIN_SH)
    # hair
    d.chord([hx - 10, hy - 4, hx + 10, hy + 11], 180, 360, fill=HAIR)
    d.line([hx - 8, hy + 1, hx - 9, hy + 6], fill=HAIR)
    d.line([hx + 8, hy + 1, hx + 9, hy + 6], fill=HAIR)
    d.line([hx - 6, hy - 1, hx + 3, hy - 2], fill=HAIR_LT)
    # brow — this single pair of lines is what makes him look angry
    d.line([hx - 7, hy + 5, hx - 2, hy + 6], fill=OUT)
    d.line([hx + 2, hy + 6, hx + 7, hy + 5], fill=OUT)
    # eyes
    d.rectangle([hx - 6, hy + 7, hx - 4, hy + 9], fill=OUT)
    d.rectangle([hx + 4, hy + 7, hx + 6, hy + 9], fill=OUT)
    # moustache + mouth
    d.rectangle([hx - 5, hy + 11, hx + 5, hy + 12], fill=HAIR)
    d.line([hx - 2, hy + 13, hx + 2, hy + 13], fill=OUT)


def frame(row, col):
    n = max(1, ROW_FRAMES[row] - 1)
    t = col / n
    w = math.sin(t * math.tau)

    if row == 0:      # idle: breathe, shift weight, arms sway
        return dict(bob=-abs(math.sin(t * math.pi)) * 1.5, lean=w * 0.25,
                    arm_f=w * 0.25, arm_b=-w * 0.25, flex=0.2 + 0.2 * abs(w))
    if row == 1:      # walk: legs swing, body bobs, arms counter-swing
        return dict(bob=-abs(math.sin(t * math.tau)) * 2.0, lean=0.25,
                    legs=math.sin(t * math.tau), arm_f=-math.sin(t * math.tau) * 0.6,
                    arm_b=math.sin(t * math.tau) * 0.8, flex=0.3)
    if row == 2:      # attack: wind back, then drive through
        if t < 0.34:
            return dict(punch=-0.45, lean=-0.5, crouch=0.5, flex=1.0, arm_b=-0.6)
        p = (t - 0.34) / 0.66
        return dict(punch=min(1.0, p * 1.6), lean=0.6 * p, crouch=0.3,
                    flex=1.0 - 0.4 * p, arm_b=0.5, legs=-0.35)
    if row == 3:      # hurt: thrown back
        return dict(lean=-0.9, bob=-2.0 + col, arm_f=-0.8, arm_b=-0.9,
                    crouch=0.4, legs=-0.4)
    if row == 4:      # death: buckle, then drop
        return dict(down=min(1.0, t * 1.25), crouch=t, lean=-0.5 + t,
                    arm_f=-0.5, arm_b=-0.5)
    # dodge: never returns exactly 0, or the first frame falls through the
    # `roll > 0` check and the roll starts with him standing bolt upright
    return dict(roll=0.08 + t * 0.92)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    sheet = Image.new("RGBA", (F * COLS, F * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(ROW_FRAMES[row]):
            cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            d = ImageDraw.Draw(cell)
            draw_player(d, **frame(row, col))
            sheet.alpha_composite(cell, (col * F, row * F))
    path = os.path.join(root, "assets", "characters", "player.png")
    sheet.save(path)
    print(f"assets/characters/player.png  ({F * COLS}x{F * ROWS}, {COLS}x{ROWS} grid)")


if __name__ == "__main__":
    main()
