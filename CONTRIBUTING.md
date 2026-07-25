# Contributing

## Branch workflow

`master` is the shared integration branch. Do not push to it directly.

```bash
git checkout -b feature/vending-machine-dialogue
# work
git push -u origin feature/vending-machine-dialogue
# open a PR into master
```

Branch names: `feature/…`, `fix/…`, `art/…`, `audio/…`, `level/…`.

Personal branches (`Edwin`, `Angel`, `Agustin`, `Mathias`) are fine for
in-progress work, but merge into `master` via a PR so someone else sees it.

## Commit messages

```
<area>: <what changed>

Why, if it isn't obvious.
```

Areas: `core`, `player`, `npc`, `dialogue`, `mission`, `hack`, `cyberspace`,
`ui`, `level`, `art`, `audio`, `docs`, `tools`.

```
hack: add traffic-light target and surveillance construct
ui: stop the trace bar showing outside cyberspace
art: replace placeholder vending machine sprite
```

One logical change per commit. Do not mix an art drop with a systems refactor —
it makes review and reverts painful.

## Before you open a PR

```bash
python3 tools/validate_project.py
```

Then **open the project in Godot and press F5.** The validator checks
structure, not behaviour; it cannot tell you the game is broken.

In the PR describe what you changed, how to see it in game, and anything you
knowingly left unfinished.

---

## Who owns what

The architecture exists so these lanes rarely collide. Stay in your lane and
merges stay boring.

| Role | Owns | Rarely needs to touch |
|---|---|---|
| **Player** | `scripts/player/`, `scenes/player/` | data, levels |
| **NPCs & writing** | `data/npcs/`, `data/dialogue/`, `scripts/npcs/` | core, cyberspace |
| **Levels & maps** | `levels/`, `data/locations/` | scripts |
| **3D cyberspace** | `scenes/cyberspace/`, `scripts/cyberspace/`, `scripts/enemies/`, `data/cyberspace/` | 2D scenes |
| **Art** | `assets/sprites/`, `textures/`, `models/`, `animations/` | scripts |
| **Audio** | `assets/audio/`, `scripts/audio/` | gameplay |
| **Systems** | `scripts/core/`, `scripts/hacking/`, `scripts/missions/`, `scripts/inventory/` | content |

**Shared files — coordinate before editing:**

- `project.godot` (autoloads, input map)
- `scripts/core/event_bus.gd` (adding a signal is fine; changing one is not)
- `scenes/main/Main.tscn`
- `README.md` / `CONTRIBUTING.md`

---

## Avoiding merge conflicts

Godot projects conflict badly if you fight the tooling. Rules that actually help:

**1. Never commit `.godot/`.** It is generated, per-machine, and enormous. It is
gitignored — keep it that way. If you see it in `git status`, something is wrong.

**2. Do commit `*.png.import` files.** They sit next to assets and are not
covered by the `.import/` ignore. Without them, everyone re-imports differently.

**3. Prefer new files over edits to shared ones.** Adding
`data/npcs/my_npc.tres` conflicts with nobody. Editing a giant shared scene
conflicts with everybody. This is the whole reason the project is data-driven.

**4. One scene per person per branch.** `.tscn` files are text but merge
horribly — node ids and `load_steps` shift. If two people must edit one scene,
split it into sub-scenes first.

**5. Do not reformat files you are not changing.** A whitespace pass across
`scripts/` turns every other open PR into a conflict.

**6. Pull before you start, not just before you push.**

```bash
git checkout master && git pull
git checkout -b feature/my-thing
```

**7. If you hit a `.tscn` conflict, take one side whole.** Do not hand-merge the
node list — resolve with `--ours`/`--theirs`, reopen in Godot, and redo the
smaller change by hand. Hand-merged scene files fail in ways that are very hard
to debug.

---

## Code conventions

**GDScript**

- Tabs for indentation (Godot's default). Never mix tabs and spaces.
- `snake_case` for files, functions, variables; `PascalCase` for `class_name`.
- Scripts: `snake_case.gd`. Scenes: `PascalCase.tscn`. Data: `snake_case.tres`.
- Type hints on exports and function signatures: `func foo(x: int) -> void:`.
- `@export` anything a designer should be able to change without code.
- Prefix intentionally unused parameters with `_`.

**Signals**

Global signals live in `EventBus` and nowhere else. Node-local signals stay on
the node. If you add a signal to `EventBus`, document its arguments in the
comment block.

**The architectural rule**

Core systems never contain content. If you find yourself writing

```gdscript
if target.id == &"vending_machine":
    # special case
```

in a system script, stop — that behaviour belongs in the Resource, or in a
construct subclass. See `scripts/cyberspace/wheel_chamber.gd` for how to add
bespoke behaviour without touching a system.

---

## Things not to commit

Covered by `.gitignore`, listed here so it is explicit:

- `.godot/`, `.import/` — generated
- build exports, `builds/`, `dist/`
- `.vscode/`, `.idea/`, `*.swp`
- `.DS_Store`, `Thumbs.db`, `desktop.ini`
- **secrets**: `.env`, API keys, signing keys, `*.keystore`

If you ever commit a credential, assume it is compromised: revoke it first,
then rewrite history. Removing it in a later commit is not enough.
