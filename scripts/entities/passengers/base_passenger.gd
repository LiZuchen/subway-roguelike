extends RigidBody2D
class_name BasePassenger

## Modes: PACKED (shuffle), EXITING (rush door), ENTERING (walk in)

enum Mode { PACKED, EXITING, ENTERING }

var passenger_radius: float = 16.0
var push_mass: float = 1.0
var active: bool = true
var mode: Mode = Mode.PACKED
var exit_target: Vector2 = Vector2.ZERO  # door position to head toward

var wander_timer: float = 0.0
var wander_interval: float = 2.0
var wander_force: float = 60.0
var wander_direction: Vector2 = Vector2.ZERO

# Per-passenger timer — stuck longer = push harder (shared by exiting & entering)
var _exit_elapsed: float = 0.0
var _color: Color


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.94
	mass = push_mass

	var mat = PhysicsMaterial.new()
	mat.bounce = 0.55
	mat.friction = 0.0
	physics_material_override = mat

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = passenger_radius
	col.shape = shape
	add_child(col)

	_color = _get_color()

	collision_layer = 1
	collision_mask = 1 + 4

	wander_timer = randf_range(0.5, 2.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, passenger_radius, _color)


func _get_color() -> Color:
	return Color.GRAY


func set_exiting(door_pos: Vector2) -> void:
	mode = Mode.EXITING
	exit_target = door_pos
	_reset_wander_force()  # absolute, not multiplicative — safe if re-marked
	wander_force *= 3.0
	mass = push_mass * 2.5  # heavier to push through, but not a bulldozer
	_exit_elapsed = 0.0
	_color = Color.RED
	queue_redraw()
	apply_central_impulse((door_pos - global_position).normalized() * 800.0)


func set_entering(door_pos: Vector2, inward_dir: Vector2) -> void:
	mode = Mode.ENTERING
	exit_target = door_pos + inward_dir * 180.0
	_reset_wander_force()  # absolute, not multiplicative — safe if recycled
	wander_force *= 2.0
	mass = push_mass * 1.2
	_exit_elapsed = 0.0
	_color = Color.GREEN
	queue_redraw()


func activate_entering(inward_dir: Vector2) -> void:
	linear_velocity = Vector2.ZERO
	apply_central_impulse(inward_dir * 300.0)


func set_packed() -> void:
	mode = Mode.PACKED
	mass = push_mass  # restore normal mass
	_reset_wander_force()
	_color = _get_color()
	queue_redraw()


func _reset_wander_force() -> void:
	pass  # overridden by subclasses


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not active:
		return

	match mode:
		Mode.EXITING:
			_exit_elapsed += state.step
			var urgency = 1.0 + _exit_elapsed * 2.0
			_move_toward(state, exit_target, wander_force * 2.0 * urgency, 0.92)
		Mode.ENTERING:
			_exit_elapsed += state.step
			var urgency = 1.0 + _exit_elapsed * 2.0
			# Horizontal distance to target — start fading once past the door
			var dx = abs(global_position.x - exit_target.x)
			if dx < 180.0:
				var t = dx / 180.0
				urgency *= t * t  # quadratic fade, much faster decay
			if dx < 30.0:
				set_packed()
				return
			_move_toward(state, exit_target, wander_force * urgency * 0.4, 0.92)
		Mode.PACKED:
			_packed_shuffle(state)


func _move_toward(state: PhysicsDirectBodyState2D, target: Vector2, force: float, damp: float) -> void:
	var dir = (target - global_position).normalized()
	# Less randomness for entering (they have a clear goal)
	if damp > 0.95:
		dir += Vector2(randf_range(-0.1, 0.1), randf_range(-0.05, 0.05))
	else:
		dir += Vector2(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	dir = dir.normalized()
	state.apply_central_force(dir * force)
	state.linear_velocity *= damp


func _packed_shuffle(state: PhysicsDirectBodyState2D) -> void:
	wander_timer -= state.step
	if wander_timer <= 0:
		wander_timer = randf_range(1.5, wander_interval)
		wander_direction = Vector2(randf_range(-0.6, 0.6), randf_range(-0.2, 0.2)).normalized()
	# Very weak force — barely moves, just enough to shift weight
	state.apply_central_force(wander_direction * wander_force * 0.25)
	# High damping in packed mode — hard to move
	state.linear_velocity *= 0.85
