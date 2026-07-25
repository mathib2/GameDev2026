# Architecture

## The one rule

**Core systems never contain content.**

There is no list of NPCs in a script. No `match target_id: "vending_machine": ...`
anywhere. No map knows about another map. Adding content means adding a file in
`res://data/` and placing a scene — it does not mean editing a system.

Everything below exists to make that rule hold under six people committing at
once.

---

## Layers

```
        ┌──────────────────────────────────────────────┐
 data/  │  .tres Resources — items, NPCs, missions,     │   designers + writers
        │  dialogue, hack targets, constructs           │
        └───────────────────┬──────────────────────────┘
                            │ indexed at boot by id
        ┌───────────────────▼──────────────────────────┐
scripts/│  Autoload systems — hold state, route events  │   systems programmers
 core/  │  Never reference specific content.            │
        └───────────────────┬──────────────────────────┘
                            │ signals via EventBus
        ┌───────────────────▼──────────────────────────┐
scenes/ │  Reusable scenes — Player, NPC,               │   gameplay + UI
        │  HackableObject, HUD, constructs              │
        └───────────────────┬──────────────────────────┘
                            │ instanced + configured
        ┌───────────────────▼──────────────────────────┐
levels/ │  Maps — just arrangements of the above        │   level designers
        └──────────────────────────────────────────────┘
```

A change at one layer should not force a change at another. If it does, that is
a design bug worth reporting.

---

## Autoloads

Ten, loaded in this order (order matters — later ones use earlier ones):

| Autoload | Responsibility | Holds state? |
|---|---|---|
| `EventBus` | Declares every global signal. **Nothing else.** | No |
| `GameState` | Flags, stats, credits, heat, integrity, what's been hacked | Yes |
| `ContentDB` | Scans `res://data` at boot, indexes every Resource by `id` | Yes (index) |
| `AudioManager` | Music, ambience, pooled SFX | No |
| `DialogueManager` | Walks a `DialogueData` tree | Yes (cursor) |
| `InventoryManager` | Item counts, buy/sell, stat bonuses | Yes |
| `MissionManager` | Active/completed contracts | Yes |
| `HackManager` | The full intrusion lifecycle | Yes |
| `SceneRouter` | Location loads, 2D↔3D handoff | Yes (refs) |
| `SaveManager` | Snapshot/restore | No |

**EventBus holds no state.** If you want to add a variable to it, it belongs in
`GameState`. This is what stops it becoming a god object.

---

## How systems communicate

Through `EventBus` signals, not direct references. A system that needs to react
to something connects to a signal; it does not get a reference to whoever
emitted it.

This is why the HUD has no reference to the player, and the player has no
reference to the dialogue box.

```
Player presses E on a HackableObject
        │
        ▼
EventBus.hack_requested(target: HackTargetData, source: Node)
        │
        ▼
HackManager  ── gate checks (already hacked? skill high enough?) ──┐
        │                                                          │
        │ passes                                        fails ─────▼
        ▼                                          EventBus.hack_refused
EventBus.hack_transition_started(target)
        │
        ▼
HackTransition (UI) shows the briefing, then calls
HackManager.begin_intrusion()
        │
        ▼
SceneRouter.enter_cyberspace(target)
   suspends the 2D world (process_mode = DISABLED, visible = false)
   instances target.cyberspace.scene_path
   calls construct.configure(target)
        │
        ▼
EventBus.cyberspace_entered(target)   → HUD shows trace bar + node counter
        │
   ┌────┴─────────────────────────────┐
   │ player captures HackNodes        │  HackManager.capture_node()
   │ ICE contact adds trace           │  HackManager.add_trace()
   │ trace timer runs                 │  HackManager._process()
   └────┬─────────────────────────────┘
        │
   nodes >= required            trace >= 1.0 / player aborts
        ▼                                 ▼
HackManager.succeed()             HackManager.fail(reason)
   mark_hacked, set success_flags     set failure_flags, add heat
   grant rewards
        │                                 │
        └──────────────┬──────────────────┘
                       ▼
        EventBus.cyberspace_exited(target, success)
                       │
                       ▼
        SceneRouter frees the construct, un-suspends the 2D world
```

Note what `HackManager` does **not** know: what a vending machine is, what the
factory construct looks like, or that a wheel exists. All of that is in
`HackTargetData` and `CyberspaceData` resources.

---

## Data architecture

Every data Resource has a `StringName id`. `ContentDB` scans `res://data`
recursively at boot and indexes by that id, so:

- content is **discovered**, not registered — no manifest to merge-conflict on
- data references data **by id** (`RewardData.id`, `DialogueLine.starts_mission`),
  not by hard resource link, which keeps `.tres` diffs small and independent
- save files only ever store ids and flags, so rebalancing content never
  invalidates a save

Duplicate ids are reported as warnings at boot and by `tools/validate_project.py`.

### Flags are the universal currency

Missions do not observe hacks, dialogue, or pickups. They observe **flags**:

```
MissionObjective.completed_when_flag  ──watches──▶  GameState.flags
                                                          ▲
                    ┌─────────────────────────────────────┤
        HackTargetData.success_flags     DialogueLine.sets_flags
        ItemData.sets_flags              HackableObject.discovery_flag
```

Any system that can set a flag can advance a mission without importing
`MissionManager`. This is the main reason missions are content, not code.

---

## Scene architecture

| Scene | Root type | Driven by | Owner |
|---|---|---|---|
| `Main.tscn` | `Node` | — | shared, rarely edited |
| `Player.tscn` | `CharacterBody2D` | `CharacterData` | Dev A |
| `NPC.tscn` | `Area2D` (`Interactable`) | `NPCData` | Dev B |
| `HackableObject.tscn` | `Area2D` (`Interactable`) | `HackTargetData` | Dev D |
| `Netrunner.tscn` | `CharacterBody3D` | `CyberspaceData` | Dev D |
| `HackNode.tscn` / `ICE.tscn` | `Area3D` / `CharacterBody3D` | `EnemyData` | Dev D |
| constructs | `Node3D` (`CyberspaceScene`) | `HackTargetData` | Dev D |
| `HUD` / `DialogueBox` / … | `Control` | EventBus only | Dev E |
| maps | `Node2D` | instanced scenes | Dev C |

`Main.tscn` is deliberately near-empty: a `World` node and a `UI` CanvasLayer.
It has no gameplay in it, which is what stops it becoming the file everyone has
to touch. **If you are adding game logic to `Main`, stop** — it belongs in a
system or a scene.

### Interactable

`Interactable` (Area2D) is the base for anything you can press E on. The player
never type-checks: it calls `interact()` and reads `get_prompt()`. Adding a new
kind of interactable — a door, a terminal, a pickup — requires no change to the
player, the HUD, or any manager.

### CyberspaceScene

Constructs subclass `CyberspaceScene` or use it directly. The contract:

- root extends `CyberspaceScene`
- optionally expose `runner_spawn`, `node_spawn_root`, `ice_spawn_root` NodePaths
- `HackNode` instances are found by the `hack_node` group

`configure(target)` spawns the netrunner, then tops up nodes and ICE to the
counts in `HackTargetData`. Hand-placed nodes are respected — the auto-scatter
only fills the gap. One construct can therefore serve several targets at
different difficulties.

`WheelChamber` is the worked example of a construct adding its own theatre
(`scripts/cyberspace/wheel_chamber.gd`) without any core system knowing.

---

## Extending the game

| I want to… | I touch |
|---|---|
| add an item | `data/items/*.tres` |
| add an NPC | `data/npcs/*.tres` + `data/dialogue/*.tres` + place `NPC.tscn` |
| add a conversation | `data/dialogue/*.tres` |
| add a mission | `data/missions/*.tres` (objectives = flags) |
| add a hackable object | `data/hack_targets/*.tres` + place `HackableObject.tscn` |
| add a construct | `scenes/cyberspace/*.tscn` + `data/cyberspace/*.tres` |
| add a map | `levels/**/*.tscn` + `data/locations/*.tres` |
| retune the player | `scripts/player/player.gd` |
| change the HUD | `scenes/ui/HUD.tscn` + `scripts/ui/hud.gd` |
| add a global event | `scripts/core/event_bus.gd` (signal only) |

If your change requires editing `hack_manager.gd`, `content_db.gd`, or
`main.gd` to add **content**, raise it in review — that is the architecture
failing, not you.

---

## Known gaps

Honest list of what is scaffolded but not finished:

- **Shops** — `NPCData.is_shopkeeper` and `EventBus.shop_opened` exist and
  `InventoryManager.buy/sell` work, but there is no shop UI scene yet.
- **Enemies in 2D** — `EnemyData` supports it; only ICE (3D) is implemented.
- **Save/load UI** — `SaveManager` works; nothing calls it yet.
- **Pause menu** — `scenes/menus/` is empty; `main.gd` has the hook.
- **Audio** — every hook is wired and every `AudioStream` field is safe when
  null, but no actual audio files ship yet.
- **Animation** — `Player`/`NPC` support `SpriteFrames`; placeholder art is
  static single-frame.
