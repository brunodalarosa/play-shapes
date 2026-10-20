extends TestScript
## Emoji presets load as 3D parts, preserve their references and keep shut eyes during blinks.

const EMOJIS := {
	"face_grinning": "😀",
	"face_winking": "😉",
	"face_smiling_eyes": "😊",
	"face_neutral": "😐",
	"face_surprised": "😮",
	"face_confused": "😕",
	"face_disappointed": "😞",
	"face_frowning_open_mouth": "😦",
	"face_rolling_eyes": "🙄",
	"face_diagonal_mouth": "🫤",
	"face_frowning": "☹️",
	"face_confounded": "😖",
	"face_dizzy": "😵",
}


func _run() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ShapeFaceManifest.MANIFEST)
	)
	var manifest := ShapeFaceManifest.load_default()
	for name: String in EMOJIS:
		check(data.faces[name].emoji_reference == EMOJIS[name], "%s keeps its emoji" % name)
		var face := ShapeFace3D.new()
		face.manifest = manifest
		face.face_name = name
		root.add_child(face)
		var preset := manifest.face(name)
		check(face.quads().size() == preset.layers.size(), "%s draws every 3D part" % name)
		for index: int in preset.layers.size():
			var layer := preset.layers[index]
			var quad := face.quads()[index]
			var material := quad.material_override as StandardMaterial3D
			check(material.albedo_texture != null, "%s part %d loads" % [name, index])
			check(
				(quad.mesh as QuadMesh).size.is_equal_approx(layer.size * face.height),
				"%s part %d keeps its size" % [name, index],
			)
		face.blinking = true
		check(face.quads().size() == preset.layers.size(), "%s keeps parts on a blink" % name)
		face.queue_free()

	for name: String in ["face_smiling_eyes", "face_disappointed", "face_confounded", "face_dizzy"]:
		check(not manifest.face(name).can_blink(), "%s has shut or crossed eyes" % name)
		check(
			manifest.blinked(name).layers[0].part == manifest.face(name).layers[0].part,
			"%s keeps its eyes on a blink" % name,
		)
	var wink := manifest.blinked("face_winking")
	check(wink.layers[0].part == ShapeFaceManifest.BLINK_EYE, "The wink's open eye blinks")
	check(wink.layers[1].part == "facial_part_eye_closed_up", "The wink's shut eye stays shut")
	var selected := TiltShift3DExpressionTuning.new()
	for name: String in EMOJIS:
		selected.play_face = name
		check(selected.validation_errors().is_empty(), "%s can be selected in tuning" % name)
