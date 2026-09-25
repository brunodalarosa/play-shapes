"""Open the APPROVED static source, then run this. Saves a separate animated file."""
from pathlib import Path
import sys
import math
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, CONTROLS, activate_clip, foot_phase, curves

scene = next(s for s in bpy.data.scenes if s.name.startswith('PS056 |'))
bpy.context.window.scene = scene
scene.name = 'PS057 | Squircle Animation Studio'
scene['Approval'] = 'PS056 model approved; PS057 motion and export pending owner review.'
scene['Export contract'] = '24 fps; 256 RGBA; ortho 4.5; front 0/0, three-quarter 35/9; root Z=0.'
scene['Shadow policy'] = 'No baked shadow. Review floor is a contact guide only.'
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.fps = 24
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.seed = 57
scene.cycles.use_animated_seed = False
scene.render.use_file_extension = True
scene.render.image_settings.color_depth = '8'

data = bpy.data.armatures.new('PS057 | Rigid floating-part controls')
rig = bpy.data.objects.new('Animation.Controls', data)
scene.collection.objects.link(rig)
rig.parent = bpy.data.objects['Character.Root - ground anchor']
rig.show_in_front = True
for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
rest = {name: bpy.data.objects[pivot].location.copy() for name, pivot in CONTROLS.items()}
rot = {name: bpy.data.objects[pivot].rotation_euler.copy() for name, pivot in CONTROLS.items()}
bpy.ops.object.mode_set(mode='EDIT')
for name in CONTROLS:
    bone = data.edit_bones.new(name)
    bone.head = rest[name]
    bone.tail = rest[name] + Vector((0, .25, 0))
bpy.ops.object.mode_set(mode='OBJECT')
for name, pivot in CONTROLS.items():
    pb = rig.pose.bones[name]
    pb.rotation_mode = 'XYZ'
    con = bpy.data.objects[pivot].constraints.new('COPY_TRANSFORMS')
    con.name = 'PS057 | Follow editable rigid control'
    con.target = rig
    con.subtarget = name
    con.target_space = con.owner_space = 'WORLD'

rig.animation_data_create()
for clip, spec in CLIPS.items():
    action = bpy.data.actions.new('PS057 | ' + clip.title())
    action.use_fake_user = True
    rig.animation_data.action = action
    action['clip'] = clip
    action['fps'] = spec['fps']
    action['export_frames'] = spec['frames']
    action['ground_speed_m_per_second'] = spec['speed']
    action['Notes'] = 'Export 1..N; N+1 is the duplicate seam key, never exported.'
    n = spec['frames']
    for frame in range(1, n + 2):
        phase = (frame - 1) / n
        theta = math.tau * phase
        for name in CONTROLS:
            pb = rig.pose.bones[name]
            pb.location = (0, 0, 0)
            pb.rotation_euler = rot[name]
            pb.scale = (1, 1, 1)
        body = rig.pose.bones['Body']
        if clip == 'idle':
            breath = math.sin(theta)
            body.location.z = .035 * breath
            body.scale = (1 - .008*breath, 1 - .004*breath, 1 + .018*breath)
            body.rotation_euler.y = .018 * math.sin(theta - .4)
            for side, name in [(-1, 'Hand.L'), (1, 'Hand.R')]:
                hand = rig.pose.bones[name]
                wave = theta + side*.65
                hand.location = (.025*side*math.cos(wave), -.025*math.sin(wave), .055*math.sin(wave))
                hand.rotation_euler.y += .06*math.sin(wave + .6)
                hand.rotation_euler.z += .035*math.cos(wave)
        else:
            running = clip == 'run'
            stance = spec['stance']
            duration = n / spec['fps']
            stride = spec['speed'] * duration * stance
            # Two body pulses per cycle; run includes a visible airborne phase.
            pulse = math.cos(2*theta - (.75*math.pi if running else 0))
            bob = (.16 if running else .055) * (1 - pulse)
            body.location = ((.065 if running else .045)*math.sin(theta), -.055 if running else 0,
                             bob + (.16 if running else 0))
            body.rotation_euler = (-.105 if running else -.025, .055*math.sin(theta), .06*math.sin(theta))
            squash = (.035 if running else .015)*pulse
            body.scale = (1 + squash/2, 1 + squash/2, 1-squash)
            for side, name, offset in [(-1,'Foot.L',0), (1,'Foot.R',.5)]:
                y, lift = foot_phase(phase+offset, stance, stride)
                foot = rig.pose.bones[name]
                foot.location = (0, y, (.28 if running else .22)*lift)
                # Flat soles through stance and swing avoid floor penetration.
            for side, name in [(-1,'Hand.L'), (1,'Hand.R')]:
                hand = rig.pose.bones[name]
                swing = side*math.sin(theta)
                inward = .28 + 1.05*max(0, -swing)**4 if running else .06
                hand.location = (-side*inward,
                                 (.60 if running else .33)*swing - (.25 if running else .04),
                                 (.36 if running else .08) + (.30 if running else .10)*-swing)
                hand.rotation_euler.x = -.18*swing
                hand.rotation_euler.y += (.22 if running else .12)*swing
                hand.rotation_euler.z += .12*swing
        for name in CONTROLS:
            pb = rig.pose.bones[name]
            for prop in ('location', 'rotation_euler', 'scale'):
                pb.keyframe_insert(prop, frame=frame, group=name)
    for curve in curves(action):
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
        curve.modifiers.new('CYCLES')
    action.use_frame_range = True
    action.frame_start, action.frame_end = 1, n
    action.use_cyclic = True

# Packed originals stay available; relative external files also resolve in this copy.
for expression in ('neutral', 'blink'):
    old = bpy.data.images['PS056 Face - ' + expression]
    name = old.name
    img = bpy.data.images.load(str(HERE.parent / 'squircle-3d' / 'textures' / (expression + '.png')), check_existing=False)
    old.user_remap(img)
    bpy.data.images.remove(old)
    img.name = name
    img.use_fake_user = True
    img.pack()
activate_clip(scene, 'idle')
scene.camera = bpy.data.objects['Camera.ThreeQuarter']
scene.timeline_markers.clear()
scene.timeline_markers.new('Idle: 1-48 | Walk: 1-24 | Run: 1-16', frame=1)
rig['How to switch'] = 'Select this rig; Dope Sheet > Action Editor; choose PS057 Idle/Walk/Run. Set end 48/24/16.'
rig['Rig type'] = 'Five rigid independent bones drive original pivots; geometry is unchanged.'
for area in bpy.context.screen.areas:
    if area.type == 'PROPERTIES':
        area.spaces.active.context = 'OBJECT'
    if area.type == 'VIEW_3D':
        area.spaces.active.overlay.show_overlays = False
guide = bpy.data.texts.new('START HERE - PS057 Animation and export')
guide.write('Select Animation.Controls. In Dope Sheet > Action Editor choose PS057 | Idle, Walk or Run.\n'
            'Timeline end: Idle 48, Walk 24, Run 16; all 24 fps. Final seam key at N+1 is not exported.\n'
            'Pose Mode: Body, Hand.L/R and Foot.L/R are independent rigid controls.\n'
            'README.md beside this blend describes export layers and review. Motion awaits owner approval.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'squircle-animated.blend'))
print('PS057_SAVED', bpy.data.filepath)
