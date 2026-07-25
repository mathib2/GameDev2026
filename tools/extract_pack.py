#!/usr/bin/env python3
"""Split a sprite-pack sheet into individual PNGs by connected alpha islands.

The packs we pull in are not grid-aligned — a sniper rifle spans six 16px cells
while a pistol fits in one — so slicing on a fixed grid mangles them. This finds
each sprite as a connected run of non-transparent pixels instead, then merges
islands that are close enough to be one sprite (a scope sitting a pixel above a
barrel, a muzzle flash detached from the gun).

Usage:
    python3 tools/extract_pack.py <sheet.png> <outdir> [--gap 2] [--min-px 12]

Writes <outdir>/sprite_XXX.png plus <outdir>/_contact.png, a numbered contact
sheet for eyeballing which index is which.
"""

import argparse
import sys
from collections import deque

from PIL import Image, ImageDraw


def islands(img, alpha_floor=8):
    """Label connected non-transparent regions, 8-connectivity. Returns bboxes."""
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or px[sx, sy][3] <= alpha_floor:
                continue
            x0 = x1 = sx
            y0 = y1 = sy
            q = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            while q:
                x, y = q.popleft()
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                            if px[nx, ny][3] > alpha_floor:
                                seen[ny * w + nx] = 1
                                q.append((nx, ny))
            boxes.append([x0, y0, x1, y1])
    return boxes


def merge_close(boxes, gap):
    """Union boxes whose expanded rects overlap — repeatedly, until stable."""
    changed = True
    while changed:
        changed = False
        out = []
        for b in boxes:
            for o in out:
                if (b[0] - gap <= o[2] and o[0] - gap <= b[2]
                        and b[1] - gap <= o[3] and o[1] - gap <= b[3]):
                    o[0] = min(o[0], b[0]); o[1] = min(o[1], b[1])
                    o[2] = max(o[2], b[2]); o[3] = max(o[3], b[3])
                    changed = True
                    break
            else:
                out.append(list(b))
        boxes = out
    return boxes


def load_sprites(path, gap=0, min_px=12):
    """Sheet -> ordered list of (bbox, cropped RGBA sprite).

    Single source of truth for sprite *indices*. Anything that refers to a
    sprite by number — build_weapon_assets.py's PICKS table, the contact sheet,
    the montage — must come through here, or the numbering silently diverges
    and you quietly ship a banana where a shotgun should be.
    """
    img = Image.open(path).convert("RGBA")
    boxes = merge_close(islands(img), gap)
    boxes.sort(key=lambda b: (b[1] // 16, b[0]))
    out = []
    for b in boxes:
        crop = img.crop((b[0], b[1], b[2] + 1, b[3] + 1))
        if sum(1 for p in crop.getdata() if p[3] > 8) < min_px:
            continue
        out.append((b, crop))
    return img, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("outdir")
    ap.add_argument("--gap", type=int, default=2,
                    help="merge islands within this many px of each other")
    ap.add_argument("--min-px", type=int, default=12,
                    help="drop sprites with fewer opaque pixels than this")
    args = ap.parse_args()

    import os
    os.makedirs(args.outdir, exist_ok=True)

    img, kept = load_sprites(args.sheet, args.gap, args.min_px)

    for i, (b, crop) in enumerate(kept):
        crop.save(f"{args.outdir}/sprite_{i:03d}.png")
        print(f"{i:03d}  {crop.width:>3}x{crop.height:<3} at ({b[0]},{b[1]})")

    # contact sheet: original at 4x with numbered boxes
    scale = 4
    contact = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    contact = Image.alpha_composite(
        Image.new("RGBA", contact.size, (32, 32, 40, 255)), contact)
    d = ImageDraw.Draw(contact)
    for i, (b, _) in enumerate(kept):
        d.rectangle([b[0] * scale - 1, b[1] * scale - 1,
                     (b[2] + 1) * scale, (b[3] + 1) * scale],
                    outline=(255, 80, 80, 255))
        d.text((b[0] * scale, b[1] * scale - 9), str(i), fill=(255, 220, 80, 255))
    contact.save(f"{args.outdir}/_contact.png")
    print(f"\n{len(kept)} sprites -> {args.outdir}/  (see _contact.png)", file=sys.stderr)


if __name__ == "__main__":
    main()
