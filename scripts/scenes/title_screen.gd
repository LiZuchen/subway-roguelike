extends Control

## Title screen.

func _ready() -> void:
	# Build simple UI programmatically
	_build_ui()


func _build_ui() -> void:
	# Title
	var title = Label.new()
	title.text = "挤地铁大作战"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.2
	title.offset_left = -250
	title.offset_right = 250
	title.offset_top = 0
	add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "横板2D肉鸽挤地铁游戏"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 0.3
	subtitle.offset_left = -200
	subtitle.offset_right = 200
	add_child(subtitle)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "开始上班"
	start_btn.anchor_left = 0.5
	start_btn.anchor_right = 0.5
	start_btn.anchor_top = 0.5
	start_btn.offset_left = -100
	start_btn.offset_right = 100
	start_btn.offset_top = 0
	start_btn.pressed.connect(_on_start_pressed)
	add_child(start_btn)

	# Upgrade button
	var upgrade_btn = Button.new()
	upgrade_btn.text = "升级"
	upgrade_btn.anchor_left = 0.5
	upgrade_btn.anchor_right = 0.5
	upgrade_btn.anchor_top = 0.58
	upgrade_btn.offset_left = -100
	upgrade_btn.offset_right = 100
	upgrade_btn.offset_top = 0
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	add_child(upgrade_btn)

	# Salary display
	var salary_label = Label.new()
	salary_label.text = "余额：¥" + str(GameState.salary)
	salary_label.add_theme_font_size_override("font_size", 20)
	salary_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	salary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salary_label.anchor_left = 0.5
	salary_label.anchor_right = 0.5
	salary_label.anchor_top = 0.66
	salary_label.offset_left = -150
	salary_label.offset_right = 150
	add_child(salary_label)

	# Background color
	var bg = ColorRect.new()
	bg.color = Color(0.95, 0.95, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.z_index = -1


func _on_start_pressed() -> void:
	GameState.reset_run()
	# Fade or direct transition
	get_tree().change_scene_to_file("res://scenes/carriage.tscn")


func _on_upgrade_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn")
