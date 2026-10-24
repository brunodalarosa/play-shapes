class_name Bubbles3DHandWobble
extends SkeletonModifier3D
## Lets a floating Cubio's hands drift gently on top of whatever clip plays, so Idle reads as
## floating in water without a new animation.

const HANDS: Array[StringName] = [&"Hand.L", &"Hand.R"]

## Largest drift of each hand, in skeleton units.
@export var amount: float = 0.0
## Drift cycles per second.
@export var speed: float = 0.9

var _time := 0.0
var _phase := 0.0


func _init() -> void:
	_phase = randf() * TAU


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or amount <= 0.0:
		return
	_time += delta
	for index: int in HANDS.size():
		var bone := skeleton.find_bone(HANDS[index])
		if bone < 0:
			continue
		var cycle := TAU * speed * _time + _phase + float(index) * 2.1
		var drift := Vector3(sin(cycle * 0.7) * 0.5, sin(cycle), cos(cycle * 0.8) * 0.3) * amount
		skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + drift)
