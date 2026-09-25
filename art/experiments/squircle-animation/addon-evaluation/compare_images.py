import bpy, json, numpy as np
from pathlib import Path
root=Path(__file__).resolve().parent
pairs=[('reference-threequarter-35x9-128.png','addon-sheet-threequarter-35x9-128.png')]
out={}
for ref_name,addon_name in pairs:
    a=bpy.data.images.load(str(root/ref_name),check_existing=False)
    b=bpy.data.images.load(str(root/addon_name),check_existing=False)
    pa=np.asarray(a.pixels[:],dtype=np.float32).reshape((a.size[1],a.size[0],4))
    pb=np.asarray(b.pixels[:],dtype=np.float32).reshape((b.size[1],b.size[0],4))
    mask=(pa[:,:,3] > 0.05) & (pb[:,:,3] > 0.05)
    rgb_abs=np.abs(pa[:,:,:3]-pb[:,:,:3])
    alpha_abs=np.abs(pa[:,:,3]-pb[:,:,3])
    idx=np.unravel_index(np.argmax(np.where(mask[:,:,None],rgb_abs,-1)),rgb_abs.shape)\n    out={'reference':ref_name,'addon':addon_name,'dimensions':list(a.size),'alpha_coverage_reference_pixels':int(np.count_nonzero(pa[:,:,3]>.05)),'alpha_coverage_addon_pixels':int(np.count_nonzero(pb[:,:,3]>.05)),'mean_rgb_abs_diff_opaque':float(rgb_abs[mask].mean()) if mask.any() else None,'max_rgb_abs_diff_opaque':float(rgb_abs[mask].max()) if mask.any() else None,'max_diff_pixel_yx_channel':list(idx),'ref_rgba_at_max_diff':pa[idx[0],idx[1],:].tolist(),'addon_rgba_at_max_diff':pb[idx[0],idx[1],:].tolist(),'mean_alpha_abs_diff_all':float(alpha_abs.mean()),'reference_center_rgba':pa[64,64,:].tolist(),'addon_center_rgba':pb[64,64,:].tolist()}
    (root/'color-comparison.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
    print(json.dumps(out,indent=2))
    bpy.data.images.remove(a); bpy.data.images.remove(b)
