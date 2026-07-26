# Architecture

## The one rule

**Core systems never contain content.** No script holds a list of enemies. No
`match enemy_id:` anywhere. Adding content = adding a `.tres`.

## Layers

```
data/     .tres Resources (enemies, weapons, items)   designers
   │      indexed at boot by ContentDB, keyed on `id`
scripts/  autoload systems — state + routing, never content
   │      communicate via EventBus signals
scenes/   reusable scenes driven by assigned Resources
   │
levels/   rooms build themselves from a RoomInfo
```

## Autoloads

| Autoload | Responsibility | State? |
|---|---|---|
| `EventBus` | declares every global signal, nothing else | no |
| `GameState` | health, coins, items, computed stats | yes |
| `ContentDB` | scans `res://data`, indexes by id | yes (index) |
| `AudioManager` | pooled SFX + music | no |
| `GameFeel` | screen shake, hit stop | yes |
| `Effects` | particles, damage numbers, impacts | no |
| `RunManager` | floors, rooms, travel | yes |

`EventBus` holds no variables. If you want to add one, it belongs in
`GameState` — that is what stops it becoming a god object.

## Stats are computed, never mutated

Items never touch the player. `GameState` recomputes from a base table plus
every item's `modifiers` dictionary, so effects can be added or removed
cleanly and a new item needs no code:

```
BASE ──┐
       ├─▶ _recompute() ──▶ stat("damage_mult") ──▶ player reads it
items ─┘
```

Keys ending `_mult` multiply; everything else adds.

## Combat flow

```
Player._melee()  ─ arc + range test ─▶ enemy.take_damage(dmg, from, crit, kb)
Player._shoot()  ─ Projectile ───────▶ enemy.take_damage(...)
                                          │
                    ┌─────────────────────┼─────────────────────┐
              damage number          knockback              hit flash
                    │                     │                     │
                    └──▶ EventBus.hit_stop + screen_shake ◀──────┘
```

Hit stop and shake are per-weapon (`WeaponData.hitstop` / `.shake`) so a
sledgehammer and a toy gun feel genuinely different. `GameFeel` runs with
`PROCESS_MODE_ALWAYS` and ticks on unscaled time, or hit stop (which sets
`time_scale` to ~0) could never expire.

## Animation

`SheetAnimator` (`scripts/core/sheet_animator.gd`) plays grid spritesheets:
rows = animations, columns = frames, driven by `hframes`/`vframes` + `frame`.
No `SpriteFrames` resources to hand-author, no `AnimationPlayer` per character.
An artist replaces a PNG keeping the grid and nothing else changes.

## Floors

`FloorGenerator` random-walks a grid (ported from the HTML prototype's
`genFloor()`), discourages dense blobs so the map stays branchy, then promotes
dead ends: furthest becomes the boss, the rest become treasure/shop/secret.
Elites are picked from ordinary combat rooms on deeper floors.

`Room` builds its own floor tiles, wall colliders, door triggers and decor from
a `RoomInfo`. There is no hand-authored scene per room, so two people adding
rooms cannot conflict.

## Room layouts

What is *inside* a room is a layout: cover and enemy anchors designed against
each other, the way Isaac and Gungeon build theirs. Scattering obstacles at
random and then dropping enemies wherever they land produces a box with junk in
it; a layout produces a fight with a shape.

```
data/rooms/*.tres ──┐
  authored ASCII    ├─▶ Room._choose_layout() ──▶ crates + enemy anchors
RoomLayout          │      seeded per room, so re-entry is identical
  .procedural() ────┘
```

Authored layouts come first, drawn by weight from those tagging the room's kind
and depth. Combat rooms roll `PROC_CHANCE` to take a generated one instead, and
anything the library cannot serve falls through to the generator — the library
is finite and a fourteen-floor run is not.

Two rules hold both paths, by different means:

| | rule | authored | generated |
|---|---|---|---|
| 1 | nothing solid in a door lane | `check()` rejects it at load | never writes to a lane |
| 2 | nothing walled in | `check()` flood-fills from the centre | anchors drawn from the reachable set |

Rule 1 is safety: walls are not breakable and doors are the only way out, so a
blocked lane is a soft-locked run. Rule 2 is quality — crates *are* breakable,
so a sealed enemy is merely a room that will not open until the player smashes
their way in.

A rejected layout is logged with its reason and skipped, never shipped.

## Skills

Items are *found*; skills are *bought*. `GameState.SKILLS` defines five, each
capped at 5 levels, purchased by walking into a shrine in a shop room. They
fold into `_recompute()` through the same modifier dictionary items use, so no
stat code knows skills exist — a new skill is one entry in that constant.

```
BASE ──┐
items ─┼─▶ _recompute() ──▶ stat("damage_mult")
skills ┘   (applied once per level)
```

## Rewards

| Thing | Where | Cost | Pays out |
|---|---|---|---|
| Item pedestal | treasure, shop, elite/boss clear | free or priced | one `ItemData` |
| Weapon pedestal | treasure, boss clear | free | one `WeaponData` |
| Wooden chest | 22% of cleared combat rooms | free | coins, sometimes a heart |
| Gold chest | treasure rooms, shops | free / priced | an item or a weapon, plus coins |
| Skill shrine | shops (2 of 5, random) | coins, rising per level | one permanent skill level |

All of them are *walked into* rather than prompted — there is no interact key
in this game, and adding one for a single feature would be worse than the
duplication.

## Known gaps

Honest list of what is scaffolded but unfinished:

- **`tiny_teddy` grants stats instead of a companion.** `ItemData.companion_scene`
  exists and `RunManager._on_item_collected` honours it, but no item sets it.
- **No 3D elements** (section 16 was explicitly optional).
- **Shop rooms** price items but there is still no dedicated shop *UI* — the
  shop is pedestals, shrines and a chest laid out in a room.
- **The minimap** marks visited rooms and the boss, but not shops or treasure.
- **Bosses do not scale past floor 4.** `SUB-BASEMENT n` floors reuse the
  four-boss rotation with only the `floor_index` health multiplier.
