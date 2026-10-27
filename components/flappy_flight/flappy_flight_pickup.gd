class_name FlappyFlightPickup
extends RefCounted
## A speed pickup: a square trigger centred at x, y, metres. Every player can take each one once.

var x := 0.0
var y := 0.0
var half_size := 0.0


static func from_dictionary(data: Dictionary) -> FlappyFlightPickup:
	var pickup := FlappyFlightPickup.new()
	pickup.x = data.x
	pickup.y = data.y
	pickup.half_size = data.half_size
	return pickup


func to_dictionary() -> Dictionary:
	return { "x": x, "y": y, "half_size": half_size }
