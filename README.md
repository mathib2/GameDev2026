# Rogue Protocol

A 2D cyberpunk RPG in which an extraordinarily skilled netrunner solves
completely trivial problems using military-grade cybersecurity.

> *To reinvent the wheel means to waste time and effort creating a basic thing
> that already exists and works well.*

Want a soda? The machine takes coins, and you have coins. You will instead
breach its supply-chain firmware through a 3D cyberspace construct patrolled by
intrusion countermeasures, on a 60-second trace timer, and issue a dispense
command as root.

The signature mechanic is the round trip:

```
2D world → hack initiated → briefing → 3D cyberspace → intrusion
        → success/failure → back to 2D → consequences
```

---

## Requirements

- **Godot 4.3** or newer (4.x, standard build — no C#/Mono needed)
- Download: <https://godotengine.org/download>

## Running the game

1. Open Godot, choose **Import**, and select `project.godot` in this folder.
2. Let it finish the first import (it builds `.godot/`, which is gitignored).
3. Press **F5**.

| Key | Action |
|---|---|
| `WASD` / arrows | move |
| `E` | interact / talk / hack |
| `Space` | advance dialogue, jump in cyberspace |
| `I` | inventory + contracts |
| `Esc` | abort an intrusion |
| `M` | mute |

## Project structure

```
assets/     art, audio, fonts, shaders          — swap files in place
data/       .tres Resources: the game's content — add files here
scenes/     reusable scenes (player, NPC, UI, constructs)
scripts/    systems and behaviour
  core/       EventBus, GameState, ContentDB, SceneRouter
  data/       Resource class definitions (the schemas)
  hacking/    HackManager, HackableObject
  cyberspace/ constructs, netrunner, hack nodes
levels/     maps — arrangements of the above
docs/       architecture and system notes
tools/      validate_project.py
```

**The rule:** core systems never contain content. Adding an NPC, mission, item,
or hackable object means adding a `.tres` file — not editing a script. See
[docs/architecture.md](docs/architecture.md).

---

## How to add things

### …a character sprite, texture, or model

Drop the file in `assets/sprites/` (or `textures/`, `models/`). In the
character's `.tres`, set `sprite` — or `sprite_frames` for animation. Nothing
else changes. Replacing placeholder art is literally overwriting the PNG.

### …an NPC

1. `data/npcs/my_npc.tres` → new Resource → **NPCData**. Set `id`,
   `display_name`, `sprite`, `behaviour`.
2. `data/dialogue/my_npc_intro.tres` → **DialogueData**, add `DialogueLine`
   entries as sub-resources.
3. Assign the dialogue to the NPC's `dialogues` array.
4. Open a map, instance `scenes/npcs/NPC.tscn`, assign your `.tres` to `data`.

No scripts. When an NPC has several dialogues, the highest-`priority` one whose
`required_flags` / `blocked_by_flags` pass is used.

### …a mission

`data/missions/my_mission.tres` → **MissionData**. Each `MissionObjective` has a
`completed_when_flag`. Anything that sets that flag completes the objective — a
hack, a dialogue line, an item, walking into range of something. Set
`auto_start`, or start it from a `DialogueLine.starts_mission`.

### …a hackable object

1. `data/hack_targets/my_target.tres` → **HackTargetData**.
2. Write `mundane_solution` / `absurd_solution` / `threat_assessment` — this is
   where the comedy lives, and it is content, not code.
3. Point `cyberspace` at a **CyberspaceData**.
4. Add `rewards`, `success_flags`, difficulty, `trace_time`, `ice_count`.
5. Instance `scenes/objects/HackableObject.tscn` in a map, assign `target`.

### …a 3D cyberspace environment

1. New 3D scene in `scenes/cyberspace/`, root script `cyberspace_scene.gd`
   (or a subclass for bespoke behaviour — see `wheel_chamber.gd`).
2. Add geometry, a `WorldEnvironment`, and a floor with collision on layer 1.
3. Add `Marker3D`s under `RunnerSpawn`, `NodeSpawns`, `ICESpawns`, and wire the
   three NodePath exports.
4. `data/cyberspace/my_construct.tres` → **CyberspaceData** pointing at the scene.
5. Reference it from any `HackTargetData`.

Different targets use different constructs: vending machine → digital factory,
camera → surveillance network, car → digital highway, corporate server →
digital skyscraper.

### …a map or level

New scene in `levels/city/` (or `interiors/`, `cyberspace/`), instance
`Player.tscn`, NPCs and hackables. Then `data/locations/my_map.tres` →
**LocationData** with `scene_path`. Travel with
`SceneRouter.goto_location(&"my_map")`.

### …music, ambience, or sound effects

Drop files in `assets/audio/{music,ambient,sfx,dialogue}/` and assign them in
the relevant `.tres`. Every audio field is optional and null-safe, so content
ships fine before the audio exists.

---

## Validating your changes

```bash
python3 tools/validate_project.py
```

Checks that every `res://` path resolves, every `ExtResource`/`SubResource` is
declared and used, `load_steps` is correct, node parents resolve, autoloads
exist, `@onready $Node` paths exist in the paired scene, and data ids are
present and unique.

It does **not** check GDScript semantics or runtime behaviour — open the
project in Godot for that.

## The mission

There is an optional contract called **REINVENT THE WHEEL**. Talk to Vale.

---

## Team

| Branch | Owner |
|--------|-------|
| `master` | Shared / integration branch |
| `godot-port` | Godot 4.x project (this branch) |
| `Edwin` | Edwin's working branch |
| `Angel` | Angel's working branch |
| `Agustin` | Agustin's working branch |
| `Mathias` | Mathias's working branch |

```bash
git clone https://github.com/mathib2/GameDev2026.git
cd GameDev2026
git checkout godot-port
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch workflow, which files belong
to whom, and how to avoid merge conflicts in a Godot repo.
