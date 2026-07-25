#!/usr/bin/env python3
"""Draw spritesheets for the two new bosses.

Grid matches SheetAnimator.DEFAULT_ROWS exactly — 5 columns x 5 rows of 96px:

    row 0 idle   (4 frames)   row 3 hurt   (2 frames)
    row 1 walk   (4 frames)   row 4 death  (5 frames)
    row 2 attack (4 frames)

Both are drawn from primitives rather than hand-pixelled, so the palette and
proportions can be retuned in one place. The brief was "cool and scary", and at
96px the thing that actually reads as scary is silhouette and eyes — not
detail. So: oversized heads, hollow sockets with a pinpoint of light, and a
palette that stays cold until the moment the boss commits to an attack.

    python3 tools/build_bosses.py
"""

import math
import os

from PIL import Image, ImageDraw

F = 96                      # frame size
COLS, ROWS = 5, 5
ROW_FRAMES = [4, 4, 4, 2, 5]


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


# ── The Porcelain Choir ──────────────────────────────────────────────────────
PORC = (232, 226, 224)
PORC_SH = (168, 162, 170)
PORC_DK = (108, 104, 118)
DRESS = (86, 96, 130)
DRESS_DK = (52, 60, 88)
CRACK = (60, 56, 68)
EYE = (14, 12, 18)
GLOW = (226, 64, 72)
HAIR = (52, 40, 46)


def porcelain(d, bob, lean, mouth, crack_n, glow_boost, collapse=0.0):
    cx = F // 2 + int(lean * 5)
    top = 16 + int(bob) + int(collapse * 26)

    if collapse >= 1.0:
        # shattered: a heap of shards
        for i, (dx, dy, r) in enumerate([(-16, 4, 7), (-4, 9, 5), (9, 6, 8),
                                         (18, 10, 4), (0, -2, 6)]):
            d.polygon([(cx + dx, F - 16 + dy), (cx + dx + r, F - 12 + dy),
                       (cx + dx - r + 2, F - 8 + dy)],
                      fill=PORC if i % 2 else PORC_SH, outline=PORC_DK)
        return

    # dress / body
    hem = F - 10 + int(collapse * 6)
    d.polygon([(cx, top + 34), (cx - 26, hem), (cx + 26, hem)],
              fill=DRESS, outline=DRESS_DK)
    d.polygon([(cx, top + 40), (cx - 14, hem - 2), (cx + 14, hem - 2)],
              fill=mix(DRESS, DRESS_DK, 0.45))
    # arms — hung off the shoulders, below the head, or they read as ears
    ax = 24 + int(lean * 3)
    sy = top + 52
    d.line([cx - 14, sy, cx - ax, sy + 8 - int(lean * 10)], fill=PORC_SH, width=5)
    d.line([cx + 14, sy, cx + ax, sy + 8 + int(lean * 10)], fill=PORC_SH, width=5)
    d.ellipse([cx - ax - 3, sy + 5 - int(lean * 10), cx - ax + 3, sy + 11 - int(lean * 10)],
              fill=PORC)
    d.ellipse([cx + ax - 3, sy + 5 + int(lean * 10), cx + ax + 3, sy + 11 + int(lean * 10)],
              fill=PORC)

    # head
    hw, hh = 21, 23
    d.ellipse([cx - hw, top, cx + hw, top + hh * 2], fill=PORC, outline=PORC_DK)
    # hair
    d.chord([cx - hw, top - 2, cx + hw, top + hh + 6], 180, 360, fill=HAIR)
    d.ellipse([cx - hw - 3, top + 10, cx - hw + 6, top + 30], fill=HAIR)
    d.ellipse([cx + hw - 6, top + 10, cx + hw + 3, top + 30], fill=HAIR)

    # eye sockets: hollow, with a pinpoint. The whole face reads off these.
    for sx in (-9, 9):
        ex = cx + sx
        ey = top + 24
        d.ellipse([ex - 6, ey - 6, ex + 6, ey + 6], fill=EYE)
        g = mix(GLOW, (255, 240, 240), glow_boost * 0.6)
        r = 2 + int(glow_boost * 2)
        d.ellipse([ex - r, ey - r + 1, ex + r, ey + r + 1], fill=g)

    # mouth: a thin line at rest, a wide hole mid-scream
    mw = 3 + int(mouth * 11)
    mh = 1 + int(mouth * 9)
    my = top + 38
    d.ellipse([cx - mw, my - mh // 2, cx + mw, my + mh], fill=EYE)
    if mouth > 0.5:
        d.ellipse([cx - mw + 2, my + 1, cx + mw - 2, my + mh - 1], fill=(96, 22, 30))

    # cracks radiating from the left socket. Every endpoint is kept inside the
    # head ellipse — a crack that runs off the skull reads as an antenna.
    crack_pts = [(-9, 19, -16, 11), (-9, 29, -15, 39), (9, 19, 16, 13),
                 (-2, 33, -8, 43), (9, 29, 14, 37)]
    for i in range(min(crack_n, len(crack_pts))):
        x0, y0, x1, y1 = crack_pts[i]
        d.line([cx + x0, top + y0, cx + x1, top + y1], fill=CRACK, width=1)


# ── Jack ─────────────────────────────────────────────────────────────────────
BOX = (146, 96, 52)
BOX_DK = (86, 54, 30)
BOX_LT = (196, 142, 88)
BRASS = (214, 178, 74)
SPRING = (176, 176, 190)
SPRING_DK = (108, 108, 126)
SKIN = (238, 232, 226)
SKIN_SH = (186, 176, 178)
RED = (206, 46, 56)
GREEN = (58, 158, 96)
TOOTH = (250, 248, 242)
MOUTH_IN = (72, 12, 20)


def jack(d, ext, lean, grin, glow_boost, collapse=0.0):
    cx = F // 2
    by = F - 8

    # box
    d.rectangle([cx - 26, by - 30, cx + 26, by], fill=BOX, outline=BOX_DK)
    d.rectangle([cx - 26, by - 30, cx + 26, by - 26], fill=BOX_LT)
    for x in (-13, 0, 13):
        d.line([cx + x, by - 26, cx + x, by - 1], fill=BOX_DK)
    d.rectangle([cx - 5, by - 16, cx + 5, by - 8], fill=BRASS, outline=BOX_DK)
    # open lid, hinged back
    d.polygon([(cx - 26, by - 30), (cx + 26, by - 30),
               (cx + 20, by - 42), (cx - 32, by - 42)], fill=BOX_DK)

    if collapse >= 1.0:
        return

    # spring: a zigzag whose height is the extension. Sits high enough that the
    # coil is actually visible under the head rather than hidden behind it —
    # the spring is the whole reason this reads as a jack-in-the-box.
    head_y = by - 58 - int(ext * 30)
    coils = 5
    pts = []
    for i in range(coils * 2 + 1):
        t = i / (coils * 2.0)
        y = by - 30 + (head_y + 16 - (by - 30)) * t
        x = cx + (10 if i % 2 else -10) * (0.4 + 0.6 * t) + lean * 6 * t
        pts.append((x, y))
    for i in range(len(pts) - 1):
        d.line([pts[i], pts[i + 1]], fill=SPRING, width=3)
        d.line([pts[i][0], pts[i][1] + 1, pts[i + 1][0], pts[i + 1][1] + 1],
               fill=SPRING_DK, width=1)

    hx = cx + int(lean * 9)

    # hat: floppy, two-tone
    d.polygon([(hx - 16, head_y - 2), (hx + 16, head_y - 2), (hx, head_y - 24)],
              fill=RED, outline=(120, 20, 28))
    d.ellipse([hx + 4, head_y - 30, hx + 14, head_y - 20], fill=GREEN)
    d.ellipse([hx - 20, head_y - 4, hx + 20, head_y + 4], fill=GREEN,
              outline=(30, 96, 58))

    # head
    d.ellipse([hx - 19, head_y, hx + 19, head_y + 36], fill=SKIN, outline=SKIN_SH)

    # eyes: black sockets, red pinpoints that flare on the wind-up
    for sx in (-8, 8):
        ex, ey = hx + sx, head_y + 13
        d.ellipse([ex - 6, ey - 5, ex + 6, ey + 6], fill=(16, 14, 18))
        r = 2 + int(glow_boost * 2)
        d.ellipse([ex - r, ey - r, ex + r, ey + r],
                  fill=mix(RED, (255, 230, 220), glow_boost * 0.7))
    # cheeks
    d.ellipse([hx - 19, head_y + 18, hx - 9, head_y + 25], fill=(224, 116, 120))
    d.ellipse([hx + 9, head_y + 18, hx + 19, head_y + 25], fill=(224, 116, 120))

    # grin: widens and grows teeth
    gw = 8 + int(grin * 9)
    gh = 3 + int(grin * 9)
    gy = head_y + 26
    d.chord([hx - gw, gy - gh, hx + gw, gy + gh], 0, 180, fill=MOUTH_IN,
            outline=(40, 8, 14))
    if grin > 0.35:
        step = max(3, (gw * 2) // 5)
        for tx in range(hx - gw + 2, hx + gw - 2, step):
            d.polygon([(tx, gy), (tx + step - 1, gy), (tx + step // 2, gy + gh - 1)],
                      fill=TOOTH)


# ── sheet assembly ───────────────────────────────────────────────────────────
def build(draw_fn, params_for):
    sheet = Image.new("RGBA", (F * COLS, F * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(ROW_FRAMES[row]):
            cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            d = ImageDraw.Draw(cell)
            draw_fn(d, **params_for(row, col))
            if row == 3:                      # hurt: blown out to near-white
                px = cell.load()
                for y in range(F):
                    for x in range(F):
                        r, g, b, a = px[x, y]
                        if a:
                            px[x, y] = (*mix((r, g, b), (255, 255, 255), 0.55), a)
            sheet.alpha_composite(cell, (col * F, row * F))
    return sheet


def porc_params(row, col):
    n = max(1, ROW_FRAMES[row] - 1)
    t = col / n
    if row == 0:                                            # idle: slow breath
        return dict(bob=math.sin(t * math.tau) * 2, lean=0.0, mouth=0.0,
                    crack_n=2, glow_boost=0.15 + 0.15 * math.sin(t * math.tau))
    if row == 1:                                            # walk: stiff sway
        return dict(bob=abs(math.sin(t * math.pi)) * -2, lean=math.sin(t * math.tau) * 0.8,
                    mouth=0.1, crack_n=2, glow_boost=0.2)
    if row == 2:                                            # attack: the scream
        return dict(bob=-1 - 3 * t, lean=0.0, mouth=min(1.0, t * 1.5),
                    crack_n=3, glow_boost=0.3 + 0.7 * t)
    if row == 3:                                            # hurt
        return dict(bob=1.0, lean=-0.5 + col, mouth=0.4, crack_n=4, glow_boost=0.6)
    return dict(bob=2 + col * 2, lean=col * 0.4, mouth=0.6,      # death
                crack_n=min(5, 2 + col), glow_boost=max(0.0, 0.6 - col * 0.2),
                collapse=col / 4.0)


def jack_params(row, col):
    n = max(1, ROW_FRAMES[row] - 1)
    t = col / n
    if row == 0:
        return dict(ext=0.45 + 0.1 * math.sin(t * math.tau), lean=0.0,
                    grin=0.35, glow_boost=0.2)
    if row == 1:
        return dict(ext=0.5, lean=math.sin(t * math.tau), grin=0.4, glow_boost=0.25)
    if row == 2:                                            # wind down, then lunge
        e = 0.15 if t < 0.34 else 0.55 + 0.75 * (t - 0.34)
        return dict(ext=min(1.35, e), lean=0.0, grin=min(1.0, 0.3 + t * 1.1),
                    glow_boost=min(1.0, t * 1.4))
    if row == 3:
        return dict(ext=0.35, lean=-0.6 + 1.2 * col, grin=0.2, glow_boost=0.7)
    return dict(ext=max(0.0, 0.5 - col * 0.15), lean=col * 0.3,
                grin=max(0.0, 0.5 - col * 0.15), glow_boost=max(0.0, 0.5 - col * 0.15),
                collapse=1.0 if col >= 4 else 0.0)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "bosses")
    os.makedirs(out, exist_ok=True)
    for name, fn, params in (("boss_porcelain_choir", porcelain, porc_params),
                             ("boss_jack", jack, jack_params)):
        sheet = build(fn, params)
        sheet.save(os.path.join(out, f"{name}.png"))
        print(f"assets/bosses/{name}.png  ({F * COLS}x{F * ROWS}, {COLS}x{ROWS} grid)")


if __name__ == "__main__":
    main()
