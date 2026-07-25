# Data Resources

Every piece of game content is a Godot `Resource` saved as `.tres` under
`res://data/`. `ContentDB` scans that folder at boot and indexes everything by
its `id`.

## Why

- **No manifest.** Content is discovered, so there is no registry file for four
  people to conflict on.
- **Small diffs.** One NPC is one file. Two people adding two NPCs never touch
  the same bytes.
- **Durable saves.** Saves store ids and flags, never Resources, so rebalancing
  content cannot invalidate a save.
- **Designer-editable.** Everything is `@export`ed and editable in the inspector
  by someone who does not write GDScript.

## The types

| Class | Folder | Purpose |
|---|---|---|
| `ItemData` | `data/items/` | items, gear, key objects |
| `NPCData` | `data/npcs/` | characters (extends `CharacterData`) |
| `EnemyData` | `data/characters/` | hostiles and ICE |
| `DialogueData` | `data/dialogue/` | a conversation tree |
| `DialogueLine` | (sub-resource) | one beat |
| `DialogueChoice` | (sub-resource) | a branch |
| `MissionData` | `data/missions/` | a contract |
| `MissionObjective` | (sub-resource) | one step, satisfied by a flag |
| `RewardData` | (sub-resource) | item / credits / flag / xp / unlock / heal |
| `HackTargetData` | `data/hack_targets/` | a hackable object |
| `CyberspaceData` | `data/cyberspace/` | a 3D construct |
| `LocationData` | `data/locations/` | a map |

## Rules

**1. Every resource needs a unique, non-empty `id`.** It is how everything else
refers to it. `tools/validate_project.py` enforces this.

**2. Reference other content by id, not by resource link, where you can.**

```gdscript
grants_item = &"nutri_cola"          # good — loose, small diff
```

Direct links (`HackTargetData.cyberspace`) are used where the relationship is
structural and one-to-one. Ids are used where content should stay independent.

**3. Flags are how systems talk to content.** A mission objective completes when
a flag is set; it does not care who set it. Namespace them: `wheel_reinvented`,
`met_vale`, `camera_11_owned`.

**4. Sub-resources belong in the same file as their owner.** Dialogue lines live
in the dialogue `.tres`; reward entries live in the mission or hack target.
One conversation = one file = one reviewable diff.

## Creating one in the editor

1. Right-click the target folder → **New Resource**.
2. Search the class (e.g. `HackTargetData`) → **Create**.
3. Save as `snake_case.tres` in the right folder.
4. Fill in the inspector. **Set `id` first** — an empty id is skipped at boot
   with a warning.

To add a sub-resource (a dialogue line), click the array field → **Add
Element** → **New DialogueLine**.

## Hand-editing `.tres`

Usually a bad idea; the editor is safer. If you must:

- `load_steps` must equal `ext_resource` + `sub_resource` + 1
- every `ExtResource("x")` needs a matching `[ext_resource ... id="x"]`
- `StringName` values are written `&"like_this"`
- plain arrays (`[SubResource("A"), SubResource("B")]`) are coerced into the
  typed array on load

Then run `python3 tools/validate_project.py`, which checks all of the above.

## Load errors

`ContentDB` reports problems at boot rather than failing silently:

```
[ContentDB] 3 items, 2 npcs, 2 missions, 3 hack targets, 1 locations, 2 constructs
```

Warnings are pushed for a missing `id`, an unrecognised type, or a duplicate id
(later file wins). Check the output panel if content is not appearing.
