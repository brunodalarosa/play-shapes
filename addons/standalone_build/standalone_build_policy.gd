@tool
class_name StandaloneBuildPolicy
extends RefCounted

const PRESET_NAME := "Play Shapes Windows Release"
const PLATFORM := "Windows Desktop"
const ARCHITECTURE := "x86_64"
const STAGING_RELATIVE := "builds/standalone/windows-x86_64"
const EXECUTABLE_NAME := "Play Shapes.exe"
const PACK_NAME := "Play Shapes.pck"
const METADATA_NAME := "build-info.json"
const ZIP_RELATIVE := "builds/standalone/Play-Shapes-windows-x86_64.zip"
const INCLUDE_FILTER := (
	"web/public/*.html,web/public/*.webmanifest,web/public/*.css,web/public/*.js,"
	+ "web/public/platform_input_settings.json,web/public/models/*.glb,"
	+ "assets/runtime/playground_plaza/*/License.txt,"
	+ "assets/runtime/minigames/bubbles_3d/*/License.txt,"
	+ "assets/runtime/shape_faces/face_presets.json,"
	+ "assets/runtime/minigames/tilt_shift_3d/*/License.txt"
)
const EXCLUDE_FILTER := "addons/godot_mcp/**,addons/standalone_build/**,addons/tilt_shift_3d_workshop/**,scratch/**,comparisons/**,docs/images/tilt-shift-workshop/**,local/**,*.local.json,*.pem,*.key,*.crt,*.cer,*.der,*.p12,*.pfx,art/**,builds/**,opencode.json,tools/**,tests/**,minigames/*/tests/**,test-results/**,web/package.json,web/package-lock.json,web/tsconfig.json,web/node_modules/**,web/src/**,web/tests/**"
const REQUIRED_BROWSER_PATHS := [
	"web/public/platform_input_settings.json",
	"web/public/index.html",
	"web/public/app.js",
	"web/public/three_view.js",
	"web/public/models/cubio.glb",
	"web/public/models/jellyfish.glb",
	"web/public/manifest.webmanifest",
	"web/public/app-icon-180.png",
	"web/public/app-icon-192.png",
	"web/public/app-icon-512.png",
	"web/public/style.css",
]
const REQUIRED_RUNTIME_PATHS := [
	"debug/tilt_shift_3d_review.tscn",
	"web/public/platform_input_settings.json",
	"debug/motion_lab/motion_lab.tscn",
	"debug/motion_lab/motion_lab.gd",
	"debug/motion_lab/motion_plot.gd",
	"host/motion_input_channel.gd",
	"host/motion_orientation.gd",
	"host/controller_network_config.gd",
	"host/controller_stream.gd",
	"host/controller_tls.gd",
	"host/controller_certificate.gd",
	"web/public/index.html",
	"web/public/app.js",
	"web/public/manifest.webmanifest",
	"web/public/app-icon-180.png",
	"web/public/app-icon-192.png",
	"web/public/app-icon-512.png",
	"web/public/style.css",
	"characters/character_selection.gd",
	"characters/cubio_preview.gd",
	"characters/lobby_cubio.tscn",
	"characters/lobby_cubio.gd",
	"characters/cubio_3d.tscn",
	"characters/cubio_3d.gd",
	"characters/cubio_tint.gdshader",
	"characters/cubio_face.gdshader",
	"characters/cubio_front.gdshaderinc",
	"scenes/lobby_playground_world.tscn",
	"scenes/lobby_playground_world.gd",
	"scenes/plaza_landing.gd",
	"scenes/plaza_billboard.tscn",
	"scenes/plaza_billboard.gd",
	"Tuning/Shared/Lobby/Default.tres",
	"Tuning/Shared/lobby_movement_tuning.gd",
	"assets/runtime/animated_characters/cubio/model/cubio.glb",
	"assets/runtime/animated_characters/cubio/model/face-neutral.png",
	"assets/runtime/animated_characters/cubio/model/face-blink.png",
	"assets/runtime/playground_plaza/cafe/cafe.glb",
	"assets/runtime/playground_plaza/billboard/billboard.glb",
	"assets/runtime/playground_plaza/logo_sign/logo_sign.glb",
	"assets/runtime/playground_plaza/table/cafe-table.glb",
	"assets/runtime/playground_plaza/chair/chair_A.gltf",
	"assets/runtime/playground_plaza/chair/License.txt",
	"assets/runtime/playground_plaza/tree/Tree_2_E_Color1.gltf",
	"assets/runtime/playground_plaza/tree/License.txt",
	"assets/runtime/playground_plaza/potted_plant/bush.gltf",
	"assets/runtime/playground_plaza/potted_plant/License.txt",
	"assets/runtime/minigames/bubbles_3d/coral/Tree_Bare_2_A_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/coral/Tree_Bare_1_C_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/coral/License.txt",
	"assets/runtime/minigames/bubbles_3d/kelp/Grass_2_D_Singlesided_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/kelp/Grass_1_C_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/kelp/License.txt",
	"assets/runtime/minigames/bubbles_3d/rocks/forest_nature/Rock_3_M_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/rocks/forest_nature/Rock_1_L_Color1.gltf",
	"assets/runtime/minigames/bubbles_3d/rocks/forest_nature/License.txt",
	"assets/runtime/minigames/bubbles_3d/rocks/space_base_bits/rocks_A.gltf",
	"assets/runtime/minigames/bubbles_3d/rocks/space_base_bits/License.txt",
	"assets/runtime/minigames/bubbles_3d/mug/cup.glb",
	"assets/runtime/minigames/bubbles_3d/mug/License.txt",
	"assets/runtime/minigames/bubbles_3d/bottle/bottle_A_green.gltf",
	"assets/runtime/minigames/bubbles_3d/bottle/License.txt",
	"assets/runtime/minigames/bubbles_3d/jellyfish/jellyfish.glb",
	"assets/runtime/minigames/bubbles_3d/pufferfish/pufferfish.glb",
	"assets/runtime/shape_faces/face_presets.json",
	"assets/runtime/shape_faces/facial_part_eye_closed_down.png",
	"assets/runtime/shape_faces/facial_part_eye_closed_up.png",
	"assets/runtime/shape_faces/facial_part_eye_half_bottom.png",
	"assets/runtime/shape_faces/facial_part_eye_half_top.png",
	"assets/runtime/shape_faces/facial_part_eye_half_top_wing.png",
	"assets/runtime/shape_faces/facial_part_eye_open.png",
	"assets/runtime/shape_faces/facial_part_eye_x.png",
	"assets/runtime/shape_faces/facial_part_eyebrow_a.png",
	"assets/runtime/shape_faces/facial_part_eyebrow_b.png",
	"assets/runtime/shape_faces/facial_part_eyebrow_c.png",
	"assets/runtime/shape_faces/facial_part_eyebrow_d.png",
	"assets/runtime/shape_faces/facial_part_mouth_angry.png",
	"assets/runtime/shape_faces/facial_part_mouth_happy.png",
	"assets/runtime/shape_faces/facial_part_mouth_sad.png",
	"assets/runtime/shape_faces/facial_part_mouth_smirk.png",
	"assets/runtime/shape_faces/facial_part_eye_looking_up.png",
	"assets/runtime/shape_faces/facial_part_eye_squeezed.png",
	"assets/runtime/shape_faces/facial_part_mouth_grin.png",
	"assets/runtime/shape_faces/facial_part_mouth_neutral.png",
	"assets/runtime/shape_faces/facial_part_mouth_open.png",
	"assets/runtime/shape_faces/facial_part_mouth_confused.png",
	"assets/runtime/shape_faces/facial_part_mouth_open_frown.png",
	"assets/runtime/shape_faces/facial_part_mouth_deep_frown.png",
	"assets/runtime/shape_faces/facial_part_mouth_scrunched.png",
	"assets/runtime/shape_faces/facial_part_cheek.png",
	"assets/runtime/shape_faces/facial_part_mouth_kiss.png",
	"assets/runtime/shape_faces/facial_part_eye_soft_closed_up.png",
	"assets/runtime/shape_faces/facial_part_eye_soft_closed_down.png",
	"assets/runtime/shape_faces/facial_part_eye_side_glance.png",
	"assets/runtime/shape_faces/facial_part_eye_tired.png",
	"assets/runtime/shape_faces/facial_part_eye_wide.png",
	"assets/runtime/shape_faces/facial_part_eyebrow_soft.png",
	"assets/runtime/shape_faces/facial_part_cheek_blush.png",
	"assets/runtime/shape_faces/facial_part_bag.png",
	"assets/runtime/shape_faces/facial_part_eye_spiral.png",
	"assets/runtime/shape_faces/facial_part_eye_pleading.png",
	"assets/runtime/shape_faces/facial_part_mouth_woozy.png",
	"assets/runtime/shape_faces/facial_part_mouth_beaming.png",
	"assets/runtime/shape_faces/facial_part_mouth_wail.png",
	"assets/runtime/shape_faces/facial_part_mouth_astonished.png",
	"assets/runtime/shape_faces/facial_part_mouth_grimace.png",
	"assets/runtime/shape_faces/facial_part_mouth_tongue_open.png",
	"assets/runtime/shape_faces/facial_part_tongue.png",
	"assets/runtime/shape_faces/facial_part_tear_drop.png",
	"assets/runtime/shape_faces/facial_part_sunglasses.png",
	"assets/runtime/shape_faces/facial_part_eye_heart.png",
	"assets/runtime/shape_faces/facial_part_eye_star.png",
	"assets/runtime/shape_faces/facial_part_sleep_bubble.png",
	"assets/runtime/shape_faces/facial_part_sleep_z.png",
	"assets/runtime/shape_faces/facial_part_drool.png",
	"assets/runtime/shape_faces/facial_part_eye_money.png",
	"assets/runtime/shape_faces/facial_part_money_tongue.png",
	"assets/runtime/shape_faces/facial_part_tear_stream.png",
	"assets/runtime/shape_faces/facial_part_tear_pool.png",
	"assets/runtime/shape_faces/facial_part_halo.png",
	"assets/runtime/minigames/tilt_shift_3d/crate/bin.glb",
	"assets/runtime/minigames/tilt_shift_3d/crate/License.txt",
	"assets/runtime/minigames/tilt_shift_3d/trash_badge.png",
	"assets/runtime/minigames/tilt_shift_3d/tilt_shift_3d_preview.png",
	"assets/runtime/minigames/tilt_shift_3d/props/platformer/pipe_90_A_blue.gltf",
	"assets/runtime/minigames/tilt_shift_3d/props/platformer/pipe_180_B_blue.gltf",
	"assets/runtime/minigames/tilt_shift_3d/props/platformer/License.txt",
	"assets/runtime/minigames/tilt_shift_3d/props/resource_bits/Parts_Cog.gltf",
	"assets/runtime/minigames/tilt_shift_3d/props/resource_bits/License.txt",
	"assets/runtime/minigames/tilt_shift_3d/props/city_builder/watertower.gltf",
	"assets/runtime/minigames/tilt_shift_3d/props/city_builder/License.txt",
	"minigames/005_3d_tilt_shift/3d_tilt_shift.tscn",
	"minigames/005_3d_tilt_shift/tilt_shift_3d_minigame.tres",
	"minigames/005_3d_tilt_shift/tilt_shift_3d_pre_minigame_content.tres",
	"minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn",
	"minigames/005_3d_tilt_shift/tilt_shift_3d_session.gd",
	"minigames/005_3d_tilt_shift/tilt_shift_3d_protocol.gd",
	"minigames/005_3d_tilt_shift/tuning/Default.tres",
	"components/rounded_bar/rounded_bar.gd",
	"components/shape_face/shape_face_3d.gd",
	"components/shape_face/shape_face_manifest.gd",
	"addons/kenyoni/qr_code/qr_code_rect.gd",
	"scenes/boot.tscn",
	"scenes/lobby.tscn",
	"scenes/pre_minigame_screen.tscn",
	"scenes/pre_minigame_screen.gd",
	"scenes/pre_minigame_content.gd",
	"assets/runtime/minigames/bubbles_3d/bubbles_3d_preview.png",
	"host/pre_minigame_readiness.gd",
	"minigames/catalog.tres",
	"minigames/minigame_catalog.gd",
	"minigames/minigame_definition.gd",
	"assets/runtime/bgm/Beach_music.ogg",
	"assets/runtime/sfxs/drawKnife2.ogg",
	"assets/runtime/sfxs/chop.ogg",
	"assets/runtime/sfxs/maximize_006.ogg",
	"assets/runtime/sfxs/select_006.ogg",
	"assets/runtime/sfxs/stonesHit1.ogg",
	"minigames/004_3d_bubbles/bubbles_3d_minigame.tres",
	"minigames/004_3d_bubbles/bubbles_3d_pre_minigame_content.tres",
	"minigames/004_3d_bubbles/3d_bubbles.tscn",
	"minigames/004_3d_bubbles/bubbles_3d_presentation.gd",
	"minigames/004_3d_bubbles/bubbles_3d_round_controller.gd",
	"minigames/004_3d_bubbles/bubbles_3d_protocol.gd",
	"minigames/004_3d_bubbles/bubbles_3d_tuning.gd",
	"minigames/004_3d_bubbles/tuning/Default.tres",
	"minigames/004_3d_bubbles/bubbles_3d_player_arena.gd",
	"minigames/004_3d_bubbles/bubbles_3d_player_bubble.gd",
	"minigames/004_3d_bubbles/bubbles_3d_hand_wobble.gd",
	"minigames/004_3d_bubbles/bubbles_3d_creature_arena.gd",
	"minigames/004_3d_bubbles/bubbles_3d_jellyfish.gd",
	"minigames/004_3d_bubbles/bubbles_3d_jellyfish_swarm.gd",
	"minigames/004_3d_bubbles/jellyfish_body.gdshader",
	"minigames/004_3d_bubbles/bubbles_3d_pufferfish.gd",
	"host/minigame_protocol.gd",
	"components/plane_3d/plane_lock_3d.gd",
	"components/plane_3d/plane_walls_3d.gd",
	"components/screen_follow_label.gd",
	"components/bubble_shell/bubble_shell_3d.gd",
	"components/bubble_shell/bubble_shell.gdshader",
	"components/underwater_environment/underwater_environment.tscn",
	"components/underwater_environment/underwater_environment.gd",
	"components/underwater_environment/water_backdrop.gdshader",
	"components/underwater_environment/god_rays.gdshader",
	"components/underwater_environment/underwater_prop.gdshader",
]
const EXPECTED_ZIP_ENTRIES := [
	"Play-Shapes-windows-x86_64/",
	"Play-Shapes-windows-x86_64/Play Shapes.exe",
	"Play-Shapes-windows-x86_64/Play Shapes.pck",
	"Play-Shapes-windows-x86_64/build-info.json",
]

static func validate_preset(config_path: String) -> String:
	var config := ConfigFile.new()
	var load_error := config.load(config_path)
	if load_error != OK:
		return "Cannot read export_presets.cfg (error %d)." % load_error
	var preset_section := _find_preset_section(config, PRESET_NAME)
	if preset_section.is_empty():
		return "Export preset '%s' is missing. Restore it in export_presets.cfg." % PRESET_NAME
	if config.get_value(preset_section, "platform", "") != PLATFORM:
		return "Preset '%s' must use the %s platform." % [PRESET_NAME, PLATFORM]
	if config.get_value(preset_section, "include_filter", "") != INCLUDE_FILTER:
		return "Preset '%s' has an unexpected browser include filter." % PRESET_NAME
	if config.get_value(preset_section, "exclude_filter", "") != EXCLUDE_FILTER:
		return "Preset '%s' has an unexpected development-file exclude filter." % PRESET_NAME
	if config.get_value(preset_section, "export_path", "") != STAGING_RELATIVE.path_join(EXECUTABLE_NAME):
		return "Preset '%s' must export only inside %s." % [PRESET_NAME, STAGING_RELATIVE]
	var options_section := "%s.options" % preset_section
	if config.get_value(options_section, "binary_format/architecture", "") != ARCHITECTURE:
		return "Preset '%s' must target %s." % [PRESET_NAME, ARCHITECTURE]
	if config.get_value(options_section, "binary_format/embed_pck", true):
		return "Preset '%s' must keep the PCK external." % PRESET_NAME
	if config.get_value(options_section, "debug/export_console_wrapper", 1) != 0:
		return "Preset '%s' must disable the console wrapper." % PRESET_NAME
	return ""

static func standard_release_template_path() -> String:
	return _standard_template_root().path_join("windows_release_x86_64.exe")

static func standard_debug_template_path() -> String:
	return _standard_template_root().path_join("windows_debug_x86_64.exe")

static func _standard_template_root() -> String:
	var version := Engine.get_version_info()
	var folder := "%d.%d.%d.%s" % [version.major, version.minor, version.patch, version.status]
	return OS.get_environment("APPDATA").path_join("Godot/export_templates").path_join(folder)

static func validate_templates(release_path: String, debug_path: String) -> String:
	var missing := PackedStringArray()
	if not FileAccess.file_exists(release_path):
		missing.append(release_path)
	# Godot validates both standard template files before allowing this preset to export,
	# even though the one-click command itself always requests a release artifact.
	if not FileAccess.file_exists(debug_path):
		missing.append(debug_path)
	if not missing.is_empty():
		return "The matching Godot Windows x86_64 export templates are missing. Install them from Editor > Manage Export Templates, then retry. Expected:\n- %s" % "\n- ".join(missing)
	return ""

static func validate_owned_paths(project_root: String) -> String:
	var root := project_root.simplify_path().trim_suffix("/")
	var staging := root.path_join(STAGING_RELATIVE).simplify_path()
	var archive := root.path_join(ZIP_RELATIVE).simplify_path()
	if not staging.begins_with(root + "/builds/standalone/"):
		return "Refusing to clean an unowned staging path: %s" % staging
	if not archive.begins_with(root + "/builds/standalone/"):
		return "Refusing to replace an unowned ZIP path: %s" % archive
	return ""

static func validate_export_result(exit_code: int, executable_path: String, pack_path: String, output: String) -> String:
	if exit_code != 0:
		return "Godot export failed with exit code %d.\n\n%s" % [exit_code, _tail(output)]
	if not FileAccess.file_exists(executable_path):
		return "Export reported success but did not create %s." % executable_path
	if not FileAccess.file_exists(pack_path):
		return "Export reported success but did not create the external PCK: %s." % pack_path
	return ""

static func pack_contains_required_browser_paths(pack_path: String) -> PackedStringArray:
	return pack_missing_paths(pack_path, REQUIRED_BROWSER_PATHS)

static func pack_contains_required_runtime_paths(pack_path: String) -> PackedStringArray:
	return pack_missing_paths(pack_path, REQUIRED_RUNTIME_PATHS)

static func pack_missing_paths(pack_path: String, required_paths: Array) -> PackedStringArray:
	var missing := PackedStringArray()
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		missing.append("<unreadable PCK>")
		return missing
	var bytes := file.get_buffer(file.get_length())
	for path in required_paths:
		if not _bytes_contain(bytes, path.to_utf8_buffer()):
			missing.append(path)
	return missing

static func pack_contains_any_path(pack_path: String, paths: Array) -> String:
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		return "<unreadable PCK>"
	var bytes := file.get_buffer(file.get_length())
	for path in paths:
		if _bytes_contain(bytes, path.to_utf8_buffer()):
			return path
	return ""

static func _bytes_contain(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty() or needle.size() > haystack.size():
		return false
	var last_start := haystack.size() - needle.size()
	var start := haystack.find(needle[0])
	while start >= 0 and start <= last_start:
		var matches := true
		for offset in range(needle.size()):
			if haystack[start + offset] != needle[offset]:
				matches = false
				break
		if matches:
			return true
		start = haystack.find(needle[0], start + 1)
	return false

static func create_build_info(source_revision: String) -> Dictionary:
	return {
		"preset": PRESET_NAME,
		"architecture": ARCHITECTURE,
		"godot_version": Engine.get_version_info().string,
		"renderer": "gl_compatibility",
		"build_time_utc": Time.get_datetime_string_from_system(true, true),
		"source_revision": source_revision,
	}

static func _find_preset_section(config: ConfigFile, preset_name: String) -> String:
	for section in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			if config.get_value(section, "name", "") == preset_name:
				return section
	return ""

static func _tail(output: String, limit := 6000) -> String:
	if output.length() <= limit:
		return output
	return "...\n" + output.right(limit)
