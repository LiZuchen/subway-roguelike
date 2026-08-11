extends Control

## Upgrade screen. Buy permanent upgrades with salary.

const UPGRADES = [
	{
		"id": "gym_membership",
		"name": "健身会员",
		"desc": "体力 +1（从3格变为4格）",
		"cost": 50,
	},
	# Future upgrades can be added here
]

var upgrade_buttons: Array[Button] = []


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
	title.text = "升级"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.1
	title.offset_left = -150
	title.offset_right = 150
	add_child(title)

	# Salary
	var salary_label = Label.new()
	salary_label.text = "余额：¥" + str(GameState.salary)
	salary_label.add_theme_font_size_override("font_size", 22)
	salary_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	salary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salary_label.anchor_left = 0.5
	salary_label.anchor_right = 0.5
	salary_label.anchor_top = 0.2
	salary_label.offset_left = -200
	salary_label.offset_right = 200
	add_child(salary_label)

	# Upgrade cards
	var y_start = 0.32
	for i in range(UPGRADES.size()):
		var upgrade = UPGRADES[i]
		var card = Panel.new()
		card.anchor_left = 0.2
		card.anchor_right = 0.8
		card.anchor_top = y_start + i * 0.15
		card.offset_top = 0
		card.offset_bottom = 60
		add_child(card)

		# Name
		var name_label = Label.new()
		name_label.text = upgrade["name"]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color.BLACK)
		name_label.position = Vector2(16, 8)
		card.add_child(name_label)

		# Description
		var desc_label = Label.new()
		desc_label.text = upgrade["desc"]
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		desc_label.position = Vector2(16, 32)
		card.add_child(desc_label)

		# Buy button / Owned label
		var owned = GameState.upgrades.get(upgrade["id"], false)
		if owned:
			var owned_label = Label.new()
			owned_label.text = "已拥有"
			owned_label.add_theme_font_size_override("font_size", 16)
			owned_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
			owned_label.position = Vector2(card.size.x - 100, 18)
			card.add_child(owned_label)
		else:
			var btn = Button.new()
			btn.text = "¥" + str(upgrade["cost"])
			btn.position = Vector2(card.size.x - 100, 14)
			btn.size = Vector2(80, 32)
			if GameState.salary < upgrade["cost"]:
				btn.disabled = true
				btn.text += " (不够)"
			btn.pressed.connect(_on_buy_pressed.bind(i, btn))
			card.add_child(btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.anchor_left = 0.5
	back_btn.anchor_right = 0.5
	back_btn.anchor_top = 0.8
	back_btn.offset_left = -100
	back_btn.offset_right = 100
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(back_btn)


func _on_buy_pressed(index: int, btn: Button) -> void:
	var upgrade = UPGRADES[index]
	var success = GameState.buy_upgrade(upgrade["id"], upgrade["cost"])
	if success:
		btn.disabled = true
		btn.text = "已购买"
		_refresh()


func _refresh() -> void:
	get_tree().reload_current_scene()
