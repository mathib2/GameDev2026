#!/usr/bin/env python3
"""Map the CC0 16x16 RPG item pack onto STUFFED's artifact and melee icons.

Straight copies, no recolouring. Unlike the weapon pack — which is military
and had to be repainted before it belonged in a toy box — these are generic
objects (food, boots, a flask, a goblet) that read fine as junk out of a
child's room. They also carry far more colour depth than the procedural icons
they replace, which is the whole point: the old ones were 2-3 flat tones.

Anything with no good match in the pack keeps its existing art, listed at the
bottom so the decision is visible rather than implied.

    python3 tools/build_item_art.py
"""

import os
import shutil

PACK = "assets/third_party/rpg_item_pack/Item__%02d.png"

# pack index -> destination
MAPPING = {
    # melee weapons
    12: "assets/items/wpn_hammer.png",
    9:  "assets/items/wpn_bat.png",
    # artifacts
    67: "assets/items/item_giant_steak.png",
    66: "assets/items/item_mystery_meat.png",
    31: "assets/items/item_energy_drink.png",
    71: "assets/items/item_angry_coffee.png",
    48: "assets/items/item_lucky_sock.png",
    50: "assets/items/item_steel_toecaps.png",
    2:  "assets/items/item_letter_opener.png",
    32: "assets/items/item_bad_marble.png",
    14: "assets/items/item_sandbox_spade.png",
    13: "assets/items/item_golden_dumbbell.png",
    56: "assets/items/item_dads_belt.png",
    64: "assets/items/item_protein_shake.png",
    65: "assets/items/item_gutshot.png",
    40: "assets/items/item_growth_spurt.png",
}

# kept as-is, and why
KEPT = {
    "item_first_aid.png": "the medkit cross reads more clearly than any pack item",
    "item_loose_screw.png": "no screwdriver in the pack",
    "item_walkie_talkie.png": "no radio in the pack",
    "item_tiny_teddy.png": "a teddy is the one thing a fantasy pack will never have",
    "wpn_fists.png": "not an object; has to stay bespoke",
}


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    os.chdir(root)
    missing = 0
    for idx, dest in sorted(MAPPING.items(), key=lambda kv: kv[1]):
        src = PACK % idx
        if not os.path.exists(src):
            print(f"!! missing {src}")
            missing += 1
            continue
        shutil.copyfile(src, dest)
        print(f"{dest}  <- Item__{idx:02d}")
    print(f"\n{len(MAPPING) - missing} icons replaced")
    print("kept as-is:")
    for k, why in KEPT.items():
        print(f"  {k:26s} {why}")


if __name__ == "__main__":
    main()
