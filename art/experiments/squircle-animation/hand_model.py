"""Original rounded glove hands, inspired by the owner's supplied silhouette.

Local -Y is the palm normal, +Z points toward fingertips. Three thick fingers,
a side thumb, broad palm and a rolled cuff; the original toy material is shared.
"""
import math
import bpy


def ellipsoid(name, location, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def rebuild_hands():
    for name, side in [('Hand.L', -1), ('Hand.R', 1)]:
        hand = bpy.data.objects[name]
        palm=ellipsoid('Glove palm', (0,0,.16), (.265,.115,.285))
        wrist=ellipsoid('Glove wrist', (0,0,-.09), (.205,.115,.16))
        for vertex in wrist.data.vertices: vertex.co.z=max(vertex.co.z,-.10)
        pieces=[palm,wrist]
        # Broad, rounded fingers with a small relaxed curl toward the palm.
        for x, length, tilt in [(-.195,.235,-.12),(0,.275,0),(.195,.215,.13)]:
            # Capsule shafts retain thickness instead of tapering to pointed tips.
            bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=24,
                                                location=(x,-.025,.405+length*.32))
            finger=bpy.context.object
            radius=.092
            for vertex in finger.data.vertices:
                z=vertex.co.z
                vertex.co.x*=radius
                vertex.co.y*=.102
                vertex.co.z=z*radius+(math.copysign(length-radius,z) if abs(z)>1e-6 else 0)
            finger.rotation_euler = (.13,tilt,0)
            pieces.append(finger)
        thumb = ellipsoid('Glove thumb', (-.295,-.014,.18), (.13,.11,.195))
        thumb.rotation_euler[1] = -.9
        pieces.append(thumb)
        bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=16,
                                      location=(0,0,-.17),major_radius=.178,minor_radius=.041)
        cuff=bpy.context.object
        cuff.scale=(1.25,.69,1)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        pieces.append(cuff)
        for obj in bpy.context.selected_objects: obj.select_set(False)
        for obj in pieces: obj.select_set(True)
        bpy.context.view_layer.objects.active=pieces[0]
        bpy.ops.object.join()
        joined=bpy.context.object
        # Preserve all component positions in hand-local space before union.
        bpy.context.scene.cursor.location=(0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        remesh=joined.modifiers.new('Continuous rounded glove','REMESH')
        remesh.mode='VOXEL'; remesh.voxel_size=.012; remesh.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        smooth=joined.modifiers.new('Soft finger webs','SMOOTH')
        smooth.factor=.7; smooth.iterations=3
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        for vertex in joined.data.vertices:
            vertex.co.x *= side
        # Mirroring changes winding; recalculate normals on the temporary mesh.
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        material=hand.active_material
        hand.data=joined.data.copy()
        hand.data.name=name+' | Rounded glove mesh'
        hand.modifiers.clear()
        sub=hand.modifiers.new('Glove surface finish','SUBSURF')
        sub.levels=1; sub.render_levels=2
        hand.data.materials.clear(); hand.data.materials.append(material)
        for poly in hand.data.polygons: poly.use_smooth=True
        hand['Palm normal local']=[0.,-1.,0.]
        hand['Design']='Broad rounded glove; thumb + three fingers; small rolled cuff. Original geometry.'
        bpy.data.objects.remove(joined,do_unlink=True)


def pose_hands(rig, clip, theta):
    for side,name in [(-1,'Hand.L'),(1,'Hand.R')]:
        hand=rig.pose.bones[name]
        if clip=='idle':
            wave=theta+side*.65
            hand.location=(-side*.10+side*.015*math.cos(wave),-.015*math.sin(wave),.025*math.sin(wave))
            hand.rotation_euler=(math.pi/2+.14+.025*math.sin(wave),
                                 .025*side*math.cos(wave),side*.18+.025*math.sin(wave))
        else:
            running=clip=='run'
            swing=side*math.sin(theta-.18)
            # Loose wrist follow-through; no raised wave or face-reaching pose.
            hand.location=(-side*(.20 if running else .125),
                           (.37 if running else .23)*swing-.04,
                           (.11 if running else .025)-(.065 if running else .035)*swing)
            hand.rotation_euler=(math.pi/2+.14+(.065 if running else .04)*swing,
                                 side*.025+.035*math.sin(theta+.25),
                                 side*.18+(.055 if running else .035)*swing)
