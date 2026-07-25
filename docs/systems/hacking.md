# The hacking system

The one feature that has to be right. Everything else is a normal RPG.

## Design intent

The joke is **disproportion**. The gap between the problem and the response is
the whole game, so the systems are tuned to make the response feel heavy:

- a formal briefing before every intrusion, however trivial the target
- a trace timer, ICE patrols, and a node-capture objective for a can of soda
- deadpan `threat_assessment` copy that treats a bin-facing camera as an op

The failure state is being **noticed**, not being killed. ICE adds trace on
contact; it does not deal damage. You lose by being traced, and the cost is
heat, not death — which keeps the tone comic rather than punishing.

## Lifecycle

`HackManager` is a small state machine:

```
IDLE ──hack_requested──▶ BRIEFING ──begin_intrusion()──▶ TRANSITIONING
                             │                                │
                             │                          enter_cyberspace
                             │                                ▼
                             │                             ACTIVE
                             │                     ┌──────────┴──────────┐
                             │            nodes >= required      trace >= 1.0
                             │                     ▼                    ▼
                             └────────────────▶ RESOLVING ◀──────────────┘
                                                   │
                                                   ▼
                                                 IDLE
```

`BRIEFING` waits for the UI. `HackTransition` runs its tween and then calls
`begin_intrusion()` — the manager does not own timing, so the presentation can
be redesigned without touching the state machine.

## What lives where

| Concern | Lives in | Owner |
|---|---|---|
| lifecycle, gating, trace, resolution | `hack_manager.gd` | systems |
| target flavour, difficulty, rewards | `HackTargetData` `.tres` | design/writing |
| which 3D scene, look, runner speed | `CyberspaceData` `.tres` | 3D |
| 3D geometry and spawn markers | construct `.tscn` | 3D |
| briefing/result presentation | `hack_transition.gd` | UI |
| trace bar, node counter | `hud.gd` | UI |

`hack_manager.gd` contains **no target-specific code** and should stay that way.

## Gating

`_why_not(target)` returns a refusal string, or `""` to proceed. It checks:

- target has a construct assigned
- non-repeatable targets are not already hacked
- `GameState.get_stat("intrusion")` meets `required_skill`
  (which includes item bonuses via `InventoryManager.get_stat_bonus`)

Add a gate here, not at the call site — every entry point routes through
`EventBus.hack_requested`.

## Tuning a target

| Field | Effect |
|---|---|
| `difficulty` | label only; drives the briefing text |
| `trace_time` | seconds until auto-fail. `0` = untimed |
| `required_nodes` | nodes to capture to win |
| `ice_count` | ICE spawned |
| `required_skill` | minimum `intrusion` to attempt |
| `failure_heat` | heat added on failure |
| `repeatable` | can be hacked more than once |

Trace accrues at `1.0 / trace_time` per second, plus `trace_on_contact` per ICE
hit (default `0.18`, i.e. roughly five hits).

Rough guidance: a `TRIVIAL` target wants 3 nodes / 90 s / 1 ICE; `ABSURD` wants
5 nodes / 45 s / 4 ICE. The wheel deliberately breaks this — it is generous
(4 nodes / 90 s) because nobody should miss the punchline.

## Adding bespoke behaviour

Subclass `CyberspaceScene`. `wheel_chamber.gd` is the reference: it listens for
`EventBus.hack_succeeded`, checks the target id, and runs its own sequence.

```gdscript
extends CyberspaceScene

func _ready() -> void:
    EventBus.hack_succeeded.connect(_on_success)

func _on_success(t: HackTargetData) -> void:
    if t == null or t.id != &"my_target":
        return
    # theatre here
```

Guard on the id — constructs are shared between targets, and the signal is
global.

## Gotchas

- **The 2D world is suspended, not freed.** `SceneRouter` sets
  `process_mode = DISABLED` and `visible = false`. Anything relying on
  `_process` in the 2D world stops during a hack — usually what you want.
- **Mouse capture.** `Netrunner` captures the mouse on `_ready` and releases in
  `_exit_tree`. If you add another way out of cyberspace, make sure the runner
  is freed or the cursor stays trapped.
- **`hack_succeeded` fires before `cyberspace_exited`.** Rewards are granted
  while the construct is still alive, so on-success theatre can still play.
