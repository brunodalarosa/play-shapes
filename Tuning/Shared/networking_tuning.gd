class_name NetworkingTuning
extends Resource
## Host-only LAN and session behavior. Changes apply after relaunching the project.

@export_category("LAN listeners")
## HTTP listener port. Higher/lower has no game-feel effect; change only to avoid a local conflict. Default: 8080. Safe range: 1024-65535.
@export_range(1024, 65535, 1) var http_port: int = 8080:
	set(value): http_port = clampi(value, 1024, 65535)
## WebSocket listener port. It must differ from the HTTP port. Default: 8081. Safe range: 1024-65535.
@export_range(1024, 65535, 1) var websocket_port: int = 8081:
	set(value): websocket_port = clampi(value, 1024, 65535)
## Maximum simultaneous transport connections per service. Higher tolerates more tabs; lower limits resource use. Default: 32. Safe range: 1-128.
@export_range(1, 128, 1) var max_connections: int = 32:
	set(value): max_connections = clampi(value, 1, 128)
## Time allowed for an incomplete HTTP request or WebSocket hello, in seconds. Higher tolerates slower clients; lower rejects stalled clients sooner. Default: 5. Safe range: 0.25-30.
@export_range(0.25, 30.0, 0.25, "suffix:s") var request_timeout_seconds: float = 5.0:
	set(value): request_timeout_seconds = clampf(value, 0.25, 30.0)

@export_category("Player session")
## Maximum registered players. Higher allows larger parties; lower keeps the shared display less crowded. Default: 20. Safe range: 1-32.
@export_range(1, 32, 1, "suffix: players") var max_players: int = 20:
	set(value): max_players = clampi(value, 1, 32)
## Time a disconnected player's seat and name remain reserved, in seconds. Higher is more forgiving; lower frees seats sooner. Default: 60. Safe range: 1-300.
@export_range(1.0, 300.0, 1.0, "suffix:s") var reconnect_grace_seconds: float = 60.0:
	set(value): reconnect_grace_seconds = clampf(value, 1.0, 300.0)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if http_port == websocket_port:
		errors.append("Networking: HTTP port and WebSocket port must be different.")
	if max_players > max_connections:
		errors.append("Networking: Max players (%d) cannot exceed max connections (%d)." % [max_players, max_connections])
	return errors
