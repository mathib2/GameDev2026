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

Spawn it from `Room._spawn_boss()`.

---

## Add a room type

`FloorGenerator.RoomKind` plus a case in `Room.populate()`. Existing kinds:
`START · COMBAT · TREASURE · SHOP · ELITE · SECRET · BOSS`.

Rooms build themselves from a `RoomInfo` — floors, walls, doors and decor are
generated, so there is no hand-authored scene per room and two people adding
rooms cannot conflict.

---

## Testing your change

```bash
# structural check, no Godot needed
python3 tools/validate_project.py

# real gameplay: generates a floor, clears it, fights the boss
godot --headless --autostart --smoketest --quit-after 8000
```

The smoke test exits non-zero on failure and is what CI runs. It catches things
`--import` cannot, because it only fails once objects actually spawn and
interact.

Then **play it.** Neither check can tell you the game feels good.
