class_name HostSettings
extends Resource

@export_range(1024, 65535) var http_port: int = 8080
@export_range(1024, 65535) var websocket_port: int = 8081
@export_range(1, 128) var max_connections: int = 32
@export var request_timeout_seconds: float = 5.0
@export_range(1, 32) var max_players: int = 20
@export_range(1.0, 300.0, 1.0, "suffix:s") var reconnect_grace_seconds: float = 60.0
