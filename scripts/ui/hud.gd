extends Control

## HUD: top-left stamina + salary display.

var stamina_label: Label
var salary_label: Label


func _ready() -> void:
	# Panel background
	var panel = Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(200, 60)
	panel.z_index = 100
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(24, 20)
	vbox.z_index = 101
	add_child(vbox)

	stamina_label = Label.new()
	stamina_label.add_theme_font_size_override("font_size", 18)
	stamina_label.add_theme_color_override("font_color", Color.BLACK)
	vbox.add_child(stamina_label)

	salary_label = Label.new()
	salary_label.add_theme_font_size_override("font_size", 18)
	salary_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	vbox.add_child(salary_label)

	_update_display()
	EventBus.player_fell.connect(_on_update)


func _process(_delta: float) -> void:
	_update_display()


func _update_display() -> void:
	stamina_label.text = "体力： " + "♥".repeat(GameState.current_stamina) + "♡".repeat(max(0, GameState.stamina - GameState.current_stamina))
	salary_label.text = "余额：¥" + str(GameState.salary)


func _on_update(_stamina_left: int) -> void:
	_update_display()
