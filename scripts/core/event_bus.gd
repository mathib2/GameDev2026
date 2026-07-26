extends Node

## Global signal hub. Autoload: EventBus
##
## Systems emit and listen here instead of holding references to each other.
## Declares signals and nothing else — state belongs in GameState.

# ── run flow ──────────────────────────────────────────────────────────────
signal run_started()
signal run_ended(victory: bool)
signal floor_entered(index: int, name: String)
signal room_entered(room: Node)
signal room_cleared(room: Node)
signal minimap_dirty()

# ── combat ────────────────────────────────────────────────────────────────
signal player_spawned(player: Node)
signal player_damaged(amount: int, hp: int, max_hp: int)
signal player_healed(hp: int, max_hp: int)
signal player_died()
signal enemy_died(enemy: Node)

# ── boss ──────────────────────────────────────────────────────────────────
signal boss_spawned(boss: Node, display_name: String)
signal boss_health_changed(fraction: float)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss: Node)
signal boss_intro_started(display_name: String, subtitle: String)
signal boss_intro_finished()

# ── economy / progression ─────────────────────────────────────────────────
signal coins_changed(total: int)
signal item_collected(item: ItemData)
signal weapon_equipped(weapon: WeaponData)
signal stat_changed()

# ── presentation ──────────────────────────────────────────────────────────
signal screen_shake(strength: float, duration: float)
signal hit_stop(duration: float)
signal toast(text: String, colour: Color)
signal flash(colour: Color, duration: float)
