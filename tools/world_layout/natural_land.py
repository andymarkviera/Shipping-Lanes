"""Patch 2.9 items 6A and 6B: the natural world, baked from one fixed seed.

Item 6B: the North and South Pole ports stay put; every other port is drawn
by the seed to a coastal spot on the skeleton (land behind its quay, open sea
at its berths, approach and drop area, by sea to every other port within the
route budget). The Palm Isles, desert, tropical and rainy-city regions follow
their ports, the volcano's Ember Isle is drawn into open sea, and each bridge
crosses its strait at a seeded point. The land below is then bent round the
new spots exactly as item 6A bent it round the old ones.

Seeded fractal noise and a domain warp turn the old Patch 2.5 block layout
into irregular continents, peninsulas, bays and islands (no straight or boxy
coasts), and a few new seeded islands fill the open sea. Until item 6B moves
the ports, the shapes are bent round what must stay: every port keeps open
water at its berths, approach and heavy drop area and land behind its quay;
every sea route the ports used stays open; each strait keeps its width with
land on both banks and under each bridge's ends; icebergs keep sea round
them; Ember Isle stays alone round its volcano.

Writes:
  features/world/natural_land.json   the signed coast depth grid (metres
                                     inland, + land / - sea) and a simplified
                                     outline per landmass for the maps
  features/game/progression.gd       the LAND cover rectangles, LANDMASSES, the
                                     volcano and its land index, the moved ports
                                     and the bridges' crossing points
  features/sky/*_biome.gd            the desert, tropical and rain centres

Standard library only. Same seed, same world, on every machine:

    python3 tools/world_layout/natural_land.py
"""
import base64
import heapq
import itertools
import json
import math
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import traversal_budget as tb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SEED = 2906
CELL = 25.0
ORIGIN = (-3600.0, -4450.0)
COUNT = (348, 348)
# Depth is stored in one byte a sample: DEPTH_STEP metres a step, 0 at 128.
DEPTH_STEP = 2.0
WARP_M = 760.0
NOISE_M = 330.0
# Keep-clear sea edges wobble out by up to this much, so they are never straight.
WOBBLE_M = 190.0
# The Patch 2.5 blocks, kept only as the rough skeleton the seed bends.
SKELETON = [
    ("Hearthland", [(-1500, -3700, 1000, 3300), (-1500, -400, 1400, 1100), (-1500, 700, 1100, 1000), (-1500, 1700, 1200, 1300),
                    (-3300, -2950, 1800, 1900), (-3500, -1050, 2000, 1700), (-3150, 650, 1650, 1350), (-3400, 2000, 1900, 1000),
                    (-2200, -3860, 700, 910), (-1500, -4150, 2850, 450)]),
    ("Northern Neck", [(-1500, 3000, 2080, 400), (780, 3000, 2220, 400)]),
    ("Ironreach", [(1800, -3000, 1200, 1500), (1900, -1500, 1100, 600), (1900, -760, 1100, 360), (1600, -400, 1400, 1100),
                   (1750, 700, 1250, 2300), (1900, -4150, 1900, 1150), (3000, -3000, 800, 2100), (3000, -760, 800, 3160)]),
    ("Kelp Isle", [(4050, -2600, 900, 4000)]),
    ("Gull Isle", [(-1000, 3700, 1000, 400)]),
    ("Strait islets", [(880, 1320, 240, 360), (450, -2050, 300, 300)]),
    ("Palm Isles", [(-260, -2900, 240, 220), (120, -3380, 220, 200), (-330, -1950, 200, 200)]),
    ("Ember Isle", [(4270, -4305, 420, 370)]),
]
# The skeleton as written; SKELETON itself is rebuilt round each placement.
SKELETON_SRC = SKELETON
# Names for the new seeded islands, in the order the seed finds them.
NEW_ISLES = ["Tern Isle", "Driftwood Isle", "Cormorant Rock", "Saltmarsh Isle", "Puffin Isle", "Breaker Isle"]


class Noise:
    """Seeded smooth value noise on a lattice, summed in octaves."""

    def __init__(self, seed):
        rng = random.Random(seed)
        self.perm = list(range(256))
        rng.shuffle(self.perm)
        self.perm += self.perm
        self.values = [rng.uniform(-1.0, 1.0) for _ in range(256)]

    def _at(self, i, j):
        return self.values[self.perm[(self.perm[i & 255] + j) & 255]]

    def value(self, x, z):
        i, j = math.floor(x), math.floor(z)
        fx, fz = x - i, z - j
        sx, sz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
        a = self._at(i, j) + (self._at(i + 1, j) - self._at(i, j)) * sx
        b = self._at(i, j + 1) + (self._at(i + 1, j + 1) - self._at(i, j + 1)) * sx
        return a + (b - a) * sz

    def fbm(self, x, z, scale, octaves=4):
        total, amp, norm = 0.0, 1.0, 0.0
        for octave in range(octaves):
            total += amp * self.value(x / scale + octave * 17.3, z / scale - octave * 9.1)
            norm += amp
            amp *= 0.5
            scale /= 2.1
        return total / norm


def rect_sdf(p, rect, round_m=0.0):
    """Signed distance to a rectangle (x, z, w, d): - inside, + outside."""
    x, z, w, d = rect
    r = min(round_m, 0.45 * min(w, d))
    cx, cz = x + w / 2, z + d / 2
    qx, qz = abs(p[0] - cx) - (w / 2 - r), abs(p[1] - cz) - (d / 2 - r)
    return math.hypot(max(qx, 0.0), max(qz, 0.0)) + min(max(qx, qz), 0.0) - r


def strait_offsets(p, strait):
    """Metres across a strait's centre line, and past its ends."""
    a, b = strait['start'], strait['end']
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    along = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    t = (p[0] - a[0]) * along[0] + (p[1] - a[1]) * along[1]
    lateral = abs((p[0] - a[0]) * -along[1] + (p[1] - a[1]) * along[0])
    return lateral, max(0.0, -t, t - length)


def trim(rect, straits):
    """A cover block cut back to the straits' banks: no block reaches into a
    strait's width (straits run along X or Z), so its sample grid never
    narrows a channel."""
    x, z, w, d = rect
    for strait in straits:
        (ax, az), (bx, bz), half = strait['start'], strait['end'], strait['width'] / 2
        if ax == bx:
            low, high = min(az, bz) - half - 8, max(az, bz) + half + 8
            if z < high and z + d > low and x < ax + half and x + w > ax - half:
                if x + w / 2 < ax: w = ax - half - x
                else: w, x = x + w - (ax + half), ax + half
        elif az == bz:
            low, high = min(ax, bx) - half - 8, max(ax, bx) + half + 8
            if x < high and x + w > low and z < az + half and z + d > az - half:
                if z + d / 2 < az: d = az - half - z
                else: d, z = z + d - (az + half), az + half
    return (x, z, w, d)


def segment_sdf(p, a, b):
    ax, az = p[0] - a[0], p[1] - a[1]
    bx, bz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, (ax * bx + az * bz) / max(bx * bx + bz * bz, 1e-9)))
    return math.hypot(ax - bx * t, az - bz * t)


# Patch 2.9 item 6B. Where the four strait ports were before the move: pay
# keeps these chart distances (saved jobs rebuild to the same pay) and old
# saves near them are moved to the new spots. The poles never move.
LEGACY = {
    'port_brindle_quay': ((0, 0, 0), 1.0), 'port_slatewater_works': ((1500, 0, 0), -1.0),
    'port_cinder_point': ((-200, 0, 2200), 1.0), 'port_gannet_light': ((1700, 0, -2200), -1.0),
}
PLACE_SEED = SEED + 6
# Each placement attempt draws from its own seeded stream, so attempts can be
# searched apart. PLACE_ATTEMPT is the first attempt that fits every rule
# below; `--search` looks again from attempt 0 (slow) and prints it.
PLACE_ATTEMPT = 0
# Regions round their ports, as offsets from the old port (inland is +X when
# drop_side is -1); mirrored when a port's open side flips.
REGIONS = {'desert': ('port_cinder_point', (-1700, 2300)), 'tropical': ('port_gannet_light', (1000, -2300)),
           'rain': ('port_slatewater_works', (1650, 700))}
MIN_PORT_GAP_M = 1900.0
# No strait port in the polar seas (polar_biome.gd: no polar look past 2950 m
# from the north/south edge), with room to spare.
POLAR_CLEAR_M = 3300.0
# Ember Isle's volcano: off every sea lane point and leg (volcano_check wants
# over 1000 m) and every port (over 2500 m).
VOLCANO_LANE_M = 1150.0
VOLCANO_PORT_M = 2650.0
# world_land_check: no straight coast over 400 m away from the quays.
STRAIGHT_MAX_M = 380.0
# The most of a port's berth or drop area the skeleton may cover at its spot.
CARVE_SHARE = 0.3


def follow(port_id, point, ports):
    """`point` placed round `port_id`'s new spot as it sat round the old one."""
    (ox, _, oz), old_side = LEGACY[port_id]
    new = ports[port_id]
    flip = new['drop_side'] / old_side
    return (new['at'][0] + (point[0] - ox) * flip, new['at'][2] + (point[1] - oz))


def carve(rects, cuts):
    """The rects with the cut rectangles taken out (each splits in up to four)."""
    for c in cuts:
        out = []
        for x, z, w, d in rects:
            if not (x < c[0] + c[2] and c[0] < x + w and z < c[1] + c[3] and c[1] < z + d):
                out.append((x, z, w, d))
                continue
            if x < c[0]: out.append((x, z, c[0] - x, d))
            if x + w > c[0] + c[2]: out.append((c[0] + c[2], z, x + w - c[0] - c[2], d))
            lx, hx = max(x, c[0]), min(x + w, c[0] + c[2])
            if z < c[1]: out.append((lx, z, hx - lx, c[1] - z))
            if z + d > c[1] + c[3]: out.append((lx, c[1] + c[3], hx - lx, z + d - c[1] - c[3]))
        rects = out
    return rects


def place_world(geo, layout, first=0, step=1):
    """The seeded spots: ports, Palm Isles, regions, Ember Isle and bridges,
    one candidate per attempt that fits, from attempt `first` on."""
    wrap, plan = geo['wrap'], layout['game_world']
    base = [r for name, rects in SKELETON_SRC if name not in ('Palm Isles', 'Ember Isle') for r in rects]
    big = [r for name, rects in SKELETON_SRC if name not in ('Palm Isles', 'Ember Isle', 'Strait islets', 'Gull Isle') for r in rects]
    poles = [p for p in geo['world'] if 'pole' in p['id']]
    edge = (geo['centre'][0] - wrap / 2 + 2300, geo['centre'][1] - wrap / 2 + 2300,
            geo['centre'][0] + wrap / 2 - 2300, geo['centre'][1] + wrap / 2 - 2300)
    rim = (geo['centre'][0] - wrap / 2 + 2150, geo['centre'][1] - wrap / 2 + 2150,
           geo['centre'][0] + wrap / 2 - 2150, geo['centre'][1] + wrap / 2 - 2150)
    in_land = lambda q, rects: any(tb._inside(q, r) for r in rects)
    clear = lambda area, rects, grow: not any(r[0] < area[0] + area[2] + grow and area[0] - grow < r[0] + r[2] and r[1] < area[1] + area[3] + grow and area[1] - grow < r[1] + r[3] for r in rects)
    gap = lambda a, b: math.hypot(tb._short(a[0] - b[0], wrap), tb._short(a[1] - b[1], wrap))
    solid = base + geo['ice']
    banks = []

    def share(area, rects):
        # The part of `area` the rects cover (they may overlap a little).
        hit = 0.0
        for r in rects:
            w = min(area[0] + area[2], r[0] + r[2]) - max(area[0], r[0])
            d = min(area[1] + area[3], r[1] + r[3]) - max(area[1], r[1])
            if w > 0 and d > 0: hit += w * d
        return hit / (area[2] * area[3])

    def spot_ok(x, z, ds, placed, extra):
        # The quay's land stays inside the land rim; its sea may run past it.
        if not all(rim[0] < q < rim[2] for q in (x, x - ds * 330)) or not (rim[1] + 150 < z and z + 1050 < rim[3]): return False
        if any(not in_land((x - ds * xx, z + zz), base) for xx in (110, 220, 320) for zz in range(-100, 1001, 110)): return False
        # The land below carves the berths, approach and drop area out; the
        # seed may only pick a spot where that cuts away little of the land.
        berths, drop = (min(x + ds * 40, x + ds * 350), z - 1400, 310, 2200), (min(x + ds * 450, x + ds * 850) - 150, z - 1350, 700, 700)
        if not clear(berths, geo['ice'] + extra + banks, 200) or not clear(drop, geo['ice'] + extra + banks, 200): return False
        if share(berths, base) > CARVE_SHARE or share(drop, base) > CARVE_SHARE: return False
        if any(math.hypot(x - bx, z - bz) < br + 900 for bx, br, bz in geo['bergs']): return False
        if any(segment_sdf((x, z), s['start'], s["end"]) < 800 for s in geo['straits']): return False
        if any(abs(tb._short(q - geo['centre'][1], wrap)) > wrap / 2 - POLAR_CLEAR_M for q in (z - 500, z + 200)): return False
        return all(gap((x, z), (p['at'][0], p['at'][2])) >= MIN_PORT_GAP_M for p in placed)

    def isles_ok(isles, ports):
        for r in isles:
            c = (r[0] + r[2] / 2, r[1] + r[3] / 2)
            if not clear(r, solid, 200) or not (edge[0] < c[0] < edge[2] and edge[1] < c[1] < edge[3]): return False
            for p in ports:
                x, _, z = p['at']
                if not clear(r, [(min(x - p['drop_side'] * 15, x + p['drop_side'] * 350), z - 1400, 365, 2200),
                                 (min(x + p['drop_side'] * 450, x + p['drop_side'] * 850) - 150, z - 1350, 700, 700)], 100): return False
        return True

    for attempt in itertools.count(first, step):
        rng = random.Random(PLACE_SEED * 100003 + attempt)
        # Each bridge crosses its own strait well clear of the others' water.
        bridges = {}
        for strait in geo['straits']:
            a, b = strait['start'], strait['end']
            while True:
                t = rng.uniform(0.38, 0.62)
                at = (round((a[0] + (b[0] - a[0]) * t) / 10) * 10, round((a[1] + (b[1] - a[1]) * t) / 10) * 10)
                if all(segment_sdf(at, o['start'], o['end']) > 700 for o in geo['straits'] if o is not strait): break
            bridges[_strait_id(strait['name'])] = at
        # The headlands the land keeps at each strait's middle and under each
        # bridge's ends (see main): no port's berths or drop area on them.
        banks.clear()
        for strait in geo['straits']:
            a, b, half = strait['start'], strait['end'], strait['width'] / 2
            for (cx, cz), along, across in ((((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), 260, half + 200), (bridges[_strait_id(strait['name'])], 290, half + 1150)):
                w, d = (2 * along, 2 * across) if a[0] == b[0] else (2 * across, 2 * along)
                banks.append((cx - w / 2, cz - d / 2, w, d))
        placed = list(poles)
        ports = {}
        for port_id in LEGACY:
            for _ in range(4000):
                rect = rng.choice(big)
                ds = rng.choice((-1.0, 1.0))
                x = (rect[0] if ds < 0 else rect[0] + rect[2]) + ds * 90.0
                z = rng.uniform(rect[1] - 400, rect[1] + rect[3] - 200)
                x, z = round(x / 10) * 10, round(z / 10) * 10
                if spot_ok(x, z, ds, placed, []):
                    ports[port_id] = dict(id=port_id, at=[float(x), 0.0, float(z)], drop_side=ds)
                    placed.append(ports[port_id])
                    break
            else: break
        if len(ports) != len(LEGACY): continue
        # The Palm Isles: the same three isles, drawn as a group into the sea
        # off Gannet Light's open side; the tropics centre between them.
        gannet = ports['port_gannet_light']
        old_isles = dict(SKELETON_SRC)['Palm Isles']
        mid = (sum(r[0] + r[2] / 2 for r in old_isles) / 3, sum(r[1] + r[3] / 2 for r in old_isles) / 3)
        flip = gannet['drop_side'] / LEGACY['port_gannet_light'][1]
        for _ in range(300):
            centroid = (gannet['at'][0] + gannet['drop_side'] * rng.uniform(900, 2000), gannet['at'][2] + rng.uniform(-1200, 1200))
            palms = [(round(centroid[0] + (r[0] + r[2] / 2 - mid[0]) * flip - r[2] / 2), round(centroid[1] + r[1] + r[3] / 2 - mid[1] - r[3] / 2), r[2], r[3]) for r in old_isles]
            tropic = (gannet['at'][0] + 0.45 * (centroid[0] - gannet['at'][0]), gannet['at'][2] + 0.45 * (centroid[1] - gannet['at'][2]))
            if all(math.hypot(r[0] + r[2] / 2 - tropic[0], r[1] + r[3] / 2 - tropic[1]) < 1450 for r in palms) and isles_ok(palms, placed): break
        else: continue
        world = [ports.get(p['id'], p) for p in geo['world']]
        # Each region holds its own port and no other, off the poles and the
        # other regions (CLEAR_M from each biome script).
        regions = {name: follow(port_id, point, ports) for name, (port_id, point) in REGIONS.items()}
        regions['tropical'] = (round(tropic[0] / 10) * 10, round(tropic[1] / 10) * 10)
        reach = {name: float(re.search(r'const CLEAR_M: float = ([\d.]+)', tb.read('features/sky/%s_biome.gd' % name)).group(1)) for name in REGIONS}
        if any(gap(regions[n], (p['at'][0], p['at'][2])) < reach[n] + 100 for n in REGIONS for p in world if p['id'] != REGIONS[n][0]): continue
        # Out of the polar seas (polar_biome.gd: none within 2950 m of the edge).
        if any(abs(tb._short(q - geo['centre'][1], wrap)) > wrap / 2 - POLAR_CLEAR_M for n in REGIONS for q in (regions[n][1], ports[REGIONS[n][0]]['at'][2])): continue
        if any(gap(regions[a], regions[b]) < reach[a] + reach[b] for a in REGIONS for b in REGIONS if a < b): continue
        cuts = []
        for p in world:
            x, _, z = p['at']
            ds = p['drop_side']
            cuts += [(min(x + ds * 15, x + ds * 350) - 60, z - 1460, 455, 2320), (min(x + ds * 450, x + ds * 850) - 210, z - 1410, 820, 820)]
        trial = dict(geo, land=carve(base, cuts) + palms, world=world)
        gates = [(p['at'][0], p['at'][2] - geo['gate']) for p in world]
        legs = set()
        for a, b in itertools.combinations(gates, 2):
            length, path = tb.sea_route(trial, a, b)
            if length is None or length > plan['max_route_m'] - 500: break
            legs.update(zip(path, path[1:]))
        else: length = 0
        if length is None or length > plan['max_route_m'] - 500: continue
        # Ember Isle: open sea, off every port, route, isle and strait.
        ember = dict(SKELETON_SRC)['Ember Isle'][0]
        for _ in range(4000):
            vx, vz = round(rng.uniform(edge[0], edge[2]) / 10) * 10, round(rng.uniform(edge[1], edge[3]) / 10) * 10
            rect = (vx - ember[2] / 2, vz - ember[3] / 2, ember[2], ember[3])
            if not clear(rect, solid + palms, 650) or not isles_ok([rect], world): continue
            if any(segment_sdf((vx, vz), u, v) < VOLCANO_LANE_M for u, v in legs): continue
            if any(gap((vx, vz), q) < VOLCANO_LANE_M for q in geo['lanes']): continue
            if any(gap((vx, vz), (p['at'][0], p['at'][2])) < VOLCANO_PORT_M for p in world): continue
            if any(math.hypot(vx - bx, vz - bz) < br + 900 for bx, br, bz in geo['bergs']): continue
            if any(segment_sdf((vx, vz), s['start'], s['end']) < 1200 for s in geo['straits']): continue
            break
        else: continue
        if any(gap(regions[n], (vx, vz)) < reach[n] + 300 for n in REGIONS): continue
        yield attempt, dict(world=world, palms=palms, volcano=(vx, vz), ember=rect, bridges=bridges, regions=regions)


def main():
    layout = tb.load()
    geo = tb.game_world(layout)
    first = 0 if '--search' in sys.argv else PLACE_ATTEMPT
    skeleton0 = SKELETON_SRC
    for attempt, placed in place_world(geo, layout, first):
        print('placement attempt', attempt)
        baked = bake(dict(geo, world=placed['world']), placed, skeleton0)
        problem = baked_problem(geo, placed, baked)
        if problem:
            print('  baked world rejected:', problem)
            continue
        break
    print('PLACE_ATTEMPT', attempt)
    depth, outlines, isles, rects, ranges, volcano_index, masses, land, nx, nz = baked
    write_json(depth, outlines, len(isles))
    if '--preview' in sys.argv: preview(land, nx, nz, dict(geo, world=placed['world']))
    write_progression(rects, ranges, volcano_index)
    write_placement(placed)
    total = sum(r[2] * r[3] for r in rects)
    print('natural land: seed %d, %d landmasses, %d new isles, %d cover blocks, %.1f km2' % (SEED, len(masses), len(isles), len(rects), total / 1e6))


def baked_problem(geo, placed, baked):
    """What volcano_check or world_land_check would find wrong with the baked
    land, or None: the volcano off every lane leg the game's own routes take
    on the baked land, and no long straight coast away from the quays."""
    depth, outlines, isles, rects, ranges, volcano_index, masses, land, nx, nz = baked
    world = placed['world']
    ports = [(p['at'][0], p['at'][2]) for p in world]
    harbour_m = float(re.search(r'const HARBOUR_M: float = ([\d.]+)', tb.read('features/toon/toon_coast.gd')).group(1))
    def harbour_weight(q):
        w = 0.0
        for px, pz in ports:
            near = (px, min(max(q[1], pz - 60.0), pz + 1000.0))
            w = max(w, 1.0 - min(max((math.dist(q, near) - harbour_m) / 160.0, 0.0), 1.0))
        return w
    run = 0.0
    for entry in outlines:
        ring, n = entry['outline'], len(entry['outline'])
        for i in range(n):
            j = i + 2
            while j < i + n:
                a, b = ring[i], ring[j % n]
                if not (math.dist(a, b) > 0 and all(segment_sdf(ring[k % n], a, b) < 6.0 for k in range(i + 1, j))): break
                if harbour_weight(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)) <= 0.0: run = max(run, math.dist(a, b))
                j += 1
    if run > STRAIGHT_MAX_M: return 'straight coast %.0f m' % run
    trial = dict(geo, land=rects, world=world)
    gates = [(p['at'][0], p['at'][2] - geo['gate']) for p in world]
    v = placed['volcano']
    gap = min(math.dist(v, q) for q in geo['lanes'])
    for a in gates:
        for b in gates:
            if a == b: continue
            length, path = tb.sea_route(trial, a, b)
            if length is None: return 'no sea route'
            if length > layout_max(geo): return 'route over budget'
            gap = min([gap] + [segment_sdf(v, u, w) for u, w in zip(path, path[1:])])
    if gap < VOLCANO_LANE_M - 100.0: return 'volcano %.0f m from a lane' % gap
    return None


def layout_max(geo):
    return tb.load()['game_world']['max_route_m']


def bake(geo, placed, skeleton0):
    """The natural land bent round `placed`: depth grid, outlines, cover rects."""
    global SKELETON
    SKELETON = [(name, placed['palms'] if name == 'Palm Isles' else ([placed['ember']] if name == 'Ember Isle' else rects)) for name, rects in skeleton0]
    skeleton = [r for _, rects in SKELETON for r in rects]
    old = dict(geo, land=skeleton)
    warp_x, warp_z, shape, isle_noise = Noise(SEED), Noise(SEED + 1), Noise(SEED + 2), Noise(SEED + 3)
    wrap = geo['wrap']
    edge = (geo['centre'][0] - wrap / 2 + 2050, geo['centre'][1] - wrap / 2 + 2050,
            geo['centre'][0] + wrap / 2 - 2050, geo['centre'][1] + wrap / 2 - 2050)

    # What must stay sea: (kind, data, keep metres). Ports: berths, approach,
    # drop area. Routes: every leg any port-to-port route took on the old
    # layout. Icebergs. Straits: their full width.
    water = []
    keep_land = []
    for port in geo['world']:
        side, (x, _, z) = -port['drop_side'], port['at']
        water.append(('rect', (min(x + side * 15, x - side * 350), z - 1400, 365, 2200), 60.0))
        water.append(('rect', (min(x + port['drop_side'] * 450, x + port['drop_side'] * 850) - 150, z - 1350, 700, 700), 60.0))
        if 'pole' in port['id']: continue
        # Land behind the quay, where the skeleton had it.
        quay = (min(x + side * 95, x + side * 330), z - 120, 235, 1140)
        keep_land.append(('quay', quay))
        keep_land.append(('strip', (min(x + side * 95, x + side * 215), z - 60, 120, 640)))
    strait_legs = set()
    for strait in geo['straits']:
        strait_legs.add((tuple(strait['start']), tuple(strait['end'])))
        strait_legs.add((tuple(strait['end']), tuple(strait['start'])))
    gates = [(p['at'][0], p['at'][2] - geo['gate']) for p in geo['world']]
    legs = set()
    for a in gates:
        for b in gates:
            if a == b: continue
            _, path = tb.sea_route(old, a, b)
            for u, v in zip(path, path[1:]):
                if (tuple(u), tuple(v)) not in strait_legs: legs.add((tuple(u), tuple(v)))
    for u, v in legs:
        step = (tb._short(v[0] - u[0], wrap), tb._short(v[1] - u[1], wrap))
        water.append(('leg', (u, (u[0] + step[0], u[1] + step[1])), 95.0))
    for x, r, z in geo['bergs']:
        water.append(('disc', (x, z, r), 175.0))
    for strait in geo['straits']:
        water.append(('leg', (tuple(strait['start']), tuple(strait['end'])), strait['width'] / 2 + 8.0))
    # Banks: land close on both sides of each strait's middle, and under each
    # bridge's ends (see toon_bridge.gd: half span + 30 m flat + 120 m ramp).
    for strait in geo['straits']:
        a, b, half = strait['start'], strait['end'], strait['width'] / 2
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        along = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        across = (-along[1], along[0])
        spots = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 200.0, half + 140.0)]
        bx, bz = placed['bridges'][_strait_id(strait['name'])]
        spots.append((bx, bz, 230.0, half + 520.0))
        for cx, cz, reach_along, reach_across in spots:
            for k in (1, -1):
                keep_land.append(('bank', (cx, cz, along, across, k, half + 8.0, reach_across, reach_along)))
    vx, vz = placed['volcano']
    vbase = float(re.search(r'"base_m": ([\d.]+)', tb.read('features/game/progression.gd')).group(1))

    # New seeded islands: in open sea, well off every route, port and coast.
    rng = random.Random(SEED + 4)
    isles = []
    def far_from_everything(cx, cz, r):
        if not (edge[0] + r + 300 < cx < edge[2] - r - 300 and edge[1] + r + 300 < cz < edge[3] - r - 300): return False
        if any(rect_sdf((cx, cz), s) < r + 420 for s in skeleton): return False
        if any(segment_sdf((cx, cz), u, v) < r + 330 for u, v in legs): return False
        if any(math.hypot(cx - p['at'][0], cz - p['at'][2]) < r + 1200 for p in geo['world']): return False
        if any(math.hypot(cx - x, cz - z) < r + br + 400 for x, br, z in geo['bergs']): return False
        if any(math.hypot(cx - ix, cz - iz) < r + ir + 700 for ix, iz, ir in isles): return False
        return math.hypot(cx - vx, cz - vz) > r + 1500
    for _ in range(4000):
        if len(isles) == len(NEW_ISLES): break
        r = rng.uniform(150.0, 360.0)
        cx, cz = rng.uniform(edge[0], edge[2]), rng.uniform(edge[1], edge[3])
        if far_from_everything(cx, cz, r): isles.append((cx, cz, r))
    print('seeded isles', len(isles))

    nx, nz = COUNT
    land = bytearray(nx * nz)
    for j in range(nz):
        pz = ORIGIN[1] + j * CELL
        for i in range(nx):
            px = ORIGIN[0] + i * CELL
            p = (px, pz)
            wp = (px + WARP_M * warp_x.fbm(px, pz, 3000.0, 4), pz + WARP_M * warp_z.fbm(px, pz, 3000.0, 4))
            base = min(rect_sdf(wp, s, 420.0) for s in skeleton)
            f = -base + NOISE_M * shape.fbm(px, pz, 1700.0, 5)
            wobble = WOBBLE_M * abs(isle_noise.fbm(px + 9000, pz, 650.0, 3)) * 1.6
            for cx, cz, r in isles:
                f = max(f, r - math.hypot(px - cx, pz - cz) + 0.55 * r * isle_noise.fbm(px, pz, 700.0, 4))
            # Small skeleton isles keep a core, so the seed reshapes them
            # without washing them away.
            for s in skeleton:
                if min(s[2], s[3]) <= 420: f = max(f, 0.52 * min(s[2], s[3]) - math.hypot(px - s[0] - s[2] / 2, pz - s[1] - s[3] / 2) + 40 * isle_noise.fbm(px, pz, 300.0, 3))
            dv = math.hypot(px - vx, pz - vz)
            for kind, data in keep_land:
                if kind == 'bank' or kind == 'strip': continue
                if kind == 'quay':
                    # A rounded hinterland behind the quay, where the skeleton had land.
                    q = ((px - data[0] - data[2] / 2) / (data[2] / 2 + 60)) ** 2 + ((pz - data[1] - data[3] / 2) / (data[3] / 2)) ** 2
                    if q < 1.5: f = max(f, min(140.0 * (1.0 - q) - 30.0 * abs(isle_noise.fbm(px, pz - 7000, 300.0, 2)), -min(rect_sdf(p, s) for s in skeleton) + 10))
            for kind, data, keep in water:
                if kind == 'rect': d = rect_sdf(p, data, 120.0)
                elif kind == 'disc': d = math.hypot(px - data[0], pz - data[1]) - data[2]
                else: d = segment_sdf(p, data[0], data[1])
                f = min(f, d - keep - (wobble if kind != 'leg' or keep < 100 else wobble * 0.6))
            # Last word: the strip behind each quay and the strait banks are
            # land, then each strait is open water its full width.
            for kind, data in keep_land:
                if kind == 'quay': continue
                if kind == 'strip':
                    if rect_sdf(p, data) < 0: f = max(f, 30.0)
                else:
                    # A rounded headland on each bank, not a box.
                    cx, cz, along, across, k, inner, outer, reach = data
                    rx, rz = px - cx, pz - cz
                    t = rx * along[0] + rz * along[1]
                    sd = (rx * across[0] + rz * across[1]) * k
                    half_w = (outer - inner) / 2 + 60.0
                    q = (t / reach) ** 2 + ((sd - (inner + outer) / 2) / half_w) ** 2
                    if q < 1.5: f = max(f, 140.0 * (1.0 - q) - 30.0 * abs(isle_noise.fbm(px, pz + 7000, 300.0, 2)))
            for strait in geo['straits']:
                lateral, overhang = strait_offsets(p, strait)
                f = min(f, max(lateral - strait['width'] / 2 - 1.0, overhang - strait['width'] / 2 - 8.0))
            rim = min(px - edge[0], edge[2] - px, pz - edge[1], edge[3] - pz)
            f = min(f, rim - 30, rim - 170 + 220 * shape.fbm(px - 5000, pz, 420.0, 3) + max(0.0, 900.0 - dv))
            # Ember Isle: a ragged island round the volcano's foot, open sea
            # round it (it sits near the south edge, so it comes last).
            f = max(f, vbase + 95 - dv + 45 * isle_noise.fbm(px, pz, 260.0, 3))
            f = min(f, max(vbase + 200 - dv, dv - vbase - 900), rim - 30)
            land[j * nx + i] = 1 if f > 0 else 0

    # No lakes: sea that cannot reach the edge of the grid becomes land.
    seen = bytearray(nx * nz)
    stack = [k for k in range(nx * nz) if not land[k] and (k % nx in (0, nx - 1) or k // nx in (0, nz - 1))]
    for k in stack: seen[k] = 1
    while stack:
        k = stack.pop()
        i, j = k % nx, k // nx
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < nz:
                q = b * nx + a
                if not seen[q] and not land[q]:
                    seen[q] = 1
                    stack.append(q)
    for k in range(nx * nz):
        if not land[k] and not seen[k]: land[k] = 1
    # Specks: drop land cells with fewer than two land neighbours.
    for k in range(nx * nz):
        if land[k]:
            i, j = k % nx, k // nx
            around = sum(land[b * nx + a] for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)) if 0 <= a < nx and 0 <= b < nz)
            if around < 2: land[k] = 0

    depth = signed_depth(land, nx, nz)
    masses = components(land, nx, nz)
    masses.sort(key=len, reverse=True)
    names = name_masses(masses, nx, (vx, vz), isles)
    # Components of one name (the canal's two banks, the three Palm Isles) are
    # one landmass; each keeps its own outline for the maps.
    groups = {}
    for m, name in enumerate(names): groups.setdefault(name.rsplit(' ', 1)[0] if name[-1].isdigit() else name, []).append(m)
    rects, ranges, outlines = [], [], []
    volcano_index = -1
    for name in sorted(groups, key=lambda n: (SKELETON_ORDER.get(n, 99), n)):
        start = len(rects)
        for m in groups[name]:
            cover = [trim(r, geo['straits']) for r in cover_rects(masses[m], nx)]
            cover = [r for r in cover if r[2] > 0 and r[3] > 0]
            cover.sort(key=lambda r: -r[2] * r[3])
            if name == 'Ember Isle' and volcano_index < 0: volcano_index = len(rects)
            rects += cover
            outlines.append({'name': name, 'outline': outline(masses[m], depth, nx, nz)})
        ranges.append((name, start, len(rects)))
    return depth, outlines, isles, rects, ranges, volcano_index, masses, land, nx, nz


SKELETON_ORDER = {name: index for index, (name, _) in enumerate(SKELETON)}


def _strait_id(name):
    return name.lower().replace(' ', '_')


def signed_depth(land, nx, nz):
    """Metres from each sample to the coast: + inland, - at sea (chamfer)."""
    big = 1e9
    out = [big] * (nx * nz)
    heap = []
    for k in range(nx * nz):
        i, j = k % nx, k // nx
        for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
            if 0 <= a < nx and 0 <= b < nz and land[b * nx + a] != land[k]:
                out[k] = CELL / 2
                heapq.heappush(heap, (CELL / 2, k))
                break
    steps = [(1, 0, CELL), (-1, 0, CELL), (0, 1, CELL), (0, -1, CELL),
             (1, 1, CELL * 1.4142), (1, -1, CELL * 1.4142), (-1, 1, CELL * 1.4142), (-1, -1, CELL * 1.4142),
             (2, 1, CELL * 2.2361), (2, -1, CELL * 2.2361), (-2, 1, CELL * 2.2361), (-2, -1, CELL * 2.2361),
             (1, 2, CELL * 2.2361), (1, -2, CELL * 2.2361), (-1, 2, CELL * 2.2361), (-1, -2, CELL * 2.2361)]
    while heap:
        d, k = heapq.heappop(heap)
        if d > out[k] or d > 300: continue
        i, j = k % nx, k // nx
        for di, dj, cost in steps:
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < nz:
                q = b * nx + a
                if land[q] == land[k] and d + cost < out[q]:
                    out[q] = d + cost
                    heapq.heappush(heap, (d + cost, q))
    return [min(out[k], 300.0) * (1 if land[k] else -1) for k in range(nx * nz)]


def components(land, nx, nz):
    label = [-1] * (nx * nz)
    masses = []
    for start in range(nx * nz):
        if not land[start] or label[start] >= 0: continue
        cells, stack = [], [start]
        label[start] = len(masses)
        while stack:
            k = stack.pop()
            cells.append(k)
            i, j = k % nx, k // nx
            for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if 0 <= a < nx and 0 <= b < nz and land[b * nx + a] and label[b * nx + a] < 0:
                    label[b * nx + a] = len(masses)
                    stack.append(b * nx + a)
        masses.append(set(cells))
    return masses


def name_masses(masses, nx, volcano, isles):
    """Each landmass takes the name of the skeleton it covers most, or of the
    seeded isle it grew from; a skeleton name used twice gets a number."""
    names, used = [], {}
    for cells in sorted(masses, key=len, reverse=True):
        votes = {}
        for k in cells:
            p = (ORIGIN[0] + (k % nx) * CELL, ORIGIN[1] + (k // nx) * CELL)
            for name, rects in SKELETON:
                if any(tb._inside(p, r) for r in rects): votes[name] = votes.get(name, 0) + 1
        if votes: name = max(votes, key=lambda n: (votes[n], n))
        elif not isles: name = 'Islet'
        else:
            best = min(range(len(isles)), key=lambda n: min(math.hypot(ORIGIN[0] + (k % nx) * CELL - isles[n][0], ORIGIN[1] + (k // nx) * CELL - isles[n][1]) for k in list(cells)[:50]))
            name = NEW_ISLES[best]
        used[name] = used.get(name, 0) + 1
        names.append(name if used[name] == 1 else '%s %d' % (name, used[name]))
    return names


def cover_rects(cells, nx):
    """The landmass's samples as few rectangles: runs along X merged down Z."""
    rows = {}
    for k in cells: rows.setdefault(k // nx, []).append(k % nx)
    open_runs, out = {}, []
    for j in sorted(rows) + [None]:
        runs = []
        if j is not None:
            xs = sorted(rows[j])
            start = prev = xs[0]
            for x in xs[1:] + [None]:
                if x is not None and x == prev + 1:
                    prev = x
                    continue
                runs.append((start, prev))
                if x is not None: start = prev = x
        nxt = {}
        for run in runs:
            if run in open_runs and open_runs[run][1] == j - 1: nxt[run] = (open_runs[run][0], j)
            else: nxt[run] = (j, j)
        for run, (j0, j1) in open_runs.items():
            if nxt.get(run, (None,))[0] != j0:
                out.append((ORIGIN[0] + (run[0] - 0.5) * CELL, ORIGIN[1] + (j0 - 0.5) * CELL, (run[1] - run[0] + 1) * CELL, (j1 - j0 + 1) * CELL))
        open_runs = nxt
    return out


def outline(cells, depth, nx, nz):
    """The landmass's coast for the maps: marching squares on the depth grid,
    joined into rings, the longest kept and thinned to about 60 m."""
    def value(i, j):
        if 0 <= i < nx and 0 <= j < nz and (j * nx + i) in cells: return depth[j * nx + i]
        return -CELL / 2 if not (0 <= i < nx and 0 <= j < nz) else min(depth[j * nx + i], -CELL / 2)
    xs = [k % nx for k in cells]
    zs = [k // nx for k in cells]
    links = {}
    for j in range(min(zs) - 1, max(zs) + 1):
        for i in range(min(xs) - 1, max(xs) + 1):
            c = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            v = [value(*q) for q in c]
            edges = []
            for e in range(4):
                a, b = c[e], c[(e + 1) % 4]
                va, vb = v[e], v[(e + 1) % 4]
                if (va > 0) != (vb > 0):
                    t = va / (va - vb)
                    edges.append((e, (round(ORIGIN[0] + (a[0] + (b[0] - a[0]) * t) * CELL, 1), round(ORIGIN[1] + (a[1] + (b[1] - a[1]) * t) * CELL, 1))))
            if len(edges) == 2: pairs = [(edges[0][1], edges[1][1])]
            elif len(edges) == 4:
                pairs = [(edges[0][1], edges[1][1]), (edges[2][1], edges[3][1])] if v[0] > 0 else [(edges[0][1], edges[3][1]), (edges[1][1], edges[2][1])]
            else: pairs = []
            for p, q in pairs:
                links.setdefault(p, []).append(q)
                links.setdefault(q, []).append(p)
    rings, done = [], set()
    for start in links:
        if start in done: continue
        ring, at, last = [start], start, None
        done.add(start)
        while True:
            nxt = [q for q in links[at] if q != last and q not in done]
            if not nxt: break
            last, at = at, nxt[0]
            done.add(at)
            ring.append(at)
        rings.append(ring)
    ring = max(rings, key=len)
    thin = [ring[0]]
    for p in ring[1:]:
        if math.hypot(p[0] - thin[-1][0], p[1] - thin[-1][1]) >= 60.0: thin.append(p)
    return [[p[0], p[1]] for p in thin]


def write_json(depth, outlines, isles):
    data = bytes(max(0, min(255, int(round(d / DEPTH_STEP)) + 128)) for d in depth)
    out = {
        'note': 'Patch 2.9 item 6A: natural world land, baked by tools/world_layout/natural_land.py from seed %d. Do not edit by hand.' % SEED,
        'seed': SEED, 'cell_m': CELL, 'origin': list(ORIGIN), 'count': list(COUNT), 'depth_step_m': DEPTH_STEP,
        'depth_zero': 128, 'new_isles': isles, 'depth': base64.b64encode(data).decode('ascii'), 'outlines': outlines,
    }
    (ROOT / 'features/world/natural_land.json').write_text(json.dumps(out, separators=(',', ':')) + '\n', encoding='utf-8')


def write_progression(rects, ranges, volcano_index):
    path = ROOT / 'features/game/progression.gd'
    source = path.read_text(encoding='utf-8')
    lines = ['const LAND = [']
    for name, start, end in ranges:
        lines.append('\t# %s' % name)
        for r in rects[start:end]: lines.append('\tRect2(%g, %g, %g, %g),' % r)
    lines.append(']')
    lines.append('## The named landmasses, as [name, first LAND index, end index).')
    lines.append('const LANDMASSES = [')
    for name, start, end in ranges: lines.append('\t["%s", %d, %d],' % (name, start, end))
    lines.append(']')
    block = '\n'.join(lines)
    source = re.sub(r'(## BEGIN NATURAL LAND[^\n]*\n).*?(\n## END NATURAL LAND)', lambda m: m.group(1) + block + m.group(2), source, flags=re.S)
    source = re.sub(r'("land": )\d+(, "at": Vector2)', lambda m: m.group(1) + str(volcano_index) + m.group(2), source)
    path.write_text(source, encoding='utf-8')


def write_placement(placed):
    """Item 6B: the moved ports (with their old spots), the volcano, the
    bridges' crossings and the region centres."""
    path = ROOT / 'features/game/progression.gd'
    source = path.read_text(encoding='utf-8')
    for port in placed['world']:
        if port['id'] not in LEGACY: continue
        (ox, _, oz), old_side = LEGACY[port['id']]
        x, _, z = port['at']
        entry = '{"id": "%s", "at": Vector3(%g, 0, %g), "drop_side": %.1f, "was": Vector3(%g, 0, %g), "was_side": %.1f}' % (port['id'], x, z, port['drop_side'], ox, oz, old_side)
        source = re.sub(r'\{"id": "%s", "at": [^}]*\}' % port['id'], lambda m: entry, source, count=1)
    vx, vz = placed['volcano']
    source = re.sub(r'(const VOLCANO = \{[^}]*"at": Vector2\()[^)]*', lambda m: m.group(1) + '%g, %g' % (vx, vz), source)
    for strait_id, (bx, bz) in placed['bridges'].items():
        source = re.sub(r'("strait": "%s", "style": "\w+", "at": Vector2\()[^)]*' % strait_id, lambda m: m.group(1) + '%g, %g' % (bx, bz), source)
    path.write_text(source, encoding='utf-8')
    for name, (cx, cz) in placed['regions'].items():
        biome = ROOT / ('features/sky/%s_biome.gd' % name)
        text = re.sub(r'const CENTRE := Vector2\([^)]*\)', 'const CENTRE := Vector2(%g, %g)' % (cx, cz), biome.read_text(encoding='utf-8'), count=1)
        biome.write_text(text, encoding='utf-8')


def preview(land, nx, nz, geo):
    """A PNG of the land (green), ports (red) and lanes (white) for a look."""
    import zlib, struct
    px = bytearray()
    for j in reversed(range(nz)):
        px.append(0)
        for i in range(nx):
            px += bytes((90, 170, 80) if land[j * nx + i] else (30, 140, 210))
    for p in geo['world']:
        i, j = int((p['at'][0] - ORIGIN[0]) / CELL), int((p['at'][2] - ORIGIN[1]) / CELL)
        for di in range(-3, 4):
            for dj in range(-3, 4):
                a, b = i + di, nz - 1 - (j + dj)
                if 0 <= a < nx and 0 <= b < nz: px[b * (nx * 3 + 1) + 1 + a * 3:b * (nx * 3 + 1) + 4 + a * 3] = bytes((230, 40, 40))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', nx, nz, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(px))) + chunk(b'IEND', b'')
    Path('/tmp/natural_land_preview.png').write_bytes(png)


if __name__ == '__main__':
    main()
