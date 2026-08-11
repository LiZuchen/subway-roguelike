extends Area2D
class_name GrabPoint

## A grab-able rail point on the ceiling of the carriage.


func _ready() -> void:
	add_to_group("grab_points")
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	add_child(col)
	collision_mask = 0
	collision_layer = 2  # layer 2 = grab points
