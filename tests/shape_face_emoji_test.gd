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
	"face_kissing": "😗",
	"face_kissing_smiling_eyes": "😙",
	"face_kissing_closed_eyes": "😚",
	"face_warm_smile": "☺️",
	"face_raised_eyebrow": "🤨",
	"face_smirking": "😏",
	"face_persevering": "😣",
	"face_hushed": "😯",
	"face_exhausted": "🫩",
	"face_relieved": "😌",
	"face_unamused": "😒",
	"face_pensive": "😔",
	"face_worried": "😟",
	"face_flushed": "😳",
	"face_spiral_eyes": "😵‍💫",
	"face_woozy": "🥴",
	"face_angry": "😠",
	"face_pleading": "🥺",
	"face_anguished": "😧",
	"face_beaming": "😁",
	"face_tired": "😫",
	"face_astonished": "😲",
	"face_weary": "😩",
	"face_grimacing": "😬",
	"face_tongue": "😛",
	"face_winking_tongue": "😜",
	"face_squinting_tongue": "😝",
	"face_savoring_food": "😋",
	"face_zany": "🤪",
	"face_joy_tears": "😂",
	"face_grinning_sweat": "😅",
	"face_sunglasses": "😎",
	"face_heart_eyes": "😍",
	"face_smiling_tear": "🥲",
	"face_star_struck": "🤩",
	"face_sad_relieved": "😥",
	"face_sleepy": "😪",
	"face_sleeping": "😴",
	"face_drooling": "🤤",
	"face_downcast_sweat": "😓",
	"face_money_mouth": "🤑",
	"face_crying": "😢",
	"face_loudly_crying": "😭",
	"face_holding_back_tears": "🥹",
	"face_halo": "😇",
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

	for name: String in [
		"face_smiling_eyes",
		"face_disappointed",
		"face_confounded",
		"face_dizzy",
		"face_kissing_smiling_eyes",
		"face_kissing_closed_eyes",
		"face_warm_smile",
		"face_persevering",
		"face_relieved",
		"face_pensive",
		"face_spiral_eyes",
		"face_beaming",
		"face_tired",
		"face_weary",
		"face_squinting_tongue",
		"face_savoring_food",
		"face_joy_tears",
		"face_grinning_sweat",
		"face_sunglasses",
		"face_heart_eyes",
		"face_star_struck",
		"face_sleepy",
		"face_sleeping",
		"face_downcast_sweat",
		"face_money_mouth",
		"face_loudly_crying",
		"face_halo",
	]:
		check(not manifest.face(name).can_blink(), "%s has a fixed eye pose" % name)
		check(
			manifest.blinked(name).layers[0].part == manifest.face(name).layers[0].part,
			"%s keeps its eyes on a blink" % name,
		)
	var wink := manifest.blinked("face_winking")
	check(wink.layers[0].part == ShapeFaceManifest.BLINK_EYE, "The wink's open eye blinks")
	check(wink.layers[1].part == "facial_part_eye_closed_up", "The wink's shut eye stays shut")
	var exhausted := manifest.blinked("face_exhausted")
	check(exhausted.layers[0].part == ShapeFaceManifest.BLINK_EYE, "Heavy-lidded eyes can blink")
	for index: int in [2, 3]:
		check(exhausted.layers[index].part == "facial_part_eyebrow_a", "Brows survive blinking")
	check(
		manifest.face("face_spiral_eyes").layers[0].part == "facial_part_eye_spiral",
		"The spiral-eyed face has its own eye parts",
	)
	check(
		manifest.face("face_dizzy").layers[0].part == "facial_part_eye_x",
		"The original dizzy face keeps its X-eyes",
	)
	var pleading := manifest.blinked("face_pleading")
	check(pleading.layers[0].part == ShapeFaceManifest.BLINK_EYE, "Pleading eyes can blink")
	check(pleading.layers[4].part == "facial_part_mouth_sad", "A pleading blink keeps its mouth")
	var teary := manifest.face("face_holding_back_tears")
	check(teary.layers[0].part == "facial_part_eye_teary", "Held-back tears well in the eyes")
	check(
		manifest.blinked("face_holding_back_tears").layers[0].part == ShapeFaceManifest.BLINK_EYE,
		"Teary eyes can blink",
	)
	var woozy := manifest.face("face_woozy")
	check(woozy.layers[0].part != woozy.layers[1].part, "The woozy eyes have different shapes")
	check(woozy.layers[0].center.y != woozy.layers[1].center.y, "The woozy eyes sit unevenly")
	for name: String in [
		"face_tongue",
		"face_winking_tongue",
		"face_squinting_tongue",
		"face_savoring_food",
		"face_zany",
	]:
		var open := manifest.face(name)
		var blinked := manifest.blinked(name)
		check(open.layers[3].part == "facial_part_tongue", "%s has a tongue layer" % name)
		var tongue := open.layers[3]
		var blink_tongue := blinked.layers[3]
		check(
			(
				blink_tongue.part == tongue.part and blink_tongue.center == tongue.center
				and blink_tongue.size == tongue.size
				and blink_tongue.rotation_degrees == tongue.rotation_degrees
				and blink_tongue.mirror == tongue.mirror
			),
			"%s keeps its tongue during blinks" % name,
		)
	var tongue_wink := manifest.blinked("face_winking_tongue")
	check(tongue_wink.layers[0].part == ShapeFaceManifest.BLINK_EYE, "The tongue wink can blink")
	check(
		tongue_wink.layers[1].part == "facial_part_eye_closed_up",
		"The tongue wink keeps its shut eye",
	)
	var zany := manifest.face("face_zany")
	check(zany.layers[0].size != zany.layers[1].size, "The zany eyes have different sizes")
	check(
		not manifest.face("face_money_mouth").layers[1].mirror,
		"Money symbols keep their reading direction",
	)
	for name: String in ["face_smirking", "face_unamused"]:
		check(
			not manifest.face(name).layers[1].mirror,
			"%s looks to one side with both eyes" % name,
		)
	var selected := TiltShift3DExpressionTuning.new()
	for name: String in EMOJIS:
		selected.play_face = name
		check(selected.validation_errors().is_empty(), "%s can be selected in tuning" % name)
	_check_decorations(manifest)


func _check_decorations(manifest: ShapeFaceManifest) -> void:
	var expected := {
		"face_joy_tears": ["facial_part_tear_drop", 2],
		"face_grinning_sweat": ["facial_part_tear_drop", 1],
		"face_sunglasses": ["facial_part_sunglasses", 1],
		"face_smiling_tear": ["facial_part_tear_drop", 1],
		"face_sad_relieved": ["facial_part_tear_drop", 1],
		"face_sleepy": ["facial_part_sleep_bubble", 1],
		"face_sleeping": ["facial_part_sleep_z", 1],
		"face_drooling": ["facial_part_tear_drop", 1],
		"face_downcast_sweat": ["facial_part_tear_drop", 1],
		"face_money_mouth": ["facial_part_tongue", 1],
		"face_crying": ["facial_part_tear_drop", 1],
		"face_loudly_crying": ["facial_part_tear_stream", 2],
		"face_halo": ["facial_part_halo", 1],
	}
	for name: String in expected:
		var open := manifest.face(name)
		var blinked := manifest.blinked(name)
		var count := 0
		for index: int in open.layers.size():
			var layer := open.layers[index]
			if layer.part != expected[name][0]:
				continue
			count += 1
			var blink := blinked.layers[index]
			check(
				(
					blink.part == layer.part and blink.center == layer.center
					and blink.size == layer.size
					and blink.rotation_degrees == layer.rotation_degrees
					and blink.mirror == layer.mirror
				),
				"%s keeps its decoration during blinks" % name,
			)
		check(count == expected[name][1], "%s has the expected decorations" % name)
