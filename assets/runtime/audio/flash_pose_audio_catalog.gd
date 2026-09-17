class_name FlashPoseAudioCatalog
extends RefCounted
## Stable Flash? Pose! audio paths. This catalog loads assets but does not own playback.

const MUSIC_BY_STYLE: Dictionary = {
	&"bounce": preload("res://assets/runtime/bgm/Bouncing_music.ogg"),
	&"swing": preload("res://assets/runtime/bgm/Swinging_music.ogg"),
	&"disco": preload("res://assets/runtime/bgm/Wacky_music.ogg"),
}

## Both supplied flash sounds remain candidates until the owner listens in PS-029.
## Their stable order permits deterministic or seeded selection by later presentation code.
const FLASH_CANDIDATES: Array[AudioStream] = [
	preload("res://assets/runtime/sfxs/flash_1.ogg"),
	preload("res://assets/runtime/sfxs/flash_2.ogg"),
]
