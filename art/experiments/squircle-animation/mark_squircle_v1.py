"""Record owner approval in the editable Squircle v1 Blender source.

This only updates descriptive metadata. Geometry, actions, cameras and textures
remain as approved. Run once on squircle-animated.blend before the v1 export.
"""
from pathlib import Path
import bpy

here = Path(__file__).resolve().parent
scene = bpy.data.scenes['PS057 | Squircle Animation Studio']
assert scene.get('PS064 inward palms applied', False)
assert scene.get('Play Shapes character version') != 'Squircle v1', 'Already marked v1'
scene['Play Shapes character version'] = 'Squircle v1'
scene['Hand revision'] = 'Owner-approved inward palms, lowered wrists; idle, walk and run canonical v1.'
guide = bpy.data.texts.get('START HERE - PS064 Hands')
if guide:
    guide.clear()
    guide.write(
        'PLAY SHAPES SQUIRCLE V1 - OWNER APPROVED\n'
        'Select PS057 | Idle / Walk / Run on Animation.Controls.\n'
        'Hand curl: 0 idle, .35 walk, 1 run; native Closed fist shape keys follow the rig.\n'
        'Actions loop at 48 / 24 / 16 frames at 24 fps. Frame N+1 repeats frame 1.\n'
        'The palms face inward and wrist height is lowered 0.14 m.\n'
        'Render via export_frames.py, make_previews.py, then review_ps064.py.\n'
        'Previous iterations are archived in before-ps064/ and before-inward-ps064/.\n'
    )
bpy.ops.wm.save_as_mainfile(filepath=str(here/'squircle-animated.blend'))
