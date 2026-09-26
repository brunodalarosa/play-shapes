"""Render the revised glove silhouette from above, without saving scene changes."""
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
scene=bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene=scene
scene.frame_set(1)
bpy.context.view_layer.update()
hand=bpy.data.objects['Hand.R']
for obj in scene.objects:
    if obj.type=='MESH':obj.hide_render=obj!=hand
center=hand.matrix_world@Vector((0,0,.25))
data=bpy.data.cameras.new('Hand detail camera')
camera=bpy.data.objects.new('Hand detail camera',data)
scene.collection.objects.link(camera)
camera.location=center+Vector((.15,-.8,4))
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=1.25
scene.camera=camera
scene.render.resolution_x=scene.render.resolution_y=512
scene.render.resolution_percentage=100
scene.cycles.samples=48
scene.render.film_transparent=True
scene.render.filepath=str(HERE/'previews'/'hand-detail.png')
bpy.ops.render.render(write_still=True)
