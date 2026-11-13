"""Patch 2.2 item 1: writes the container layouts for container ships 2-5.

Run from the repository root: python3 tools/build_container_ladder.py
The deck, house and bridge positions match features/toon/chunky_look.gd
(_dress_box_ship): rows start clear of the stern house, ship 5 leaves a gap
for its forward bridge, and every row fits inside the hull's bow taper.
"""
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
# tier: length, beam, height, columns, rows, stack tiers, box scale, file
SHIPS = {
    2: (96.0, 18.0, 5.0, 5, 6, 2, 1.0, "container_02_layout.tres"),
    3: (140.0, 25.0, 6.0, 7, 8, 2, 1.15, "container_03_layout.tres"),
    4: (200.0, 32.0, 7.0, 8, 10, 3, 1.3, "container_04_layout.tres"),
    5: (270.0, 38.0, 8.0, 8, 12, 3, 1.4, "container_05_layout.tres"),
}
COLOURS = "0.709804, 0.403922, 0.286275, 1, 0.47451, 0.611765, 0.611765, 1, 0.784314, 0.647059, 0.407843, 1, 0.309804, 0.498039, 0.658824, 1, 0.847059, 0.690196, 0.290196, 1"


def half_width(length, beam, z):
    """chunky_look.hull_mesh's half-width at z (inner rail face)."""
    t = z / length + 0.5
    bow = min(max((t - 0.7) / 0.3, 0.0), 1.0)
    width = beam / 2 * (math.sqrt(max(0.0, 1 - bow * bow)) if bow > 0 else 1.0)
    return max(width - 0.6, width * 0.5)


def rows_for(tier, length, scale):
    aft = -length / 2
    start = aft + 18 * scale
    end = length * (0.34 if tier == 5 else 0.31)
    count = SHIPS[tier][4]
    spans = [(start, end)]
    if tier == 5:
        bridge = length * 0.2
        spans = [(start, bridge - 7 * scale), (bridge + 7 * scale, end)]
    total = sum(b - a for a, b in spans)
    pitch = total / count
    rows = []
    for a, b in spans:
        n = round((b - a) / pitch)
        rows += [a + pitch * (i + 0.5) for i in range(n)]
    assert len(rows) == count, (tier, len(rows))
    return rows, pitch


def build(tier):
    length, beam, height, columns, count, stacks, k, name = SHIPS[tier]
    scale = height / 4.0
    deck = 2.6 * scale
    rows, pitch = rows_for(tier, length, scale)
    box = (2.438 * k, 2.59 * k, min(12.192, pitch - 0.6))
    col_pitch = 2.7 * k
    centres = []
    for stack in range(stacks):
        y = deck + 0.5 + box[1] / 2 + 0.02 + stack * (box[1] + 0.1)
        for z in reversed(rows):
            edge = max(abs(z - box[2] / 2), abs(z + box[2] / 2))
            fit = min(half_width(length, beam, z + box[2] / 2), half_width(length, beam, z - box[2] / 2))
            assert (columns - 1) * col_pitch / 2 + box[0] / 2 <= fit, (tier, z, fit, edge)
            for c in range(columns):
                x = (c - (columns - 1) / 2) * col_pitch
                centres.append((round(x, 3), round(y, 3), round(z, 3)))
    flat = ", ".join("%g, %g, %g" % c for c in centres)
    text = ('[gd_resource type="Resource" script_class="ContainerLayout" load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://features/cargo/container_layout.gd" id="1"]\n'
            '[resource]\nscript = ExtResource("1")\n'
            'centres = PackedVector3Array(%s)\n'
            'container_size_m = Vector3(%g, %g, %g)\n'
            'colors = PackedColorArray(%s)\n') % (flat, round(box[0], 3), round(box[1], 3), round(box[2], 3), COLOURS)
    path = ROOT / "features/ships/container_ladder" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print(name, len(centres), "slots, box", [round(v, 2) for v in box])


if __name__ == "__main__":
    for tier in SHIPS:
        build(tier)
