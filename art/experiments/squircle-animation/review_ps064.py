"""Build review media and publish the approved Squircle v1 runtime sheets.

Run after export_frames.py and make_previews.py. Optional walk-open-ps064 export
is generated with --clips walk --hand-curl 0 --output walk-open-ps064.
"""
from pathlib import Path
import json, hashlib, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = Path(__file__).resolve().parent
PRE = HERE/'previews'
BEFORE = HERE/'before-inward-ps064/previews'
ROOT = HERE.parents[2]
OUT = ROOT/'assets/runtime/animated_characters/squircle/v1'
OUT.mkdir(parents=True,exist_ok=True)
manifest = json.loads((HERE/'export/manifest.json').read_text())

timing = [round((i+1)*100/24)*10-round(i*100/24)*10 for i in range(48)]

def frame(folder, action, view, tick):
    count = {'idle':48,'walk':24,'run':16}[action]
    return Image.open(folder/'frames'/action/view/f'{tick%count+1:04d}.png').convert('RGBA')

def animate(name, size, sources):
    font = ImageFont.truetype('DejaVuSans.ttf',12 if size==128 else 16)
    boards=[]
    for tick in range(48):
        board=Image.new('RGBA',(4*(size+20)+20,2*(size+40)+65),(26,33,47,255))
        draw=ImageDraw.Draw(board)
        draw.text((20,12),f'PS-064 / {name} / {size} px canvases / approval pending',font=font,fill='white')
        for row, view in enumerate(('front','three-quarter')):
            for col,(label,read_frame) in enumerate(sources):
                x,y=20+col*(size+20),48+row*(size+40)
                board.alpha_composite(read_frame(view,tick).resize((size,size),Image.Resampling.LANCZOS),(x,y))
                draw.text((x,y+size+3),label+' / '+('front' if row==0 else '35°'),font=font,fill='white')
        boards.append(board.convert('RGB'))
    boards[0].save(PRE/f'{name}-{size}.gif',save_all=True,append_images=boards[1:],duration=timing,loop=0,optimize=False)
    boards[5].save(PRE/f'{name}-{size}.png')

for size in (256,128):
    animate('before-after',size,[(f'{era} {action}',lambda v,t,p=p,a=action:frame(p,a,v,t))
        for action in ('idle','run') for era,p in [('Before',BEFORE),('After',PRE)]])

alternative=HERE/'walk-open-ps064'
if (alternative/'manifest.json').exists():
    alt=json.loads((alternative/'manifest.json').read_text())
    cache={}
    tex=Image.open(alternative/'expressions/neutral.png').convert('RGBA')
    for clip in alt['clips']:
        sequence=[]
        for record in clip['sequence']:
            p0,p1,p2=np.asarray(record['face_corners_px'])
            inverse=np.linalg.inv(np.column_stack(((p1-p0)/tex.width,(p2-p0)/tex.height)))
            offset=-inverse@p0
            face=tex.transform((256,256),Image.Transform.AFFINE,(*inverse[0],offset[0],*inverse[1],offset[1]),Image.Resampling.BICUBIC)
            pixels=np.array(face)
            mask=np.array(Image.open(alternative/record['face_mask']))[:,:,3]
            pixels[:,:,3]=np.rint(pixels[:,:,3].astype(float)*mask/255).astype(np.uint8)
            sequence.append(Image.alpha_composite(Image.open(alternative/record['colorable']).convert('RGBA'),Image.fromarray(pixels)))
        cache[clip['view']]=sequence
    for size in (128,256):
        animate('walk-options',size,[('Before walk',lambda v,t:frame(BEFORE,'walk',v,t)),
            ('Relaxed open',lambda v,t:cache[v][t%24]),
            ('Curled 35%',lambda v,t:frame(PRE,'walk',v,t)),
            ('Run fist',lambda v,t:frame(PRE,'run',v,t))])

hashes={}
for clip in manifest['clips']:
    for layer in ('colorable','neutral','blink'):
        name=f'{clip["name"]}-{clip["view"]}-{layer}.png'
        shutil.copyfile(PRE/name,OUT/name)
        hashes[name]=hashlib.sha256((OUT/name).read_bytes()).hexdigest()
clip_manifest={'schema':'play-shapes.squircle-animation.v1',
               'source':'art/experiments/squircle-animation/squircle-animated.blend',
               'source_sha256':manifest['source_sha256'],
               'resolution':[256,256], 'shape_id':'squircle',
               'clips':[{'name':clip['name'], 'view':clip['view'], 'frames':clip['frames'],
                         'fps':clip['fps'], 'anchor_px':clip['anchor_px'],
                         'sheet_columns':8, 'first_frame':1, 'last_frame':clip['frames']}
                        for clip in manifest['clips']]}
(OUT/'manifest.json').write_text(json.dumps(clip_manifest,indent=2)+'\n',encoding='utf-8')
record={'source_sha256':manifest['source_sha256'],'sheets':hashes,
        'runtime_directory':'assets/runtime/animated_characters/squircle/v1',
        'note':'Approved Squircle v1 sheets are shared by the Playground lobby and F12 preview.'}
(HERE/'ps064-runtime-sync.json').write_text(json.dumps(record,indent=2)+'\n')
print('Squircle v1: 18 Godot sheets, manifest, and review media updated.')

if all((PRE/f'hand-detail-{pose}.png').exists() for pose in ('open','closed')):
    board=Image.new('RGBA',(1024,560),(26,33,47,255))
    draw=ImageDraw.Draw(board)
    font=ImageFont.truetype('DejaVuSans.ttf',20)
    for i,pose in enumerate(('open','closed')):
        board.alpha_composite(Image.open(PRE/f'hand-detail-{pose}.png').convert('RGBA'),(i*512,40))
        draw.text((i*512+20,12),f'PS064 / {pose} / original toy glove',font=font,fill='white')
    board.save(PRE/'hand-detail.png')
