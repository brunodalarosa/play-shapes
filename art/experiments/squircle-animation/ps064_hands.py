"""Original toy glove with editable relaxed/closed shape and rigid wrist motion.

Local +Z runs from cuff to fingers; -Y is the palm. The same topology supports
both poses, so native shape-key drivers follow the saved rig action in Blender.
"""
import math
import bpy
from mathutils import Vector, Euler, Matrix


def inward_rotation(rotation, running=False):
    """Mirror wrist yaw/roll toward the body; run swings about the inward axis."""
    x,y,z=rotation
    inward=Euler((math.pi-.13 if running else x,-y,-z),'XYZ')
    if running:
        # Swing around world X (toward the torso), rather than rotating the palm
        # away from it. Keep the original swing phase and angular amplitude.
        swing=x-(math.pi-.13)
        return (Matrix.Rotation(swing,3,'X')@inward.to_matrix()).to_euler('XYZ',inward)
    return inward


def glove_coordinates(closed):
    vertices, faces = [], []

    def lobe(center, scale, rotation=(0, 0, 0)):
        # Identical UV topology for each lobe in both shape-key endpoints.
        start = len(vertices)
        rotation = Euler(rotation).to_matrix()
        rings, segments = 20, 32
        for r in range(rings + 1):
            phi = math.pi * r / rings
            for s in range(segments):
                theta = math.tau * s / segments
                v = Vector((scale[0]*math.sin(phi)*math.cos(theta),
                            scale[1]*math.sin(phi)*math.sin(theta), scale[2]*math.cos(phi)))
                vertices.append(tuple(rotation @ v + Vector(center)))
        for r in range(rings):
            for s in range(segments):
                a = start + r*segments+s
                b = start + r*segments+(s+1)%segments
                faces.append((a, a+segments, b+segments, b))

    lobe((0, 0, .14), (.245, .145 if closed else .12, .245))
    lobe((0, 0, -.095), (.175, .105, .12))
    # Three rounded finger lobes fold into the palm, retaining knuckle scallops.
    for x, length, tilt in [(-.175,.23,-.10),(0,.26,0),(.175,.21,.10)]:
        if closed:
            lobe((x, -.12, .285 + (.025 if x == 0 else 0)), (.098, .14, .145), (.12, 0, 0))
        else:
            lobe((x, -.055, .37+length*.25), (.092, .103, length), (.40, tilt, 0))
    if closed:
        lobe((-.175, -.235, .15), (.125, .115, .205), (.12, -.95, -.16))
    else:
        lobe((-.28, -.025, .16), (.125, .105, .18), (.16, -.65, 0))
    # Rolled, softly elliptical cuff; identical in both endpoints.
    start = len(vertices)
    for i in range(48):
        a = math.tau*i/48
        for j in range(12):
            b = math.tau*j/12
            vertices.append(((.178+.038*math.cos(b))*1.15*math.cos(a),
                             (.178+.038*math.cos(b))*.68*math.sin(a), -.17+.038*math.sin(b)))
    for i in range(48):
        for j in range(12):
            faces.append((start+i*12+j, start+((i+1)%48)*12+j,
                          start+((i+1)%48)*12+(j+1)%12, start+i*12+(j+1)%12))
    return vertices, faces


def rebuild_hands(rig):
    opened, faces = glove_coordinates(False)
    closed, _ = glove_coordinates(True)
    rig['Hand curl'] = 0.0
    rig.id_properties_ui('Hand curl').update(min=0.0, max=1.0, description='0 relaxed open; 1 closed fist. Keyed by each action.')
    for name, side in [('Hand.L', -1), ('Hand.R', 1)]:
        obj = bpy.data.objects[name]
        material = obj.active_material
        mesh = bpy.data.meshes.new(name+' | PS064 editable glove')
        mesh.from_pydata([(x*side,y,z) for x,y,z in opened], [],
                         [tuple(reversed(f)) if side<0 else f for f in faces])
        mesh.update()
        obj.data = mesh
        obj.rotation_euler = (0, 0, 0)
        mesh.materials.append(material)
        obj.shape_key_add(name='Relaxed open')
        key = obj.shape_key_add(name='Closed fist')
        for v, (x,y,z) in zip(key.data, closed):
            v.co = (x*side,y,z)
        driver = key.driver_add('value').driver
        var = driver.variables.new()
        var.name = 'curl'; var.type = 'SINGLE_PROP'
        var.targets[0].id = rig; var.targets[0].data_path = '["Hand curl"]'
        driver.expression = 'curl'
        obj.modifiers.clear()
        remesh = obj.modifiers.new('Soft joined toy glove', 'REMESH')
        remesh.mode = 'VOXEL'; remesh.voxel_size = .012; remesh.use_smooth_shade = True
        smooth = obj.modifiers.new('Rounded knuckle finish', 'SMOOTH')
        smooth.factor = .65; smooth.iterations = 3
        sub = obj.modifiers.new('Toy surface finish', 'SUBSURF')
        sub.levels = sub.render_levels = 1
        obj['Design'] = 'PS064 original three-finger glove; inward relaxed curl / folded fist with crossing thumb.'


def pose_hands(rig, clip, theta):
    rig['Hand curl'] = {'idle':0.0, 'walk':.35, 'run':1.0}[clip]
    for side,name in [(-1,'Hand.L'),(1,'Hand.R')]:
        hand = rig.pose.bones[name]
        if clip == 'idle':
            wave = theta + side*.72
            hand.location = (-side*.10+side*.012*math.cos(wave), -.025+.018*math.sin(wave), .04+.022*math.sin(wave)+.006*math.sin(2*wave))
            # Authored wrist basis is corrected below to face inward.
            hand.rotation_euler = (math.pi-.13+.035*math.sin(wave), side*.12,
                                   -side*1.05+.025*math.sin(wave+.4))
        else:
            running = clip == 'run'
            # Oppose the same-side foot: front hand as that foot travels back.
            swing = side*math.cos(theta-(.375 if running else .625)*math.pi)
            hand.location = (-side*(.08 if running else .10),
                             -.06+(.67 if running else .30)*swing,
                             (.21 if running else .04)-(.23 if running else .055)*swing)
            hand.rotation_euler = (math.pi-(.65 if running else .13)+(.50 if running else .18)*swing,
                                   side*.12, -side*1.05+.08*math.sin(theta+.25))
        hand.rotation_euler=inward_rotation(hand.rotation_euler,clip=='run')
