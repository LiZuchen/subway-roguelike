extends Node
## Global game state singleton. Persists across scenes.

# Player permanent stats
var salary: int = 100          # = HP, game over at 0
var stamina: int = 3           # Max stamina slots
var stability: float = 3.0     # Push resistance (higher = more stable)
var speed: float = 200.0       # Movement speed in corridor

# Upgrades owned
var upgrades: Dictionary = {
	"gym_membership": false,    # +1 stamina
}

# Current run state (reset each run)
var current_stamina: int = 3
var current_station: int = 0   # 0 = home, stations 1..N, N+1 = company
var total_stations: int = 5
var run_start_time: float = 0.0
var late_seconds: float = 0.0
var game_over: bool = false

# Result of the last finished run (shown on the result screen)
var last_result: Dictionary = {}

# Whether we're mid-run
var in_run: bool = false

# Schedule (must match carriage.gd STATION_DURATION / CarriageState.DOOR_OPEN_DURATION):
# one station = 5s packed + 15s doors open; the final station's doors open after
# (total_stations - 1) full cycles + 5s travel from home.
const PACKED_SECONDS: float = 5.0
const DOOR_OPEN_SECONDS: float = 15.0
const FALL_OFF_PENALTY_SECONDS: float = 180.0  # 被挤下车 = 等下一趟车

const SAVE_PATH = "user://save_data.json"

func _ready() -> void:
	load_game()

func reset_run() -> void:
	current_stamina = stamina
	current_station = 0
	run_start_time = Time.get_ticks_msec() / 1000.0
	late_seconds = 0.0
	game_over = false
	in_run = true
	last_result = {}

func add_late_seconds(secs: float) -> void:
	late_seconds += secs

func finish_run() -> Dictionary:
	in_run = false

	# Add the actual trip time beyond the scheduled arrival, so 准时/迟到 is a
	# real judgment of this run instead of a static value.
	if run_start_time > 0.0:
		var elapsed = Time.get_ticks_msec() / 1000.0 - run_start_time
		var scheduled = (total_stations - 1) * (PACKED_SECONDS + DOOR_OPEN_SECONDS) + PACKED_SECONDS
		late_seconds += maxf(0.0, elapsed - scheduled)

	var result = {}
	if late_seconds < 30.0:
		result["type"] = "on_time"
		result["change"] = 50
		result["desc"] = "准时到达！"
	elif late_seconds < 300.0:
		result["type"] = "slight_late"
		result["change"] = 20
		result["desc"] = "迟到不到5分钟"
	elif late_seconds < 900.0:
		result["type"] = "late"
		result["change"] = 0
		result["desc"] = "迟到不到15分钟"
	else:
		result["type"] = "very_late"
		result["change"] = -30
		result["desc"] = "迟到超过15分钟！"

	salary = max(0, salary + result["change"])
	last_result = result
	save_game()
	return result

func player_fell_off() -> void:
	"""Called when player is pushed off the carriage."""
	late_seconds += FALL_OFF_PENALTY_SECONDS  # waiting for the next train
	current_stamina -= 1
	if current_stamina <= 0:
		# Dead mid-run
		salary = max(0, salary - 50)
		game_over = true
		in_run = false
		last_result = {
			"type": "died",
			"change": -50,
			"desc": "体力耗尽，被人潮抬下了车……",
		}
		save_game()
		EventBus.player_died.emit()
	else:
		EventBus.player_fell.emit(current_stamina)

func can_afford(cost: int) -> bool:
	return salary >= cost

func spend(cost: int) -> void:
	salary = max(0, salary - cost)
	save_game()

func buy_upgrade(upgrade_id: String, cost: int) -> bool:
	if not can_afford(cost):
		return false
	if upgrades.has(upgrade_id) and upgrades[upgrade_id]:
		return false
	spend(cost)
	upgrades[upgrade_id] = true
	apply_upgrades()
	return true

func apply_upgrades() -> void:
	if upgrades.get("gym_membership", false):
		stamina = 4  # base 3 + 1

func save_game() -> void:
	var data = {
		"salary": salary,
		"stamina": stamina,
		"stability": stability,
		"speed": speed,
		"upgrades": upgrades,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json:
			salary = json.get("salary", 100)
			stamina = json.get("stamina", 3)
			stability = json.get("stability", 3.0)
			speed = json.get("speed", 200.0)
			upgrades = json.get("upgrades", {})
			apply_upgrades()

func reset_all() -> void:
	salary = 100
	stamina = 3
	stability = 3.0
	speed = 200.0
	upgrades = {}
	save_game()
