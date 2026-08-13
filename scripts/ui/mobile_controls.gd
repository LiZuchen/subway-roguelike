extends Control

## Virtual joystick + grab button for mobile/web touch input.

var _joystick_center: Vector2
var _joystick_radius: float = 60.0
var _joystick_touch_index: int = -1
var _joystick_bg: ColorRect
var _joystick_thumb: ColorRect
var _grab_button: Button
var _grabbing: bool = false


func _ready() -> void:
	# Only show on touch-capable platforms
	if not _is_touch_device():
		queue_free()
		return

	z_index = 200

	# Joystick background
	var joy_center = Vector2(120, 580)
	_joystick_center = joy_center
	_joystick_bg = ColorRect.new()
	_joystick_bg.color = Color(1, 1, 1, 0.15)
	_joystick_bg.size = Vector2(_joystick_radius * 2, _joystick_radius * 2)
	_joystick_bg.position = joy_center - Vector2(_joystick_radius, _joystick_radius)
	add_child(_joystick_bg)

	# Joystick thumb
	_joystick_thumb = ColorRect.new()
	_joystick_thumb.color = Color(1, 1, 1, 0.35)
	_joystick_thumb.size = Vector2(36, 36)
	_joystick_thumb.position = joy_center - Vector2(18, 18)
	add_child(_joystick_thumb)

	# Grab button
	_grab_button = Button.new()
	_grab_button.text = "抓"
	_grab_button.add_theme_font_size_override("font_size", 22)
	_grab_button.size = Vector2(90, 90)
	_grab_button.position = Vector2(1070, 550)
	_grab_button.pressed.connect(_on_grab_pressed)
	_grab_button.button_up.connect(_on_grab_released)
	add_child(_grab_button)


func _is_touch_device() -> bool:
	return OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios")


func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return

	if event is InputEventScreenTouch:
		if event.pressed and _joystick_touch_index == -1:
			# Check if touch is in the left half of screen (joystick zone)
			if event.position.x < 640:
				_joystick_touch_index = event.index
				_update_joystick(event.position)
		elif not event.pressed and event.index == _joystick_touch_index:
			_release_joystick()

	if event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)


func _update_joystick(touch_pos: Vector2) -> void:
	var offset = touch_pos - _joystick_center
	var clamped = offset.limit_length(_joystick_radius)
	_joystick_thumb.position = _joystick_center + clamped - _joystick_thumb.size / 2

	# Map to input actions
	var dir = offset / _joystick_radius  # normalized to [-1, 1]
	_emit_move(dir)


func _release_joystick() -> void:
	_joystick_touch_index = -1
	_joystick_thumb.position = _joystick_center - _joystick_thumb.size / 2
	_emit_move(Vector2.ZERO)


func _emit_move(dir: Vector2) -> void:
	# Release all movement actions first
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

	var deadzone = 0.2
	if abs(dir.x) > deadzone:
		if dir.x < 0:
			Input.action_press("move_left", -dir.x)
		else:
			Input.action_press("move_right", dir.x)
	if abs(dir.y) > deadzone:
		if dir.y < 0:
			Input.action_press("move_up", -dir.y)
		else:
			Input.action_press("move_down", dir.y)


func _on_grab_pressed() -> void:
	Input.action_press("grab")


func _on_grab_released() -> void:
	Input.action_release("grab")
