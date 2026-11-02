"""One active hull; dock-only atomic exchange. Never transfer cargo between ships."""
import copy
import json
from pathlib import Path
from ship_purchase import CATALOG

SLOTS = json.loads(Path(__file__).with_name('fleet_slots.json').read_text())
CLOSED_JOBS = ('delivered', 'abandoned', 'cancelled', 'canceled', 'failed')


def transition(profile, request):
    def reject(code): return code, profile, 0, None
    if profile.get('recovery', {}).get('state') == 'pending': return reject('RECOVERY_REQUIRED')
    if profile['cargo'] or any(j.get('state') not in CLOSED_JOBS for j in profile['jobs']):
        return reject('FLEET_LOADED')
    active = profile['ship']
    stored = profile.get('stored_ships', [])
    ids = [active['id']] + [s['id'] for s in stored]
    if len(set(ids)) != len(ids): return reject('OWNED_ID_CONFLICT')
    target = next((s for s in stored if s['id'] == request['ship_id']), None)
    if target is None: return reject('SHIP_NOT_STORED')
    if target['definition'] not in CATALOG: return reject('UNKNOWN_SHIP')
    port = request['port_id']
    if port not in SLOTS or target.get('storage_port_id') != port: return reject('FLEET_WRONG_PORT')
    if active.get('condition_bp', 10000) <= 0 or target.get('condition_bp', 10000) <= 0:
        return reject('RECOVERY_REQUIRED')
    if target.get('cargo') or target.get('jobs'): return reject('FLEET_LOADED')
    slot = request['slot']
    if 'position' in target:
        if slot != -1: return reject('BAD_SLOT')
        position = target['position']
    else:
        if not 0 <= slot < len(SLOTS[port]): return reject('BAD_SLOT')
        position = SLOTS[port][slot]
    candidate = copy.deepcopy(profile)
    incoming = candidate['stored_ships'].pop(ids.index(target['id']) - 1)
    outgoing = candidate['ship']
    outgoing['storage_port_id'] = port
    candidate['stored_ships'].append(outgoing)
    incoming['position'] = copy.deepcopy(position)
    incoming.pop('storage_port_id', None)
    candidate['ship'] = incoming
    return 'FLEET_SWITCHED', candidate, 0, None
