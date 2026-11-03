"""Game-shop resale of empty stored ships; the active hull can never be sold."""
import copy
import json
from pathlib import Path
from fleet import CLOSED_JOBS
from ship_purchase import CATALOG, PORTS
from refueling import UNIT_PRICE_MINOR

VALUATION = json.loads(Path(__file__).with_name('resale_values.json').read_text())


def value(ship):
    definition = CATALOG.get(ship.get('definition'))
    rate = VALUATION.get(ship.get('definition'))
    condition = ship.get('condition_bp', 10000)
    if definition is None or type(rate) is not int or not 0 <= rate <= 10000:
        return None
    if type(condition) is not int or not 1 <= condition <= 10000:
        return None
    # New records retain actual cost; legacy records use the current catalog price.
    basis = ship.get('acquisition_cost_minor', definition['cost_minor'])
    if type(basis) is not int or basis < 0:
        return None
    return min(basis, definition['cost_minor']) * rate * condition // 100000000


def transition(profile, request, treasury, wallet):
    def reject(code): return code, profile, 0, None
    active = profile['ship']
    if request['ship_id'] == active['id']: return reject('ACTIVE_SHIP_RETAINED')
    if active.get('condition_bp', 10000) <= 0 or profile.get('recovery', {}).get('state') == 'pending':
        return reject('RECOVERY_REQUIRED')
    if profile['cargo'] or any(j.get('state') not in CLOSED_JOBS for j in profile['jobs']):
        return reject('FLEET_LOADED')
    stored = profile.get('stored_ships', [])
    ids = [active['id']] + [s['id'] for s in stored]
    if len(set(ids)) != len(ids): return reject('OWNED_ID_CONFLICT')
    target = next((s for s in stored if s['id'] == request['ship_id']), None)
    if target is None: return reject('SHIP_NOT_STORED')
    if request['port_id'] not in PORTS or target.get('storage_port_id') != request['port_id']:
        return reject('FLEET_WRONG_PORT')
    if target.get('cargo') or target.get('jobs'): return reject('FLEET_LOADED')
    amount = value(target)
    if amount is None: return reject('RESALE_UNAVAILABLE')
    if amount != request['value_minor']: return reject('QUOTE_CHANGED')
    repayment = min(profile.get('recovery_debt_minor', 0), max(1, amount // 2)) if amount > 0 else 0
    if active.get('definition') not in CATALOG or (active.get('fuel_liters', 0) < 1 and wallet + amount - repayment < UNIT_PRICE_MINOR):
        return reject('KEEP_USABLE_SHIP')
    if treasury < amount: return reject('INSUFFICIENT_RESOURCES')
    candidate = copy.deepcopy(profile)
    candidate['stored_ships'] = [s for s in candidate['stored_ships'] if s['id'] != target['id']]
    return 'SHIP_SOLD', candidate, amount, dict(ship_id=target['id'], gross_minor=amount)
