# Asset credits and licensing

## Summary

**Every asset in this repository is original, generated for this project.**
There is no third-party content, and therefore no third-party licence to
comply with.

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
