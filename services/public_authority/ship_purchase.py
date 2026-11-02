"""Earned-credit ships. Definitions are shared; owned records hold only instance state.

Called under the existing lease/profile lock and atomic receipt transaction.
The trusted game server attests docking; no client supplies recipient or owned ID.
"""
import copy
import json
import uuid
from pathlib import Path

CATALOG = {row['definition']: row for row in json.loads(Path(__file__).with_name('ship_catalog.json').read_text())}
PORTS = ('port_brindle_quay', 'port_slatewater_works')
MAX_STORED_SHIPS = 100


def transition(profile, request, wallet):
    def reject(code): return code, profile, 0, None
    if request['port_id'] not in PORTS: return reject('NO_SHIP_SERVICE')
    if any(j.get('state') == 'loading' for j in profile['jobs']): return reject('LOADING_PENDING')
    definition = CATALOG.get(request['definition_id'])
    if definition is None: return reject('UNKNOWN_SHIP')
    if request['cost_minor'] != definition['cost_minor']: return reject('QUOTE_CHANGED')
    if wallet < definition['cost_minor']: return reject('INSUFFICIENT_FUNDS')
    stored = profile.get('stored_ships', [])
    if len(stored) >= MAX_STORED_SHIPS: return reject('FLEET_LIMIT')
    owned_id = str(uuid.uuid5(uuid.UUID(request['account']), 'ship_purchase_' + request['action_id']))
    if owned_id == profile['ship']['id'] or any(s['id'] == owned_id for s in stored):
        return reject('OWNED_ID_CONFLICT')
    owned = dict(id=owned_id, definition=definition['definition'], condition_bp=10000,
                 wear_fraction_bp=0.0, fuel_liters=0.0, storage_port_id=request['port_id'])
    candidate = copy.deepcopy(profile)
    candidate.setdefault('stored_ships', []).append(owned)
    return 'SHIP_PURCHASED', candidate, -definition['cost_minor'], owned
