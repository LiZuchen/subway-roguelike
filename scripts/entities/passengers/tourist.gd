extends BasePassenger
class_name Tourist

## 大背包游客 — turns with backpack sweep.

var _base_wander_force: float = 75.0
var turn_timer: float = 0.0
var turn_interval: float = 5.0


func _ready() -> void:
	passenger_radius = 21.0
	push_mass = 1.8
	wander_force = _base_wander_force
	wander_interval = 4.0
	turn_timer = randf_range(1.0, turn_interval)
	super._ready()


func _get_color() -> Color:
	return Color(0.3, 0.55, 0.75)  # blue-gray, distinct from others


func _reset_wander_force() -> void:
	wander_force = _base_wander_force


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not active:
		return

	super._integrate_forces(state)

	if mode == Mode.PACKED:
		turn_timer -= state.step
		if turn_timer <= 0:
			turn_timer = turn_interval
			wander_direction = Vector2(randf_range(-1, 1), 0).normalized()
			state.apply_central_impulse(wander_direction * 250.0)
