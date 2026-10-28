class_name LobbyController
extends Node3D
## What the host services need from the lobby world. Kept free of scene and model references,
## so naming the lobby here does not load its characters on every launch.


func reconcile(_players: Array[Dictionary]) -> void:
	pass


func handle_input(_player: Dictionary, _message: Dictionary, _now_msec: int) -> Dictionary:
	return { }


func reset_sequence(_player_id: String) -> void:
	pass


func clear_all_input() -> void:
	pass
