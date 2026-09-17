#!/usr/bin/env python3
"""Sync and verify the manifest-owned runtime sprite set."""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import sys
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "assets/runtime/shape_characters/manifest.json"
ALLOWED_ROLES = {"body", "hand", "foot", "face", "environment"}
ALLOWED_TINT_POLICIES = {"player_tint", "untinted"}
ALLOWED_MIRROR_POLICIES = {"none", "allowed", "horizontal"}
ARCHIVE_REFERENCE = "assets/Kenney_Shape_Characters"
PRODUCTION_EXTENSIONS = {".gd", ".tscn", ".tres"}
IMPORT_SETTINGS = {
    "compress/mode": "0",
    "mipmaps/generate": "true",
    "process/fix_alpha_border": "true",
    "detect_3d/compress_to": "0",
}


class PipelineError(Exception):
    pass


def _load_manifest(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PipelineError(f"Cannot read manifest {path}: {error}") from error
    if data.get("schema_version") != 1:
        raise PipelineError("manifest schema_version must be 1")
    if not isinstance(data.get("assets"), list) or not data["assets"]:
        raise PipelineError("manifest assets must be a non-empty list")
    expected_policy = {
        "name": "smooth_sprite",
        "compression": "lossless",
        "mipmaps": True,
        "fix_alpha_border": True,
        "repeat": "disabled",
        "automatic_3d_compression": False,
    }
    if data.get("import_policy") != expected_policy:
        raise PipelineError("manifest import_policy must define the supported smooth_sprite settings")
    return data


def _safe_project_path(value: object, field: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        raise PipelineError(f"{field} must be a non-empty string")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "\\" in value:
        raise PipelineError(f"{field} must be a safe project-relative POSIX path: {value!r}")
    return path


def _png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if len(data) != 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise PipelineError(f"Not a supported PNG: {path}")
    return struct.unpack(">II", data[16:24])


def _validated_entries(root: Path, manifest: dict) -> tuple[Path, list[tuple[dict, Path, Path]]]:
    runtime_rel = _safe_project_path(manifest.get("runtime_root"), "runtime_root")
    runtime_root = root.joinpath(*runtime_rel.parts)
    names: set[str] = set()
    outputs: set[str] = set()
    entries: list[tuple[dict, Path, Path]] = []
    required = {"name", "runtime_path", "source_path", "role", "tint_policy", "canonical_resolution", "behavior", "provenance", "mirror", "dimensions"}

    for index, entry in enumerate(manifest["assets"]):
        if not isinstance(entry, dict):
            raise PipelineError(f"asset #{index + 1} must be an object")
        missing = sorted(required - entry.keys())
        if missing:
            raise PipelineError(f"asset #{index + 1} is missing: {', '.join(missing)}")
        name = entry["name"]
        if not isinstance(name, str) or not name:
            raise PipelineError(f"asset #{index + 1} has an invalid name")
        if name in names:
            raise PipelineError(f"duplicate runtime name: {name}")
        names.add(name)
        runtime_path = _safe_project_path(entry["runtime_path"], f"{name}.runtime_path")
        source_path = _safe_project_path(entry["source_path"], f"{name}.source_path")
        runtime_key = runtime_path.as_posix().casefold()
        if runtime_key in outputs:
            raise PipelineError(f"duplicate runtime path: {runtime_path}")
        outputs.add(runtime_key)
        if runtime_path.suffix.lower() != ".png":
            raise PipelineError(f"{name}: runtime_path must end in .png")
        if entry["role"] not in ALLOWED_ROLES:
            raise PipelineError(f"{name}: unsupported role {entry['role']!r}")
        if entry["tint_policy"] not in ALLOWED_TINT_POLICIES:
            raise PipelineError(f"{name}: unsupported tint policy {entry['tint_policy']!r}")
        if entry["mirror"] not in ALLOWED_MIRROR_POLICIES:
            raise PipelineError(f"{name}: unsupported mirror policy {entry['mirror']!r}")
        if entry["canonical_resolution"] != "Double" or entry["behavior"] != "copy":
            raise PipelineError(f"{name}: only Double-resolution copied assets are supported")
        provenance = entry["provenance"]
        if not isinstance(provenance, dict) or any(not provenance.get(key) for key in ("creator", "license", "source")):
            raise PipelineError(f"{name}: provenance requires creator, license, and source")
        dimensions = entry["dimensions"]
        if not isinstance(dimensions, list) or len(dimensions) != 2 or any(not isinstance(value, int) or value <= 0 for value in dimensions):
            raise PipelineError(f"{name}: dimensions must be two positive integers")
        source = root.joinpath(*source_path.parts)
        output = runtime_root.joinpath(*runtime_path.parts)
        if not source.is_file():
            raise PipelineError(f"{name}: missing source {source_path}")
        actual_dimensions = _png_dimensions(source)
        if actual_dimensions != tuple(dimensions):
            raise PipelineError(f"{name}: source dimensions are {actual_dimensions}, expected {tuple(dimensions)}")
        entries.append((entry, source, output))
    return runtime_root, entries


def _normalize_import_sidecar(path: Path) -> bool:
    if not path.is_file():
        return False
    text = path.read_text(encoding="utf-8")
    updated = text
    for key, expected in IMPORT_SETTINGS.items():
        lines = updated.splitlines()
        replaced = False
        for index, line in enumerate(lines):
            if line.startswith(f"{key}="):
                lines[index] = f"{key}={expected}"
                replaced = True
                break
        if not replaced:
            raise PipelineError(f"{path}: missing import setting {key}")
        updated = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    if updated != text:
        path.write_text(updated, encoding="utf-8", newline="\n")
        return True
    return False


def sync(root: Path, manifest_path: Path) -> None:
    manifest = _load_manifest(manifest_path)
    runtime_root, entries = _validated_entries(root, manifest)
    expected = {output.resolve() for _, _, output in entries}
    expected.add(manifest_path.resolve())
    if runtime_root.exists():
        unexpected = [path for path in runtime_root.rglob("*") if path.is_file() and path.resolve() not in expected and not (path.name.endswith(".png.import") and path.with_suffix("").resolve() in expected)]
        if unexpected:
            shown = ", ".join(str(path.relative_to(root)).replace("\\", "/") for path in unexpected[:8])
            raise PipelineError(f"unexpected runtime output files: {shown}")
    copied = 0
    import_updates = 0
    for _, source, output in entries:
        output.parent.mkdir(parents=True, exist_ok=True)
        if not output.exists() or output.read_bytes() != source.read_bytes():
            shutil.copy2(source, output)
            copied += 1
        if _normalize_import_sidecar(Path(f"{output}.import")):
            import_updates += 1
    print(f"Runtime asset sync complete: {len(entries)} assets, {copied} copied, {import_updates} import sidecars updated.")
    if any(not Path(f"{output}.import").exists() for _, _, output in entries):
        print("Godot still needs to import new PNGs; run the editor import, then sync and check again.")


def _check_import_sidecar(path: Path) -> None:
    if not path.is_file():
        raise PipelineError(f"missing Godot import sidecar: {path}")
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    for key, expected in IMPORT_SETTINGS.items():
        if values.get(key) != expected:
            raise PipelineError(f"{path}: {key} must be {expected}, found {values.get(key)!r}")


def _check_forbidden_references(root: Path) -> None:
    violations: list[str] = []
    ignored_roots = {".git", ".godot", "test-results", "art", "tools"}
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in PRODUCTION_EXTENSIONS:
            continue
        relative = path.relative_to(root)
        if relative.parts and relative.parts[0] in ignored_roots:
            continue
        if relative.as_posix().startswith(f"{ARCHIVE_REFERENCE}/"):
            continue
        if ARCHIVE_REFERENCE in path.read_text(encoding="utf-8"):
            violations.append(relative.as_posix())
    if violations:
        raise PipelineError("production files reference the source archive: " + ", ".join(violations))


def _check_boundary(root: Path) -> None:
    gdignore = root / ARCHIVE_REFERENCE / ".gdignore"
    if not gdignore.is_file():
        raise PipelineError(f"archive import boundary is missing: {gdignore}")
    preset = root / "export_presets.cfg"
    if not preset.is_file() or "assets/Kenney_Shape_Characters/**" not in preset.read_text(encoding="utf-8"):
        raise PipelineError("export_presets.cfg must explicitly exclude assets/Kenney_Shape_Characters/**")


def check(root: Path, manifest_path: Path) -> None:
    manifest = _load_manifest(manifest_path)
    runtime_root, entries = _validated_entries(root, manifest)
    expected = {output.resolve() for _, _, output in entries}
    expected.add(manifest_path.resolve())
    for entry, source, output in entries:
        if not output.is_file():
            raise PipelineError(f"{entry['name']}: missing runtime output {output.relative_to(root)}")
        if output.read_bytes() != source.read_bytes():
            raise PipelineError(f"{entry['name']}: runtime copy is stale")
        if _png_dimensions(output) != tuple(entry["dimensions"]):
            raise PipelineError(f"{entry['name']}: runtime dimensions do not match the manifest")
        _check_import_sidecar(Path(f"{output}.import"))
    unexpected = [path for path in runtime_root.rglob("*") if path.is_file() and path.resolve() not in expected and not (path.name.endswith(".png.import") and path.with_suffix("").resolve() in expected)]
    if unexpected:
        raise PipelineError("unexpected runtime output files: " + ", ".join(path.relative_to(root).as_posix() for path in unexpected))
    _check_forbidden_references(root)
    _check_boundary(root)
    print(f"Runtime asset check passed: {len(entries)} manifest assets are current and production uses only runtime paths.")


def check_export(root: Path, manifest_path: Path, pack: Path) -> None:
    manifest = _load_manifest(manifest_path)
    _, entries = _validated_entries(root, manifest)
    if not pack.is_file():
        raise PipelineError(f"export pack does not exist: {pack}")
    data = pack.read_bytes()
    forbidden = ARCHIVE_REFERENCE.encode("utf-8")
    if forbidden in data:
        raise PipelineError(f"export contains archival path {ARCHIVE_REFERENCE}")
    sample = f"assets/runtime/shape_characters/{entries[0][0]['runtime_path']}".encode("utf-8")
    if sample not in data:
        raise PipelineError("export does not contain the curated runtime asset set")
    print(f"Export boundary check passed: {pack.stat().st_size} bytes, runtime assets present, source archive absent.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("sync", "check", "check-export"))
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--pack", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    manifest_path = args.manifest if args.manifest.is_absolute() else (root / args.manifest)
    manifest_path = manifest_path.resolve()
    try:
        if args.command == "sync":
            sync(root, manifest_path)
        elif args.command == "check":
            check(root, manifest_path)
        else:
            if args.pack is None:
                raise PipelineError("check-export requires --pack")
            pack = args.pack if args.pack.is_absolute() else (root / args.pack)
            check_export(root, manifest_path, pack.resolve())
    except PipelineError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
