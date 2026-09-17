import hashlib
import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "assets/runtime/audio/flash_pose_audio_manifest.json"


def inspect_ogg(path: Path) -> tuple[int, int, float]:
    data = path.read_bytes()
    identification = data.index(b"\x01vorbis")
    channels = data[identification + 11]
    sample_rate = struct.unpack_from("<I", data, identification + 12)[0]
    position = 0
    final_granule = 0
    while position < len(data):
        if data[position : position + 4] != b"OggS":
            raise AssertionError(f"Invalid Ogg page at byte {position}: {path}")
        granule = struct.unpack_from("<Q", data, position + 6)[0]
        segment_count = data[position + 26]
        segment_table = data[position + 27 : position + 27 + segment_count]
        if granule != 0xFFFFFFFFFFFFFFFF:
            final_granule = max(final_granule, granule)
        position += 27 + segment_count + sum(segment_table)
    return channels, sample_rate, final_granule / sample_rate


class FlashPoseAudioMetadataTest(unittest.TestCase):
    def test_manifest_matches_supplied_ogg_files_and_imports(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(1, manifest["schema_version"])
        self.assertEqual(5, len(manifest["assets"]))
        for asset in manifest["assets"]:
            relative_path = asset["path"].removeprefix("res://")
            path = ROOT / relative_path
            self.assertTrue(path.is_file(), relative_path)
            self.assertEqual(asset["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            channels, sample_rate, duration = inspect_ogg(path)
            self.assertEqual(asset["channels"], channels)
            self.assertEqual(asset["sample_rate_hz"], sample_rate)
            self.assertAlmostEqual(asset["duration_seconds"], duration, places=5)
            import_text = path.with_suffix(path.suffix + ".import").read_text(encoding="utf-8")
            expected_loop = "true" if asset["loop"] else "false"
            self.assertIn(f"loop={expected_loop}", import_text)
            self.assertIn("loop_offset=0", import_text)


if __name__ == "__main__":
    unittest.main()
