"""Check the saved cube, independent limbs, loop/hold poses and animated clearances."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, CONTROLS, activate_clip, action_name

LIMBS = ['Hand.L', 'Hand.R', 'Foot.L', 'Foot.R']
scene = bpy.data.scenes['Cubio Animation Studio']
bpy.context.window.scene = scene
report = {'source': 'cubio-animated.blend', 'checks': [], 'clips': {}}


def check(name, passed, detail=None):
    report['checks'].append({'name': name, 'passed': bool(passed), 'detail': detail})


def maximum_matrix_error(first, last, names):
    return max(abs(first[name][row][column] - last[name][row][column])
               for name in names for row in range(4) for column in range(4))


def controls():
    return {name: bpy.data.objects[empty].matrix_world.copy()
            for name, empty in CONTROLS.items()}


def points_and_bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    low = Vector([min(v[axis] for v in points) for axis in range(3)])
    high = Vector([max(v[axis] for v in points) for axis in range(3)])
    return points, low, high


def overlaps(first, second):
    return all(first[1][axis] < second[2][axis] - 1e-6
               and second[1][axis] < first[2][axis] - 1e-6 for axis in range(3))


def contains_limb(body, points):
    # The bevelled cube is convex: every interior point lies behind all its face planes.
    inverse = body.matrix_world.inverted()
    planes = [(polygon.center.copy(), polygon.normal.copy()) for polygon in body.data.polygons]
    return any(all(normal.dot(inverse @ point - center) < -1e-6
                   for center, normal in planes) for point in points)


rig = activate_clip(scene, 'idle')
bpy.context.view_layer.update()
body = bpy.data.objects['Body.Cubio']
check('rest body is a two metre cube', max(abs(v - 2.0) for v in body.dimensions) < 1e-6,
      list(body.dimensions))
check('small uniform bevel', scene['Body bevel m'] == 0.08)
for name in LIMBS:
    obj = bpy.data.objects[name]
    expected = (0.6, 0.6, 0.6) if name.startswith('Hand') else (0.78, 0.92, 0.39)
    check(name + ' original dimensions', max(abs(a-b) for a, b in
          zip(obj.dimensions, expected)) < 2e-6, list(obj.dimensions))
    check(name + ' applied scale', max(abs(v-1) for v in obj.scale) < 1e-6)
check('face follows the body at its front surface',
      abs(bpy.data.objects['Face.Plane - neutral artwork'].location.y + 1.015) < 1e-6)

names = ['Body.Cubio'] + LIMBS
polygons = {name: [list(p.vertices) for p in bpy.data.objects[name].data.polygons]
            for name in names}
neutral = controls()
for clip, spec in CLIPS.items():
    rig = activate_clip(scene, clip)
    bpy.context.view_layer.update()
    first = controls()
    held = spec.get('playback') == 'held'
    scene.frame_set(spec['frames'] if held else spec['frames'] + 1)
    bpy.context.view_layer.update()
    end = controls()
    if held:
        scene.frame_set(spec['frames'] + 240)
        bpy.context.view_layer.update()
    seam = maximum_matrix_error(end if held else first, controls(), CONTROLS)
    check(clip + (' sustained hold' if held else ' loop seam'), seam < 1e-6, seam)
    if held:
        check(clip + ' starts at idle neutral',
              maximum_matrix_error(neutral, first, CONTROLS) < 1e-6)
        check(clip + ' keeps both feet fixed',
              maximum_matrix_error(first, end, ['Foot.L', 'Foot.R']) < 1e-6)
        check(clip + ' has no cyclic reset', not any(
            modifier.type == 'CYCLES' for layer in rig.animation_data.action.layers
            for strip in layer.strips for bag in strip.channelbags
            for curve in bag.fcurves for modifier in curve.modifiers))
    minimum_sole = float('inf')
    intersections = []
    fixed_error = 0.0
    for sample in range(spec['frames'] * 4 + 1):
        frame = 1 + sample / 4
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        geometry = {name: points_and_bounds(bpy.data.objects[name]) for name in names}
        minimum_sole = min(minimum_sole, geometry['Foot.L'][1].z, geometry['Foot.R'][1].z)
        trees = {}
        for index, name in enumerate(names):
            for other in names[index + 1:]:
                if not overlaps(geometry[name], geometry[other]):
                    continue
                for part in (name, other):
                    if part not in trees:
                        trees[part] = BVHTree.FromPolygons(
                            geometry[part][0], polygons[part], epsilon=1e-7)
                contained = name == 'Body.Cubio' and contains_limb(body, geometry[other][0])
                if trees[name].overlap(trees[other]) or contained:
                    intersections.append({'frame': frame, 'parts': [name, other]})
        if clip == 'lever_pull':
            fixed_error = max(fixed_error, maximum_matrix_error(
                first, controls(), ['Body', 'Hand.L', 'Foot.L', 'Foot.R']))
    check(clip + ' no body or limb surface intersections', not intersections,
          intersections[:8])
    check(clip + ' soles stay above ground', minimum_sole > -1e-6, minimum_sole)
    if clip == 'lever_pull':
        check('lever pull only moves the right hand', fixed_error < 1e-6, fixed_error)
    report['clips'][clip] = {
        'frames': spec['frames'], 'fps': spec['fps'], 'playback': 'held' if held else 'loop',
        'sampled_poses': spec['frames'] * 4 + 1,
        'maximum_seam_error': seam, 'minimum_sole_z': minimum_sole,
        'surface_intersections': intersections,
    }

check('all six editable actions exist', all(action_name(clip) in bpy.data.actions for clip in CLIPS))
check('five independent controls', len(rig.pose.bones) == 5)
check('neutral and blink artwork is packed and matches editable textures', all(
    bpy.data.images['Cubio Face - ' + name].packed_file.data ==
    (HERE / 'textures' / f'{name}.png').read_bytes() for name in ('neutral', 'blink')))
check('ground anchor is fixed at the origin',
      bpy.data.objects['Character.Root - ground anchor'].location.length < 1e-8)
report['source_sha256'] = hashlib.sha256((HERE / report['source']).read_bytes()).hexdigest()
report['passed'] = all(item['passed'] for item in report['checks'])
(HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', newline='\n')
failures = [item for item in report['checks'] if not item['passed']]
print('CUBIO_ANIMATION_VALIDATION', json.dumps({'passed': report['passed'], 'failures': failures}))
if failures:
    raise RuntimeError('Cubio source validation failed')
