extends Node
## Global event bus.

signal player_fell(stamina_left: int)
signal player_died()
signal player_grabbed_rail()
signal player_released_rail()

signal station_arrived(station_num: int)
signal station_departed(station_num: int)
signal doors_opened(side: int)   # -1 = left door, +1 = right door
signal doors_closed()

signal carriage_shake(direction: int, force: float)
signal carriage_stable()
