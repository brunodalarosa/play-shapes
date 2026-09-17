from __future__ import annotations

import copy
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/assets/runtime_asset_pipeline.py"
SPEC = importlib.util.spec_from_file_location("runtime_asset_pipeline", MODULE_PATH)
assert SPEC and SPEC.loader
PIPELINE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PIPELINE)


class RuntimeAssetPipelineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest_path = ROOT / "assets/runtime/shape_characters/manifest.json"
        self.manifest = PIPELINE._load_manifest(self.manifest_path)

    def test_current_manifest_and_runtime_boundary_are_valid(self) -> None:
        PIPELINE.check(ROOT, self.manifest_path)

    def test_duplicate_runtime_name_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["assets"][1]["name"] = manifest["assets"][0]["name"]
        with self.assertRaisesRegex(PIPELINE.PipelineError, "duplicate runtime name"):
            PIPELINE._validated_entries(ROOT, manifest)

    def test_unsupported_tint_policy_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["assets"][0]["tint_policy"] = "baked_color"
        with self.assertRaisesRegex(PIPELINE.PipelineError, "unsupported tint policy"):
            PIPELINE._validated_entries(ROOT, manifest)

    def test_missing_provenance_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        del manifest["assets"][0]["provenance"]["license"]
        with self.assertRaisesRegex(PIPELINE.PipelineError, "provenance requires"):
            PIPELINE._validated_entries(ROOT, manifest)

    def test_representative_sprite_intake_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture_root = Path(temporary)
            source = fixture_root / "source/example.png"
            source.parent.mkdir(parents=True)
            shutil.copy2(ROOT / "assets/Kenney_Shape_Characters/PNG/Double/blue_hand_open.png", source)
            manifest = {
                "schema_version": 1,
                "runtime_root": "assets/runtime/shape_characters",
                "archive_roots": ["source"],
                "import_policy": self.manifest["import_policy"],
                "assets": [
                    {
                        "name": "representative_hand",
                        "runtime_path": "hands/representative.png",
                        "source_path": "source/example.png",
                        "role": "hand",
                        "tint_policy": "player_tint",
                        "canonical_resolution": "Double",
                        "behavior": "copy",
                        "provenance": {"creator": "test", "license": "test", "source": "temporary fixture"},
                        "mirror": "horizontal",
                        "dimensions": [68, 76],
                    }
                ],
            }
            manifest_path = fixture_root / "assets/runtime/shape_characters/manifest.json"
            manifest_path.parent.mkdir(parents=True)
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            PIPELINE.sync(fixture_root, manifest_path)
            output = fixture_root / "assets/runtime/shape_characters/hands/representative.png"
            first_bytes = output.read_bytes()
            PIPELINE.sync(fixture_root, manifest_path)
            self.assertEqual(first_bytes, output.read_bytes())


if __name__ == "__main__":
    unittest.main()
