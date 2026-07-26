# ENTER THE STRONGEST

A top-down action roguelike. Patrick is sixteen and has never lost at
anything. Below the town is a cursed place that replicates real rooms almost
correctly — a playground, a gym, a steam room, an arena — and whoever walks
out of the bottom of it is the strongest. So he walked in. The place fills
itself with toys for him to fight; it does not understand what people fight,
only that they do.

The game plays it completely straight. The Teddy Bear King gets a screen shake,
a title card and a dramatic sting — and then he squeaks. That contrast is the
whole point, so nothing in the game ever acknowledges the joke.

> Godot 4.x port and expansion of an earlier HTML prototype (retired from the
> tree; see git history). Formerly titled STUFFED; the toys stayed when the
> title changed.

---

## Play it

**Prebuilt Windows binary:** see [Building](#building) — the export is not
committed (a 109 MB binary does not belong in git).

**From source:**

1. Install **Godot 4.3+** (built and tested with 4.7.1, standard build, no C#).
2. Open Godot → *Import* → select `project.godot`.
3. Press **F5**.

| Input | Action |
|---|---|
| `WASD` | move |
| Mouse / arrow keys | aim |
| Left click or `J` | attack |
| `Space` | dodge roll (i-frames) |
| `E` | pick up item |
| `Esc` | pause |

Movement is tuned for weight without sluggishness: high acceleration so input
registers instantly, lower friction so he keeps sliding a moment after you let
go. The dodge roll is the skill expression.

---

## The run

`Start → explore rooms → fight → collect → get stronger → boss → descend`

Five floors: **The Playground → The Gym → The Steam Room → The Underground
Arena → ????** — the last one is in black and white, and there is no name for
what is at the bottom of it. Each floor has its own surface (rubber mats,
court boards, wet ceramic, cracked concrete, a colourless grid) and is
procedurally generated — a random walk that promotes dead ends to special
rooms, so the boss is always the furthest point from the start. Five floors,
five bespoke bosses; the cap is deliberate.

**Room types:** combat · treasure · shop · elite · secret · boss

**No two rooms are laid out the same.** Every room draws a layout — where the
cover stands *and* where the fight starts, designed together — from a library of
38 authored ones in `data/rooms`, or from a generator that invents symmetric
ones when the library runs dry. It is seeded per room, so walking back in finds
the room you left.

**Eighteen enemies**, each with idle/walk/attack/hurt/death animations and its
own movement archetype. Ten Playground toys roam every floor:

| | | |
|---|---|---|
| Teddy Bear — chases | Gingerbread Man — sprints in bursts | Rubber Duck — drifts and squeaks |
| Toy Soldier — holds range and shoots | Baby Rattle — radial shockwaves | Stuffed Bunny — leaps |
| Wind-Up Teeth — bounces off walls | Porcelain Doll — slow, relentless, tanky | Toy Car — telegraphs, then charges |
| Building Block — stationary, fires spreads | | |

— and every floor below keeps two natives the others never see, tougher with
each floor down:

| Floor | Natives |
|---|---|
| The Gym | Kettlebell — telegraphs, then slides like a thrown weight · Jump Rope — skips at you in arcs |
| The Steam Room | Steam Valve — stationary, scalding radial bursts · Bar of Soap — skids in bursts, pauses |
| The Underground Arena | Punching Bag — slow, relentless, barely shoveable · Ring Bell — holds range, rings out shots |
| ???? | Static Mite — ricochets like a glitch · [REDACTED] — stationary, fires spreads of static |

**Boss: THE TEDDY BEAR KING.** Three phases, each *adding* an attack rather
than replacing one — slam, barrage, summon, charge — so it visibly escalates.

**Six weapons** (fists, bat, sledgehammer, toy gun, nail gun, shotgun) and
**ten items** (Protein Shake, Giant Steak, Angry Coffee, Dad's Old Belt,
Mystery Meat, Golden Dumbbell, Tiny Teddy Bear, Lucky Sock, Energy Drink,
Steel Toecaps).

---

## Project structure

```
assets/     characters/ enemies/ bosses/ environment/ items/ effects/ audio/
data/       enemies/ weapons/ items/ bosses/ rooms/   ← content, as .tres
scenes/     player/ enemies/ bosses/ rooms/ items/ ui/ menus/
scripts/    core/ player/ enemies/ bosses/ combat/ items/ levels/ ui/ dev/
docs/       ARCHITECTURE · ADDING_CONTENT · ASSET_CREDITS
tools/      validate_project.py
```

**The rule: core systems never contain content.** Adding an enemy, weapon or
item is a `.tres` file, not a script edit. See
[docs/ADDING_CONTENT.md](docs/ADDING_CONTENT.md).

Seven autoloads: `EventBus` (signals only, no state), `GameState`, `ContentDB`,
`AudioManager`, `GameFeel`, `Effects`, `RunManager`. Details in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Art and audio

All original — generated for this project. **The asset packs named in the brief
could not be found anywhere** (see
[docs/ASSET_CREDITS.md](docs/ASSET_CREDITS.md) for exactly where I looked).

Swapping them in later is cheap by design: every character sheet uses one grid
(rows = animations, columns = frames), so replacing a PNG in place needs no
code change.

---

## Building

Requires Godot **export templates** for 4.7.1 (*Editor → Manage Export
Templates*).

```bash
godot --headless --export-release "Windows Desktop"
# → ../EnterTheStrongest-Windows/EnterTheStrongest.exe
```

`export_presets.cfg` is committed on purpose — it defines the build and holds
no credentials. The output is gitignored.

---

## Testing

```bash
python3 tools/validate_project.py     # structure; no Godot needed
godot --headless --autostart --smoketest --quit-after 8000
```

The smoke test drives a real run without input: generates a floor, walks every
room, kills what it finds, fights the boss, and exits non-zero on failure. It
catches what `--import` cannot, because it only fails once things actually
spawn and interact — it is how the "exported build ships with zero content" bug
was found.

Neither check tells you the game *feels* good. Play it.

---

## Team

| Branch | Owner |
|---|---|
| `master` | Shared / integration |
| `stuffed-godot` | This Godot project |
| `Edwin` / `Angel` / `Agustin` / `Mathias` | Personal working branches |

See [CONTRIBUTING.md](CONTRIBUTING.md).
