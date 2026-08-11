extends Node2D
class_name SlidingDoor

## A two-panel subway door. Visual panels (Node2D) animate freely;
## collision bodies (StaticBody2D) are separate and toggled on/off.

var door_width: float = 16.0
var door_height: float = 100.0
var panel_height: float

# Visual panels (animated)
var top_vis: Node2D
var bottom_vis: Node2D

# Collision bodies (toggled, not animated)
var top_col_body: StaticBody2D
var bottom_col_body: StaticBody2D

var top_closed_y: float
var bottom_closed_y: float

enum State { CLOSED, OPENING, OPEN, CLOSING }
var _state: State = State.CLOSED
var _anim_t: float = 0.0
var _anim_duration: float = 0.0
var _anim_start_top: float
var _anim_start_bottom: float
var _anim_end_top: float
var _anim_end_bottom: float


func _ready() -> void:
	panel_height = door_height / 2.0

	# Top panel
	top_vis = _make_visual()
	top_vis.position.y = -panel_height
	top_closed_y = -panel_height
	top_col_body = _make_collision()
	top_col_body.position.y = -panel_height

	# Bottom panel
	bottom_vis = _make_visual()
	bottom_vis.position.y = 0
	bottom_closed_y = 0
	bottom_col_body = _make_collision()
	bottom_col_body.position.y = 0


func _make_visual() -> Node2D:
	var vis = Node2D.new()
	var bg = ColorRect.new()
	bg.color = Color(0.65, 0.65, 0.63)
	bg.size = Vector2(door_width, panel_height)
	vis.add_child(bg)

	var win_h = panel_height * 0.25
	var win = ColorRect.new()
	win.color = Color(0.35, 0.45, 0.55)
	win.size = Vector2(door_width - 3, win_h)
	win.position = Vector2(1.5, panel_height * 0.15)
	vis.add_child(win)

	add_child(vis)
	return vis


func _make_collision() -> StaticBody2D:
	var body = StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(door_width, panel_height)
	col.shape = shape
	col.position = Vector2(door_width / 2.0, panel_height / 2.0)
	body.add_child(col)
	add_child(body)
	return body


func _process(delta: float) -> void:
	if _state == State.CLOSED or _state == State.OPEN:
		return

	_anim_t += delta
	var frac = clamp(_anim_t / _anim_duration, 0.0, 1.0)
	frac = _ease_in_out_quad(frac)

	top_vis.position.y = lerpf(_anim_start_top, _anim_end_top, frac)
	bottom_vis.position.y = lerpf(_anim_start_bottom, _anim_end_bottom, frac)

	if _anim_t >= _anim_duration:
		top_vis.position.y = _anim_end_top
		bottom_vis.position.y = _anim_end_bottom
		if _state == State.OPENING:
			_state = State.OPEN
		else:
			_state = State.CLOSED
			# Sync collision bodies to closed position
			top_col_body.position.y = top_closed_y
			bottom_col_body.position.y = bottom_closed_y


func open_door() -> void:
	# Disable collision immediately
	top_col_body.collision_layer = 0
	bottom_col_body.collision_layer = 0

	var slide = panel_height + 4
	_anim_start_top = top_vis.position.y
	_anim_start_bottom = bottom_vis.position.y
	_anim_end_top = top_closed_y - slide
	_anim_end_bottom = bottom_closed_y + slide
	_anim_t = 0.0
	_anim_duration = 0.5
	_state = State.OPENING


func close_door() -> void:
	# Restore collision immediately for push effect
	top_col_body.collision_layer = 4
	bottom_col_body.collision_layer = 4

	_anim_start_top = top_vis.position.y
	_anim_start_bottom = bottom_vis.position.y
	_anim_end_top = top_closed_y
	_anim_end_bottom = bottom_closed_y
	_anim_t = 0.0
	_anim_duration = 0.4
	_state = State.CLOSING


func _ease_in_out_quad(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return 1.0 - (-2.0 * t + 2.0) * (-2.0 * t + 2.0) / 2.0
