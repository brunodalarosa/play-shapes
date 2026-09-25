"""Pack derived sheets, expression layers and owner review images. Python + Pillow + NumPy."""
from pathlib import Path
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
EXPORT = HERE / 'export'
OUT = HERE / 'previews'
OUT.mkdir(exist_ok=True)
manifest = json.loads((EXPORT/'manifest.json').read_text())
PALETTE = {'Red':'E53935','Orange':'F57C00','Golden Yellow':'FBC02D','Green':'43A047',
           'Cyan':'00ACC1','Blue':'1E88E5','Indigo':'3949AB','Purple':'8E24AA','Pink':'EC407A','Brown':'8D6E63'}
BG = (26,33,47,255)
PANEL = (37,48,65,255)


def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', size)


def tint(source, hex_color):
    """Display-space blue-basis tint; preserves source highlights and shared part shading.

    This is a stylized palette transfer, not ten separate physically accurate renders.
    Blue is the exact saved render. Neutral highlight is inferred from red/blue spread.
    """
    pixels = np.asarray(source).astype(np.float32)/255
    target = np.array([int(hex_color[i:i+2],16)/255 for i in (0,2,4)])
    blue = np.array([30,136,229])/255
    diffuse = np.clip((pixels[:,:,2]-pixels[:,:,0])/(blue[2]-blue[0]),0,1.4)
    pixels[:,:,:3] = np.clip(pixels[:,:,:3] + diffuse[:,:,None]*(target-blue),0,1)
    return Image.fromarray(np.rint(pixels*255).astype(np.uint8))


def face_layer(record, expression):
    texture = Image.open(EXPORT/'expressions'/f'{expression}.png').convert('RGBA')
    p0,p1,p2 = np.asarray(record['face_corners_px'])
    mat = np.column_stack(((p1-p0)/texture.width, (p2-p0)/texture.height))
    inverse = np.linalg.inv(mat)
    offset = -inverse @ p0
    coefficients = (*inverse[0],offset[0],*inverse[1],offset[1])
    projected = texture.transform((256,256),Image.Transform.AFFINE,coefficients,Image.Resampling.BICUBIC)
    pixels = np.array(projected)
    mask = np.array(Image.open(EXPORT/record['face_mask']).convert('RGBA'))[:,:,3]
    pixels[:,:,3] = np.rint(pixels[:,:,3].astype(float)*mask/255).astype(np.uint8)
    return Image.fromarray(pixels)


def sheet(images):
    result = Image.new('RGBA',(256*8,256*math.ceil(len(images)/8)))
    for i,img in enumerate(images):
        result.paste(img,((i%8)*256,(i//8)*256))
    return result


clips = {}
sheet_index = []
for clip in manifest['clips']:
    key = clip['name']+'-'+clip['view']
    frames, bases, masks, neutrals, blinks = [], [], [], [], []
    for record in clip['sequence']:
        base = Image.open(EXPORT/record['colorable']).convert('RGBA')
        neutral, blink = (face_layer(record,e) for e in ('neutral','blink'))
        composite = Image.alpha_composite(base, neutral)
        frames.append(composite)
        bases.append(base)
        masks.append(Image.open(EXPORT/record['face_mask']).convert('RGBA'))
        neutrals.append(neutral)
        blinks.append(blink)
        path = OUT/'frames'/clip['name']/clip['view']
        path.mkdir(parents=True,exist_ok=True)
        composite.save(path/f'{record["frame"]:04d}.png')
    clips[key] = {'spec':clip,'frames':frames,'bases':bases,'neutral':neutrals,'blink':blinks}
    for layer, images in [('beauty',frames),('colorable',bases),('face-mask',masks),('neutral',neutrals),('blink',blinks)]:
        sheet(images).save(OUT/f'{key}-{layer}.png')
    duration = [round((i+1)*1000/24)-round(i*1000/24) for i in range(len(frames))]
    frames[0].save(OUT/f'{key}.png',save_all=True,append_images=frames[1:],duration=duration,loop=0,disposal=0,blend=0)
    sheet_index.append({'clip':clip['name'],'view':clip['view'],'columns':8,'tile':[256,256],
                        'frames':len(frames),'fps':24,'anchor_px':clip['anchor_px'],
                        'files':{layer:f'{key}-{layer}.png' for layer in ['beauty','colorable','face-mask','neutral','blink']},
                        'rects':[{'frame':i+1,'x':i%8*256,'y':i//8*256,'w':256,'h':256} for i in range(len(frames))]})
(OUT/'sheets.json').write_text(json.dumps(sheet_index,indent=2)+'\n')

# A 2-second, six-panel loop. Two sizes are supplied as real pixels, not screenshots.
for size in (128,256):
    gap, header = 24, 64
    width, height = 3*(size+gap)+gap, 2*(size+44)+header+gap
    boards = []
    for tick in range(48):
        board = Image.new('RGBA',(width,height),BG)
        draw = ImageDraw.Draw(board)
        draw.text((gap,14),f'SQUIRCLE / MOTION STUDY  ·  {size} px',font=font(20),fill='white')
        for row, view in enumerate(('front','three-quarter')):
            for col, action in enumerate(('idle','walk','run')):
                item = clips[action+'-'+view]
                frame = tick % len(item['frames'])
                x,y = gap+col*(size+gap), header+row*(size+44)
                draw.rounded_rectangle((x,y,x+size,y+size),radius=12,fill=PANEL)
                sprite = item['frames'][frame]
                # A brief optional blink once per review cycle, independent of action.
                if tick in (35,36,37):
                    sprite = Image.alpha_composite(item['bases'][frame],item['blink'][frame])
                board.alpha_composite(sprite.resize((size,size),Image.Resampling.LANCZOS),(x,y))
                draw.text((x,y+size+6),action.title()+' / '+('front' if row==0 else '35°'),font=font(14),fill=(202,217,239))
        boards.append(board.convert('RGB'))
    durations = [round((i+1)*100/24)*10-round(i*100/24)*10 for i in range(48)]
    boards[0].save(OUT/f'motion-review-{size}.gif',save_all=True,append_images=boards[1:],duration=durations,loop=0,optimize=False)
    if size==256:
        boards[4].save(OUT/'review-sheet.png')

# All ten colors from one base frame, each in neutral and blink expressions.
board = Image.new('RGBA',(1000,570),BG)
draw = ImageDraw.Draw(board)
draw.text((22,14),'ONE RENDER / TEN PLAYER COLORS',font=font(24),fill='white')
draw.text((22,49),'Neutral and blink use the same face placement and occlusion mask.',font=font(16),fill=(190,208,232))
item = clips['run-three-quarter']
sample = 12
for i,(name,color) in enumerate(PALETTE.items()):
    x,y = (i%5)*200,90+(i//5)*235
    base=tint(item['bases'][sample],color)
    for j,expression in enumerate(('neutral','blink')):
        result=Image.alpha_composite(base,item[expression][sample]).resize((128,128),Image.Resampling.LANCZOS)
        board.alpha_composite(result,(x+36,y+j*86))
    draw.text((x+20,y+205),name,font=font(16),fill='white')
board.save(OUT/'palette-and-blink.png')

# Explicit hand/face occlusion proof at the most occluded face rectangle.
best = None
for key,item in clips.items():
    if not key.startswith('run'):
        continue
    for i,record in enumerate(item['spec']['sequence']):
        p0,p1,p2=np.asarray(record['face_corners_px'])
        area=abs(np.linalg.det(np.column_stack((p1-p0,p2-p0))))
        mask=np.array(Image.open(EXPORT/record['face_mask']).convert('RGBA'))[:,:,3]/255
        loss=1-mask.sum()/area
        if best is None or loss>best[0]: best=(loss,key,i)
loss,key,i=best
item=clips[key]
proof=Image.new('RGBA',(1024,320),BG)
d=ImageDraw.Draw(proof)
for j,(label,img) in enumerate([('Colorable',item['bases'][i]),('Face visibility mask',Image.open(EXPORT/item['spec']['sequence'][i]['face_mask']).convert('RGBA')),('Untinted expression',item['neutral'][i]),('Composite',item['frames'][i])]):
    proof.alpha_composite(img,(j*256,35))
    d.text((j*256+12,9),label,font=font(17),fill='white')
d.text((12,295),f'{key} / frame {i+1} / face rectangle occluded {loss:.1%}',font=font(15),fill='white')
proof.save(OUT/'occlusion-proof.png')
(OUT/'occlusion-proof.json').write_text(json.dumps({'clip':key,'frame':i+1,'face_rectangle_occlusion_fraction':loss},indent=2)+'\n')
(HERE/'review-data.js').write_text('window.REVIEW_DATA = '+json.dumps({'manifest':manifest,'palette':PALETTE,'sheets':sheet_index})+';\n')
print(json.dumps({'clips':len(clips),'raw_frames':sum(len(c['frames']) for c in clips.values()),'occlusion_proof':best}))
