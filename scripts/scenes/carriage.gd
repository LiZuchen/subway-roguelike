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


func _ready() -> void:
	# Compute door positions
	var door_h = 100.0
	left_door_pos = Vector2(CARRIAGE_X, CARRIAGE_Y + CARRIAGE_HEIGHT / 2)
	right_door_pos = Vector2(CARRIAGE_X + CARRIAGE_WIDTH, CARRIAGE_Y + CARRIAGE_HEIGHT / 2)

	_setup_scene()
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
	# Dark tunnel
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	# Platform visible behind doors (lighter area outside carriage)
	var door_h = 100.0
	var door_center_y = CARRIAGE_Y + CARRIAGE_HEIGHT / 2

	# Left platform (outside left door) — wide enough to hold waiting passengers
	var plat_w = 100.0
	var left_platform = ColorRect.new()
	left_platform.color = Color(0.55, 0.55, 0.5)
	left_platform.size = Vector2(plat_w, door_h + 8)
	left_platform.position = Vector2(CARRIAGE_X - plat_w - 4, door_center_y - door_h / 2 - 4)
	left_platform.z_index = -7
	add_child(left_platform)

	# Right platform
	var right_platform = ColorRect.new()
	right_platform.color = Color(0.55, 0.55, 0.5)
	right_platform.size = Vector2(plat_w, door_h + 8)
	right_platform.position = Vector2(CARRIAGE_X + CARRIAGE_WIDTH + 4, door_center_y - door_h / 2 - 4)
	right_platform.z_index = -7
	add_child(right_platform)

	# Floor extension (platform level)
	var left_floor = ColorRect.new()
	left_floor.color = Color(0.35, 0.33, 0.3)
	left_floor.size = Vector2(plat_w + 4, 10)
	left_floor.position = Vector2(CARRIAGE_X - plat_w - 4, CARRIAGE_Y + CARRIAGE_HEIGHT - 10)
	left_floor.z_index = -7
	add_child(left_floor)

	var right_floor = ColorRect.new()
	right_floor.color = Color(0.35, 0.33, 0.3)
	right_floor.size = Vector2(plat_w + 4, 10)
	right_floor.position = Vector2(CARRIAGE_X + CARRIAGE_WIDTH, CARRIAGE_Y + CARRIAGE_HEIGHT - 10)
	right_floor.z_index = -7
	add_child(right_floor)


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
	add_child(draw_node)

	var x = CARRIAGE_X
	var y = CARRIAGE_Y
	var w = CARRIAGE_WIDTH
	var h = CARRIAGE_HEIGHT

	# Outer shell
	var outer = ColorRect.new()
	outer.color = Color(0.55, 0.55, 0.5)
	outer.size = Vector2(w + 32, h + 32)
	outer.position = Vector2(x - 16, y - 16)
	outer.z_index = -6
	draw_node.add_child(outer)

	# Inner floor
	var inner = ColorRect.new()
	inner.color = Color(0.78, 0.76, 0.72)
	inner.size = Vector2(w, h)
	inner.position = Vector2(x, y)
	inner.z_index = -5
	draw_node.add_child(inner)

	# Floor strip
	var floor = ColorRect.new()
	floor.color = Color(0.35, 0.33, 0.3)
	floor.size = Vector2(w, 10)
	floor.position = Vector2(x, y + h - 10)
	draw_node.add_child(floor)

	# Ceiling rail
	var rail = ColorRect.new()
	rail.color = Color(0.4, 0.4, 0.4)
	rail.size = Vector2(w, 4)
	rail.position = Vector2(x, y + 20)
	rail.z_index = -3
	draw_node.add_child(rail)

	# Vertical poles
	for pole_x in [x + 110, x + w / 2, x + w - 130]:
		var pole = ColorRect.new()
		pole.color = Color(0.45, 0.45, 0.45)
		pole.size = Vector2(3, h - 40)
		pole.position = Vector2(pole_x, y + 30)
		pole.z_index = -3
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
