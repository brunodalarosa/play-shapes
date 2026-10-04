"""Extract the approved Tilt Shift raster masters; requires Pillow.

The build changes alpha and canvas placement, preserving visible source RGB.
Source masters live under art/ and are excluded from Godot imports and exports.
"""

import argparse
from collections import deque
from hashlib import sha256
import json
from pathlib import Path
import re

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/tilt_shift"
SOURCE = ART / "sources"
RUNTIME = ROOT / "assets/runtime/minigames/003"
PADDING = 8
POLICY = {
    "compress/mode": 0,
    "mipmaps/generate": True,
    "process/fix_alpha_border": True,
    "process/premult_alpha": False,
    "detect_3d/compress_to": 0,
}

# The measured rectangles deliberately leave room for antialiased edges.
REGIONS = [
    ("paddles/paddle_orange", "gameplay-sheet.png", (0, 0, 768, 340), "paddle"),
    ("paddles/paddle_blue", "gameplay-sheet.png", (768, 0, 1536, 340), "paddle"),
    ("paddles/paddle_neutral", "gameplay-sheet.png", (0, 340, 768, 680), "paddle"),
    ("gameplay/player_badge", "gameplay-sheet.png", (768, 340, 1536, 680), ""),
    ("gameplay/ball", "gameplay-sheet.png", (0, 680, 768, 1024), ""),
    ("gameplay/falling_marks", "gameplay-sheet.png", (768, 680, 1536, 1024), ""),
    ("baskets/orange_back", "basket-parts-sheet.png", (0, 200, 430, 530), "basket"),
    ("baskets/blue_back", "basket-parts-sheet.png", (430, 200, 825, 530), "basket"),
    ("baskets/trash_back", "basket-parts-sheet.png", (825, 200, 1254, 530), "basket"),
    ("baskets/orange_front", "basket-parts-sheet.png", (0, 570, 430, 815), "basket"),
    ("baskets/blue_front", "basket-parts-sheet.png", (430, 570, 825, 815), "basket"),
    ("baskets/trash_front", "basket-parts-sheet.png", (825, 570, 1254, 815), "basket"),
    ("baskets/trash_badge", "basket-parts-sheet.png", (450, 860, 800, 1180), ""),
    ("environment/rail_left", "factory-parts-sheet.png", (40, 30, 260, 670), ""),
    ("environment/rail_right", "factory-parts-sheet.png", (430, 30, 640, 670), ""),
    ("stations/station_base", "factory-parts-sheet.png", (660, 400, 1060, 665), ""),
    ("stations/name_plate", "factory-parts-sheet.png", (1090, 480, 1420, 670), ""),
    ("stations/lever_shaft", "factory-parts-sheet.png", (200, 695, 355, 1060), ""),
    ("stations/grip_orange", "factory-parts-sheet.png", (460, 780, 710, 1060), "grip"),
    ("stations/grip_blue", "factory-parts-sheet.png", (775, 780, 1025, 1060), "grip"),
    ("stations/pivot_socket", "factory-parts-sheet.png", (1120, 790, 1360, 1055), ""),
]

# Contact points are references on the approved art, not gameplay collision geometry.
SOURCE_ANCHORS = {
    "stations/station_base": {"socket_mount": [863, 489]},
    "stations/lever_shaft": {"rotation_pivot": [282, 987], "grip_mount": [284, 735]},
    "stations/grip_orange": {"shaft_mount": [582, 1018], "hand_contact": [582, 916]},
    "stations/grip_blue": {"shaft_mount": [905, 1018], "hand_contact": [905, 916]},
}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def clean_alpha(image, component_count=1):
    """Remove detached noise; keep two fringe pixels and opaque paper interiors."""
    width, height = image.size
    pixels = bytearray(image.tobytes())
    core = bytearray(alpha >= 128 for alpha in pixels[3::4])
    components = []

    for start in range(width * height):
        if not core[start]:
            continue

        core[start] = 0
        queue = deque([start])
        component = []

        while queue:
            pixel = queue.popleft()
            component.append(pixel)
            x, y = pixel % width, pixel // width

            for yy in range(max(0, y - 1), min(height, y + 2)):
                for xx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = yy * width + xx
                    if core[neighbor]:
                        core[neighbor] = 0
                        queue.append(neighbor)

        components.append(component)

    if len(components) < component_count:
        raise ValueError("The source region has too few opaque components")

    keep = bytearray(width * height)

    for component in sorted(components, key=len, reverse=True)[:component_count]:
        for pixel in component:
            x, y = pixel % width, pixel // width

            for yy in range(max(0, y - 2), min(height, y + 3)):
                for xx in range(max(0, x - 2), min(width, x + 3)):
                    keep[yy * width + xx] = 1

    for pixel in range(width * height):
        offset = pixel * 4
        alpha = pixels[offset + 3]
        alpha = max(0, min(255, round((alpha - 24) * 255 / 226))) if keep[pixel] else 0
        pixels[offset + 3] = alpha

        if alpha == 0:
            pixels[offset:offset + 3] = b"\0\0\0"

    return Image.frombytes("RGBA", image.size, bytes(pixels))


def prepared_images():
    source_images = {
        name: Image.open(SOURCE / name).convert("RGBA")
        for name in {region[1] for region in REGIONS}
    }
    prepared = []
    groups = {}

    for name, source, rect, group in REGIONS:
        crop = source_images[source].crop(rect)
        cleaned = clean_alpha(crop, 2 if name == "gameplay/falling_marks" else 1)
        bounds = cleaned.getchannel("A").getbbox()

        if bounds is None:
            raise ValueError(f"Empty source region: {name}")

        trimmed = cleaned.crop(bounds)
        prepared.append((name, source, rect, group, bounds, trimmed))

        if group:
            old_width, old_height = groups.get(group, (0, 0))
            groups[group] = (max(old_width, trimmed.width), max(old_height, trimmed.height))

    result = []

    for name, source, rect, group, bounds, trimmed in prepared:
        width, height = groups.get(group, trimmed.size)

        if group == "basket":
            height = trimmed.height

        canvas = Image.new("RGBA", (width + 2 * PADDING, height + 2 * PADDING))
        offset = [PADDING + (width - trimmed.width) // 2, PADDING + (height - trimmed.height) // 2]
        canvas.paste(trimmed, tuple(offset))
        pivot = [canvas.width / 2, canvas.height / 2]
        anchors = {
            anchor: [point[0] - rect[0] - bounds[0] + offset[0],
                     point[1] - rect[1] - bounds[1] + offset[1]]
            for anchor, point in SOURCE_ANCHORS.get(name, {}).items()
        }

        if "rotation_pivot" in anchors:
            pivot = anchors["rotation_pivot"]

        entry = {
            "path": name + ".png",
            "source": source,
            "sheet_rect": [rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]],
            "trim_in_rect": [bounds[0], bounds[1], trimmed.width, trimmed.height],
            "paste_offset_px": offset,
            "size": list(canvas.size),
            "padding_minimum": PADDING,
            "pivot_px": pivot,
            "pivot_normalized": [pivot[0] / canvas.width, pivot[1] / canvas.height],
            "visible_bounds_px": list(canvas.getchannel("A").getbbox()),
        }

        if anchors:
            entry["anchors_px"] = anchors

        if group:
            entry["canvas_group"] = group

        if group == "basket":
            entry["horizontal_cap_margins_px"] = [64, 64]
            entry["cap_margin_region"] = "visible_bounds_px"
            if name.endswith("_back"):
                entry["front_overlay_offset_px"] = [0, 398 - rect[1] - bounds[1]]

        result.append((entry, canvas))

    background = Image.open(SOURCE / "blue-paper-backdrop.png").convert("RGB")
    result.insert(0, ({"path": "environment/blue_paper_backdrop.png",
                      "source": "blue-paper-backdrop.png", "size": list(background.size),
                      "padding_minimum": 0, "pivot_normalized": [0.5, 0.5]}, background))
    return result


def build():
    prepared = prepared_images()
    entries = []

    for entry, image in prepared:
        path = RUNTIME / entry["path"]
        path.parent.mkdir(parents=True, exist_ok=True)

        if entry["padding_minimum"] == 0:
            path.write_bytes((SOURCE / entry["source"]).read_bytes())
        else:
            image.save(path, compress_level=9)

        entry["sha256"] = digest(path)
        entries.append(entry)

    manifest = {
        "schema": "play-shapes.tilt-shift-art.v1",
        "runtime_root": "assets/runtime/minigames/003",
        "sources": {path.name: digest(path) for path in sorted(SOURCE.glob("*.png"))},
        "alpha_cleanup": {"core_threshold": 128, "fringe_px": 2,
                          "alpha_remap": [24, 250], "transparent_rgb": [0, 0, 0]},
        "import_policy": POLICY,
        "assets": entries,
    }
    (ART / "import_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"TILT_SHIFT_ART_BUILT: {len(entries)} textures")


def check():
    manifest = json.loads((ART / "import_manifest.json").read_text(encoding="utf-8"))
    expected = {entry["path"] for entry in manifest["assets"]}
    actual = {path.relative_to(RUNTIME).as_posix() for path in RUNTIME.rglob("*.png")}
    assert actual == expected, "Runtime inventory differs from the manifest"

    for source, source_hash in manifest["sources"].items():
        assert digest(SOURCE / source) == source_hash, f"Changed source master: {source}"

    regenerated = {entry["path"]: image for entry, image in prepared_images()}

    for entry in manifest["assets"]:
        path = RUNTIME / entry["path"]
        image = Image.open(path)
        assert digest(path) == entry["sha256"], f"Changed output: {path}"
        assert list(image.size) == entry["size"], f"Wrong dimensions: {path}"
        assert image.mode == regenerated[entry["path"]].mode, f"Wrong image mode: {path}"
        assert image.tobytes() == regenerated[entry["path"]].tobytes(), f"Nonrepeatable output: {path}"

        if entry["padding_minimum"]:
            alpha = image.getchannel("A")
            left, top, right, bottom = alpha.getbbox()
            assert min(left, top, image.width - right, image.height - bottom) >= PADDING, path
            assert alpha.getextrema() == (0, 255), f"Opaque interiors or transparency missing: {path}"
            assert sum(alpha.histogram()[1:255]) > 0, f"Antialiased edge missing: {path}"

            source_image = Image.open(SOURCE / entry["source"]).convert("RGBA")
            x, y, _, _ = entry["sheet_rect"]
            tx, ty, width, height = entry["trim_in_rect"]
            original = source_image.crop((x + tx, y + ty, x + tx + width, y + ty + height))
            px, py = entry["paste_offset_px"]
            visible = image.crop((px, py, px + width, py + height))
            differences = ImageChops.difference(original.convert("RGB"), visible.convert("RGB"))
            for channel in differences.split():
                changed = channel.point(lambda value: 255 if value else 0)
                assert ImageChops.multiply(changed, visible.getchannel("A")).getbbox() is None, path

        config = (path.parent / (path.name + ".import")).read_text(encoding="utf-8")
        for key, value in POLICY.items():
            text_value = str(value).lower()
            assert f"{key}={text_value}" in config, f"Wrong Godot policy: {path}: {key}"

    paddles = [entry for entry in manifest["assets"] if entry.get("canvas_group") == "paddle"]
    assert len({tuple(entry["size"]) for entry in paddles}) == 1, "Paddle canvases differ"
    assert all(entry["pivot_normalized"] == [0.5, 0.5] for entry in paddles), "Paddle pivots differ"
    baskets = [entry for entry in manifest["assets"] if entry.get("canvas_group") == "basket"]
    assert len({entry["size"][0] for entry in baskets}) == 1, "Basket layer widths differ"
    assert all(entry["size"][0] > sum(entry["horizontal_cap_margins_px"]) for entry in baskets)
    print(f"TILT_SHIFT_ART_OK: {len(manifest['assets'])} textures, source RGB, padding and imports")


def imports():
    for path in RUNTIME.rglob("*.png.import"):
        original = path.read_text(encoding="utf-8")
        configured = original

        for key, value in POLICY.items():
            pattern = rf"^{re.escape(key)}=.*$"
            configured, count = re.subn(
                pattern, f"{key}={str(value).lower()}", configured, flags=re.MULTILINE
            )
            if count != 1:
                raise ValueError(f"Missing or repeated Godot import setting: {path}: {key}")

        if configured != original:
            path.write_text(configured, encoding="utf-8")

    print("TILT_SHIFT_IMPORTS_CONFIGURED")


def review():
    manifest = json.loads((ART / "import_manifest.json").read_text(encoding="utf-8"))
    entries = [entry for entry in manifest["assets"] if entry["padding_minimum"]]
    canvas = Image.new("RGB", (1500, 7 * 320), "#ece8df")
    draw = ImageDraw.Draw(canvas)

    for index, entry in enumerate(entries):
        column, row = index % 3, index // 3
        left, top = column * 500, row * 320
        draw.rectangle((left + 8, top + 8, left + 492, top + 280), fill="#629dc5")
        image = Image.open(RUNTIME / entry["path"])
        image.thumbnail((460, 250), Image.Resampling.LANCZOS)
        x, y = left + (500 - image.width) // 2, top + 144 - image.height // 2
        canvas.paste(image, (x, y), image)
        draw.text((left + 16, top + 288), entry["path"], fill="#202830")

    path = ROOT / "test-results/tilt-shift-art/contact-sheet.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)
    print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "imports", "check", "review"])
    args = parser.parse_args()
    {"build": build, "imports": imports, "check": check, "review": review}[args.command]()
