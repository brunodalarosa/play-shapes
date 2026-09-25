import bpy, json
scene=bpy.context.scene
print('SCENE',scene.name,'camera',scene.camera.name if scene.camera else None)
for o in bpy.data.objects:
    print('OBJECT',o.name,'TYPE',o.type,'PARENT',o.parent.name if o.parent else None,'LOC',tuple(round(x,4) for x in o.location))
