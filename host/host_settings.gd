class_name HostSettings
extends Resource

@export_range(1024, 65535) var http_port: int = 8080
@export_range(1024, 65535) var websocket_port: int = 8081
@export_range(1, 128) var max_connections: int = 32
@export var request_timeout_seconds: float = 5.0
