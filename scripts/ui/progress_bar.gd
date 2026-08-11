extends Control

## Station progress bar at top-right.

var stations: Array[String] = ["家", "1", "2", "3", "4", "5", "公司"]
var progress_label: Label
var bar_bg: ColorRect
var bar_fill: ColorRect


func _ready() -> void:
	# Panel
	var panel = Panel.new()
	panel.position = Vector2(950, 12)
	panel.size = Vector2(310, 60)
	panel.z_index = 100
	add_child(panel)

	progress_label = Label.new()
	progress_label.position = Vector2(960, 16)
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color.BLACK)
	progress_label.z_index = 101
	add_child(progress_label)

	# Progress bar
	bar_bg = ColorRect.new()
	bar_bg.color = Color(0.3, 0.3, 0.3)
	bar_bg.position = Vector2(960, 42)
	bar_bg.size = Vector2(290, 14)
	bar_bg.z_index = 101
	add_child(bar_bg)

	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.3, 0.7, 0.3)
	bar_fill.position = Vector2(961, 43)
	bar_fill.size = Vector2(0, 12)
	bar_fill.z_index = 102
	add_child(bar_fill)


func _process(_delta: float) -> void:
	var current = GameState.current_station
	var total = GameState.total_stations
	if current == 5:
		progress_label.text = "终点站 %d/%d  →  下车！" % [current, total]
	else:
		progress_label.text = "第 %d/%d 站  →  公司" % [current, total]
	var pct = clamp(float(current) / float(total), 0.0, 1.0)
	bar_fill.size.x = 288 * pct
