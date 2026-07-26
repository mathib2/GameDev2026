# Adding content

The rule: **core systems never contain content.** Adding an enemy, weapon or
item means adding a `.tres` file — not editing a script. `ContentDB` scans
`res://data` at boot and indexes by `id`, so there is no manifest to conflict on.

---

## Add an enemy

1. **Art** — `assets/enemies/enemy_<name>.png`, 32×32 frames, rows:
   `0 idle · 1 walk · 2 attack · 3 hurt · 4 death`.
2. **Data** — right-click `data/enemies/` → *New Resource* → **EnemyData**.
   Save as `<name>.tres`.
3. Set `id` (must be unique), `display_name`, `spritesheet`, and pick a
   `behaviour`.
4. Tune health, speed, cooldowns, drops, and sounds.
5. Gate it by depth: `min_floor` is the first floor it appears on, and
   `max_floor` (default -1 = no cap) the last. `min_floor == max_floor` makes
   it **native to exactly one floor** — that is how the Gym keeps its
   Kettlebell and ???? keeps its [REDACTED]. `godot --headless --genaudit`
   prints every floor's roster so you can see where a new toy landed.

That's it — it now appears in the spawn pool automatically.

### Behaviour archetypes

| Archetype | Used by | What it does |
|---|---|---|
| `CHASER` | Teddy Bear | walks straight at you |
| `SPRINTER` | Gingerbread Man | bursts of speed, pauses to twitch |
| `WANDERER` | Rubber Duck | drifts, cheats slightly toward you |
| `SHOOTER` | Toy Soldier | holds range, fires |
| `SHOCKWAVE` | Baby Rattle | stationary, radial bursts |
| `HOPPER` | Stuffed Bunny | leaps in arcs |
| `PATROL` | Wind-Up Teeth | bounces off walls, homes up close |
| `CREEPER` | Porcelain Doll | slow, relentless, high HP |
| `CHARGER` | Toy Car | telegraphs, then rockets in a line |
| `BUILDER` | Building Block | stationary, fires a spread |

Need a genuinely new *movement pattern*? Add a case to `_think()` in
`scripts/enemies/enemy.gd` and a value to the `Behaviour` enum. Do **not** make
a new scene per enemy.

---

## Add a weapon

`data/weapons/<id>.tres` → **WeaponData**.

- `kind = MELEE` uses `arc_degrees` + `reach` (a sweep in front of you)
- `kind = RANGED` uses `projectile_*`, `spread_degrees`, `pierce`

`shake` and `hitstop` are per-weapon on purpose — a sledgehammer should freeze
time longer than a toy gun. That contrast is most of what makes a weapon feel
different.

Equip on run start in `RunManager.start_run()`, or drop one on a pedestal.

---

## Add an item

`data/items/<id>.tres` → **ItemData**. Effects are a plain `modifiers`
dictionary applied to stats, so no code is involved.

Recognised keys:

```
damage_mult  damage_flat  speed_mult  max_health  fire_rate_mult
knockback_mult  crit_chance  dodge_cooldown_mult  contact_armour
```

Keys ending `_mult` multiply together; everything else adds. Set `weight` for
rarity and `unique` to stop it appearing twice.

Write a `flavour` line — it is what pops up on pickup, and it is where the
humour lives. Keep it short and stupid: *"raw. obviously"*.

---

## Add a boss

Bosses are bespoke enough to justify their own script. Copy
`scripts/bosses/teddy_bear_king.gd` as a starting point:

- three phases triggered at health fractions, each **adding** an attack rather
  than replacing one, so the fight visibly escalates
- emit `EventBus.boss_spawned`, `boss_health_changed`, `boss_phase_changed`,
  `boss_defeated` — the HUD and RunManager listen and need nothing else
- do the intro straight: `boss_intro_started`, a big shake, a serious sting.
  **Then** the squeak. The game must never acknowledge the joke.

There is one boss per floor — five of each, and the cap is deliberate.
`Room.BOSS_SCENES` is indexed by `floor_index`, not cycled. To add a sixth,
write the script and scene, append it to that list, and give it a floor to
live on in `RunManager.FLOOR_NAMES` — the smoke test derives its pass criteria
from `total_floors()`, so it starts requiring the new boss automatically
rather than silently skipping it.

Art: `tools/build_bosses.py` draws the 5x5 96px sheets procedurally. Add a draw
function plus a `*_params` function returning per-frame values, and add both to
the tuple in `main()`.

---

## Add a skill

One entry in `GameState.SKILLS`:

```gdscript
&"greed": {"name": "GREED", "blurb": "+1 coin per pickup",
    "mods": {&"coin_bonus": 1}},
```

`mods` uses the same keys as items (`_mult` multiplies, everything else adds)
and is applied once per level, capped at `SKILL_MAX`. Add a colour to
`TINTS` in `scripts/items/skill_shrine.gd` so its shrine is distinguishable —
that is the only other place that needs touching, and shops pick which two
skills to stock at random.

## Add a room layout

A layout is where the cover stands and where the fight starts, drawn as ASCII.
`data/rooms/<id>.tres` → **RoomLayoutData**. Like everything else in `data/`, it
is found at boot — no list to register it on.

The grid is **12 rows of exactly 20 characters**: the room's full tile size,
border included. The border ring and its door gaps are drawn so you can see what
you are doing and are ignored on parse — `Room` builds its own walls.

This is `data/rooms/combat_crossfire.tres`, unedited:

```
#########..#########
#..................#
#..##..##..##..##..#
#..#.e..#..#..e.#..#
#....e........e....#
....................     <- rows 5 and 6 are the horizontal door lane
....................
#....e........e....#
#..#.e..#..#..e.#..#
#..##..##..##..##..#
#..................#
#########..#########
         ^^
         columns 9 and 10 are the vertical one
```

| char | means |
|---|---|
| `.` or space | empty floor |
| `#` | crate — breakable cover, blocks movement *and* shots |
| `o` | optional crate: there about half the time |
| `e` | enemy spawn anchor |
| `E` | anchor for the big one — the room spawns a champion on it |
| `p` | cosmetic prop, no collision |
| `r` | reward anchor: where a pedestal or chest goes |

Then tag where it may appear:

```gdscript
kinds = PackedStringArray("combat", "elite")   # never "boss"
min_floor = 2        # gentle layouts can retire with max_floor
weight = 1.5         # relative pick chance against the others
```

### The two rules

**Columns 9-10 and rows 5-6 are the door lanes.** Nothing solid may sit in
them — walls are not breakable and doors are the only way out, so a blocked lane
is a soft-locked run. **Nothing may be walled in**, either; an enemy sealed
behind crates is a room whose doors will not open until the player works out
they are meant to smash their way in.

Both are enforced. `ContentDB` runs `RoomLayoutData.validate()` at load and
*refuses* a layout that breaks them, with the reason in the warning log — the
room falls back to a generated layout rather than shipping broken.

### Sizing it

Keep it between roughly 4 and 24 crates. Crates pay out coins, so a wall-to-wall
room does not just play badly, it prints money. Four to eight anchors is plenty:
the floor decides how many toys it wants, and anything past the anchor count
fills open floor at random.

### Checking it

```bash
godot --headless --genaudit --audit-runs 50
```

prints how many layouts each room kind can draw on, and stress-tests the
procedural generator that fills the gaps.

---

## Add a room type

`FloorGenerator.RoomKind` plus a case in `Room.populate()`, and a name in
`FloorGenerator.KIND_NAMES` so layouts can tag themselves for it. Existing kinds:
`START · COMBAT · TREASURE · SHOP · ELITE · SECRET · BOSS`.

Rooms build themselves from a `RoomInfo` — floors, walls, doors and decor are
generated, so there is no hand-authored scene per room and two people adding
rooms cannot conflict.

---

## Testing your change

```bash
# real gameplay: generates every floor, clears them, fights every boss,
# and checks the skill economy. This is the gate.
godot --headless --autostart --smoketest --quit-after 200000

# look at it without playing it — writes PNGs to the user data dir.
# Needs a real window; --headless renders nothing to capture.
godot --autostart --screenshot --shot-delay 6 --shot-count 3
```

The smoke test exits non-zero on failure and is what CI runs. It catches things
`--import` cannot, because it only fails once objects actually spawn and
interact.

Then **play it.** Neither check can tell you the game feels good.
