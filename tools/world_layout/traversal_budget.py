"""Step 88 world layout: route lengths, top speeds and time scale must agree.

Reads features/world/world_layout.json and the ship, port and berth records it
names. Lengths are great-circle metres on the navigation sphere. Standard library
only; no Godot, database or network. Run from anywhere:

    python3 tools/world_layout/traversal_budget.py
"""
import functools
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / 'features/world/world_layout.json'
CLASSES = ['S', 'M', 'L', 'XL']


def load():
    return json.loads(LAYOUT.read_text(encoding='utf-8'))


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def record(path):
    """Top-level `name = value` pairs of a Godot text resource."""
    return dict(re.findall(r'^(\w+) = (.+)$', read(path), re.M))


@functools.lru_cache(maxsize=None)
def ship_defaults():
    found = re.findall(r'^@export var (\w+): \w+ = (.+)$', read('features/catalog/ship_definition.gd'), re.M)
    return tuple(found)


def vector(value):
    return [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', value[value.index('('):])]


def strings(value):
    return re.findall(r'"(\w+)"', value)


def constant(path, name):
    return float(re.search(r'const %s: float = ([\d.]+)' % name, read(path)).group(1))


def hull(layout, ship_id):
    plan = layout['hulls'][ship_id]
    fields = {**dict(ship_defaults()), **record(plan['record'])}
    beam, _, length = vector(fields['hull_size_m'])
    return dict(
        id=ship_id, record_id=fields['id'].strip('"'), family=plan['family'],
        size_class=plan['size_class'], beam=beam, length=length,
        top=float(fields['forward_acceleration_mps2']) / float(fields['linear_drag_per_second']),
        tank=float(fields['fuel_capacity_liters']), full_lps=float(fields['fuel_full_output_lps']))


def hulls(layout):
    return [hull(layout, ship_id) for ship_id in layout['hulls']]


def separation(layout, a, b):
    """Great-circle metres between two [lat, lon] degree pairs."""
    lat1, lon1, lat2, lon2 = (math.radians(v) for v in (*a, *b))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 2 * layout['scale']['navigation_radius_m'] * math.asin(min(1.0, math.sqrt(h)))


def bearing(a, b):
    """Initial bearing in degrees, 0 north, increasing toward east."""
    lat1, lon1, lat2, lon2 = (math.radians(v) for v in (*a, *b))
    y = math.sin(lon2 - lon1) * math.cos(lat2)
    x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1)
    return math.degrees(math.atan2(y, x)) % 360


def route_points(layout, route):
    a, b = layout['ports'][route['from']], layout['ports'][route['to']]
    marks = [layout['waypoints'][name] for name in route['via']]
    return [a['position'], a['sea_gate']] + marks + [b['sea_gate'], b['position']]


def route_lengths(layout, route):
    """(outbound, return) metres. A measured route keeps its measured lengths."""
    if 'measured' in route:
        return route['measured']['outbound_m'], route['measured']['return_m']
    points = route_points(layout, route)
    length = sum(separation(layout, p, q) for p, q in zip(points, points[1:]))
    return length, length


def cruise_game_seconds(layout, ship, length_m):
    world_m = length_m / layout['scale']['navigation_meters_per_world_meter']
    return world_m / (ship['top'] * layout['budget']['planning_speed_fraction'])


def leg_seconds(layout, ship, length_m):
    """Real seconds berth to berth at the planning pace."""
    game_s = cruise_game_seconds(layout, ship, length_m) + layout['budget']['port_allowance_s']
    return game_s / layout['scale']['game_seconds_per_real_second']


def leg_fuel(layout, ship, length_m):
    budget = layout['budget']
    full_output_s = cruise_game_seconds(layout, ship, length_m) * budget['planning_speed_fraction']
    return (full_output_s + budget['port_allowance_full_output_s']) * ship['full_lps']


def rank(size_class):
    return CLASSES.index(size_class)


def port_class(layout, route):
    return min((layout['ports'][route[end]]['max_class'] for end in ('from', 'to')), key=rank)


def route_class(layout, route):
    limits = [port_class(layout, route)]
    limits += [layout['passages'][name]['max_class'] for name in route.get('passages', [])]
    return min(limits, key=rank)


def families(layout, route):
    a, b = (layout['ports'][route[end]]['services'] for end in ('from', 'to'))
    return [family for family, service in layout['families'].items() if service in a and service in b]


def permitted(layout, ship, route):
    return ship['family'] in families(layout, route) and rank(ship['size_class']) <= rank(route_class(layout, route))


def fits(size_class, layout, beam, length):
    limit = layout['size_classes'][size_class]
    return beam <= limit['max_beam_m'] and length <= limit['max_length_m']


def carries_cargo(path):
    """True when a ship record lists at least one cargo type."""
    return bool(strings(record(path).get('cargo_type_ids', '')))


def within(value, window):
    return window[0] <= value < window[1]


def failures(layout):
    """Every disagreement found, as text. Empty means the layout is consistent."""
    bad = []
    scale, budget, clear = layout['scale'], layout['budget'], layout['clearance']
    ports, routes, classes = layout['ports'], layout['routes'], layout['size_classes']
    by_id = {route['id']: route for route in routes}
    fleet = hulls(layout)
    reference = hull(layout, budget['reference_hull'])

    # Scale: one radius, one metre scale, one time scale, shared with the game.
    if scale['navigation_radius_m'] != constant('features/geography/navigation_experiment.gd', 'RADIUS_M'):
        bad.append('navigation radius differs from navigation_experiment.gd')
    if scale['navigation_meters_per_world_meter'] != 1.0 or scale['game_seconds_per_real_second'] != 1.0:
        bad.append('scale differs from the UNITS_AND_TIME.md prototype defaults')

    # Hulls: every cargo ship record is planned, with its real top speed and size
    # class. Records with no cargo types (Patch 2.4 small boats) take no cargo
    # jobs and so have no route budget; they are left out.
    speed_cap = constant('features/collision/collision_rules.gd', 'SUPPORTED_SPEED_MPS')
    recorded = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'features/catalog/records').glob('*.tres')
                      if 'script_class="ShipDefinition"' in p.read_text(encoding='utf-8')
                      and carries_cargo(p.relative_to(ROOT).as_posix()))
    if recorded != sorted(plan['record'] for plan in layout['hulls'].values()):
        bad.append('planned hulls do not match the ship records')
    for ship in fleet:
        plan = layout['hulls'][ship['id']]
        if ship['record_id'] != ship['id']: bad.append('%s: record ID mismatch' % ship['id'])
        if abs(ship['top'] - plan['top_speed_mps']) > 1e-6 or ship['top'] > speed_cap:
            bad.append('%s: planned top speed disagrees with its record' % ship['id'])
        smallest = next((c for c in CLASSES if fits(c, layout, ship['beam'], ship['length'])), None)
        if smallest != ship['size_class']: bad.append('%s: size class disagrees with hull size' % ship['id'])
        if not any(permitted(layout, ship, route) for route in routes):
            bad.append('%s: no permitted route' % ship['id'])

    # Size classes and visible passage widths.
    for small, large in zip(CLASSES, CLASSES[1:]):
        if not fits(large, layout, classes[small]['max_beam_m'], classes[small]['max_length_m']):
            bad.append('size classes are not ascending')
    factor = clear['passage_width_per_beam']
    if clear['open_lane_min_width_m'] < factor * classes[CLASSES[-1]]['max_beam_m']:
        bad.append('open lanes are too narrow for the largest class')
    for name, passage in layout['passages'].items():
        width, limit = passage['clear_width_m'], rank(passage['max_class'])
        if width < factor * classes[passage['max_class']]['max_beam_m']:
            bad.append('%s: too narrow for its own class' % name)
        if limit + 1 < len(CLASSES) and width >= factor * classes[CLASSES[limit + 1]]['max_beam_m']:
            bad.append('%s: width does not exclude the next class' % name)
        if not 1 <= len(passage['waypoints']) <= 2 or any(w not in layout['waypoints'] for w in passage['waypoints']):
            bad.append('%s: a passage is one point or one straight cut' % name)

    # Ports: records, berths, sea gates and spacing.
    margin = 2 * clear['berth_margin_m']
    for port_id, port in ports.items():
        if 'record' in port:
            fields = record(port['record'])
            if fields['id'].strip('"') != port_id: bad.append('%s: record ID mismatch' % port_id)
            if not set(strings(fields['service_ids'])) <= set(port['services']):
                bad.append('%s: planned services drop a recorded service' % port_id)
            berth = record(port['berth_record'])
            if berth['port_id'].strip('"') != port_id: bad.append('%s: berth belongs to another port' % port_id)
            width, _, length = vector(berth['envelope_m'])
        else:
            width, length = port['planned_berth_envelope_m']
        limit = classes[port['max_class']]
        if limit['max_beam_m'] + margin > width or limit['max_length_m'] + margin > length:
            bad.append('%s: berth envelope is smaller than its class' % port_id)
        if not {'refuel', 'repair'} <= set(port['services']): bad.append('%s: no refuel or repair' % port_id)
        gate = separation(layout, port['position'], port['sea_gate'])
        turn = abs((bearing(port['position'], port['sea_gate']) - port['open_water_bearing_deg'] + 180) % 360 - 180)
        if not within(gate, clear['sea_gate_distance_m']) or turn > clear['sea_gate_bearing_tolerance_deg']:
            bad.append('%s: sea gate is not in its open water' % port_id)
    close = {frozenset(pair['ports']): pair['separation_m'] for pair in layout['co_visible_port_pairs']}
    names = list(ports)
    for index, a in enumerate(names):
        for b in names[index + 1:]:
            apart = separation(layout, ports[a]['position'], ports[b]['position'])
            pair = frozenset((a, b))
            if pair in close:
                if abs(apart - close[pair]) > 0.01: bad.append('%s/%s: existing anchor moved' % (a, b))
            elif apart < clear['min_port_separation_m']:
                bad.append('%s/%s: closer than the port presentation range allows' % (a, b))
            if apart > clear['max_region_span_m']: bad.append('%s/%s: region is not compact' % (a, b))

    # Budget model against the measured Step 67 legs.
    for row in budget['calibration']:
        ship = hull(layout, row['hull'])
        for label, model, measured in (('time', leg_seconds(layout, ship, row['length_m']), row['seconds']),
                                       ('fuel', leg_fuel(layout, ship, row['length_m']), row['fuel_liters'])):
            if abs(model - measured) > budget['calibration_tolerance'] * measured:
                bad.append('%s %s model %.2f misses measured %.2f' % (row['hull'], label, model, measured))

    # Routes: tier targets, fuel range, leg cap, shortcuts and their alternatives.
    if len(by_id) != len(routes): bad.append('duplicate route ID')
    reached = {budget['reference_hull']: set()}
    for route in routes:
        name = route['id']
        if route['from'] not in ports or route['to'] not in ports or any(w not in layout['waypoints'] for w in route['via']):
            bad.append('%s: unknown port or waypoint' % name)
            continue
        if not families(layout, route): bad.append('%s: serves no cargo family' % name)
        for passage in route.get('passages', []):
            if any(w not in route['via'] for w in layout['passages'][passage]['waypoints']):
                bad.append('%s: does not sail through %s' % (name, passage))
        lengths = route_lengths(layout, route)
        for length in lengths:
            minutes = leg_seconds(layout, reference, length) / 60
            if not within(minutes, layout['tiers_minutes'][route['tier']]):
                bad.append('%s: %.2f min is outside the %s target' % (name, minutes, route['tier']))
            for ship in fleet:
                if not permitted(layout, ship, route): continue
                if leg_seconds(layout, ship, length) / 60 > budget['max_leg_minutes']:
                    bad.append('%s: too long for %s' % (name, ship['id']))
                if leg_fuel(layout, ship, length) > budget['fuel_reserve_fraction'] * ship['tank']:
                    bad.append('%s: beyond the fuel range of %s' % (name, ship['id']))
        if rank(route_class(layout, route)) < rank(port_class(layout, route)) and 'alternative' not in route:
            bad.append('%s: size-limited with no alternative' % name)
        if 'alternative' in route:
            other = by_id.get(route['alternative'])
            if other is None or {other['from'], other['to']} != {route['from'], route['to']}:
                bad.append('%s: alternative does not join the same ports' % name)
            else:
                if route_class(layout, other) != port_class(layout, other):
                    bad.append('%s: alternative is size-limited too' % name)
                saving = leg_seconds(layout, reference, route_lengths(layout, other)[0]) - leg_seconds(layout, reference, lengths[0])
                if saving < budget['min_shortcut_saving_s']: bad.append('%s: shortcut saves too little' % name)
        if permitted(layout, reference, route): reached[budget['reference_hull']].update((route['from'], route['to']))
    if reached[budget['reference_hull']] != set(ports): bad.append('a port has no route for the reference hull')
    return bad


def minutes(seconds):
    return '%.1f' % (seconds / 60)


def route_table(layout):
    reference = hull(layout, layout['budget']['reference_hull'])
    lines = ['| Route | Tier | Length km | Starter min | Starter fuel L | Largest class | Families |',
             '|---|---|---:|---:|---:|---|---|']
    for route in layout['routes']:
        lengths = sorted(set(route_lengths(layout, route)))
        lines.append('| %s | %s | %s | %s | %s | %s | %s |' % (
            route['id'], route['tier'], ' / '.join('%.2f' % (m / 1000) for m in lengths),
            ' / '.join(minutes(leg_seconds(layout, reference, m)) for m in lengths),
            ' / '.join('%.0f' % leg_fuel(layout, reference, m) for m in lengths),
            route_class(layout, route), ', '.join(families(layout, route))))
    return '\n'.join(lines)


def hull_table(layout):
    budget = layout['budget']
    lines = ['| Hull | Class | Top m/s | Planning m/s | Longest permitted leg km | Its time min | Its fuel L | Fuel limit L |',
             '|---|---|---:|---:|---:|---:|---:|---:|']
    for ship in hulls(layout):
        legs = [max(route_lengths(layout, r)) for r in layout['routes'] if permitted(layout, ship, r)]
        longest = max(legs)
        lines.append('| %s | %s | %.3f | %.2f | %.2f | %s | %.0f | %.0f |' % (
            ship['id'], ship['size_class'], ship['top'], ship['top'] * budget['planning_speed_fraction'],
            longest / 1000, minutes(leg_seconds(layout, ship, longest)), leg_fuel(layout, ship, longest),
            budget['fuel_reserve_fraction'] * ship['tank']))
    return '\n'.join(lines)


if __name__ == '__main__':
    plan = load()
    found = failures(plan)
    print(route_table(plan), hull_table(plan), sep='\n\n')
    for line in found: print('FAIL', line)
    print('WORLD_LAYOUT_%s routes=%d failures=%d' % ('FAIL' if found else 'PASS', len(plan['routes']), len(found)))
    sys.exit(1 if found else 0)
