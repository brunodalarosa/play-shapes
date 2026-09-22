"""GIMP-only review composition; run after extract_bubbles_gimp.py.

Review graphics are not gameplay implementation. Generated scenery overlays
are runtime art; review PNGs and layered XCF stay under excluded art/.
"""
import math


def canvas(width, height, color=None):
    image = Gimp.Image.new(width, height, Gimp.ImageBaseType.RGB)
    layer = Gimp.Layer.new(image, 'Background', width, height, Gimp.ImageType.RGBA_IMAGE, 100, Gimp.LayerMode.NORMAL)
    image.insert_layer(layer, None, 0)
    if color:
        Gimp.context_set_foreground(Gegl.Color.new(color))
        layer.fill(Gimp.FillType.FOREGROUND)
    else:
        layer.fill(Gimp.FillType.TRANSPARENT)
    return image


def place(image, relative, x, y, width=None, opacity=100, angle=0, white=False):
    path = OUT/relative
    if relative.startswith('../../shape_characters/'):
        path = ROOT/'test-results/ps-036-038/gimp-shapes'/relative.removeprefix('../../shape_characters/')
    layer = Gimp.file_load_layer(Gimp.RunMode.NONINTERACTIVE, image, Gio.File.new_for_path(str(path)))
    image.insert_layer(layer, None, 0)
    if white:
        w, h = layer.get_width(), layer.get_height()
        rect = Gegl.Rectangle.new(0,0,w,h)
        buffer = layer.get_buffer()
        pixels = bytearray(buffer.get(rect,1.0,"R'G'B'A u8",Gegl.AbyssPolicy.NONE))
        for i in range(0,len(pixels),4):
            pixels[i:i+3] = b'\xff\xff\xff'
        buffer.set(rect,"R'G'B'A u8",bytes(pixels))
        buffer.flush()
        layer.update(0,0,w,h)
    if width:
        layer.scale(width, round(layer.get_height()*width/layer.get_width()), False)
    layer.set_offsets(x,y)
    layer.set_opacity(opacity)
    if angle:
        layer.transform_rotate(math.radians(angle), True, 0, 0)
    return layer


def label(image, text, x, y, size=22, color='#ffffff'):
    layer = Gimp.TextLayer.new(image, text, Gimp.Font.get_by_name('Sans-serif'), size, Gimp.Unit.pixel())
    image.insert_layer(layer,None,0)
    layer.set_color(Gegl.Color.new(color))
    layer.set_offsets(x,y)
    return layer


def ellipse(image, x, y, w, h, color, opacity=100, ring=0):
    layer = Gimp.Layer.new(image,'Review bubble',image.get_width(),image.get_height(),Gimp.ImageType.RGBA_IMAGE,opacity,Gimp.LayerMode.NORMAL)
    image.insert_layer(layer,None,0)
    layer.fill(Gimp.FillType.TRANSPARENT)
    image.select_ellipse(Gimp.ChannelOps.REPLACE,x,y,w,h)
    if ring:
        image.select_ellipse(Gimp.ChannelOps.SUBTRACT,x+ring,y+ring,w-2*ring,h-2*ring)
    Gimp.context_set_foreground(Gegl.Color.new(color))
    layer.edit_fill(Gimp.FillType.FOREGROUND)
    Gimp.Selection.none(image)
    return layer


def shape_character(image,cx,cy,scale=1.0):
    # Existing production artwork, unchanged, for a representative player.
    base = '../../shape_characters/'
    for part,x,y,width in [
        ('bodies/circle.png',-25,-25,50),
        ('faces/neutral.png',-16,-15,32),
        ('hands/open.png',-40,7,16),('hands/open.png',25,7,16),
        ('feet/round.png',-26,29,22),('feet/round.png',5,29,22),
    ]:
        place(image,base+part,cx+round(x*scale),cy+round(y*scale),round(width*scale))


def build_overlays():
    # Open center, isolated edge accents; no sand strip or continuous floor.
    layouts = {
        'midground': [
            ('reef_shelf',-95,950,410,62), ('reef_shelf',1650,945,370,62),
            ('sea_plant',-80,810,240,55), ('sponge_purple',1830,855,210,55),
        ],
        'foreground': [
            ('kelp',-95,872,205,85), ('coral_red',1770,960,220,85),
            ('hanging_reef',-65,-128,240,75), ('hanging_reef',1760,-138,230,75),
            ('shell_starfish',1620,1040,145,80),
        ],
    }
    for name, placements in layouts.items():
        image = canvas(1920,1080)
        for sprite,x,y,width,opacity in placements:
            place(image,'environment/'+sprite+'.png',x,y,width,opacity)
        export_png(image,OUT/('environment/'+name+'.png'))
        image.delete()
    manifest = json.loads((ART/'extraction_manifest.json').read_text())
    manifest['compositions'] = layouts
    overlay_paths = {'environment/'+name+'.png' for name in layouts}
    manifest['assets'] = [a for a in manifest['assets'] if a['path'] not in overlay_paths]
    for name in layouts:
        path = OUT/('environment/'+name+'.png')
        manifest['assets'].append({'path': 'environment/'+name+'.png','size':[1920,1080],
                                  'sha256':sha256(path.read_bytes()).hexdigest()})
    (ART/'extraction_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')


def contact_sheet():
    image = canvas(1440,1400,'#132d42')
    label(image,'Extracted paper art / native pixels / GIMP alpha cleanup',28,22,30)
    for index, (name, _) in enumerate(REGIONS):
        x,y = 25+(index%4)*355, 92+(index//4)*320
        place(image,name+'.png',x,y)
        label(image,name.split('/')[-1],x,y+266,20)
    export_png(image,ART/'sprite-contact-sheet.png')
    image.delete()


def arena_review():
    image = canvas(1920,1080)
    place(image,'environment/far_background.png',0,0)
    place(image,'environment/midground.png',0,0)
    place(image,'environment/foreground.png',0,0)
    export_png(image,ART/'environment-review-fhd.png')
    label(image,'10-player readability study / static art review',35,24,25)
    label(image,'3',925,35,100)
    colors = ['#ff6b81','#ffd15c','#65eb9a','#77ccff','#c89cff',
              '#ffa65d','#68ece0','#ef93ee','#d8f17a','#f8f4d8']
    centers = [(300,285),(620,280),(980,325),(1350,285),(1680,315),
               (260,695),(590,730),(960,725),(1320,700),(1670,750)]
    for i, ((cx,cy),color) in enumerate(zip(centers,colors)):
        diameter = [164,190,220,185,210][i%5]
        ellipse(image,cx-diameter//2,cy-diameter//2,diameter,diameter,color,13)
        ellipse(image,cx-diameter//2,cy-diameter//2,diameter,diameter,color,100,3)
        shape_character(image,cx,cy)
        for j in range(5):
            a = math.radians(30+j*65)
            px,py = cx+int(math.cos(a)*diameter*.29)-10,cy+int(math.sin(a)*diameter*.29)-13
            place(image,'jellyfish/jellyfish.png',px,py,22)
        label(image,'Player '+str(i+1),cx-53,cy+diameter//2+8,24)
    for x,y in [(430,420),(790,510),(1150,440),(1450,520),(380,860),(1110,860)]:
        place(image,'jellyfish/jellyfish.png',x,y,50)
    for x,y,width,angle in [(50,440,132,0),(650,870,145,-35),(1540,460,145,35),(1100,115,132,90)]:
        place(image,'pufferfish/pufferfish_left.png',x,y,width,100,angle)
    label(image,'> >',13,400,32,'#fff3af')
    label(image,'Sizes and cap are review samples, not gameplay tuning.',35,1030,23)
    export_png(image,ART/'arena-review-10-players-fhd.png')
    Gimp.file_save(Gimp.RunMode.NONINTERACTIVE,image,Gio.File.new_for_path(str(ART/'arena-review.xcf')))
    Gimp.Display.new(image)
    return image


def size_review():
    image = canvas(1440,900,'#edf3f4')
    label(image,'Creature scale, blink and direction review',30,25,32,'#132d42')
    for i,width in enumerate([22,32,50,72]):
        x=35+i*135
        place(image,'jellyfish/jellyfish.png',x,130,width)
        label(image,str(width)+' px wide',x,240,18,'#132d42')
    label(image,'White blink preserves the same alpha silhouette',30,315,22,'#132d42')
    for i,width in enumerate([22,32,50,72]):
        x=35+i*135
        ellipse(image,x-8,365,100,112,'#18536d')
        place(image,'jellyfish/jellyfish.png',x+8,377,width,white=True)
    label(image,'Pufferfish / 110 px wide / cardinal and diagonal travel',30,525,22,'#132d42')
    for i,angle in enumerate([0,-45,45,90,180]):
        place(image,'pufferfish/pufferfish_left.png',40+i*155,610,110,angle=angle)
    place(image,'pufferfish/pufferfish_right.png',810,610,110)
    label(image,'Portrait phone study / five visible collectibles',930,90,19,'#132d42')
    ellipse(image,997,230,320,320,'#18536d')
    ellipse(image,997,230,320,320,'#7cd5f0',100,4)
    shape_character(image,1157,380,1.4)
    label(image,'5',1144,160,42,'#132d42')
    for i in range(5):
        a=math.radians(20+i*70)
        place(image,'jellyfish/jellyfish.png',1143+int(math.cos(a)*104),375+int(math.sin(a)*104),28)
    label(image,'Static review only; no phone runtime is implemented.',30,842,21,'#132d42')
    export_png(image,ART/'creature-size-review.png')
    image.delete()


def compose_all():
    Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
    build_overlays()
    contact_sheet()
    size_review()
    arena_review()
    Gimp.displays_flush()
    print('Exported 3 environment layers, sprite contact sheet, creature review and layered FHD study.')
