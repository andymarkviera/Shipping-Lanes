"""Patch 2.9.1 item 6: the polar ice caps, baked from one fixed seed.

The world wraps north-south, so its top and bottom ends are one line: the
north/south edge. The ice cap lies along that edge all the way round the
world, with an irregular coast, bays, headlands and calved floes on both its
north and south sides. A tongue of the cap runs out to the North Pole port
and backs its quay; the South Pole port keeps an ice island behind its quay
(its quay runs away from the cap, and the route budget needs the water south
of it). Neither port moves.

Bent round what must stay: both ports' berths, approach and heavy drop area
are open water; the sea lanes' points, the land and Ember Isle keep their sea
room. Patch 4.0.3 item 2: on the globe the edge is both poles, so the cap is
solid ice for POLE_SOLID_M either side of it, all the way round: no lead
crosses the edge any more (they showed as open wedges and streaks running
into the pole, and a channel a ship could sail through). Icebergs the ice would swallow are moved to
the nearest open polar water.

Writes:
  features/world/polar_ice.json   the signed coast depth grid (metres inland,
                                  + ice / - sea) and the outlines for the maps
  features/game/progression.gd    ICE_SHELVES (the solid cover blocks, in 20
                                  chunks), ICE_CHUNKS and the moved icebergs

Standard library only. Same seed, same ice, on every machine:

  python3 tools/world_layout/polar_ice.py            (add --preview for a PPM)
"""
import base64
import heapq
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import natural_land as nl  # noqa: E402
import traversal_budget as tb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SEED = 2916
WRAP = 4000.0 * math.pi
NX = 500
HALF = 185
NZ = HALF * 2
CELL = WRAP / NX
COLUMNS = 10
COLUMN_CELLS = NX // COLUMNS
DEPTH_STEP = 2.0
# The cap's reach from the edge, metres, before the coast noise.
CAP_M = 800.0
CAP_NOISE_M = 560.0
CAP_MAX_M = 1300.0
LEAD_HALF_M = 165.0
# Patch 4.0.3 item 2: solid ice this far either side of the edge (the poles).
POLE_SOLID_M = 800.0
BERG_GAP_M = 190.0
# Patch 3.2: the North Pole port sits in an ice field reached only through
# narrow winding straits (each also a run of sea-lane points in progression.gd).
STRAIT_HALF_M = 115.0
NORTH_STRAITS = [
    # West: from the basin along the Ironreach headland to Needle Gut's water.
    [(3640, 3450), (3420, 3560), (3100, 3640), (2800, 3720), (2400, 3550), (2000, 3680), (1650, 3570), (1250, 3650), (950, 3620)],
    # South: down between Ironreach and the round island to Kelp Strait.
    [(4250, 2480), (4080, 2300), (4230, 2100), (4100, 1900), (4230, 1700)],
    # East: out to the open eastern sea.
    [(4750, 3300), (5150, 3050), (5500, 3000), (5850, 3250), (6150, 3150), (6400, 2850)],
]
# The basin round the port: three overlapping bays (X, Z, radius), together
# well round its berths, approach and heavy drop area.
BASIN = [(3900.0, 4250.0, 690.0), (4300.0, 3550.0, 770.0), (4300.0, 3000.0, 660.0), (3860.0, 2760.0, 340.0)]
FIELD_WEST_M = 1250.0
FIELD_EAST_M = 6600.0
# Patch 3.2 item 3: seeded glaciers and extra icebergs in the southern sea.
GLACIER_TRIES = 1500
EXTRA_BERGS = 25
ORIGINAL_BERGS = 20


def periodic(noise, x, z, scale, octaves, x0):
    """Fractal noise that repeats every WRAP metres along X."""
    u = (x - x0) % WRAP
    return ((WRAP - u) * noise.fbm(u, z, scale, octaves) + u * noise.fbm(u - WRAP, z, scale, octaves)) / WRAP


def bake(geo, glaciers=()):
    cx, cz = geo['centre']
    x0, edge_n, edge_s = cx - WRAP / 2, cz + WRAP / 2, cz - WRAP / 2
    coast, fine, floe = nl.Noise(SEED), nl.Noise(SEED + 1), nl.Noise(SEED + 2)
    ports = {p['id']: p for p in geo['world']}
    north, south = ports['port_north_pole']['at'], ports['port_south_pole']['at']
    # Everything below works in the north copy: z runs on past the edge, so
    # a southern spot is its z plus one world.
    up = lambda z: z + WRAP if z < cz else z
    lanes = [(x, up(z)) for x, z in geo['lanes']]
    land = [(r[0], up(r[1]), r[2], r[3]) for r in geo['land']]
    land = [r for r in land if r[1] + r[3] > edge_n - HALF * CELL - 500.0 and r[1] < edge_n + HALF * CELL + 500.0]
    # Patch 4.0.3 item 2: no leads across the edge (it is the pole on the globe).
    leads = []
    # Patch 3.2: a natural glacier tongue from the cap backs the South Pole
    # quay (it replaces the old rectangular island).
    # It spills off Hearthland's south coast, clear of the lead and the route.
    tongue = [(south[0] + 230.0, up(south[2] + 140.0)), (south[0] + 480.0, up(south[2] + 60.0)), (south[0] + 760.0, up(south[2] + 120.0)),
              (south[0] + 1050.0, up(south[2] + 40.0))]
    strait_points = {p for path in NORTH_STRAITS for p in path}

    def short(dx):
        return tb._short(dx, WRAP)

    def lead_gap(p, lead):
        # The lead's copy nearest the point along X.
        (ax, az), (bx, bz) = lead
        shift = round((p[0] - (ax + bx) / 2) / WRAP) * WRAP
        return nl.segment_sdf(p, (ax + shift, az), (bx + shift, bz))

    def strait_gap(p):
        return min(nl.segment_sdf(p, path[n], path[n + 1]) for path in NORTH_STRAITS for n in range(len(path) - 1))

    def in_field(x, z, wobble):
        """Patch 3.2: the North Pole ice field, from the cap down to Ironreach."""
        noise = periodic(coast, x, z, 900.0, 3, x0)
        ragged = periodic(floe, x, z, 480.0, 3, x0)
        west, east = FIELD_WEST_M + 140.0 * noise + 260.0 * ragged, FIELD_EAST_M + 160.0 * noise - 260.0 * ragged
        if not west < x < east: return False
        # Lower round the port's south strait and the island beside it, higher
        # towards both ends.
        base = 2300.0 - 600.0 * max(0.0, 1.0 - abs(x - 4150.0) / 1000.0) + 130.0 * noise + 60.0 * wobble
        base += 2.4 * max(0.0, west + 700.0 - x) + 2.4 * max(0.0, x - (east - 700.0))
        return z > base

    def is_ice(x, z):
        p = (x, z)
        s = abs(z - edge_n)
        northern = z < edge_n
        wobble = periodic(fine, x, z, 420.0, 3, x0)
        reach = CAP_M + CAP_NOISE_M * periodic(coast, x, z, 1150.0, 4, x0) + 190.0 * wobble
        reach = min(reach, CAP_MAX_M)
        # Patch 4.0.3 item 2: the pole itself is always under the cap.
        if s < POLE_SOLID_M: return True
        if not northern:
            # The South Pole port's approach and drop area reach far south.
            away = max(0.0, south[0] - 1050.0 - x, x - (south[0] + 150.0))
            reach = min(reach, 720.0 + away * 0.9)
        ice = s < reach
        # Floes calved off the coast.
        if not ice and s < reach + 300.0 and periodic(floe, x, z, 170.0, 2, x0) > 0.36: ice = True
        cap = ice
        field = northern and in_field(x, z, wobble)
        if field: ice = True
        if not northern:
            for gx, gz, gr, ga, gs in glaciers:
                dx, dz = short(x - gx), z - gz
                if abs(dx) > gr * 2.6 or abs(dz) > gr * 2.6: continue
                # An elongated, lumpy floe of glacier ice at its own heading.
                along, across = dx * math.cos(ga) + dz * math.sin(ga), -dx * math.sin(ga) + dz * math.cos(ga)
                gap = math.hypot(along / gs, across * gs)
                if gap < gr * (1.0 + 0.38 * periodic(floe, x, z, 150.0, 2, x0) + 0.15 * wobble): ice = True
        if northern:
            # The tongue out to the North Pole port, behind its quay.
            spine = [(north[0] - 400.0, north[2] + 30.0), (north[0] - 560.0, north[2] + 520.0), (north[0] - 430.0, north[2] + 980.0), (north[0] - 520.0, edge_n - 850.0)]
            girth = 300.0 + 150.0 * periodic(coast, x, z, 520.0, 3, x0) + 60.0 * wobble
            if x < north[0] - 85.0 and min(nl.segment_sdf(p, spine[n], spine[n + 1]) for n in range(3)) < girth: ice = True
            if north[0] - 250.0 <= x < north[0] - 85.0 and north[2] - 290.0 <= z <= north[2] + 600.0: ice = True
        else:
            girth = 165.0 + 45.0 * periodic(coast, x, z, 520.0, 3, x0) + 30.0 * wobble
            if x > south[0] + 85.0 and min(nl.segment_sdf(p, tongue[n], tongue[n + 1]) for n in range(len(tongue) - 1)) < girth: ice = True
        if not ice: return False
        # Open water that must stay.
        if northern and not field and z < north[2] - 310.0: return False
        # The port's basin in the field: berths, approach and heavy drop area.
        if northern and (x >= north[0] - 85.0 or not north[2] - 350.0 < z < north[2] + 700.0) and any(
                math.hypot(x - bx, z - bz) < br + 70.0 * periodic(floe, x, z, 260.0, 2, x0) + 30.0 * wobble for bx, bz, br in BASIN): return False
        if northern and strait_gap(p) < STRAIT_HALF_M + 30.0 * periodic(floe, x, z, 300.0, 2, x0) + 15.0 * wobble: return False
        if not northern and x <= south[0] + 85.0 and x > south[0] - 1050.0 and z > up(south[2] - 1480.0): return False
        if not northern and z > up(south[2] + 300.0): return False
        for lead in leads:
            if lead_gap(p, lead) < LEAD_HALF_M + 70.0 * periodic(floe, x, z, 380.0, 2, x0) + 30.0 * wobble: return False
        # Patch 3.2: the straight eastern lead is gone (it drew a streak from the pole).
        if any(math.hypot(short(x - lx), z - lz) < 230.0 for lx, lz in lanes if (lx, lz) not in strait_points): return False
        # The cap keeps well off the land; the ports' own ice stands where the
        # old shelves stood, nearer to it.
        quay_glacier = not northern and x > south[0] + 85.0 and min(nl.segment_sdf(p, tongue[n], tongue[n + 1]) for n in range(len(tongue) - 1)) < 260.0
        room = 0.0 if field or quay_glacier else (480.0 if cap else 140.0)
        if any(nl.rect_sdf((r[0] + r[2] / 2 + short(x - r[0] - r[2] / 2), z), r) < room for r in land): return False
        return True

    ice = [False] * (NX * NZ)
    for j in range(NZ):
        z = edge_n + (j - HALF + 0.5) * CELL
        for i in range(NX):
            ice[j * NX + i] = is_ice(x0 + (i + 0.5) * CELL, z)
    # Specks melt and ponds freeze over: no floe under four samples, no lake.
    for cells in components(ice, True):
        if len(cells) < 4:
            for k in cells: ice[k] = False
    for cells in components(ice, False):
        if len(cells) < 400 and not any(k // NX in (0, NZ - 1) for k in cells):
            for k in cells: ice[k] = True
    depth = signed_depth(ice)
    chunks, rects = [], []
    outlines = []
    for side in range(2):
        for column in range(COLUMNS):
            own = [k for k in range(NX * NZ) if ice[k] and (k // NX >= HALF) == bool(side) and (k % NX) // COLUMN_CELLS == column]
            first = len(rects)
            rects += cover_rects(own, x0, edge_n, edge_s)
            chunks.append((first, len(rects)))
            outlines += chunk_outlines(set(own), x0, edge_n, edge_s)
    return dict(ice=ice, depth=depth, rects=rects, chunks=chunks, outlines=outlines, x0=x0, edge_n=edge_n, edge_s=edge_s, leads=leads, glaciers=glaciers)


def route_segments(geo):
    """Every leg of every port-to-port sea route, as segments in world X/Z."""
    gates = [(p['at'][0], p['at'][2] - geo['gate']) for p in geo['world']]
    out = []
    for a in range(len(gates)):
        for b in range(a + 1, len(gates)):
            _, path = tb.sea_route(geo, gates[a], gates[b])
            for n in range(len(path) - 1):
                p, q = path[n], path[n + 1]
                out.append((p, (p[0] + tb._short(q[0] - p[0], WRAP), p[1] + tb._short(q[1] - p[1], WRAP))))
    return out


def route_gap(segments, x, z):
    """Metres from (x, z) to the nearest route leg, round the world both ways."""
    best = 1e9
    for a, b in segments:
        for sx in (-WRAP, 0.0, WRAP):
            for sz in (-WRAP, 0.0, WRAP):
                best = min(best, nl.segment_sdf((x + sx, z + sz), a, b))
    return best


def ember(geo):
    """Ember Isle's land blocks: the volcano wants open sea all round them."""
    return [geo['land'][n] for name, first, end in geo['masses'] if name == 'Ember Isle' for n in range(first, end)]


def plan(geo):
    """Patch 3.2: bake in two stages so a re-bake gives the same ice. The sea
    routes are found round the land and the glacier-free ice only (no
    icebergs): nothing this script writes changes them. The glaciers and the
    extra icebergs then keep clear of those routes."""
    first = bake(geo)
    segments = route_segments(dict(geo, ice=first['rects'], bergs=[]))
    baked = bake(geo, scatter_glaciers(geo, first['edge_n'], segments))
    baked['segments'] = segments
    return baked


def scatter_glaciers(geo, edge_n, segments):
    """Patch 3.2 item 3: seeded glaciers of varied size in the southern polar
    sea (north copy: z past the edge), clear of every sea route, the ports'
    approaches and the land. Same seed, same glaciers, on every machine."""
    import random
    rng = random.Random(SEED + 32)
    cx, cz = geo['centre']
    south = next(p for p in geo['world'] if p['id'] == 'port_south_pole')['at']
    out = []
    for _ in range(GLACIER_TRIES):
        x = cx + rng.uniform(-WRAP / 2, WRAP / 2)
        r = rng.uniform(90.0, 300.0)
        stretch = rng.uniform(1.0, 1.9)
        angle = rng.uniform(0.0, math.pi)
        z = edge_n + rng.uniform(1100.0 + r, 2500.0)
        real = z - WRAP
        reach = r * 1.4 * stretch
        if route_gap(segments, x, real) < reach + 170.0: continue
        if any(math.hypot(tb._short(x - p['at'][0], WRAP), real - p['at'][2]) < reach + 800.0 for p in geo['world']): continue
        if math.hypot(tb._short(x - south[0], WRAP), real - south[2]) < reach + 1300.0: continue
        if any(nl.rect_sdf((x, real), q) < reach + 220.0 for q in geo['land']): continue
        if any(nl.rect_sdf((x, real), q) < reach + 600.0 for q in ember(geo)): continue
        if any(math.hypot(tb._short(x - g[0], WRAP), z - g[1]) < reach + g[2] * 1.4 * g[4] + 160.0 for g in out): continue
        out.append((x, z, r, angle, stretch))
    return out


def components(mask, value):
    label = [False] * (NX * NZ)
    out = []
    for start in range(NX * NZ):
        if mask[start] != value or label[start]: continue
        cells, stack = [], [start]
        label[start] = True
        while stack:
            k = stack.pop()
            cells.append(k)
            i, j = k % NX, k // NX
            for a, b in (((i + 1) % NX, j), ((i - 1) % NX, j), (i, j + 1), (i, j - 1)):
                if 0 <= b < NZ and mask[b * NX + a] == value and not label[b * NX + a]:
                    label[b * NX + a] = True
                    stack.append(b * NX + a)
        out.append(cells)
    return out


def signed_depth(ice):
    """Metres from each sample to the coast: + on ice, - at sea (chamfer),
    round the world along X."""
    big = 1e9
    out = [big] * (NX * NZ)
    heap = []
    for k in range(NX * NZ):
        i, j = k % NX, k // NX
        for a, b in (((i + 1) % NX, j), ((i - 1) % NX, j), (i, j + 1), (i, j - 1)):
            if (ice[b * NX + a] if 0 <= b < NZ else False) != ice[k]:
                out[k] = CELL / 2
                heapq.heappush(heap, (CELL / 2, k))
                break
    steps = [(di, dj, CELL * math.hypot(di, dj)) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1),
             (2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2))]
    while heap:
        d, k = heapq.heappop(heap)
        if d > out[k] or d > 300: continue
        i, j = k % NX, k // NX
        for di, dj, cost in steps:
            a, b = (i + di) % NX, j + dj
            if 0 <= b < NZ:
                q = b * NX + a
                if ice[q] == ice[k] and d + cost < out[q]:
                    out[q] = d + cost
                    heapq.heappush(heap, (d + cost, q))
    depth = [min(out[k], 300.0) * (1 if ice[k] else -1) for k in range(NX * NZ)]
    # Two soft passes take the samples' stair steps out of slanting coasts.
    for _ in range(2):
        rows = [[(depth[j * NX + (i - 1) % NX] + 2 * depth[j * NX + i] + depth[j * NX + (i + 1) % NX]) / 4 for i in range(NX)] for j in range(NZ)]
        depth = [(rows[max(j - 1, 0)][i] + 2 * rows[j][i] + rows[min(j + 1, NZ - 1)][i]) / 4 for j in range(NZ) for i in range(NX)]
    return depth


def cover_rects(cells, x0, edge_n, edge_s):
    """One chunk's samples as few rectangles: runs along X merged down Z."""
    rows = {}
    for k in cells: rows.setdefault(k // NX, []).append(k % NX)
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
                z = (edge_s if j0 >= HALF else edge_n) + (j0 - HALF) * CELL
                out.append((round(x0 + run[0] * CELL, 2), round(z, 2), round((run[1] - run[0] + 1) * CELL, 2), round((j1 - j0 + 1) * CELL, 2)))
        open_runs = nxt
    return out


def chunk_outlines(own, x0, edge_n, edge_s):
    """The chunk's pieces for the maps: each piece's outer edge traced along
    the sample squares, so neighbouring chunks meet exactly, then thinned."""
    if not own: return []
    south = next(iter(own)) // NX >= HALF
    seen, rings = set(), []
    for start in sorted(own):
        if start in seen: continue
        piece, stack = set(), [start]
        seen.add(start)
        while stack:
            k = stack.pop()
            piece.add(k)
            i, j = k % NX, k // NX
            for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                q = b * NX + a
                if 0 <= a < NX and 0 <= b < NZ and q in own and q not in seen:
                    seen.add(q)
                    stack.append(q)
        # Directed edges with the piece on the left, joined corner to corner.
        nxt = {}
        for k in piece:
            i, j = k % NX, k // NX
            for (a, b), edge in (((i, j - 1), ((i, j), (i + 1, j))), ((i + 1, j), ((i + 1, j), (i + 1, j + 1))),
                                 ((i, j + 1), ((i + 1, j + 1), (i, j + 1))), ((i - 1, j), ((i, j + 1), (i, j)))):
                if not (0 <= a < NX and 0 <= b < NZ and (b * NX + a) in piece): nxt.setdefault(edge[0], []).append(edge[1])
        while nxt:
            at = first = min(nxt)
            ring = []
            while True:
                ring.append(at)
                options = nxt[at]
                step = options.pop()
                if not options: del nxt[at]
                at = step
                if at == first: break
            points = [(x0 + i * CELL, (edge_s if south else edge_n) + (j - HALF) * CELL) for i, j in ring]
            rings.append([[round(x, 1), round(z, 1)] for x, z in thin(points, 22.0)])
    return [ring for ring in rings if len(ring) >= 3]


def thin(points, tolerance):
    """Douglas-Peucker on a closed ring."""
    if len(points) < 5: return points
    far = max(range(len(points)), key=lambda n: math.hypot(points[n][0] - points[0][0], points[n][1] - points[0][1]))

    def simplify(run):
        keep = [0, len(run) - 1]
        stack = [(0, len(run) - 1)]
        while stack:
            a, b = stack.pop()
            worst, index = 0.0, -1
            for n in range(a + 1, b):
                gap = nl.segment_sdf(run[n], run[a], run[b])
                if gap > worst: worst, index = gap, n
            if worst > tolerance:
                keep.append(index)
                stack += [(a, index), (index, b)]
        return [run[n] for n in sorted(keep)]

    return simplify(points[:far + 1])[:-1] + simplify(points[far:] + [points[0]])[:-1]


def move_bergs(geo, baked):
    """Icebergs the ice would swallow or crowd go to the nearest open polar
    water: clear of the ice, the land, the ports, the leads and each other."""
    cx, cz = geo['centre']
    depth, x0, edge_n = baked['depth'], baked['x0'], baked['edge_n']
    up = lambda z: z + WRAP if z < cz else z

    def ice_gap(x, z):
        j = math.floor((z - edge_n) / CELL + HALF)
        if not 0 <= j < NZ: return 300.0
        return -depth[j * NX + int((x - x0) // CELL) % NX]

    def fits(x, z, r, others, pad):
        # `pad` 0 is what the checks ask of a berg that stays; a moved one
        # keeps more room.
        if ice_gap(x, z) < min(r + BERG_GAP_M, 290.0): return False
        if any(ice_gap(x + dx, z + dz) < (130.0 if pad == 20.0 else 200.0) for dx in (-150, 0, 150) for dz in (-150, 0, 150)): return False
        if abs(z - edge_n) > 2500.0: return False
        if any(lead_clear(x, z, lead) < r + 220.0 + pad for lead in baked['leads']): return False
        # Only new icebergs need this: the routes were found round the old ones.
        if pad == 20.0 and route_gap(segments, x, z - WRAP if z > edge_n else z) < r + 140.0: return False
        if any(math.hypot(tb._short(x - lx, WRAP), z - up(lz)) < r + 120.0 + pad * 2 for lx, lz in geo['lanes']): return False
        if any(nl.rect_sdf((x, z), (q[0], up(q[1]), q[2], q[3])) < r + 160.0 + pad * 5 for q in geo['land']): return False
        # Ember Isle's volcano keeps open sea round it (tools/volcano_check.gd).
        if any(nl.rect_sdf((x, z), (q[0], up(q[1]), q[2], q[3])) < r + 900.0 for q in ember(geo)): return False
        for p in geo['world']:
            lx, lz = tb._short(x - p['at'][0], WRAP), z - up(p['at'][2])
            if math.hypot(lx, lz) < r + 710.0 + pad * 2: return False
            if 290 - pad - r < lx * p['drop_side'] < 1010 + pad + r and -1360 - pad - r < lz < -640 + pad + r: return False
        return all(math.hypot(tb._short(x - ox, WRAP), z - up(oz)) > r + orad + 60.0 + pad * 3 for ox, orad, oz in others)

    def lead_clear(x, z, lead):
        (ax, az), (bx, bz) = lead
        return min(nl.segment_sdf((x + shift, z), (ax, az), (bx, bz)) for shift in (-WRAP, 0.0, WRAP))

    segments = baked['segments']
    # Only the original icebergs move; a re-bake re-adds the extra ones.
    geo = dict(geo, bergs=geo['bergs'][:ORIGINAL_BERGS])
    kept = [b for b in geo['bergs'] if fits(b[0], up(b[2]), b[1], [o for o in geo['bergs'] if o != b], 0.0)]
    out, moved = [], 0
    for berg in geo['bergs']:
        if berg in kept:
            out.append(berg)
            continue
        others = kept + [o for o in out if o not in kept]
        x, r, z = berg[0], berg[1], up(berg[2])
        found = None
        # Patch 3.2: the North Pole ice field swallows more of them, so the
        # search reaches further, round the world if it must.
        for ring in range(1, 125):
            spots = [(x + ring * 100.0 * math.cos(a * math.pi / 24), z + ring * 100.0 * math.sin(a * math.pi / 24)) for a in range(48)]
            spots = [q for q in spots if fits(q[0], q[1], r, others, 100.0 if ring < 60 else 60.0)]
            if spots:
                found = min(spots, key=lambda q: (abs(q[1] - z), q[0]))
                break
        if found is None: raise SystemExit('no open water for iceberg %s' % (berg,))
        fx = cx + tb._short(found[0] - cx, WRAP)
        fz = found[1] - WRAP if found[1] > edge_n else found[1]
        out.append((float(round(fx / 10) * 10), r, float(round(fz / 10) * 10)))
        moved += 1
    # Patch 3.2 item 3: EXTRA_BERGS more, seeded, of varied size, scattered
    # through the southern polar sea. Written after the old ones, so the old
    # icebergs keep their index.
    import random
    rng = random.Random(SEED + 77)
    added = 0
    for _ in range(20000):
        if added == EXTRA_BERGS: break
        r = float(rng.choice((30, 35, 40, 45, 50, 55, 60, 70, 80, 90)))
        x, z = cx + rng.uniform(-WRAP / 2, WRAP / 2), edge_n + rng.uniform(300.0, 2500.0)
        if not fits(x, z, r, out, 20.0): continue
        out.append((float(round(x / 10) * 10), r, float(round((z - WRAP) / 10) * 10)))
        added += 1
    if added < EXTRA_BERGS: raise SystemExit('only %d of %d extra icebergs found open water' % (added, EXTRA_BERGS))
    return out, moved


def problems(geo, baked):
    """What the Godot checks ask of the two polar ports, asked here first."""
    rects = baked['rects']
    solid = lambda p: any(tb._inside(p, r) for r in rects)
    hits = lambda a: any(r[0] < a[0] + a[2] and a[0] < r[0] + r[2] and r[1] < a[1] + a[3] and a[1] < r[1] + r[3] for r in rects)
    out = []
    for port in geo['world']:
        x, _, z = port['at']
        side = -port['drop_side']
        if 'pole' in port['id'] and not solid((x + side * 105, z + 100)): out.append('%s has no ice behind its quay' % port['id'])
        if hits((min(x + side * 15, x - side * 350), z - 1400, 365, 2200)): out.append('%s berths or approach iced in' % port['id'])
        if hits((min(x + port['drop_side'] * 450, x + port['drop_side'] * 850) - 150, z - 1350, 700, 700)): out.append('%s drop area iced in' % port['id'])
    if any(r[2] > WRAP / COLUMNS + 1 for r in rects): out.append('a block is wider than its chunk')
    return out


def write_json(baked):
    data = bytes(max(0, min(255, int(round(d / DEPTH_STEP)) + 128)) for d in baked['depth'])
    out = {
        'note': 'Patch 2.9.1 item 6: polar ice caps, baked by tools/world_layout/polar_ice.py from seed %d. Do not edit by hand.' % SEED,
        'seed': SEED, 'cell_m': CELL, 'count': [NX, NZ], 'half_rows': HALF, 'depth_step_m': DEPTH_STEP, 'depth_zero': 128,
        'depth': base64.b64encode(data).decode('ascii'), 'outlines': baked['outlines'],
    }
    (ROOT / 'features/world/polar_ice.json').write_text(json.dumps(out, separators=(',', ':')) + '\n', encoding='utf-8')


def write_progression(baked, bergs):
    path = ROOT / 'features/game/progression.gd'
    source = path.read_text(encoding='utf-8')
    lines = ['const ICE_SHELVES = [']
    for index, (first, end) in enumerate(baked['chunks']):
        lines.append('\t# %s chunk %d' % ('South' if index >= COLUMNS else 'North', index % COLUMNS))
        for r in baked['rects'][first:end]: lines.append('\tRect2(%g, %g, %g, %g),' % r)
    lines.append(']')
    lines.append('## The chunks, as [first ICE_SHELVES index, end index): ten columns west to')
    lines.append('## east on the north side of the edge, then ten on the south side.')
    lines.append('const ICE_CHUNKS = [%s]' % ', '.join('[%d, %d]' % c for c in baked['chunks']))
    source, count = re.subn(r'(## BEGIN POLAR ICE[^\n]*\n).*?(\n## END POLAR ICE)', lambda m: m.group(1) + '\n'.join(lines) + m.group(2), source, flags=re.S)
    if count != 1: raise SystemExit('progression.gd has no POLAR ICE block')
    rows = ['\t' + ', '.join('Vector3(%g, %g, %g)' % b for b in bergs[n:n + 4]) + ',' for n in range(0, len(bergs), 4)]
    source, count = re.subn(r'(\nconst ICEBERGS = \[\n).*?(\n\])', lambda m: m.group(1) + '\n'.join(rows) + m.group(2), source, count=1, flags=re.S)
    if count != 1: raise SystemExit('progression.gd has no ICEBERGS list')
    path.write_text(source, encoding='utf-8')


def preview(geo, baked, bergs):
    ice, depth = baked['ice'], baked['depth']
    rows = []
    for j in range(NZ - 1, -1, -1):
        row = bytearray()
        for i in range(NX - 1, -1, -1):
            k = j * NX + i
            row += bytes((247, 251, 253) if depth[k] > 20 else ((143, 195, 214) if ice[k] else (26, 160, 216)))
        rows.append(row)
    for x, r, z in bergs:
        zc = z + WRAP if z < geo['centre'][1] else z
        j, i = int((zc - baked['edge_n']) / CELL + HALF), int((x - baked['x0']) / CELL) % NX
        if 0 <= j < NZ: rows[NZ - 1 - j][(NX - 1 - i) * 3:(NX - 1 - i) * 3 + 3] = bytes((255, 60, 60))
    for port in geo['world']:
        zc = port['at'][2] + WRAP if port['at'][2] < geo['centre'][1] else port['at'][2]
        j, i = int((zc - baked['edge_n']) / CELL + HALF), int((port['at'][0] - baked['x0']) / CELL) % NX
        if 0 <= j < NZ: rows[NZ - 1 - j][(NX - 1 - i) * 3:(NX - 1 - i) * 3 + 3] = bytes((255, 220, 0))
    Path('polar_ice_preview.ppm').write_bytes(b'P6 %d %d 255\n' % (NX, NZ) + b''.join(rows))


# Patch 4.0.3 item 7: the ice is planned round the six ports it was first
# baked with, so adding a port (Point Nemo, far from the poles) leaves the
# baked ice, glaciers and icebergs exactly as they are.
BAKE_LANES = 46
BAKE_PORTS = ['port_brindle_quay', 'port_slatewater_works', 'port_cinder_point', 'port_gannet_light', 'port_north_pole', 'port_south_pole']


def main():
    geo = tb.game_world(tb.load())
    geo['world'] = [p for p in geo['world'] if p['id'] in BAKE_PORTS]
    geo['nemo'] = []
    # (And round the sea lanes it was baked with: Patch 4.0.3 added one by Point Nemo.)
    geo['lanes'] = geo['lanes'][:BAKE_LANES]
    baked = plan(geo)
    found = problems(geo, baked)
    if found: raise SystemExit('polar ice rejected: ' + '; '.join(found))
    bergs, moved = move_bergs(geo, baked)
    write_json(baked)
    write_progression(baked, bergs)
    if '--preview' in sys.argv: preview(geo, baked, bergs)
    area = sum(baked['ice']) * CELL * CELL
    print('polar ice: seed %d, %d cover blocks in %d chunks, %d outlines, %.1f km2, %d of %d icebergs moved' % (
        SEED, len(baked['rects']), len(baked['chunks']), len(baked['outlines']), area / 1e6, moved, len(bergs)))


if __name__ == '__main__':
    main()
