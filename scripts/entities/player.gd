extends RigidBody2D
class_name Player

## Elastic ball player. RigidBody2D for natural bouncy crowd collisions.

const GRAB_PUSH_REDUCTION = 0.15
const MOVE_FORCE = 300.0
const MAX_SPEED = 100.0

var is_grabbing: bool = false
var grab_target: GrabPoint = null
var alive: bool = true
var push_time: float = 0.0  # accumulates while pushing against crowd
var player_radius: float = 20.0
var _color: Color = Color.BLUE
var _show_indicator: bool = false


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.92
	mass = 1.0

	var mat = PhysicsMaterial.new()
	mat.bounce = 0.55
	mat.friction = 0.0
	physics_material_override = mat

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = player_radius
	col.shape = shape
	add_child(col)

	collision_layer = 1
	collision_mask = 1 + 4

	EventBus.player_fell.connect(_on_fell)
	EventBus.carriage_shake.connect(_on_carriage_shake)


func _draw() -> void:
	draw_circle(Vector2.ZERO, player_radius, _color)
	if _show_indicator:
		draw_circle(Vector2.ZERO, player_radius + 2, Color(0, 1, 0, 0.4), false)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not alive:
		return

	if is_grabbing:
		if _color != Color.CYAN:
			_color = Color.CYAN
			_show_indicator = true
			queue_redraw()
		state.linear_velocity *= 0.7
		return

	if _color != Color.BLUE:
		_color = Color.BLUE
		_show_indicator = false
		queue_redraw()

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		var force = input_dir * MOVE_FORCE * get_push_multiplier()
		state.apply_central_force(force)
		var vel = state.linear_velocity
		if vel.length() > MAX_SPEED:
			state.linear_velocity = vel.normalized() * MAX_SPEED
		# Accumulate push time when blocked (moving slower than expected)
		if vel.length() < MAX_SPEED * 0.3:
			push_time += state.step
		else:
			push_time = max(0.0, push_time - state.step * 2.0)
	else:
		push_time = max(0.0, push_time - state.step * 3.0)


func _input(event: InputEvent) -> void:
	if not alive:
		return
	if event.is_action_pressed("grab"):
		if is_grabbing:
			release_grab()
		else:
			try_grab()


func try_grab() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results = space_state.intersect_point(query)
	for result in results:
		var node = result.get("collider")
		if node and node is GrabPoint:
			grab_target = node
			is_grabbing = true
			linear_velocity = Vector2.ZERO
			EventBus.player_grabbed_rail.emit()
			return


func release_grab() -> void:
	is_grabbing = false
	grab_target = null
	EventBus.player_released_rail.emit()


func get_push_multiplier() -> float:
	return GRAB_PUSH_REDUCTION if is_grabbing else 1.0


func _on_fell(stamina_left: int) -> void:
	position = Vector2(640, 360)
	linear_velocity = Vector2.ZERO
	if stamina_left <= 0:
		alive = false
		_color = Color.RED
		queue_redraw()


func _on_carriage_shake(direction: int, force: float) -> void:
	if not alive:
		return
	apply_central_force(Vector2(direction * force / GameState.stability * get_push_multiplier(), 0))
