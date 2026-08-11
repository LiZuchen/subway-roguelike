extends Node
class_name CrowdPhysics

## Applies crowd push forces to RigidBody2D entities each frame.

const BASE_PUSH = 3.0
const PUSH_RANGE = 80.0
const JITTER_INTENSITY = 1.8

var carriage_area: Rect2
var passenger_nodes: Array[BasePassenger] = []
var player_ref: Player = null
var density: float = 0.5
var allow_player_exit: bool = false  # set true at final station


func _ready() -> void:
	EventBus.carriage_shake.connect(_on_carriage_shake)


func setup(carriage_bounds: Rect2) -> void:
	carriage_area = carriage_bounds


func register_player(p: Player) -> void:
	player_ref = p


func register_passenger(p: BasePassenger) -> void:
	passenger_nodes.append(p)


func unregister_passenger(p: BasePassenger) -> void:
	passenger_nodes.erase(p)


func clear_passengers() -> void:
	passenger_nodes.clear()


func _cleanup_freed() -> void:
	# Remove freed references from the array
	var i = passenger_nodes.size() - 1
	while i >= 0:
		if not is_instance_valid(passenger_nodes[i]):
			passenger_nodes.remove_at(i)
		i -= 1


func get_active_count() -> int:
	var count = 0
	for p in passenger_nodes:
		if is_instance_valid(p) and p.active:
			count += 1
	return count


func _process(_delta: float) -> void:
	_cleanup_freed()

	var active_count = get_active_count()
	density = clamp(remap(active_count, 0, 20, 0.3, 2.0), 0.3, 2.0)

	if not player_ref or not player_ref.alive:
		return
	if player_ref.is_grabbing:
		_apply_jitter(0.12)
		return

	_apply_crowd_push()
	_apply_jitter(0.8)


func _apply_crowd_push() -> void:
	var total_push = Vector2.ZERO

	for p in passenger_nodes:
		if not is_instance_valid(p) or not p.active:
			continue
		var dist = player_ref.global_position.distance_to(p.global_position)
		if dist < PUSH_RANGE and dist > 1.0:
			var dir = (player_ref.global_position - p.global_position).normalized()
			var strength = density * p.push_mass * BASE_PUSH * (1.0 - dist / PUSH_RANGE)
			total_push += dir * strength

	# Player pushes nearby passengers (reciprocal, with accumulating urgency)
	var player_push_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if player_push_input != Vector2.ZERO and player_ref.push_time > 0.0:
		var urgency = 1.0 + player_ref.push_time * 2.0
		for p in passenger_nodes:
			if not is_instance_valid(p) or not p.active:
				continue
			var dist = player_ref.global_position.distance_to(p.global_position)
			if dist < PUSH_RANGE and dist > 1.0:
				var push_dir = player_push_input.normalized()
				var strength = density * BASE_PUSH * urgency * (1.0 - dist / PUSH_RANGE)
				p.apply_central_force(push_dir * strength)

	# Push between overlapping passengers
	for i in range(passenger_nodes.size()):
		var a = passenger_nodes[i]
		if not is_instance_valid(a):
			continue
		for j in range(i + 1, passenger_nodes.size()):
			var b = passenger_nodes[j]
			if not is_instance_valid(b) or not a.active or not b.active:
				continue
			var dist = a.global_position.distance_to(b.global_position)
			var min_dist = a.passenger_radius + b.passenger_radius + 3
			if dist < min_dist and dist > 0.5:
				var dir = (a.global_position - b.global_position).normalized()
				var overlap = min_dist - dist
				var force = dir * overlap * density * 2.0
				a.apply_central_force(force)
				b.apply_central_force(-force)

	# Apply push to player
	var player_push = total_push / GameState.stability * player_ref.get_push_multiplier()
	player_ref.apply_central_force(player_push)

	if not allow_player_exit and not carriage_area.has_point(player_ref.global_position):
		_handle_player_out_of_bounds()


func _apply_jitter(multiplier: float) -> void:
	var jitter = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-0.3, 0.3)
	) * JITTER_INTENSITY * density * multiplier
	player_ref.apply_central_force(jitter)

	for p in passenger_nodes:
		if is_instance_valid(p) and p.active and randf() < 0.25:
			p.apply_central_force(Vector2(randf_range(-0.2, 0.2), randf_range(-0.1, 0.1)) * density)


func _handle_player_out_of_bounds() -> void:
	# Push player back to center, no penalty (MVP: can't fall off mid-run)
	player_ref.position = carriage_area.get_center()
	player_ref.linear_velocity = Vector2.ZERO


func _on_carriage_shake(direction: int, force: float) -> void:
	var impulse = Vector2(direction * force, randf_range(-force * 0.2, force * 0.2))

	if player_ref and player_ref.alive:
		player_ref.apply_central_impulse(impulse * player_ref.get_push_multiplier())

	for p in passenger_nodes:
		if is_instance_valid(p) and p.active:
			p.apply_central_impulse(impulse * randf_range(0.3, 0.8))
