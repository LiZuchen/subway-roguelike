extends Node
class_name PassengerSpawner

## Spawns passengers. During door-open: spawns at door; door-closed: random in carriage.

var carriage_bounds: Rect2
var target_count: int = 22

var spawn_weights = {
	"office_worker": 55,
	"tourist": 25,
	"auntie": 20,
}

# Door positions for spawning entering/exiting passengers
var left_door_pos: Vector2 = Vector2.ZERO
var right_door_pos: Vector2 = Vector2.ZERO


func setup(bounds: Rect2, density_level: String = "rush_hour") -> void:
	carriage_bounds = bounds
	match density_level:
		"rush_hour":
			target_count = 35
			spawn_weights = {"office_worker": 55, "tourist": 25, "auntie": 20}
		"normal":
			target_count = 14
			spawn_weights = {"office_worker": 65, "tourist": 22, "auntie": 13}
		"quiet":
			target_count = 8
			spawn_weights = {"office_worker": 75, "tourist": 18, "auntie": 7}


func set_door_positions(left: Vector2, right: Vector2) -> void:
	left_door_pos = left
	right_door_pos = right


func spawn_initial() -> Array[BasePassenger]:
	var spawned: Array[BasePassenger] = []
	for i in range(target_count):
		var p = _spawn_random_in_carriage()
		if p:
			spawned.append(p)
	return spawned


func spawn_entering_batch(count: int, door_side: int) -> Array[BasePassenger]:
	## Spawn passengers spread out on the platform, not clustered at the door.
	var door_pos = left_door_pos if door_side < 0 else right_door_pos
	var inward_dir = Vector2(door_side, 0)  # left door: move right (+1), right door: move left (-1)

	var spawned: Array[BasePassenger] = []
	var plat_width = 100.0  # matches platform visual size
	for i in range(count):
		# Spread passengers along the platform, 40–120px from door
		var dist = randf_range(50.0, plat_width + 20)
		# Random vertical offset within door height range
		var y_off = randf_range(-35.0, 35.0)
		var spawn_pos = door_pos + inward_dir * dist + Vector2(0, y_off)
		var p = _spawn_at_door(spawn_pos, inward_dir)
		if p:
			p.set_entering(door_pos, inward_dir)
			p.position = spawn_pos
			spawned.append(p)
	return spawned


func _spawn_random_in_carriage() -> BasePassenger:
	var type_name = _weighted_random(spawn_weights)
	if not type_name:
		return null

	var passenger = _create_passenger(type_name)
	if not passenger:
		return null

	var margin = 40.0
	passenger.position = Vector2(
		randf_range(carriage_bounds.position.x + margin, carriage_bounds.end.x - margin),
		randf_range(carriage_bounds.position.y + 50, carriage_bounds.end.y - 20)
	)
	passenger.add_to_group("passengers")
	return passenger


func _spawn_at_door(door_pos: Vector2, inward_dir: Vector2) -> BasePassenger:
	var type_name = _weighted_random(spawn_weights)
	if not type_name:
		return null

	var passenger = _create_passenger(type_name)
	if not passenger:
		return null

	# Spawn just outside the door, will be pushed inward
	passenger.position = door_pos
	passenger.add_to_group("passengers")
	return passenger


func _create_passenger(type_name: String) -> BasePassenger:
	match type_name:
		"office_worker":
			return OfficeWorker.new()
		"tourist":
			return Tourist.new()
		"auntie":
			return Auntie.new()
	return null


func mark_exiting_passengers(door_side: int, count: int) -> void:
	## Tag some passengers as wanting to exit through the given door.
	var door_pos = left_door_pos if door_side < 0 else right_door_pos
	# Only PACKED passengers are eligible — never hijack someone already
	# entering/exiting (e.g. frozen platform passengers waiting to board).
	var candidates: Array[BasePassenger] = []
	for node in get_tree().get_nodes_in_group("passengers"):
		if node is BasePassenger and node.mode == BasePassenger.Mode.PACKED:
			candidates.append(node as BasePassenger)
	candidates.shuffle()
	for i in range(min(count, candidates.size())):
		candidates[i].set_exiting(door_pos)


func remove_exiting_passengers(recycle_entering: bool = true, door_side: int = 0) -> void:
	"""Remove exiting passengers past the door; optionally recycle pushed-out non-exiters as entering.
	door_side: -1 left, +1 right. Only recycles on the door-opening side."""
	var nodes = get_tree().get_nodes_in_group("passengers")
	for node in nodes:
		if not node is BasePassenger:
			continue
		var px = node.global_position.x
		var past_left = px < carriage_bounds.position.x + 30
		var past_right = px > carriage_bounds.end.x - 30
		if not past_left and not past_right:
			continue

		if node.mode == BasePassenger.Mode.EXITING:
			# Successfully exited — remove
			node.queue_free()
		elif recycle_entering:
			# Only recycle on the door-opening side
			var on_door_side = (door_side < 0 and past_left) or (door_side > 0 and past_right)
			if on_door_side:
				var door_pos = left_door_pos if past_left else right_door_pos
				var inward_dir = Vector2(1, 0) if past_left else Vector2(-1, 0)
				node.set_entering(door_pos, inward_dir)
				node.active = true
				node.activate_entering(inward_dir)
			else:
				# Pushed out wrong side — bounce back into carriage
				node.position.x = clamp(node.position.x,
					carriage_bounds.position.x + 40, carriage_bounds.end.x - 40)
				node.linear_velocity.x *= -0.5


func set_all_packed() -> void:
	"""Set all remaining passengers back to packed mode."""
	var nodes = get_tree().get_nodes_in_group("passengers")
	for node in nodes:
		if node is BasePassenger:
			node.set_packed()


func remove_random_passengers(count: int) -> void:
	var nodes = get_tree().get_nodes_in_group("passengers")
	nodes.shuffle()
	for i in range(min(count, nodes.size())):
		nodes[i].queue_free()


func _weighted_random(weights: Dictionary) -> String:
	var total = 0
	for w in weights.values():
		total += w
	var roll = randf() * total
	var cumulative = 0
	for key in weights:
		cumulative += weights[key]
		if roll <= cumulative:
			return key
	return weights.keys()[0]
