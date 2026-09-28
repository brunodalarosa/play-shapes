import bpy, os, sys, json, math, importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent
BLEND_COPY = ROOT / 'squircle-addon-test.blend'
ADDON = ROOT / 'sprite_sheet_generator_V2.py'
REPORT = ROOT / 'diagnostics.json'
# Use the actual copied PS-056 model.
scene = bpy.context.scene
original_camera = scene.camera.name if scene.camera else None
root = bpy.data.objects.get('Character.Root - ground anchor')
three_q = bpy.data.objects.get('Camera.ThreeQuarter')
front = bpy.data.objects.get('Camera.Front')
assert root and root.type == 'EMPTY'
assert three_q and front
scene.camera = three_q
# Tiny, bounded render settings.
scene.render.resolution_x = 128
scene.render.resolution_y = 128
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
if scene.render.engine == 'CYCLES':
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
# Unchanged approved source: this evaluated copy is disposable.
# First verify the add-on's documented rejection of a non-armature selection.
spec = importlib.util.spec_from_file_location('sprite_sheet_generator_V2', ADDON)
addon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(addon)
addon.show_error = lambda msg: print('ADDON_ERROR:', msg.replace('\n', ' | '))
addon.show_info = lambda msg: print('ADDON_INFO:', msg.replace('\n', ' | '))
addon.show_warning = lambda msg: print('ADDON_WARNING:', msg.replace('\n', ' | '))
addon.register()
settings = scene.spritesheet_settings
# Select actual non-armature pivot (this is the unrigged model's root anchor).
for obj in bpy.context.selected_objects:
    obj.select_set(False)
root.select_set(True)
bpy.context.view_layer.objects.active = root
raw_result = bpy.ops.spritesheet.detect_actions()
raw_selected_type = root.type
print('RAW_MODEL_DETECT_RESULT:', raw_result, 'ACTIVE_TYPE:', raw_selected_type)
# A valid armature wrapper can carry actions and rigidly rotate the whole detached-part hierarchy.
arm_data = bpy.data.armatures.new('TEST ONLY - Squircle compatibility armature')
rig = bpy.data.objects.new('TEST ONLY - Squircle armature', arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bone = arm_data.edit_bones.new('Root')
bone.head = (0, 0, 0)
bone.tail = (0, 0, 0.5)
bpy.ops.object.mode_set(mode='OBJECT')
root.parent = rig
root.matrix_parent_inverse = rig.matrix_world.inverted()
# Create a short, real armature-object action; it proves animation discovery, not independent hand/foot rigging.
scene.frame_start = 1
scene.frame_end = 3
scene.frame_set(1)
rig.rotation_euler = (0, 0, 0)
rig.keyframe_insert(data_path='rotation_euler', frame=1, group='TEST ONLY')
scene.frame_set(3)
rig.rotation_euler = (0, 0, math.radians(4))
rig.keyframe_insert(data_path='rotation_euler', frame=3, group='TEST ONLY')
rig.animation_data.action.name = 'addon_compat_idle'
scene.frame_set(1)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
# Test add-on action detection on actual detached character assembly.
detect_result = bpy.ops.spritesheet.detect_actions()
detected = [settings.animations[i].action_name for i in range(len(settings.animations))]
# The add-on's dynamic-bounds path only examines immediate mesh children of armature.
bounds = addon.SpriteSheetCore.get_object_bounding_box_in_frame(rig, 1, three_q)
# Capture a reference frame through Blender's direct render path, same frame/camera/settings.
scene.camera = three_q
scene.frame_set(1)
reference = ROOT / 'reference-threequarter-35x9-128.png'
scene.render.filepath = str(reference)
bpy.ops.render.render(write_still=True)
# Run the add-on's actual sheet operator with one action, one requested view angle, one frame.
settings.animations.clear()
item = settings.animations.add()
item.name = 'compat_idle_threequarter'
item.action_name = 'addon_compat_idle'
item.frame_start = 1
item.frame_end = 1
item.target_frames = 1
item.enabled = True
item.auto_scale = False
settings.use_dynamic_sizing = False
settings.base_sprite_width = 128
settings.base_sprite_height = 128
settings.max_sprite_width = 128
settings.max_sprite_height = 128
settings.columns = 1
settings.padding_percent = 0
settings.use_front = True
settings.use_right = False
settings.use_back = False
settings.use_left = False
settings.flip_y = False
settings.track_origin = False
settings.output_path = str(ROOT)
settings.output_filename = 'addon-sheet-threequarter-35x9-128'
scene.camera = three_q
scene.frame_set(1)
try:
    addon_result = bpy.ops.spritesheet.generate()
except Exception as exc:
    addon_result = 'EXCEPTION: ' + repr(exc)
    print('ADDON_OPERATOR_EXCEPTION:', repr(exc))
# Restore registration and capture useful structural evidence.
try:
    addon.unregister()
except Exception as exc:
    print('ADDON_UNREGISTER_EXCEPTION:', repr(exc))
mesh_descendants = []
def walk(o):
    for c in o.children:
        if c.type == 'MESH': mesh_descendants.append(c.name)
        walk(c)
walk(rig)
report = {
  'source_blend_copy': BLEND_COPY.name,
  'source_scene': scene.name,
  'original_scene_camera': original_camera,
  'evaluated_camera': three_q.name,
  'evaluated_camera_yaw_elevation_degrees': [35, 9],
  'approved_model_had_armature_before_test': False,
  'raw_model_active_type': raw_selected_type,
  'raw_model_action_detection_result': list(raw_result),
  'test_armature_created_only_in_copy': rig.name,
  'test_action_name': 'addon_compat_idle',
  'test_armature_direct_child_types': [c.type for c in rig.children],
  'test_armature_nested_meshes': mesh_descendants,
  'detached_parts_kept_as_separate_objects': True,
  'detached_part_count': len(mesh_descendants),
  'action_detection_result': list(detect_result),
  'detected_action_names': detected,
  'addon_dynamic_bounds_for_nested_assembly': [round(float(v), 6) for v in bounds],
  'addon_generate_result': list(addon_result) if isinstance(addon_result, set) else addon_result,
  'reference_render': reference.name,
  'addon_sheet': 'addon-sheet-threequarter-35x9-128.png',
  'addon_metadata': 'addon-sheet-threequarter-35x9-128_metadata.json',
  'render_resolution': [128, 128],
  'cycles_samples': scene.cycles.samples if scene.render.engine == 'CYCLES' else None,
  'render_engine': scene.render.engine,
  'manual_yaw_selector_present': False,
  'available_addon_yaw_controls_degrees': [0, 90, 180, 270],
  'metadata_fields_from_addon': ['sprite_sheet','columns','rows','max_sprite_width','max_sprite_height','animations[name,row,frame_count,sprite_width,sprite_height]'],
  'separate_body_face_hand_foot_layer_controls': False
}
REPORT.write_text(json.dumps(report, indent=2), encoding='utf-8')
print('DIAGNOSTICS:', json.dumps(report, indent=2))
