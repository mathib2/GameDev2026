extends CyberspaceScene

## MISSION: REINVENT THE WHEEL
##
## A construct that exists purely to deliver the thesis of the game. It behaves
## like any other construct — same capture loop, same trace timer — and then,
## on success, spends a few seconds treating the invention of a wheel as a
## major cybersecurity milestone.
##
## Implemented as a subclass rather than a special case inside HackManager,
## which is the point: constructs can add their own theatre without any core
## system knowing they exist.

const SPEC := [
	"  ✓ Bluetooth",
	"  ✓ Wi-Fi",
	"  ✓ Cloud synchronization",
	"  ✓ AI-powered rotation",
	"  ✓ Blockchain-enabled",
]

@onready var _wheel: Node3D = $TheWheel

var _spin: float = 0.0
var _celebrating: bool = false


func _ready() -> void:
	EventBus.hack_succeeded.connect(_on_success)


func _process(delta: float) -> void:
	if _wheel == null:
		return
	# It turns faster the closer you are to owning it. Subtle, and nobody asked.
	var pace: float = 0.4 if not _celebrating else 4.0
	_spin += delta * pace
	_wheel.rotation.z = _spin


func _on_success(t: HackTargetData) -> void:
	if t == null or t.id != &"the_wheel":
		return
	_celebrating = true
	_announce()


func _announce() -> void:
	# Deliberately paced. The joke is the gravity, not the speed.
	await get_tree().create_timer(0.4).timeout
	EventBus.toast_requested.emit("WHEEL 2.0 CREATED")
	await get_tree().create_timer(1.6).timeout
	for line in SPEC:
		EventBus.toast_requested.emit(line)
		await get_tree().create_timer(0.55).timeout
	await get_tree().create_timer(0.6).timeout
	EventBus.toast_requested.emit("SECURITY RATING:  0 / 10")
	await get_tree().create_timer(2.0).timeout
	EventBus.screen_shake_requested.emit(12.0)
	EventBus.toast_requested.emit("WHEEL 2.0 HAS BEEN HACKED")
	GameState.set_flag(&"wheel_reinvented")
	GameState.set_flag(&"wheel_2_compromised")
