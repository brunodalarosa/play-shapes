class_name BootRequest
extends Resource
## The Optional boot steps one entry asks for. The Essential steps always run, and each listed
## step brings the steps it needs. A scene asks by exporting a [code]boot_request[/code]
## property on its root.

## Step names from [BootSteps], such as [code]&"servers_this_pc"[/code].
@export var steps: Array[StringName] = []
## True when the entry runs the boot itself to show failures, as the full game does. Otherwise
## the host boots the launched scene, and a failed step is logged while the scene carries on.
@export var started_by_entry := false


func _init(requested: Array[StringName] = []) -> void:
	steps = requested
