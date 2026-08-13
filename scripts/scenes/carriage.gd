extends Node2D

## Cramped subway carriage. Two doors, station cycle:
## Packed (doors closed, barely move) → Doors open → Exiting flow → Doors close → Packed.

const CARRIAGE_WIDTH = 380.0
const CARRIAGE_HEIGHT = 240.0
const CARRIAGE_X = 450.0
const CARRIAGE_Y = 240.0
const WALL_THICKNESS = 16.0

const STATION_DURATION = 5.0

# Door positions (center of each door area)
var left_door_pos: Vector2
var right_door_pos: Vector2

@onready var carriage_bounds = Rect2(
	Vector2(CARRIAGE_X, CARRIAGE_Y),
	Vector2(CARRIAGE_WIDTH, CARRIAGE_HEIGHT)
)

var station_timer: float = 0.0
var crowd_physics: CrowdPhysics
var spawner: PassengerSpawner
var carriage_state: CarriageState
var player: Player
var hud: Control
var progress_ui: Control
var grab_points: Array[GrabPoint] = []
var notify_label: Label = null
var freeze_label: Label = null
var freeze_countdown: float = -1.0  # -1 = not counting
var entering_frozen: bool = true  # true during first 5s after doors open
var is_final_station: bool = false  # true when station 5 doors open
var player_exited: bool = false

# Sliding doors
var left_door: SlidingDoor = null
var right_door: SlidingDoor = null

# Tunnel effect (scrolling lights during packed phase)
var _tunnel_lights: Array[ColorRect] = []
var _tunnel_scroll: float = 0.0
var _tunnel_speed: float = 120.0
var _carriage_visual: Node2D = null


func _ready() -> void:
	# Compute door positions
	var door_h = 100.0
	left_door_pos = Vector2(CARRIAGE_X, CARRIAGE_Y + CARRIAGE_HEIGHT / 2)
	right_door_pos = Vector2(CARRIAGE_X + CARRIAGE_WIDTH, CARRIAGE_Y + CARRIAGE_HEIGHT / 2)

	_setup_scene()
	_create_tunnel_lights()
	_build_walls()
	_draw_carriage()
	_create_grab_rails()
	_spawn_player()
	_spawn_systems()
	_spawn_passengers()
	_setup_hud()
	_setup_signals()
	station_timer = STATION_DURATION


func _setup_scene() -> void:
	# Dark tunnel background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	var door_h = 100.0
	var door_center_y = CARRIAGE_Y + CARRIAGE_HEIGHT / 2
	var plat_w = 100.0

	# Build both platforms with tiles + safety line + station sign
	_build_platform(CARRIAGE_X - plat_w - 4, door_center_y - door_h / 2 - 4, plat_w, door_h + 8, -1)
	_build_platform(CARRIAGE_X + CARRIAGE_WIDTH + 4, door_center_y - door_h / 2 - 4, plat_w, door_h + 8, 1)


func _build_platform(px: float, py: float, pw: float, ph: float, side: int) -> void:
	# Platform base
	var base = ColorRect.new()
	base.color = Color(0.45, 0.43, 0.38)
	base.size = Vector2(pw, ph)
	base.position = Vector2(px, py)
	base.z_index = -7
	add_child(base)

	# Platform tile pattern (checkerboard)
	var tile_size = 16.0
	for tx in range(ceil(pw / tile_size)):
		for ty in range(ceil(ph / tile_size)):
			if (tx + ty) % 2 == 0:
				var tile = ColorRect.new()
				tile.color = Color(0.5, 0.48, 0.42)
				tile.size = Vector2(tile_size - 1, tile_size - 1)
				tile.position = Vector2(px + tx * tile_size, py + ty * tile_size)
				tile.z_index = -6
				add_child(tile)

	# Yellow safety line at platform edge (closest to carriage)
	var edge_x = px + pw - 4 if side < 0 else px
	var line = ColorRect.new()
	line.color = Color(1.0, 0.85, 0.0)
	line.size = Vector2(4, ph)
	line.position = Vector2(edge_x, py)
	line.z_index = -5
	add_child(line)

	# Station sign above platform
	var sign = ColorRect.new()
	sign.color = Color(0.15, 0.25, 0.55)
	sign.size = Vector2(pw - 10, 22)
	sign.position = Vector2(px + 5, py - 26)
	sign.z_index = -5
	add_child(sign)

	var sign_label = Label.new()
	sign_label.text = "站台"
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.add_theme_font_size_override("font_size", 12)
	sign_label.add_theme_color_override("font_color", Color.WHITE)
	sign_label.size = Vector2(pw - 10, 22)
	sign_label.position = Vector2(px + 5, py - 24)
	sign_label.z_index = -4
	add_child(sign_label)


func _create_tunnel_lights() -> void:
	# Scrolling tunnel lights — above and below the carriage (train moves vertically)
	var light_color = Color(1.0, 0.9, 0.5, 0.6)
	var gap = 40.0
	# Light columns along the carriage width (above and below)
	for side in [-1, 1]:
		var start_y = CARRIAGE_Y - 150 if side < 0 else CARRIAGE_Y + CARRIAGE_HEIGHT + 10
		for col in range(3):
			var x_pos = CARRIAGE_X + 60 + col * (CARRIAGE_WIDTH - 120) / 2.0
			var count = 8
			for i in range(count):
				var light = ColorRect.new()
				light.color = light_color
				light.size = Vector2(randf_range(2, 4), randf_range(4, 12))
				light.position = Vector2(x_pos + randf_range(-8, 8), start_y + i * gap + randf_range(-20, 20))
				light.z_index = -9
				add_child(light)
				_tunnel_lights.append(light)


func _build_walls() -> void:
	var wl = 4  # wall collision layer

	# Top wall
	_add_wall(Vector2(CARRIAGE_X, CARRIAGE_Y - WALL_THICKNESS),
		Vector2(CARRIAGE_WIDTH, WALL_THICKNESS), wl)
	# Bottom wall
	_add_wall(Vector2(CARRIAGE_X, CARRIAGE_Y + CARRIAGE_HEIGHT),
		Vector2(CARRIAGE_WIDTH, WALL_THICKNESS), wl)

	# Left wall — split into top piece and bottom piece with door gap
	var door_h = 100.0
	var door_top_y = CARRIAGE_Y + CARRIAGE_HEIGHT / 2 - door_h / 2
	var door_bottom_y = CARRIAGE_Y + CARRIAGE_HEIGHT / 2 + door_h / 2

	# Left wall: top segment
	_add_wall(Vector2(CARRIAGE_X - WALL_THICKNESS, CARRIAGE_Y),
		Vector2(WALL_THICKNESS, door_top_y - CARRIAGE_Y), wl)
	# Left wall: bottom segment
	_add_wall(Vector2(CARRIAGE_X - WALL_THICKNESS, door_bottom_y),
		Vector2(WALL_THICKNESS, CARRIAGE_Y + CARRIAGE_HEIGHT - door_bottom_y), wl)

	# Right wall: top segment
	_add_wall(Vector2(CARRIAGE_X + CARRIAGE_WIDTH, CARRIAGE_Y),
		Vector2(WALL_THICKNESS, door_top_y - CARRIAGE_Y), wl)
	# Right wall: bottom segment
	_add_wall(Vector2(CARRIAGE_X + CARRIAGE_WIDTH, door_bottom_y),
		Vector2(WALL_THICKNESS, CARRIAGE_Y + CARRIAGE_HEIGHT - door_bottom_y), wl)

	# Sliding doors — embedded in wall, panels slide up/down
	left_door = SlidingDoor.new()
	left_door.position = Vector2(CARRIAGE_X - WALL_THICKNESS + 2, door_top_y + door_h / 2)
	left_door.door_width = WALL_THICKNESS - 4  # slightly narrower than wall
	left_door.door_height = door_h
	left_door.name = "LeftDoor"
	add_child(left_door)

	right_door = SlidingDoor.new()
	right_door.position = Vector2(CARRIAGE_X + CARRIAGE_WIDTH + 2, door_top_y + door_h / 2)
	right_door.door_width = WALL_THICKNESS - 4
	right_door.door_height = door_h
	right_door.name = "RightDoor"
	add_child(right_door)


func _add_wall(pos: Vector2, size: Vector2, layer: int) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = size / 2
	body.add_child(col)
	add_child(body)
	return body


func _draw_carriage() -> void:
	var draw_node = Node2D.new()
	draw_node.name = "CarriageVisual"
	_carriage_visual = draw_node
	add_child(draw_node)

	var x = CARRIAGE_X
	var y = CARRIAGE_Y
	var w = CARRIAGE_WIDTH
	var h = CARRIAGE_HEIGHT

	# Outer shell (train body)
	var outer = ColorRect.new()
	outer.color = Color(0.5, 0.5, 0.45)
	outer.size = Vector2(w + 36, h + 36)
	outer.position = Vector2(x - 18, y - 18)
	outer.z_index = -6
	draw_node.add_child(outer)

	# Inner wall
	var inner = ColorRect.new()
	inner.color = Color(0.85, 0.83, 0.78)
	inner.size = Vector2(w, h)
	inner.position = Vector2(x, y)
	inner.z_index = -5
	draw_node.add_child(inner)

	# Floor
	var floor = ColorRect.new()
	floor.color = Color(0.25, 0.23, 0.2)
	floor.size = Vector2(w, 14)
	floor.position = Vector2(x, y + h - 14)
	draw_node.add_child(floor)

	# Floor edge line
	var floor_line = ColorRect.new()
	floor_line.color = Color(0.6, 0.6, 0.55)
	floor_line.size = Vector2(w, 2)
	floor_line.position = Vector2(x, y + h - 14)
	draw_node.add_child(floor_line)

	# Ceiling
	var ceiling = ColorRect.new()
	ceiling.color = Color(0.78, 0.76, 0.72)
	ceiling.size = Vector2(w, 18)
	ceiling.position = Vector2(x, y)
	ceiling.z_index = -3
	draw_node.add_child(ceiling)

	# Ceiling rail (handrail)
	var rail = ColorRect.new()
	rail.color = Color(0.35, 0.35, 0.35)
	rail.size = Vector2(w, 4)
	rail.position = Vector2(x, y + 22)
	rail.z_index = -2
	draw_node.add_child(rail)

	# Windows along the top (fake train windows)
	var door_h = 100.0
	var door_top_y = CARRIAGE_Y + CARRIAGE_HEIGHT / 2 - door_h / 2
	for win_x in [x + 20, x + 100, x + 190, x + w - 110, x + w - 40]:
		# Skip windows where doors are
		var win_cx = win_x + 25
		if abs(win_cx - x) < 40 or abs(win_cx - (x + w)) < 40:
			continue
		var win = ColorRect.new()
		win.color = Color(0.25, 0.3, 0.4)
		win.size = Vector2(50, 20)
		win.position = Vector2(win_x, y + 2)
		win.z_index = -4
		draw_node.add_child(win)

	# Seats along left and right walls
	var seat_color = Color(0.3, 0.35, 0.55)
	var seat_w = 14
	var seat_top = y + 30
	var seat_h = h - 40
	# Top section seat (left wall, above door)
	var seat1 = ColorRect.new()
	seat1.color = seat_color
	seat1.size = Vector2(seat_w, door_top_y - seat_top)
	seat1.position = Vector2(x + 4, seat_top)
	seat1.z_index = -4
	draw_node.add_child(seat1)
	# Bottom section seat (left wall, below door)
	var seat2 = ColorRect.new()
	seat2.color = seat_color
	seat2.size = Vector2(seat_w, (y + h - 14) - (door_top_y + door_h))
	seat2.position = Vector2(x + 4, door_top_y + door_h)
	seat2.z_index = -4
	draw_node.add_child(seat2)
	# Right wall seats
	var seat3 = ColorRect.new()
	seat3.color = seat_color
	seat3.size = Vector2(seat_w, door_top_y - seat_top)
	seat3.position = Vector2(x + w - seat_w - 4, seat_top)
	seat3.z_index = -4
	draw_node.add_child(seat3)
	var seat4 = ColorRect.new()
	seat4.color = seat_color
	seat4.size = Vector2(seat_w, (y + h - 14) - (door_top_y + door_h))
	seat4.position = Vector2(x + w - seat_w - 4, door_top_y + door_h)
	seat4.z_index = -4
	draw_node.add_child(seat4)

	# Vertical poles
	for pole_x in [x + 110, x + w / 2, x + w - 130]:
		var pole = ColorRect.new()
		pole.color = Color(0.7, 0.7, 0.65)
		pole.size = Vector2(4, h - 40)
		pole.position = Vector2(pole_x, y + 30)
		pole.z_index = -2
		draw_node.add_child(pole)


func _create_grab_rails() -> void:
	var y = CARRIAGE_Y + 32.0
	var spacing = 65.0
	var sx = CARRIAGE_X + 36.0
	var ex = CARRIAGE_X + CARRIAGE_WIDTH - 36.0

	var x = sx
	while x <= ex:
		var gp = GrabPoint.new()
		gp.position = Vector2(x, y)
		add_child(gp)
		grab_points.append(gp)

		var marker = ColorRect.new()
		marker.color = Color(0.5, 0.5, 0.5)
		marker.size = Vector2(8, 5)
		marker.position = Vector2(x - 4, y - 3)
		marker.z_index = -2
		add_child(marker)
		x += spacing

	for pole_x in [CARRIAGE_X + 110, CARRIAGE_X + CARRIAGE_WIDTH / 2, CARRIAGE_X + CARRIAGE_WIDTH - 130]:
		for gy in range(2):
			var gp = GrabPoint.new()
			gp.position = Vector2(pole_x, CARRIAGE_Y + 60 + gy * 110)
			add_child(gp)
			grab_points.append(gp)


func _spawn_player() -> void:
	player = Player.new()
	player.position = carriage_bounds.get_center()
	player.add_to_group("player")
	add_child(player)


func _spawn_systems() -> void:
	crowd_physics = CrowdPhysics.new()
	crowd_physics.setup(carriage_bounds)
	crowd_physics.register_player(player)
	add_child(crowd_physics)

	spawner = PassengerSpawner.new()
	spawner.setup(carriage_bounds, "rush_hour")
	spawner.set_door_positions(left_door_pos, right_door_pos)
	add_child(spawner)

	carriage_state = CarriageState.new()
	add_child(carriage_state)


func _spawn_passengers() -> void:
	var passengers = spawner.spawn_initial()
	for p in passengers:
		crowd_physics.register_passenger(p)
		add_child(p)


func _setup_hud() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = load("res://scripts/ui/hud.gd").new()
	canvas.add_child(hud)
	progress_ui = load("res://scripts/ui/progress_bar.gd").new()
	canvas.add_child(progress_ui)

	# Mobile touch controls (auto-hides on desktop)
	var mobile_ctrl = load("res://scripts/ui/mobile_controls.gd").new()
	canvas.add_child(mobile_ctrl)

	# Station notification label (centered top)
	notify_label = Label.new()
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.add_theme_font_size_override("font_size", 28)
	notify_label.add_theme_color_override("font_color", Color.WHITE)
	notify_label.anchor_left = 0.3
	notify_label.anchor_right = 0.7
	notify_label.anchor_top = 0.05
	notify_label.modulate.a = 0.0
	canvas.add_child(notify_label)

	# Freeze countdown label (debug)
	freeze_label = Label.new()
	freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	freeze_label.add_theme_font_size_override("font_size", 20)
	freeze_label.add_theme_color_override("font_color", Color.YELLOW)
	freeze_label.anchor_left = 0.3
	freeze_label.anchor_right = 0.7
	freeze_label.anchor_top = 0.12
	freeze_label.text = ""
	canvas.add_child(freeze_label)


func _setup_signals() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.doors_opened.connect(_on_doors_opened)
	EventBus.doors_closed.connect(_on_doors_closed)


func _process(delta: float) -> void:
	if GameState.game_over:
		return

	# Tunnel lights scroll during packed phase (doors closed)
	if not carriage_state.doors_open:
		# Decelerate when close to station (< 1.5s remaining)
		var speed = _tunnel_speed
		var brake_factor = 1.0
		if station_timer < 1.5:
			brake_factor = station_timer / 1.5
			speed = _tunnel_speed * brake_factor
		for light in _tunnel_lights:
			if not is_instance_valid(light):
				continue
			light.position.y -= speed * delta
			# Wrap lights that scrolled off-screen vertically
			if light.position.y < CARRIAGE_Y - 150:
				light.position.y += 300 + CARRIAGE_HEIGHT
			elif light.position.y > CARRIAGE_Y + CARRIAGE_HEIGHT + 150:
				light.position.y -= 300 + CARRIAGE_HEIGHT

		# Screen shake: subtle train vibration, stronger vertically (train moves up/down)
		if _carriage_visual:
			var shake_amp = 1.5 * brake_factor
			_carriage_visual.position = Vector2(
				randf_range(-shake_amp * 0.4, shake_amp * 0.4),
				randf_range(-shake_amp, shake_amp)
			)
	else:
		# Reset shake when doors open
		if _carriage_visual and _carriage_visual.position != Vector2.ZERO:
			_carriage_visual.position = Vector2.ZERO

	if carriage_state.doors_open:
		if freeze_countdown > 0:
			freeze_countdown -= delta
			if freeze_label:
				if is_final_station:
					freeze_label.text = "%s下车  关门倒计时: %.1fs" % [_final_door_arrow(), max(freeze_countdown, 0.0)]
				else:
					freeze_label.text = "上车倒计时: %.1fs" % max(freeze_countdown, 0.0)
			if freeze_countdown <= 0:
				if freeze_label and not is_final_station:
					freeze_label.text = ""
				freeze_countdown = -1.0
		return  # timer paused while doors open
	station_timer -= delta
	if station_timer <= 0:
		_station_complete()


func _station_complete() -> void:
	GameState.current_station += 1
	if GameState.current_station > GameState.total_stations:
		_arrive_at_company()
		return
	var door_side = -1 if (GameState.current_station % 2 == 1) else 1
	if GameState.current_station == GameState.total_stations:
		is_final_station = true
	carriage_state.start_door_cycle(door_side)


func _on_doors_opened(door_side: int) -> void:
	# Slide the door open
	if door_side < 0 and left_door:
		left_door.open_door()
	elif door_side > 0 and right_door:
		right_door.open_door()

	if is_final_station:
		var arrow = "←← 左门" if door_side < 0 else "右门 →→"
		_show_notification("终点站到了！%s下车" % arrow)
		freeze_label.text = "%s下车  关门倒计时: 15.0s" % arrow
		freeze_countdown = 15.0  # door close countdown
		entering_frozen = false
		crowd_physics.allow_player_exit = true
	else:
		var side_text = "左门" if door_side < 0 else "右门"
		_show_notification("第 %d 站 - %s开启" % [GameState.current_station, side_text])
		freeze_countdown = 5.0
		entering_frozen = true

	# 1. Mark exiting passengers (3-4 people)
	var exit_count = 3 + randi() % 2
	spawner.mark_exiting_passengers(door_side, exit_count)

	# 2. Spawn entering passengers (skip at final station)
	if not is_final_station:
		var enter_count = 5 + randi() % 3  # 5-7 people
		var newbies = spawner.spawn_entering_batch(enter_count, door_side)
		for p in newbies:
			p.active = false
			p.collision_layer = 0
			crowd_physics.register_passenger(p)
			add_child(p)

		var inward = Vector2(door_side, 0)
		get_tree().create_timer(5.0).timeout.connect(func():
			entering_frozen = false
			for p in newbies:
				if is_instance_valid(p):
					p.collision_layer = 1
					p.activate_entering(inward)
					p.active = true
		)

	# 3. Continuous cleanup: remove exiters, recycle pushed-out passengers
	var cleanup_timer = get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(_cleanup_exiters_loop.bind(cleanup_timer, door_side))

	# 4. Door closes at 15s (handled by carriage_state timer)


func _on_doors_closed() -> void:
	if left_door:
		left_door.close_door()
	if right_door:
		right_door.close_door()

	spawner.remove_exiting_passengers(false)
	spawner.set_all_packed()
	freeze_countdown = -1.0
	if freeze_label:
		freeze_label.text = ""

	# Final station: player didn't exit in time
	if is_final_station and not player_exited:
		crowd_physics.allow_player_exit = false
		GameState.game_over = true  # prevent _process from double-triggering
		_show_notification("错过下车！坐过站了...")
		GameState.late_seconds += 600  # heavy late penalty
		await get_tree().create_timer(1.5).timeout
		_arrive_at_company()
		return

	_show_notification("车门关闭")

	# After station 3: hint which door to exit at station 5
	if GameState.current_station == 3:
		var final_side = -1 if (GameState.total_stations % 2 == 1) else 1
		var arrow = "← 左侧" if final_side < 0 else "右侧 →"
		_show_notification("第5站(终点站)  %s车门下车" % arrow)

	station_timer = STATION_DURATION


func _show_notification(text: String) -> void:
	if not notify_label:
		return
	notify_label.text = text
	notify_label.modulate.a = 1.0
	# Fade out after 2 seconds
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notify_label, "modulate:a", 0.0, 0.5)


func _cleanup_exiters_loop(timer: SceneTreeTimer, door_side: int) -> void:
	if not is_inside_tree():
		return
	if not carriage_state.doors_open:
		return
	spawner.remove_exiting_passengers(not entering_frozen, door_side)

	# Check if player exited at final station
	if is_final_station and player and player.alive:
		var px = player.global_position.x
		var past_door = (door_side < 0 and px < carriage_bounds.position.x + 30) \
			or (door_side > 0 and px > carriage_bounds.end.x - 30)
		if past_door:
			player_exited = true
			crowd_physics.allow_player_exit = false
			_show_notification("下车成功！")
			player.alive = false
			_arrive_at_company()
			return

	var next_timer = get_tree().create_timer(0.5)
	next_timer.timeout.connect(_cleanup_exiters_loop.bind(next_timer, door_side))


func _final_door_arrow() -> String:
	return "←← 左门" if carriage_state.open_door_side < 0 else "右门 →→"


func _arrive_at_company() -> void:
	GameState.finish_run()
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")


func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
