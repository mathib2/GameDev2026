extends Control

## The 2D -> 3D handoff, and the game's main comic device.
##
## Every intrusion opens with a straight-faced military briefing, and the text
## in it comes from the HackTargetData — so the deadpan for "vending machine"
## is authored by a writer in a .tres, not hard-coded here. Then it shows the
## result on the way back out.
##
## Flow:
##   hack_transition_started -> briefing -> HackManager.begin_intrusion()
##   hack_succeeded/failed   -> result card -> fades out

@onready var _briefing: Control = $Briefing
@onready var _title: Label = $Briefing/VBox/Title
@onready var _mundane: Label = $Briefing/VBox/Mundane
@onready var _absurd: Label = $Briefing/VBox/Absurd
@onready var _threat: RichTextLabel = $Briefing/VBox/Threat
@onready var _difficulty: Label = $Briefing/VBox/Difficulty
@onready var _result: Control = $Result
@onready var _result_title: Label = $Result/VBox/Title
@onready var _result_body: RichTextLabel = $Result/VBox/Body
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	_briefing.visible = false
	_result.visible = false
	_fade.color.a = 0.0
	EventBus.hack_transition_started.connect(_on_transition_started)
	EventBus.hack_succeeded.connect(_on_success)
	EventBus.hack_failed.connect(_on_failure)


func _on_transition_started(target: HackTargetData) -> void:
	_title.text = "INTRUSION BRIEFING — %s" % target.display_name.to_upper()
	_mundane.text = "NORMAL APPROACH:  %s" % target.mundane_solution
	_absurd.text = "OUR APPROACH:  %s" % target.absurd_solution
	_threat.text = target.threat_assessment
	_difficulty.text = "SECURITY: %s      TRACE WINDOW: %s      NODES: %d" % [
		target.difficulty_label(),
		("NONE" if target.trace_time <= 0.0 else "%ds" % int(target.trace_time)),
		target.required_nodes,
	]
	_briefing.visible = true
	_briefing.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(_briefing, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.6)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void:
		_briefing.visible = false
		HackManager.begin_intrusion())
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _on_success(target: HackTargetData) -> void:
	_show_result(
		"INTRUSION SUCCESSFUL",
		Color(0.35, 1.0, 0.6),
		"[b]%s[/b] is now yours.\n\n%s" % [
			target.display_name,
			"You could have simply used it. You did not." ])


func _on_failure(target: HackTargetData, reason: String) -> void:
	_show_result(
		"INTRUSION FAILED",
		Color(1.0, 0.35, 0.3),
		"[b]%s[/b]\n\n%s repelled you. Heat increased.\n\n%s" % [
			reason, target.display_name,
			"You could have simply used it." ])


func _show_result(title: String, colour: Color, body: String) -> void:
	_result_title.text = title
	_result_title.modulate = colour
	_result_body.text = body
	_result.visible = true
	_result.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	tw.tween_property(_result, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.8)
	tw.tween_property(_result, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _result.visible = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
