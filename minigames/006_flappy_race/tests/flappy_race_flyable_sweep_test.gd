extends "res://minigames/006_flappy_race/tests/flappy_race_flyable_test.gd"
## The flyability check over many more seeds. Runs only with node tools/check.mjs --full.


func _run() -> void:
	perfect_seeds = range(5, 35)
	pickup_seeds = range(103, 118)
	super()
