extends Node

## Global signal hub. Autoload: EventBus
##
## Systems emit here and listen here instead of holding references to each
## other. This is what keeps the modules independent enough that six people can
## work in parallel without editing the same files.
##
## Rule: EventBus declares signals and nothing else. No state, no logic. If you
## are tempted to add a variable here, it belongs in GameState.

# ── World / flow ──────────────────────────────────────────────────────────
signal game_started()
signal location_changed(location_id: StringName)
signal player_spawned(player: Node)

# ── Interaction ───────────────────────────────────────────────────────────
signal interactable_focused(interactable: Node, prompt: String)
signal interactable_unfocused(interactable: Node)
signal interaction_requested(interactable: Node)

# ── Dialogue ──────────────────────────────────────────────────────────────
signal dialogue_started(dialogue: DialogueData)
signal dialogue_line_shown(line: DialogueLine)
signal dialogue_choices_offered(choices: Array)
signal dialogue_finished(dialogue_id: StringName)

# ── Inventory / economy ───────────────────────────────────────────────────
signal item_added(item_id: StringName, count: int)
signal item_removed(item_id: StringName, count: int)
signal credits_changed(new_total: int)
signal shop_opened(npc_data: NPCData)

# ── Missions ──────────────────────────────────────────────────────────────
signal mission_started(mission_id: StringName)
signal mission_objective_completed(mission_id: StringName, index: int)
signal mission_completed(mission_id: StringName)

# ── Hacking: the 2D -> 3D -> 2D round trip ────────────────────────────────
signal hack_requested(target: HackTargetData, source: Node)
signal hack_refused(target: HackTargetData, reason: String)
signal hack_transition_started(target: HackTargetData)
signal cyberspace_entered(target: HackTargetData)
signal hack_node_captured(captured: int, required: int)
signal trace_level_changed(fraction: float)
signal hack_succeeded(target: HackTargetData)
signal hack_failed(target: HackTargetData, reason: String)
signal cyberspace_exited(target: HackTargetData, success: bool)

# ── Progression ───────────────────────────────────────────────────────────
signal flag_set(flag: StringName)
signal stat_changed(stat: StringName, value: int)
signal heat_changed(heat: int)
signal reward_granted(reward: RewardData)

# ── Presentation ──────────────────────────────────────────────────────────
signal toast_requested(text: String)
signal screen_shake_requested(strength: float)
