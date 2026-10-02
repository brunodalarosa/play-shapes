"""Copy the current complete Squircle export into the shared runtime asset set."""
from pathlib import Path
import hashlib
import json
import shutil
from animation_common import CLIPS, VIEWS
from atomic_outputs import atomic_output

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'assets/runtime/animated_characters/squircle/v1'
manifest = json.loads((HERE / 'export/manifest.json').read_text())
source = HERE / 'squircle-animated.blend'
assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest['source_sha256'], 'Export is stale; re-export the saved source'
expected = {(name, view): spec['frames'] for name, spec in CLIPS.items() for view in VIEWS}
assert len(manifest['clips']) == len(expected), 'Sync requires the complete clip/view set'
assert {(c['name'], c['view']): c['frames'] for c in manifest['clips']} == expected, 'Incomplete clip set'
for clip in manifest['clips']:
    assert [f['frame'] for f in clip['sequence']] == list(range(1, clip['frames'] + 1)), 'Partial frame sequence'
    spec = CLIPS[clip['name']]
    assert clip['fps'] == spec['fps'] and clip.get('playback', 'loop') == spec.get('playback', 'loop'), 'Timing/playback metadata is stale'

# Check every input before replacing any runtime file.
names = [f'{c["name"]}-{c["view"]}-{layer}.png' for c in manifest['clips']
         for layer in ('colorable', 'neutral', 'blink')]
assert all((HERE / 'previews' / name).is_file() for name in names), 'Pack previews before syncing'
OUT.mkdir(parents=True, exist_ok=True)
hashes = {}
for name in names:
    with atomic_output(OUT / name) as temporary:
        shutil.copyfile(HERE / 'previews' / name, temporary)
    hashes[name] = hashlib.sha256((OUT / name).read_bytes()).hexdigest()
runtime = {
    'schema': 'play-shapes.squircle-animation.v1',
    'source': source.relative_to(ROOT).as_posix(),
    'source_sha256': manifest['source_sha256'],
    'resolution': [256, 256], 'shape_id': 'squircle',
    'clips': [{'name': c['name'], 'view': c['view'], 'frames': c['frames'],
               'fps': c['fps'], 'anchor_px': c['anchor_px'], 'sheet_columns': 8,
               'first_frame': 1, 'last_frame': c['frames'],
               'playback': c.get('playback', 'loop')} for c in manifest['clips']],
}
(OUT / 'manifest.json').write_text(json.dumps(runtime, indent=2) + '\n', encoding='utf-8')
record = {'source_sha256': manifest['source_sha256'], 'sheets': hashes,
          'runtime_directory': OUT.relative_to(ROOT).as_posix(),
          'note': 'Current sheets shared by Playground, Bubbles, Animation Lab and phones.'}
(HERE / 'runtime-sync.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(f'Squircle v1: {len(names)} shared runtime sheets and manifest updated.')
