"""Render the saved spherical hand for current design review; never save."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from animation_common import activate_clip
scene=bpy.data.scenes['Squircle Animation Studio']
bpy.context.window.scene=scene
hand=bpy.data.objects['Hand.R']
for obj in scene.objects:
    if obj.type=='MESH':obj.hide_render=obj!=hand
data=bpy.data.cameras.new('Hand detail camera')
camera=bpy.data.objects.new('Hand detail camera',data)
scene.collection.objects.link(camera)
data.type='ORTHO';data.ortho_scale=1.2
scene.camera=camera
scene.render.resolution_x=scene.render.resolution_y=512
scene.render.resolution_percentage=100
scene.cycles.samples=48
scene.render.film_transparent=True
activate_clip(scene,'idle')
bpy.context.view_layer.update()
center=hand.matrix_world.translation
camera.location=hand.matrix_world@Vector((.7,-3,.95))
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(HERE/'previews'/'hand-detail-sphere.png')
bpy.ops.render.render(write_still=True)
