# Flash? Pose! runtime audio

`flash_pose_audio_catalog.gd` is the stable runtime entry point for PS-023. It
maps `bounce` to Bouncing music, `swing` to Swinging music, and `disco` to Wacky
music. It also exposes `flash_1` and `flash_2` in a stable candidate order without
selecting a subjective winner.

`flash_pose_audio_manifest.json` records the supplied files' hashes, technical
metadata, intended cues, provenance, permission, and the remaining provenance
caveat. The source Ogg files are consumed directly; PS-023 created no processed
or normalized derivatives.

All three BGM imports loop from offset `0`. Gameplay should pause the selected
`AudioStreamPlayer`, remember `get_playback_position()`, and resume the same
stream at that position after the genuine-stop flash completes, as required by
DEC-016. The files do not carry authored musical loop-point metadata, so the
wrap uses the file boundary. Seam quality, click-free pause/resume, loudness,
and the preferred flash candidate remain human-listening checks in PS-029.

Flash playback belongs only to presentation handling of the round controller's
resolved genuine-stop flash request. Pausing or resuming music must never emit a
flash sound, which keeps future fake stops isolated from this cue.
