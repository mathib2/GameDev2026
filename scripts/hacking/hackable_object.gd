extends Interactable

## A mundane object in the 2D world with a wildly disproportionate attack
## surface. Vending machines, cameras, traffic lights, Roombas, and one wheel.
##
## To add a hackable object: create a HackTargetData .tres, drop
## HackableObject.tscn into a map, assign the resource. That is the whole task.

@export var target: HackTargetData
## Optional sprite override; otherwise the scene's own texture is kept.
@export var sprite_texture: Texture2D
## If true the object can also be used the boring, sensible way — which is the
## joke, since the player never will.
@export var allow_mundane_use: bool = true
@export var mundane_use_text: String = "You could just use it normally."
## Set on GameState the first time the player walks within range. Lets a
## mission have a "find the thing" objective without a bespoke trigger node.
@export var discovery_flag: StringName = &""

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _glow: Sprite2D = $HackGlow

var _pulse: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("hackable")
	if sprite_texture != null:
		_sprite.texture = sprite_texture
	if target == null:
		push_warning("[Hackable] %s has no HackTargetData assigned" % name)
	EventBus.hack_succeeded.connect(_on_hack_resolved.bind(true))
	EventBus.hack_failed.connect(_on_hack_failed)
	_refresh_glow()


func _process(delta: float) -> void:
	if not _glow.visible:
		return
	_pulse += delta * 3.0
	_glow.modulate.a = 0.35 + sin(_pulse) * 0.25


func _on_body_entered(body: Node2D) -> void:
	super._on_body_entered(body)
	if discovery_flag != &"" and body.is_in_group("player"):
		GameState.set_flag(discovery_flag)


func get_prompt() -> String:
	if target == null:
		return "Inspect"
	if not target.repeatable and GameState.was_hacked(target.id):
		return "%s (compromised)" % target.display_name
	return "Hack %s" % target.display_name


func interact() -> void:
	if target == null:
		EventBus.toast_requested.emit(mundane_use_text)
		return
	if not target.repeatable and GameState.was_hacked(target.id):
		if allow_mundane_use:
			EventBus.toast_requested.emit(mundane_use_text)
		return
	EventBus.hack_requested.emit(target, self)


func _refresh_glow() -> void:
	if target == null:
		_glow.visible = false
		return
	_glow.visible = target.repeatable or not GameState.was_hacked(target.id)


func _on_hack_resolved(_t: HackTargetData, _success: bool) -> void:
	_refresh_glow()


func _on_hack_failed(_t: HackTargetData, _reason: String) -> void:
	_refresh_glow()
