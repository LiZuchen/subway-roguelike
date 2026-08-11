extends Control

## Result screen after reaching the company (or dying).

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.88, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "结算"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.1
	title.offset_left = -150
	title.offset_right = 150
	add_child(title)

	# Result description
	var result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.anchor_left = 0.5
	result_label.anchor_right = 0.5
	result_label.anchor_top = 0.25
	result_label.offset_left = -200
	result_label.offset_right = 200
	add_child(result_label)

	# Salary display
	var salary_label = Label.new()
	salary_label.text = "余额：¥" + str(GameState.salary)
	salary_label.add_theme_font_size_override("font_size", 28)
	salary_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	salary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salary_label.anchor_left = 0.5
	salary_label.anchor_right = 0.5
	salary_label.anchor_top = 0.35
	salary_label.offset_left = -200
	salary_label.offset_right = 200
	add_child(salary_label)

	# Stamina left
	var stamina_label = Label.new()
	stamina_label.text = "剩余体力： " + "♥".repeat(GameState.current_stamina)
	stamina_label.add_theme_font_size_override("font_size", 20)
	stamina_label.add_theme_color_override("font_color", Color.BLACK)
	stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamina_label.anchor_left = 0.5
	stamina_label.anchor_right = 0.5
	stamina_label.anchor_top = 0.43
	stamina_label.offset_left = -200
	stamina_label.offset_right = 200
	add_child(stamina_label)

	# Play again button
	var play_btn = Button.new()
	play_btn.text = "再来一局"
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.55
	play_btn.offset_left = -100
	play_btn.offset_right = 100
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(play_btn)

	# Title button
	var title_btn = Button.new()
	title_btn.text = "返回主菜单"
	title_btn.anchor_left = 0.5
	title_btn.anchor_right = 0.5
	title_btn.anchor_top = 0.62
	title_btn.offset_left = -100
	title_btn.offset_right = 100
	title_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(title_btn)
