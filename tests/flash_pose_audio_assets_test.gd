extends SceneTree
## Focused Godot load and import-metadata checks for the PS-023 audio catalog.

const AudioCatalog := preload("res://assets/runtime/audio/flash_pose_audio_catalog.gd")
const EXPECTED_MUSIC_PATHS: Dictionary = {
	&"bounce": "res://assets/runtime/bgm/Bouncing_music.ogg",
	&"swing": "res://assets/runtime/bgm/Swinging_music.ogg",
	&"disco": "res://assets/runtime/bgm/Wacky_music.ogg",
}
const EXPECTED_FLASH_PATHS: Array[String] = [
	"res://assets/runtime/sfxs/flash_1.ogg",
	"res://assets/runtime/sfxs/flash_2.ogg",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for style: StringName in EXPECTED_MUSIC_PATHS:
		var stream := AudioCatalog.MUSIC_BY_STYLE.get(style) as AudioStreamOggVorbis
		if not _check(stream != null, "%s music loads as Ogg Vorbis" % style):
			return
		if not _check(stream.resource_path == EXPECTED_MUSIC_PATHS[style], "%s keeps its stable path" % style):
			return
		if not _check(stream.loop and is_zero_approx(stream.loop_offset), "%s loops from the file boundary" % style):
			return
	if not _check(AudioCatalog.FLASH_CANDIDATES.size() == EXPECTED_FLASH_PATHS.size(), "Both flash candidates remain available"):
		return
	for index: int in EXPECTED_FLASH_PATHS.size():
		var stream := AudioCatalog.FLASH_CANDIDATES[index] as AudioStreamOggVorbis
		if not _check(stream != null, "Flash candidate %d loads as Ogg Vorbis" % (index + 1)):
			return
		if not _check(stream.resource_path == EXPECTED_FLASH_PATHS[index], "Flash candidate %d keeps its stable path" % (index + 1)):
			return
		if not _check(not stream.loop, "Flash candidate %d stays one-shot" % (index + 1)):
			return
	print("Flash Pose audio checks passed: 3 looping style tracks and 2 one-shot flash candidates")
	quit(0)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
