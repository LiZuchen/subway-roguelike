extends BasePassenger
class_name OfficeWorker

## 普通上班族.

var _base_wander_force: float = 60.0


func _ready() -> void:
	passenger_radius = 20.0
	push_mass = 1.0
	wander_force = _base_wander_force
	wander_interval = 3.0
	super._ready()


func _get_color() -> Color:
	return Color(0.55, 0.55, 0.55)


func _reset_wander_force() -> void:
	wander_force = _base_wander_force
