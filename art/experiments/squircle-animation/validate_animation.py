"""Validate saved actions, wrap poses, sole contact, and camera containment in Blender."""
from pathlib import Path
import sys
import json
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from animation_common import CLIPS, CONTROLS, PARTS, VIEWS, activate_clip
scene=bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene=scene
report={'source':'squircle-animated.blend','blender':bpy.app.version_string,'checks':[], 'clips':{},
        'approval':'Technical evidence only; owner animation-feel approval pending.'}


def check(name,condition,detail=None):
    report['checks'].append({'name':name,'passed':bool(condition),'detail':detail})


for clip,spec in CLIPS.items():
    rig=activate_clip(scene,clip)
    scene.frame_set(1);bpy.context.view_layer.update()
    first={n:bpy.data.objects[p].matrix_world.copy() for n,p in CONTROLS.items()}
    scene.frame_set(spec['frames']+1);bpy.context.view_layer.update()
    seam=max(abs(first[n][r][c]-bpy.data.objects[p].matrix_world[r][c]) for n,p in CONTROLS.items() for r in range(4) for c in range(4))
    check(clip+' seam pose',seam<1e-6,seam)
    min_z=1e9;planted_z=0;max_slip=0;min_border=1e9;min_foot_body_gap=1e9;min_palm_down=1.0
    previous={}
    for sub in range(spec['frames']*4+1):
        f=1+sub/4
        scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        deps=bpy.context.evaluated_depsgraph_get()
        for hand_name in ('Hand.L','Hand.R'):
            palm=(bpy.data.objects[hand_name].matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            min_palm_down=min(min_palm_down,-palm.z)
        body=bpy.data.objects['Body.Squircle'].evaluated_get(deps)
        body_mesh=body.to_mesh()
        body_bottom=min((body.matrix_world@v.co).z for v in body_mesh.vertices)
        body.to_mesh_clear()
        for name,offset in [('Foot.L',0),('Foot.R',.5)]:
            foot=bpy.data.objects[name].evaluated_get(deps)
            mesh=foot.to_mesh()
            sole=min((foot.matrix_world@v.co).z for v in mesh.vertices)
            foot_top=max((foot.matrix_world@v.co).z for v in mesh.vertices)
            min_foot_body_gap=min(min_foot_body_gap,body_bottom-foot_top)
            foot.to_mesh_clear()
            min_z=min(min_z,sole)
            phase=((f-1)/spec['frames']+offset)%1
            planted=clip=='idle' or phase<=spec['stance']+1e-8
            position=bpy.data.objects[CONTROLS[name]].matrix_world.translation.copy()
            position.y-=spec['speed']*(f-1)/24
            if planted:
                planted_z=max(planted_z,abs(sole))
                if name in previous:
                    old_phase,old_pos=previous[name]
                    if phase>=old_phase:
                        max_slip=max(max_slip,(position-old_pos).length)
                previous[name]=(phase,position)
            else:previous.pop(name,None)
        for view,camera in VIEWS.items():
            scene.camera=bpy.data.objects[camera]
            for name in PARTS:
                obj=bpy.data.objects[name].evaluated_get(deps)
                for corner in obj.bound_box:
                    p=world_to_camera_view(scene,scene.camera,obj.matrix_world@Vector(corner))
                    min_border=min(min_border,p.x,p.y,1-p.x,1-p.y)
    check(clip+' no sole penetration',min_z>=-1e-6,min_z)
    check(clip+' planted soles',planted_z<1e-6,planted_z)
    check(clip+' stance world travel cancels',max_slip<2e-6,max_slip)
    check(clip+' fixed-camera containment',min_border>0,min_border*256)
    check(clip+' floating foot-body gap',min_foot_body_gap>.04,min_foot_body_gap)
    check(clip+' palms remain facing ground',min_palm_down>.95,min_palm_down)
    report['clips'][clip]={'max_seam_matrix_error':seam,'minimum_sole_z':min_z,
                           'max_planted_sole_error':planted_z,'max_stance_slip_per_quarter_frame_m':max_slip,
                           'minimum_projected_bound_margin_px':min_border*256,
                           'minimum_vertical_foot_body_gap_m':min_foot_body_gap,
                           'minimum_palm_down_dot':min_palm_down}
check('three independent editable actions', all('PS057 | '+x.title() in bpy.data.actions for x in CLIPS))
check('five independently controlled parts',len(rig.pose.bones)==5)
check('packed neutral and blink textures',all(bpy.data.images['PS056 Face - '+x].packed_file for x in ('neutral','blink')))
check('root fixed at ground origin',bpy.data.objects['Character.Root - ground anchor'].location.length<1e-8)
check('optional shadow disabled',bpy.data.objects['Ground.ShadowCatcher - optional'].hide_render)
report['passed']=all(c['passed'] for c in report['checks'])
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not report['passed']:raise AssertionError('PS057 animation checks failed')
