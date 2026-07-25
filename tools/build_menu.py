#!/usr/bin/env python3
"""Draw the main-menu art: paper backdrop, pinned note, and the logo.

Follows the Binding of Isaac main-menu layout the brief asked for — a sheet of
grubby paper covered in faint pencil doodles, a big pixel wordmark with
something flanking it, and the options on a torn note pinned to the page.

Two deliberate departures, because this is a different game: the flanking
shapes are tufts of stuffing rather than wings, and the doodles are toys
rather than religious iconography. The layout is the reference; the vocabulary
is ours.

    python3 tools/build_menu.py
"""

import math
import os
import random

from PIL import Image, ImageDraw

W, H = 640, 384

PAPER = (222, 219, 212)
PAPER_DK = (198, 194, 186)
PENCIL = (196, 192, 184)
PENCIL_DK = (176, 172, 164)

INK = (38, 40, 52)
LOGO_HI = (238, 246, 255)
LOGO_MID = (150, 186, 226)
LOGO_LO = (96, 132, 178)

# 5x7 pixel font — only the letters the wordmark needs.
GLYPHS = {
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}
GW, GH = 5, 7


def text_mask(word, scale, spacing=1):
    """Render a word to a 1-bit mask at the given pixel scale."""
    cols = len(word) * (GW + spacing) - spacing
    m = Image.new("L", (cols * scale, GH * scale), 0)
    d = ImageDraw.Draw(m)
    for i, ch in enumerate(word.upper()):
        g = GLYPHS.get(ch, GLYPHS[" "])
        ox = i * (GW + spacing) * scale
        for y, row in enumerate(g):
            for x, c in enumerate(row):
                if c == "#":
                    d.rectangle([ox + x * scale, y * scale,
                                 ox + (x + 1) * scale - 1, (y + 1) * scale - 1],
                                fill=255)
    return m


def outlined_word(word, scale, outline=3):
    """Word with a vertical gradient fill and a chunky dark outline."""
    m = text_mask(word, scale)
    w, h = m.size
    pad = outline * 2
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))

    # outline: stamp the mask around in a ring
    ring = Image.new("L", out.size, 0)
    for dx in range(-outline, outline + 1):
        for dy in range(-outline, outline + 1):
            if dx * dx + dy * dy > outline * outline:
                continue
            ring.paste(m, (pad + dx, pad + dy), m)
    out.paste(Image.new("RGBA", out.size, (*INK, 255)), (0, 0), ring)

    # gradient fill, light at the top
    grad = Image.new("RGBA", out.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(out.size[1]):
        t = y / max(1, out.size[1] - 1)
        if t < 0.55:
            k = t / 0.55
            col = tuple(int(LOGO_HI[i] * (1 - k) + LOGO_MID[i] * k) for i in range(3))
        else:
            k = (t - 0.55) / 0.45
            col = tuple(int(LOGO_MID[i] * (1 - k) + LOGO_LO[i] * k) for i in range(3))
        gd.line([0, y, out.size[0], y], fill=(*col, 255))
    fill = Image.new("RGBA", out.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), Image.new("L", out.size, 0).point(lambda _: 0))
    solid = Image.new("L", out.size, 0)
    solid.paste(m, (pad, pad), m)
    out.paste(grad, (0, 0), solid)

    # a highlight line along the top of each stroke
    hl = Image.new("L", out.size, 0)
    hl.paste(m, (pad, pad - max(1, scale // 3)), m)
    top = Image.new("L", out.size, 0)
    top.paste(solid, (0, 0))
    from PIL import ImageChops
    hl = ImageChops.subtract(solid, hl)
    out.paste(Image.new("RGBA", out.size, (255, 255, 255, 210)), (0, 0), hl)
    return out


def stuffing(size, flip=False):
    """A tuft of cotton wadding — the wing equivalent."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(4 if not flip else 5)
    # A cluster of overlapping lobes in a rough wedge — big and round at the
    # outer end, tapering in toward the wordmark. Arranged in two rows so it
    # reads as a mass of wadding rather than a single curved band, which is
    # what made the first attempt look like a hat.
    lobes = []
    for i in range(7):
        t = i / 6.0
        cx = int(w * (0.10 + 0.82 * t))
        cy = int(h * (0.42 + 0.10 * math.sin(t * math.pi * 1.6)))
        r = int(h * (0.34 - 0.20 * t)) + rng.randint(-2, 2)
        lobes.append((cx, cy, max(6, r)))
    for i in range(5):
        t = i / 4.0
        cx = int(w * (0.16 + 0.66 * t))
        cy = int(h * (0.68 + 0.06 * math.cos(t * math.pi)))
        r = int(h * (0.24 - 0.13 * t)) + rng.randint(-2, 2)
        lobes.append((cx, cy, max(5, r)))
    for cx, cy, r in lobes:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*INK, 255))
    for cx, cy, r in lobes:
        d.ellipse([cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3],
                  fill=(238, 240, 246, 255))
    for cx, cy, r in lobes:
        d.ellipse([cx - r + 5, cy - r + 4, cx - r + 5 + max(3, r // 2),
                   cy - r + 4 + max(3, r // 2)], fill=(255, 255, 255, 255))
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def doodle(d, rng, x, y, kind):
    """Faint pencil sketch of a toy, in the margins."""
    c = PENCIL
    if kind == 0:      # ball
        r = rng.randint(12, 22)
        d.ellipse([x - r, y - r, x + r, y + r], outline=c, width=2)
        d.arc([x - r, y - r, x + r, y + r], 200, 340, fill=c, width=2)
    elif kind == 1:    # block
        s = rng.randint(14, 22)
        d.rectangle([x, y, x + s, y + s], outline=c, width=2)
        d.line([x + s, y, x + s + 6, y - 6], fill=c, width=2)
        d.line([x, y, x + 6, y - 6], fill=c, width=2)
        d.line([x + 6, y - 6, x + s + 6, y - 6], fill=c, width=2)
    elif kind == 2:    # teddy
        r = rng.randint(9, 13)
        d.ellipse([x - r, y - r, x + r, y + r], outline=c, width=2)
        d.ellipse([x - r - 4, y - r - 3, x - r + 3, y - r + 4], outline=c, width=2)
        d.ellipse([x + r - 3, y - r - 3, x + r + 4, y - r + 4], outline=c, width=2)
        d.ellipse([x - r + 2, y + r - 2, x + r - 2, y + r + 14], outline=c, width=2)
    elif kind == 3:    # spiral
        pts = []
        for i in range(28):
            a = i * 0.55
            rr = 2 + i * 0.8
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        d.line(pts, fill=c, width=2)
    elif kind == 4:    # star
        r = rng.randint(8, 14)
        for i in range(4):
            a = i * math.pi / 4
            d.line([x - math.cos(a) * r, y - math.sin(a) * r,
                    x + math.cos(a) * r, y + math.sin(a) * r], fill=c, width=2)
    else:              # scribble
        pts = [(x, y)]
        for _ in range(7):
            pts.append((pts[-1][0] + rng.randint(-14, 16),
                        pts[-1][1] + rng.randint(-9, 10)))
        d.line(pts, fill=PENCIL_DK, width=2)


def background():
    # RGB on purpose. ImageDraw only turns on alpha blending when the *image*
    # is RGB and the draw mode is RGBA — hand it an RGBA image and a
    # translucent fill and it overwrites the alpha channel instead of
    # compositing, punching transparent holes clean through the paper. A
    # full-screen backdrop needs no transparency, so RGB is both correct and
    # the thing that makes blending work.
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(90210)
    # grubby blotches
    for _ in range(70):
        x, y = rng.randrange(W), rng.randrange(H)
        r = rng.randint(6, 40)
        d.ellipse([x - r, y - r, x + r, y + r],
                  fill=(*PAPER_DK, rng.randint(8, 22)))
    # doodles, kept out of the middle where the note and logo sit
    for _ in range(26):
        x, y = rng.randrange(20, W - 20), rng.randrange(20, H - 20)
        if 150 < x < 500 and 20 < y < 360:
            continue
        doodle(d, rng, x, y, rng.randrange(6))
    # vignette-ish edge grime
    for i in range(28):
        a = int(30 * (1 - i / 28.0))
        d.rectangle([i, i, W - 1 - i, H - 1 - i], outline=(150, 146, 138, a))
    return img.convert("RGBA")


def note(size=(268, 236)):
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")     # blend, don't punch holes — see above
    rng = random.Random(7)
    # torn edges: jitter the outline
    left = [(6 + rng.randint(-3, 3), y) for y in range(0, h, 9)]
    right = [(w - 7 + rng.randint(-3, 3), y) for y in range(h - 1, -1, -9)]
    poly = left + right
    d.polygon(poly, fill=(238, 236, 228, 255), outline=(196, 192, 182, 255))
    # opaque, pre-blended: the note IS RGBA (it needs the torn edge to be
    # transparent), so a translucent fill here would hole it — see background()
    for _ in range(26):
        x, y = rng.randrange(10, w - 10), rng.randrange(6, h - 6)
        r = rng.randint(3, 12)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(233, 231, 222, 255))
    # two tacks
    for tx in (int(w * 0.32), int(w * 0.68)):
        d.ellipse([tx - 7, 2, tx + 7, 16], fill=(78, 78, 90), outline=(38, 38, 48))
        d.ellipse([tx - 4, 5, tx + 1, 10], fill=(150, 150, 164))
    return img


def logo():
    # Sized so the whole lockup, tufts included, fits inside 640 with margin —
    # at scale 9 the wadding ran off both edges of the screen.
    big = outlined_word("STUFFED", scale=7, outline=3)
    small = outlined_word("THE", scale=3, outline=2)
    tuft_w = 96
    lw = big.width + tuft_w * 2
    lh = big.height + small.height + 6
    img = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    cy = small.height + 2
    img.alpha_composite(stuffing((tuft_w, big.height), False), (0, cy + 6))
    img.alpha_composite(stuffing((tuft_w, big.height), True),
                        (lw - tuft_w, cy + 6))
    img.alpha_composite(big, (tuft_w, cy))
    img.alpha_composite(small, (tuft_w + 10, 0))
    return img


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "ui")
    os.makedirs(out, exist_ok=True)
    for name, im in (("menu_bg", background()), ("menu_note", note()),
                     ("menu_logo", logo())):
        im.save(os.path.join(out, f"{name}.png"))
        print(f"assets/ui/{name}.png  {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
