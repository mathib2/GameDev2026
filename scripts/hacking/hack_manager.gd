extends Node

## The signature system. Autoload: HackManager
##
## Owns the full lifecycle of an intrusion:
##
##   2D world -> request -> gate checks -> transition -> 3D cyberspace
##      -> node capture vs. trace timer -> success/failure
##      -> back to 2D -> consequences
##
## Note what is NOT here: any knowledge of a specific vending machine, camera,
## or wheel. Every target-specific detail lives in a HackTargetData resource.
## Adding a hackable object touches zero lines of this file.

signal state_changed(state: State)

enum State { IDLE, BRIEFING, TRANSITIONING, ACTIVE, RESOLVING }

var state: State = State.IDLE
var active_target: HackTargetData = null
var source_node: Node = null          ## the 2D object that was hacked

var nodes_captured: int = 0
var trace: float = 0.0                ## 0..1; reaching 1.0 fails the hack
var _trace_rate: float = 0.0


func _ready() -> void:
	EventBus.hack_requested.connect(_on_hack_requested)
	set_process(false)


func _process(delta: float) -> void:
	if state != State.ACTIVE or _trace_rate <= 0.0:
		return
	trace = minf(1.0, trace + _trace_rate * delta)
	EventBus.trace_level_changed.emit(trace)
	if trace >= 1.0:
		fail("Intrusion traced.")


# ── Entry ─────────────────────────────────────────────────────────────────
func _on_hack_requested(target: HackTargetData, source: Node) -> void:
	if state != State.IDLE:
		return
	var refusal := _why_not(target)
	if refusal != "":
		EventBus.hack_refused.emit(target, refusal)
		EventBus.toast_requested.emit(refusal)
		return

	active_target = target
	source_node = source
	nodes_captured = 0
	trace = 0.0
	_trace_rate = 0.0 if target.trace_time <= 0.0 else 1.0 / target.trace_time

	_set_state(State.BRIEFING)
	AudioManager.play_sfx(target.hack_start_sfx)
	EventBus.hack_transition_started.emit(target)


## Called by the transition UI once its animation finishes.
func begin_intrusion() -> void:
	if state != State.BRIEFING:
		return
	_set_state(State.TRANSITIONING)
	if SceneRouter.enter_cyberspace(active_target):
		_set_state(State.ACTIVE)
		set_process(true)
	else:
		fail("Construct failed to load.")


func _why_not(target: HackTargetData) -> String:
	if target == null:
		return "No target."
	if not target.is_valid():
		return "%s has no cyberspace construct assigned." % target.display_name
	if not target.repeatable and GameState.was_hacked(target.id):
		return "%s is already compromised." % target.display_name
	if GameState.get_stat(&"intrusion") < target.required_skill:
		return "Intrusion %d required. You have %d." % [
			target.required_skill, GameState.get_stat(&"intrusion")]
	return ""


# ── During the intrusion ──────────────────────────────────────────────────
## Called by HackNode instances inside a cyberspace scene.
func capture_node() -> void:
	if state != State.ACTIVE:
		return
	nodes_captured += 1
	EventBus.hack_node_captured.emit(nodes_captured, active_target.required_nodes)
	if nodes_captured >= active_target.required_nodes:
		succeed()


## Called by ICE when it hits the netrunner.
func add_trace(amount: float) -> void:
	if state != State.ACTIVE:
		return
	trace = minf(1.0, trace + amount)
	EventBus.trace_level_changed.emit(trace)
	if trace >= 1.0:
		fail("Intrusion traced.")


# ── Resolution ────────────────────────────────────────────────────────────
func succeed() -> void:
	if state != State.ACTIVE:
		return
	_set_state(State.RESOLVING)
	set_process(false)
	var target := active_target

	GameState.mark_hacked(target.id)
	GameState.set_flags(target.success_flags)
	GameState.grant_rewards(target.rewards)
	AudioManager.play_sfx(target.success_sfx)

	EventBus.hack_succeeded.emit(target)
	_exit(true)


func fail(reason: String) -> void:
	if state != State.ACTIVE and state != State.TRANSITIONING:
		return
	_set_state(State.RESOLVING)
	set_process(false)
	var target := active_target

	GameState.set_flags(target.failure_flags)
	GameState.add_heat(target.failure_heat)
	AudioManager.play_sfx(target.failure_sfx)

	EventBus.hack_failed.emit(target, reason)
	_exit(false)


func abort() -> void:
	if state == State.ACTIVE:
		fail("Connection dropped.")


func _exit(success: bool) -> void:
	var target := active_target
	EventBus.cyberspace_exited.emit(target, success)
	active_target = null
	source_node = null
	_set_state(State.IDLE)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func is_active() -> bool:
	return state != State.IDLE
