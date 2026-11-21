"""Patch 4.0.3 item 7: Point Nemo, a small island chain in the big empty ocean.

Andy's markup (docs/reference/patch_4_0_3/point_nemo_location.png) puts it in
the middle of the open ocean between Slatewater Works and Brindle Quay, which
on the globe is the sea round the world's east-west edge. Three islets in a
short chain, the main one largest: it carries the Point Nemo port (its quay
on the west shore) and a runway along its length. Fixed shapes and fixed
coordinates, no randomness: client and server read the same baked data.

The natural land (natural_land.py) stays as it was. Point Nemo has its own
small grid, beside it, and its own solid blocks, because the natural land's
grid and its edge margin keep land away from the world's edges, and Point
Nemo is out in that open sea (wholly inside the world, clear of the edge).

The 2.9 rule holds: from the Point Nemo quay no other port is in sight (port
scenery fades out by 2200 m; the nearest, Slatewater Works, is 2.6 km away).

Writes:
  features/world/point_nemo.json   the signed coast depth grid and outlines
  features/game/progression.gd     NEMO_LAND (the solid cover blocks)

Standard library only:  python3 tools/world_layout/point_nemo.py
"""
import base64
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import natural_land as nl  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CELL = 25.0
ORIGIN = (5700.0, -3400.0)
COUNT = (52, 160)
DEPTH_STEP = 2.0
# The port (as in progression.gd WORLD): its quay on the main islet's west
# shore, open water (and the heavy drop area) to the west.
PORT = (5980.0, -2050.0)
# Islets: (centre x, centre z, half width, half length, squareness): a
# superellipse |x/a|^n + |z/b|^n <= 1, so the main islet's quay side is
# nearly straight. Main first, then the chain to the north-east.
ISLETS = [
    (6420.0, -1610.0, 350.0, 950.0, 4.0),
    (6560.0, -150.0, 170.0, 230.0, 2.4),
    (6730.0, 250.0, 95.0, 120.0, 2.0),
]
# A gentle wobble on the coast so it is not machine smooth (whole metres,
# fixed, no noise library).
WOBBLE_M = 14.0


def inside(x, z):
    """How far inside an islet (x, z) is, as a superellipse level (> 0 in)."""
    best = -1e9
    for cx, cz, a, b, n in ISLETS:
        u, v = (x - cx) / a, (z - cz) / b
        level = 1.0 - (abs(u) ** n + abs(v) ** n)
        wobble = WOBBLE_M * math.sin(x * 0.011 + z * 0.007) * math.sin(z * 0.013 - x * 0.005) / max(a, b)
        best = max(best, level + wobble)
    return best


def bake():
    nx, nz = COUNT
    land = [False] * (nx * nz)
    for j in range(nz):
        for i in range(nx):
            x, z = ORIGIN[0] + i * CELL, ORIGIN[1] + j * CELL
            land[j * nx + i] = inside(x, z) > 0.0
    # natural_land's helpers, on this grid.
    nl.CELL, nl.ORIGIN, nl.COUNT = CELL, ORIGIN, COUNT
    depth = nl.signed_depth(land, nx, nz)
    masses = sorted(nl.components(land, nx, nz), key=len, reverse=True)
    rects, outlines = [], []
    for index, cells in enumerate(masses):
        rects += nl.cover_rects(cells, nx)
        outlines.append({'name': 'Point Nemo' if index == 0 else 'Point Nemo %d' % (index + 1), 'outline': nl.outline(cells, depth, nx, nz)})
    return land, depth, rects, outlines, masses


def write_json(depth, outlines):
    data = bytes(max(0, min(255, int(round(d / DEPTH_STEP)) + 128)) for d in depth)
    out = {
        'note': 'Patch 4.0.3 item 7: Point Nemo, baked by tools/world_layout/point_nemo.py (fixed shapes, no seed). Do not edit by hand.',
        'cell_m': CELL, 'origin': list(ORIGIN), 'count': list(COUNT), 'depth_step_m': DEPTH_STEP, 'depth_zero': 128,
        'depth': base64.b64encode(data).decode('ascii'), 'outlines': outlines,
    }
    (ROOT / 'features/world/point_nemo.json').write_text(json.dumps(out, separators=(',', ':')) + '\n', encoding='utf-8')


def write_progression(rects):
    path = ROOT / 'features/game/progression.gd'
    source = path.read_text(encoding='utf-8')
    lines = ['const NEMO_LAND = [']
    for r in rects: lines.append('\tRect2(%g, %g, %g, %g),' % r)
    lines.append(']')
    source, count = re.subn(r'(## BEGIN POINT NEMO[^\n]*\n).*?(\n## END POINT NEMO)', lambda m: m.group(1) + '\n'.join(lines) + m.group(2), source, flags=re.S)
    if count != 1: raise SystemExit('progression.gd has no POINT NEMO block')
    path.write_text(source, encoding='utf-8')


def problems(land, depth, rects):
    nx, nz = COUNT
    out = []
    at = lambda x, z: depth[int(round((z - ORIGIN[1]) / CELL)) * nx + int(round((x - ORIGIN[0]) / CELL))]
    x, z = PORT
    # The quay backs onto land; its berths, approach and drop area are sea.
    if at(x + 105, z + 100) <= 0: out.append('the quay does not back onto land')
    for k in range(0, 1000, 50):
        if at(x + 20, z - 40 + k) > 0 and k < 900: out.append('land at the quay line (%d)' % k)
    hits = lambda area: any(r[0] < area[0] + area[2] and area[0] < r[0] + r[2] and r[1] < area[1] + area[3] and area[1] < r[1] + r[3] for r in rects)
    if hits((x - 350, z - 1400, 365, 2200)): out.append('land at the berths or approach')
    if hits((x - 1000, z - 1350, 700, 700)): out.append('land at the heavy drop area')
    edge = 750.0 + 2000.0 * math.pi
    if any(r[0] + r[2] > edge - 150.0 for r in rects): out.append('too near the east-west edge')
    return out


def main():
    land, depth, rects, outlines, masses = bake()
    found = problems(land, depth, rects)
    if found: raise SystemExit('Point Nemo rejected: ' + '; '.join(found))
    write_json(depth, outlines)
    write_progression(rects)
    print('point nemo: %d islets, %d cover blocks, %.2f km2' % (len(masses), len(rects), sum(r[2] * r[3] for r in rects) / 1e6))


if __name__ == '__main__':
    main()
