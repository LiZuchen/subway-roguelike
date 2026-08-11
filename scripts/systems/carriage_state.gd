extends Node
class_name CarriageState

## Controls carriage state: inertia + door cycles with side tracking.

const INERTIA_FORCE = 5.0
const INERTIA_DURATION = 2.5
const INERTIA_MIN_INTERVAL = 15.0
const INERTIA_MAX_INTERVAL = 30.0
const DOOR_OPEN_DURATION = 15.0

var inertia_timer: float = 0.0
var next_inertia_interval: float = 0.0
var is_shaking: bool = false
var shake_direction: int = 0

var doors_open: bool = false
var open_door_side: int = 0  # -1 left, +1 right, 0 none


func _ready() -> void:
	next_inertia_interval = randf_range(INERTIA_MIN_INTERVAL, INERTIA_MAX_INTERVAL)


func _process(delta: float) -> void:
	if not doors_open:
		_update_inertia(delta)


func _update_inertia(delta: float) -> void:
	if is_shaking:
		inertia_timer -= delta
		if inertia_timer <= 0:
			is_shaking = false
			EventBus.carriage_stable.emit()
		return

	inertia_timer -= delta
	if inertia_timer <= 0:
		_trigger_inertia()


func _trigger_inertia() -> void:
	is_shaking = true
	shake_direction = 1 if randf() > 0.5 else -1
	inertia_timer = INERTIA_DURATION
	next_inertia_interval = randf_range(INERTIA_MIN_INTERVAL, INERTIA_MAX_INTERVAL)
	EventBus.carriage_shake.emit(shake_direction, INERTIA_FORCE)


func start_door_cycle(door_side: int) -> void:
	doors_open = true
	open_door_side = door_side
	EventBus.doors_opened.emit(door_side)
	get_tree().create_timer(DOOR_OPEN_DURATION).timeout.connect(_close_doors)


func _close_doors() -> void:
	doors_open = false
	open_door_side = 0
	is_shaking = false
	inertia_timer = 2.0
	EventBus.doors_closed.emit()
