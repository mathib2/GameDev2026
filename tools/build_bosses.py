#!/usr/bin/env python3
"""Draw spritesheets for the bespoke bosses, themed to the floors they hold.

Each floor's boss wears its floor: the Porcelain Choir stands wreathed in the
Steam Room's vapour, Jack is the Underground Arena's undefeated champion —
belt on the box, gloves on springs — and the Gingerbread General runs the Gym
as its drill sergeant, sweatband, whistle and all. (The Teddy Bear King
already matched the Playground and keeps his old sheet.) Their projectiles
follow: steam puffs, thrown gloves, tiny dumbbells, emitted at the bottom of
this file. The pre-redesign sheets survive beside the new ones as *_old.png.

Grid matches SheetAnimator.DEFAULT_ROWS exactly — 5 columns x 5 rows of 96px:

    row 0 idle   (4 frames)   row 3 hurt   (2 frames)
    row 1 walk   (4 frames)   row 4 death  (5 frames)
    row 2 attack (4 frames)

All drawn from primitives rather than hand-pixelled, so the palette and
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


# ── The Porcelain Choir — boss of THE STEAM ROOM ─────────────────────────────
# Porcelain belongs in a steam room, so the redesign leans in: the dress
# reads as wet teal cloth, condensation runs down the glaze, and vapour
# curls off her constantly — thicker the moment she opens her mouth.
PORC = (234, 230, 228)
PORC_SH = (172, 172, 180)
PORC_DK = (106, 108, 122)
DRESS = (58, 96, 104)
DRESS_DK = (34, 62, 70)
CRACK = (56, 60, 68)
EYE = (14, 12, 18)
GLOW = (226, 64, 72)
HAIR = (46, 42, 48)
STEAM = (218, 230, 232)


def _steam_wisp(d, x, y, phase, strength):
    """A curl of vapour: stacked circles that shrink, wobble and fade as they
    rise. Drawn before the body so translucency never punches through her."""
    for i in range(4):
        t = (phase + i * 0.25) % 1.0
        r = max(1, int((4 - i) * (0.6 + strength * 0.7)))
        wx = x + int(math.sin((phase + i * 0.6) * math.tau) * (2 + i))
        wy = y - int(t * 16) - i * 5
        a = int(150 * (1.0 - t) * (0.5 + strength * 0.5))
        d.ellipse([wx - r, wy - r, wx + r, wy + r], fill=(*STEAM, a))


def porcelain(d, bob, lean, mouth, crack_n, glow_boost, steam_t=0.0, collapse=0.0):
    cx = F // 2 + int(lean * 5)
    top = 16 + int(bob) + int(collapse * 26)

    # the room's weather, rising off her shoulders and crown
    if collapse < 1.0:
        strength = 0.35 + mouth * 0.65
        _steam_wisp(d, cx - 16, top + 6, steam_t, strength)
        _steam_wisp(d, cx + 15, top + 9, (steam_t + 0.4) % 1.0, strength)
        _steam_wisp(d, cx, top - 2, (steam_t + 0.7) % 1.0, strength * 0.8)

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

    # condensation: a run down the glaze with a bead at the bottom, crawling
    # with the steam phase so the sheet never shows a dry frame
    dx = cx + 14
    dy0 = top + 8
    run = 6 + int(steam_t * 8)
    d.line([dx, dy0, dx, dy0 + run], fill=mix(PORC, STEAM, 0.75), width=1)
    d.ellipse([dx - 1, dy0 + run - 1, dx + 1, dy0 + run + 1],
              fill=mix(STEAM, (255, 255, 255), 0.4))


# ── Jack — boss of THE UNDERGROUND ARENA ─────────────────────────────────────
# The pit's undefeated champion. The championship belt is strapped around the
# box, the gloves ride their own springs, and both come up as he winds into an
# attack — a guard, then a lunge.
BOX = (146, 96, 52)
BOX_DK = (86, 54, 30)
BOX_LT = (196, 142, 88)
BRASS = (214, 178, 74)
BRASS_LT = (240, 214, 128)
SPRING = (176, 176, 190)
SPRING_DK = (108, 108, 126)
SKIN = (238, 232, 226)
SKIN_SH = (186, 176, 178)
RED = (206, 46, 56)
GLOVE_DK = (140, 26, 36)
GLOVE_LT = (232, 96, 100)
GREEN = (58, 158, 96)
TOOTH = (250, 248, 242)
MOUTH_IN = (72, 12, 20)


def _glove(d, x, y, side):
    """A boxing glove, thumb toward the room's centre."""
    d.ellipse([x - 7, y - 6, x + 7, y + 6], fill=RED, outline=GLOVE_DK)
    tx0, tx1 = sorted((x - 3 * side, x - 7 * side))
    d.ellipse([tx0, y + 1, tx1, y + 6], fill=RED, outline=GLOVE_DK)
    d.ellipse([x - 4, y - 4, x + 1, y - 1], fill=GLOVE_LT)
    d.rectangle([x - 3, y + 4, x + 3, y + 7], fill=TOOTH)


def jack(d, ext, lean, grin, glow_boost, collapse=0.0):
    cx = F // 2
    by = F - 8

    # box
    d.rectangle([cx - 26, by - 30, cx + 26, by], fill=BOX, outline=BOX_DK)
    d.rectangle([cx - 26, by - 30, cx + 26, by - 26], fill=BOX_LT)
    for x in (-13, 0, 13):
        d.line([cx + x, by - 26, cx + x, by - 1], fill=BOX_DK)
    d.rectangle([cx - 5, by - 16, cx + 5, by - 8], fill=BRASS, outline=BOX_DK)
    # the championship belt, strapped around the box because the box is the
    # body: gold plate front and centre, nobody has ever taken it off him
    d.rectangle([cx - 26, by - 24, cx + 26, by - 20], fill=BRASS, outline=BOX_DK)
    d.rectangle([cx - 9, by - 27, cx + 9, by - 17], fill=BRASS, outline=BOX_DK)
    d.ellipse([cx - 6, by - 25, cx + 6, by - 19], fill=BRASS_LT, outline=BOX_DK)
    d.point((cx, by - 22), fill=BOX_DK)
    # open lid, hinged back
    d.polygon([(cx - 26, by - 30), (cx + 26, by - 30),
               (cx + 20, by - 42), (cx - 32, by - 42)], fill=BOX_DK)

    if collapse >= 1.0:
        # the champion is down: gloves dropped in front of the box
        _glove(d, cx - 18, by + 2, -1)
        _glove(d, cx + 16, by + 4, 1)
        return

    # glove arms: short side springs that rise into a guard as he extends
    gy = by - 34 - int(ext * 26)
    for side in (-1, 1):
        gx = cx + side * (30 + int(ext * 6)) + int(lean * 4)
        ax = cx + side * 24
        for i in range(3):
            t0 = i / 3.0
            t1 = (i + 1) / 3.0
            x0 = ax + side * int(6 * (1 if i % 2 else -1) * (1 - t0))
            x1 = ax + side * int(6 * (1 if (i + 1) % 2 else -1) * (1 - t1))
            y0 = by - 28 + (gy - (by - 28)) * t0
            y1 = by - 28 + (gy - (by - 28)) * t1
            d.line([x0 + (gx - ax) * t0, y0, x1 + (gx - ax) * t1, y1],
                   fill=SPRING, width=2)
        _glove(d, gx, gy, side)

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


# ── The Gingerbread General — boss of THE GYM ────────────────────────────────
# Until now he borrowed the ordinary gingerbread enemy's sheet, scaled up.
# A boss deserves his own body: the Gym's drill sergeant — sweatband, whistle
# on a cord, a dumbbell he presses overhead when he barks an order. Icing
# piped at the wrists and ankles like athletic tape.
GB = (176, 114, 60)
GB_DK = (122, 76, 40)
GB_LT = (210, 152, 94)
ICING = (246, 243, 236)
BAND = (198, 58, 54)
BAND_LT = (232, 110, 104)
GUMS = [(212, 84, 96), (96, 162, 210), (238, 198, 92)]
STEEL = (152, 152, 164)
STEEL_DK = (98, 98, 112)
GG_EYE = (24, 18, 16)


def _dumbbell(d, x, y, scale=1.0):
    w = int(13 * scale)
    ph = int(7 * scale)
    d.line([x - w, y, x + w, y], fill=STEEL, width=max(2, int(3 * scale)))
    for side in (-1, 1):
        px = x + side * w
        d.rectangle([px - 2, y - ph, px + 2, y + ph], fill=STEEL_DK, outline=(60, 60, 72))
        d.rectangle([px - 2, y - ph, px + 2, y - ph + 2], fill=STEEL)


def ginger_general(d, bob, stride, press, yell, lean, collapse=0.0):
    cx = F // 2 + int(lean * 4)
    top = 12 + int(bob) + int(collapse * 30)

    if collapse >= 1.0:
        # dismissed: a heap of crumbs, one boot still standing, the dumbbell down
        for dx, dy, r, c in [(-18, 6, 7, GB), (-5, 10, 6, GB_DK), (7, 6, 8, GB),
                             (17, 11, 4, GB_LT), (0, 0, 5, GB_DK)]:
            d.ellipse([cx + dx - r, F - 18 + dy - r, cx + dx + r, F - 18 + dy + r],
                      fill=c, outline=GB_DK)
        d.rectangle([cx - 24, F - 22, cx - 16, F - 12], fill=GB, outline=GB_DK)
        _dumbbell(d, cx + 14, F - 10, 0.9)
        return

    # legs: stubby, swinging with the stride; icing tape at the ankles
    swing = int(math.sin(stride * math.tau) * 5)
    for side, s in ((-1, swing), (1, -swing)):
        lx = cx + side * 11
        d.rounded_rectangle([lx - 7, F - 34 + (s if s > 0 else 0),
                             lx + 7, F - 8 + s // 2], 6, fill=GB, outline=GB_DK)
        d.line([lx - 6, F - 16 + s // 2, lx + 6, F - 16 + s // 2], fill=ICING, width=2)

    # body: one rounded slab of biscuit
    d.rounded_rectangle([cx - 21, top + 26, cx + 21, F - 26], 14,
                        fill=GB, outline=GB_DK)
    d.rounded_rectangle([cx - 21, top + 26, cx + 21, top + 34], 8, fill=GB_LT)
    for i, g in enumerate(GUMS):
        gy = top + 40 + i * 11
        d.ellipse([cx - 3, gy, cx + 3, gy + 6], fill=g, outline=GB_DK)

    # arms. The right presses the dumbbell: at his side at rest, locked out
    # overhead at full extension. The left stays on duty at parade rest.
    ry = top + 44 - int(press * 52)
    rx = cx + 24 - int(press * 22)
    d.line([cx + 14, top + 38, rx, ry], fill=GB, width=9)
    d.ellipse([rx - 5, ry - 5, rx + 5, ry + 5], fill=GB_LT, outline=GB_DK)
    d.line([rx - 5, ry + (5 if press < 0.5 else -5), rx + 5,
            ry + (5 if press < 0.5 else -5)], fill=ICING, width=2)
    if press < 0.4:
        _dumbbell(d, rx, ry - int(press * 8), 1.0)
    lx2 = cx - 24 - int(lean * 3)
    d.line([cx - 14, top + 38, lx2, top + 52], fill=GB, width=9)
    d.ellipse([lx2 - 5, top + 48, lx2 + 5, top + 58], fill=GB_LT, outline=GB_DK)
    d.line([lx2 - 5, top + 50, lx2 + 5, top + 50], fill=ICING, width=2)

    # head, over the arms so the press reads behind him
    d.ellipse([cx - 17, top, cx + 17, top + 34], fill=GB, outline=GB_DK)
    d.arc([cx - 17, top, cx + 17, top + 34], 200, 340, fill=GB_LT, width=2)

    # sweatband, the one soft thing he owns
    d.rectangle([cx - 15, top + 6, cx + 15, top + 12], fill=BAND, outline=GB_DK)
    d.line([cx - 13, top + 9, cx + 13, top + 9], fill=BAND_LT, width=1)

    # face: raisin eyes, an icing moustache, and a mouth that barks orders
    for sx in (-7, 7):
        d.ellipse([cx + sx - 3, top + 16, cx + sx + 3, top + 22], fill=GG_EYE)
        d.point((cx + sx + 1, top + 17), fill=(120, 116, 120))
    d.line([cx - 8, top + 25, cx - 2, top + 27], fill=ICING, width=2)
    d.line([cx + 2, top + 27, cx + 8, top + 25], fill=ICING, width=2)
    mw = 2 + int(yell * 6)
    mh = 1 + int(yell * 7)
    d.ellipse([cx - mw, top + 28, cx + mw, top + 28 + mh], fill=GG_EYE)

    # the whistle, on a cord. It is how the room knows an order was given.
    d.line([cx - 10, top + 34, cx - 3, top + 44], fill=GB_DK, width=1)
    d.line([cx + 10, top + 34, cx + 3, top + 44], fill=GB_DK, width=1)
    d.ellipse([cx - 4, top + 42, cx + 4, top + 49], fill=BRASS, outline=GB_DK)
    d.point((cx + 2, top + 44), fill=(120, 96, 40))

    # the lockout: dumbbell above everything, or the press never reads
    if press >= 0.4:
        _dumbbell(d, rx, ry - int(press * 8), 1.0)


def gg_params(row, col):
    n = max(1, ROW_FRAMES[row] - 1)
    t = col / n
    if row == 0:                                            # idle: at attention
        return dict(bob=math.sin(t * math.tau) * 2, stride=0.0,
                    press=0.06 + 0.04 * math.sin(t * math.tau), yell=0.0, lean=0.0)
    if row == 1:                                            # walk: the march
        return dict(bob=abs(math.sin(t * math.tau)) * -2, stride=t,
                    press=0.1, yell=0.1, lean=math.sin(t * math.tau) * 0.6)
    if row == 2:                                            # attack: press + bark
        return dict(bob=-1 - 2 * t, stride=0.0, press=min(1.0, t * 1.3),
                    yell=min(1.0, t * 1.4), lean=0.0)
    if row == 3:                                            # hurt
        return dict(bob=1.0, stride=0.0, press=0.15, yell=0.35, lean=-0.6 + 1.2 * col)
    return dict(bob=2 + col * 2, stride=0.0,                # death: dismissed
                press=max(0.0, 0.3 - col * 0.1), yell=max(0.0, 0.5 - col * 0.15),
                lean=col * 0.4, collapse=col / 4.0)


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
                    crack_n=2, glow_boost=0.15 + 0.15 * math.sin(t * math.tau),
                    steam_t=t)
    if row == 1:                                            # walk: stiff sway
        return dict(bob=abs(math.sin(t * math.pi)) * -2, lean=math.sin(t * math.tau) * 0.8,
                    mouth=0.1, crack_n=2, glow_boost=0.2, steam_t=t)
    if row == 2:                                            # attack: the scream
        return dict(bob=-1 - 3 * t, lean=0.0, mouth=min(1.0, t * 1.5),
                    crack_n=3, glow_boost=0.3 + 0.7 * t, steam_t=t)
    if row == 3:                                            # hurt
        return dict(bob=1.0, lean=-0.5 + col, mouth=0.4, crack_n=4, glow_boost=0.6,
                    steam_t=0.3 + 0.4 * col)
    return dict(bob=2 + col * 2, lean=col * 0.4, mouth=0.6,      # death
                crack_n=min(5, 2 + col), glow_boost=max(0.0, 0.6 - col * 0.2),
                steam_t=t, collapse=col / 4.0)


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


# ── themed projectiles ───────────────────────────────────────────────────────
# Each redesigned boss fires what it is: the Choir vents scalding vapour, Jack
# throws gloves, the General hands out dumbbells. Same 10px scale family as
# fx_enemy_shot, passed into EnemyProjectile via setup()'s texture argument.
def fx_steam():
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, y, r, a in ((3, 6, 3, 235), (6, 4, 3, 235), (5, 7, 2, 235), (7, 7, 2, 160)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(*STEAM, a))
    d.ellipse([3, 3, 7, 7], fill=(246, 252, 252, 255))
    return img


def fx_glove():
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 8, 8], fill=RED, outline=GLOVE_DK)
    d.ellipse([5, 5, 9, 9], fill=RED, outline=GLOVE_DK)
    d.ellipse([2, 2, 5, 5], fill=GLOVE_LT)
    d.rectangle([1, 7, 4, 9], fill=TOOTH)
    return img


def fx_dumbbell():
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([2, 5, 8, 5], fill=STEEL, width=2)
    for px in (1, 8):
        d.rectangle([px, 2, px + 1, 8], fill=STEEL_DK)
        d.point((px, 2), fill=STEEL)
    return img


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "bosses")
    os.makedirs(out, exist_ok=True)
    for name, fn, params in (("boss_porcelain_choir", porcelain, porc_params),
                             ("boss_jack", jack, jack_params),
                             ("boss_gingerbread_general", ginger_general, gg_params)):
        sheet = build(fn, params)
        sheet.save(os.path.join(out, f"{name}.png"))
        print(f"assets/bosses/{name}.png  ({F * COLS}x{F * ROWS}, {COLS}x{ROWS} grid)")

    fxout = os.path.join(root, "assets", "effects")
    os.makedirs(fxout, exist_ok=True)
    for name, fn in (("fx_steam", fx_steam), ("fx_glove", fx_glove),
                     ("fx_dumbbell", fx_dumbbell)):
        im = fn()
        im.save(os.path.join(fxout, f"{name}.png"))
        print(f"assets/effects/{name}.png  {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
