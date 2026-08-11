extends BasePassenger
class_name Auntie

## 买菜大妈 — heavy, pushy, moves actively.

var _base_wander_force: float = 140.0


func _ready() -> void:
	passenger_radius = 22.0
	push_mass = 2.2
	wander_force = _base_wander_force
	wander_interval = 1.0
	super._ready()


func _get_color() -> Color:
	return Color(0.5, 0.5, 0.5)


func _reset_wander_force() -> void:
	wander_force = _base_wander_force
