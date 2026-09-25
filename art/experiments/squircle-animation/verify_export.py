"""Check two independently reopened exports, alpha/framing, and packed-sheet indexing."""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
original=HERE/'export'
repeat=HERE/'recheck'
a=json.loads((original/'manifest.json').read_text())
b=json.loads((repeat/'manifest.json').read_text())
assert a==b,'Fresh export changed metadata or frame ordering'
files=sorted(original.rglob('*.png'))
exact=0;max_diff=0;minimum_margin=256;unused_mask_rgb_diff=0;edge_evidence=None
for file in files:
    other=repeat/file.relative_to(original)
    assert other.exists(),other
    first=Image.open(file).convert('RGBA');second=Image.open(other).convert('RGBA')
    assert first.size==second.size
    if hashlib.sha256(file.read_bytes()).digest()==hashlib.sha256(other.read_bytes()).digest():exact+=1
    difference=np.abs(np.asarray(first).astype(int)-np.asarray(second).astype(int))
    if file.parent.name=='face-mask':
        # The contract consumes only mask alpha, and export canonicalizes RGB.
        assert np.all(np.asarray(first)[:,:,:3]==255),'Mask RGB is not canonical white'
        assert np.all(np.asarray(second)[:,:,:3]==255),'Replay mask RGB is not canonical white'
        unused_mask_rgb_diff=max(unused_mask_rgb_diff,int(difference[:,:,:3].max()))
        max_diff=max(max_diff,int(difference[:,:,3].max()))
    else:
        max_diff=max(max_diff,int(difference.max()))
    if file.parent.name=='colorable':
        assert first.size==(256,256)
        alpha=np.asarray(first)[:,:,3]
        assert alpha.min()==0 and alpha.max()==255
        if edge_evidence is None:
            pixels=np.asarray(first)
            edge=(alpha>0)&(alpha<16)
            edge_evidence={'sample':file.relative_to(original).as_posix(),
                           'edge_rgb_mean_8bit':float(pixels[:,:,:3][edge].mean()),
                           'edge_alpha_mean_8bit':float(alpha[edge].mean())}
            assert edge_evidence['edge_rgb_mean_8bit']>edge_evidence['edge_alpha_mean_8bit'], 'Unexpected premultiplied edge data'
        y,x=np.where(alpha>0)
        margin=min(x.min(),y.min(),255-x.max(),255-y.max())
        minimum_margin=min(minimum_margin,int(margin))
        assert margin>0,f'Clipped alpha at {file}'
assert max_diff<=1, f'Replay differs by {max_diff} / 255'
assert unused_mask_rgb_diff==0, 'Canonical mask RGB changed'
for clip in a['clips']:
    assert [f['frame'] for f in clip['sequence']]==list(range(1,clip['frames']+1))
    sheet=Image.open(HERE/'previews'/f'{clip["name"]}-{clip["view"]}-colorable.png').convert('RGBA')
    for i,frame in enumerate(clip['sequence']):
        tile=sheet.crop((i%8*256,i//8*256,i%8*256+256,i//8*256+256))
        raw=Image.open(original/frame['colorable']).convert('RGBA')
        assert np.array_equal(np.asarray(tile),np.asarray(raw)),'Packed frame order differs'
report={'passed':True,'metadata_identical':True,'fresh_reopen_export_files':len(files),
        'byte_identical_png_files':exact,'max_consumed_channel_difference_8bit':max_diff,
        'max_unused_mask_rgb_difference_8bit':unused_mask_rgb_diff,
        'minimum_rendered_alpha_margin_px':minimum_margin,
        'straight_alpha_edge_evidence':edge_evidence,
        'clips':len(a['clips']),'animation_frames':sum(c['frames'] for c in a['clips']),
        'packed_colorable_tiles_match_raw':True,
        'scope':'Same machine, Blender version, seed and render settings; owner motion approval separate.'}
(HERE/'export-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
