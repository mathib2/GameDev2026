# Asset credits and licensing

## Summary

Almost everything here is original, generated for this project. There is
exactly one third-party source, recorded below.

## Third-party assets

| Asset | Creator | Source | Licence | Used for |
|---|---|---|---|---|
| Weapon Pack - FREE (`anim-bullet.png`) | VladPenn | https://vladpenn.itch.io/weapon | *"Feel free to use it in any free/commercial game, if you want to credit me, that would be nice :)"* — free for commercial use, attribution optional (given here) | Silhouettes for the toy weapons, artifacts and projectiles in `assets/items/`, `assets/effects/`, `assets/environment/prop_books.png` |
| 16x16 RPG Item Pack (72 sprites) | Alex's Assets | https://alexs-assets.itch.io/16x16-rpg-item-pack | **CC0 1.0 Universal** — public domain. Commercial use, modification and redistribution all permitted, attribution not required (credited here anyway, as the author asks) | Artifact and melee-weapon icons in `assets/items/`. Copied unmodified — see `tools/build_item_art.py` for the exact mapping |

Both packs are kept unmodified under `assets/third_party/` so every derivation
is reproducible from source.

The RPG item pack is CC0, so its sprites are used as-is. The weapon pack is
not: it is a modern-military set, and its sprites are repainted by
`tools/build_weapon_assets.py`, which also *adds* shading the originals never
had — a top-down light, darkened rim pixels and a specular corner. That last
part matters because a plain colour swap cannot raise quality: a source with
three flat tones stays three flat tones through any palette, which is what
made the earlier icons read as 8-bit. **The pack is a modern-military set** — the
sprites are recoloured through plastic ramps by
`tools/build_weapon_assets.py` before use, because a photoreal AK belongs in a
different game than this one. Shapes are the creator's; palettes are ours.

To regenerate after changing a pick:

```bash
python3 tools/build_weapon_assets.py assets/third_party/vladpenn_weapon_pack.png
```

`tools/extract_pack.py` splits a sheet into numbered sprites plus a contact
sheet, which is how you find the index to put in the `PICKS` table.

## Why the provided asset packs were not used

The brief listed asset packs to integrate:

```
CatPackFree.zip                       UiCozyFree.png.zip
Resurrected RPG 1.1.rar / .zip        Pixel Art Top Down - Basic v1.2.3.zip
Pixel-Portraits-Free.zip              Spritesheets.zip
Mini RPG Retro SFX Bundle             Retro Sounds 8-Bit
Weapon Pack - FREE                    GUNS V1.01
```

None of them could be found. Searched:

- `C:\Users\ANON2\Downloads`, `Desktop`, and the OneDrive Desktop folder
- the whole user profile to depth 5, and `C:\` to depth 7
- every branch of `mathib2/GameDev2026` (`master`, `godot-port`, `Agustin`,
  `Angel`, `Edwin`, `Mathias`) — zero files with archive or audio extensions
- the repository history

Rather than block, all art and audio was generated from scratch. **If you can
point me at the packs, swapping them in is cheap** — see "Replacing assets"
below, which is the whole reason the pipeline is structured the way it is.

## What ships today

| Asset | Files | How it was made | Licence |
|---|---|---|---|
| Character spritesheets | `assets/characters/`, `assets/enemies/`, `assets/bosses/` | Procedurally drawn to PNG via a Node.js canvas script | Original — project-owned |
| Environment tiles & props | `assets/environment/` | Same | Original — project-owned |
| Item & weapon icons | `assets/items/` | Same | Original — project-owned |
| Effects | `assets/effects/` | Same | Original — project-owned |
| Sound effects (24) | `assets/audio/sfx/` | Synthesised as 8-bit style waveforms in Python | Original — project-owned |
| Music (5 loops) | `assets/audio/music/` | Same — square/saw leads over square bass | Original — project-owned |

The generator scripts are not committed (they were scratch tooling). Say the
word and I will add them under `tools/` so the art and audio are reproducible.

## Replacing assets

The pipeline is deliberately swap-in-place. **No code changes are needed to
replace any asset.**

### Sprites

Every character sheet uses the same grid: **rows = animations, columns =
frames**.

```
row 0  idle      row 3  hurt
row 1  walk      row 4  death
row 2  attack    row 5  extra (player only: dodge)
```

Overwrite the PNG keeping that layout and it just works. If your sheet has a
different number of frames per row, set the `animations` dictionary on the
`SheetAnimator` node (or on the enemy's `.tres`) — no script edits.

Current frame sizes: player `48×48`, enemies `32×32`, boss `96×96`.

### Audio

Drop a `.wav` or `.ogg` into `assets/audio/sfx/` or `assets/audio/music/` and
assign it in the relevant `.tres`. Every audio field is optional and null-safe,
so a missing sound is silent rather than a crash.

## If you add third-party assets

Add a row here **in the same commit** recording:

- asset name, creator, source URL
- exact licence (CC0, CC-BY 4.0, OGA-BY, a store EULA, …)
- attribution text the licence requires
- where it is used in the project

Do not assume "free" means unrestricted. Several common packs are free to use
but forbid redistribution of the source files — which committing them to a
public repo would do. Check before committing, not after.
