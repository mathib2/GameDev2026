extends Control

## Persistent HUD: interaction prompt, credits, heat, toasts, and the
## in-cyberspace trace bar.
##
## Reads everything from EventBus. It holds no references to the player, NPCs,
## or hack targets, so UI work never blocks gameplay work.

@onready var _prompt: Label = $Prompt
@onready var _credits: Label = $TopBar/Credits
@onready var _heat: Label = $TopBar/Heat
@onready var _toast: Label = $Toast
@onready var _trace_bar: ProgressBar = $HackPanel/TraceBar
@onready var _nodes_label: Label = $HackPanel/Nodes
@onready var _hack_panel: Control = $HackPanel

var _toast_timer: float = 0.0


func _ready() -> void:
	_prompt.visible = false
	_toast.visible = false
	_hack_panel.visible = false

	EventBus.interactable_focused.connect(_on_focus)
	EventBus.interactable_unfocused.connect(_on_unfocus)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.credits_changed.connect(_on_credits)
	EventBus.heat_changed.connect(_on_heat)
	EventBus.cyberspace_entered.connect(_on_cyberspace_entered)
	EventBus.cyberspace_exited.connect(_on_cyberspace_exited)
	EventBus.trace_level_changed.connect(_on_trace)
	EventBus.hack_node_captured.connect(_on_nodes)

	_on_credits(GameState.credits)
	_on_heat(GameState.heat)


func _process(delta: float) -> void:
	if _toast_timer <= 0.0:
		return
	_toast_timer -= delta
	_toast.modulate.a = clampf(_toast_timer, 0.0, 1.0)
	if _toast_timer <= 0.0:
		_toast.visible = false


func _on_focus(_node: Node, prompt: String) -> void:
	_prompt.text = "[E]  %s" % prompt
	_prompt.visible = true


func _on_unfocus(_node: Node) -> void:
	_prompt.visible = false


func _on_toast(text: String) -> void:
	if text == "":
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_timer = 3.0


func _on_credits(total: int) -> void:
	_credits.text = "%d ¢" % total


func _on_heat(heat: int) -> void:
	_heat.text = "HEAT " + "▮".repeat(heat) + "▯".repeat(maxi(0, 5 - heat))
	_heat.modulate = Color(1, 0.35, 0.3) if heat >= 3 else Color(0.7, 0.7, 0.75)


func _on_cyberspace_entered(target: HackTargetData) -> void:
	_hack_panel.visible = true
	_prompt.visible = false
	_trace_bar.value = 0.0
	_nodes_label.text = "NODES  0 / %d" % target.required_nodes


func _on_cyberspace_exited(_target: HackTargetData, _success: bool) -> void:
	_hack_panel.visible = false


func _on_trace(fraction: float) -> void:
	_trace_bar.value = fraction * 100.0


func _on_nodes(captured: int, required: int) -> void:
	_nodes_label.text = "NODES  %d / %d" % [captured, required]
