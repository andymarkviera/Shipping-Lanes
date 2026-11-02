"""Full restoration of D115's single condition; integer minor-credit settlement."""
import copy
import json
from pathlib import Path

MAX_CONDITION_BP = 10000
FULL_COSTS = json.loads(Path(__file__).with_name('repair_costs.json').read_text())
assert all(type(v) is int and 0 < v <= 900000000 for v in FULL_COSTS.values())
PORTS = ('port_brindle_quay', 'port_slatewater_works')


def quote(ship):
    condition = ship.get('condition_bp', MAX_CONDITION_BP)
    cost = FULL_COSTS.get(ship['definition'])
    if cost is None or type(condition) is not int or not 0 < condition <= MAX_CONDITION_BP:
        return None
    missing = MAX_CONDITION_BP - condition
    # Round the total upward once to a whole minor credit; never float currency.
    return dict(condition_bp=condition, restored_bp=missing,
                cost_minor=(missing * cost + MAX_CONDITION_BP - 1) // MAX_CONDITION_BP)


def transition(profile, request, wallet):
    def reject(code): return code, profile, 0, None
    if request['port_id'] not in PORTS: return reject('NO_REPAIR_SERVICE')
    if any(j.get('state') == 'loading' for j in profile['jobs']): return reject('LOADING_PENDING')
    terms = quote(profile['ship'])
    if terms is None: return reject('WRONG_SHIP')
    if terms['restored_bp'] == 0: return reject('NO_REPAIR_NEEDED')
    if any(request[k] != terms[k] for k in ('condition_bp', 'cost_minor')):
        return reject('QUOTE_CHANGED')
    if terms['cost_minor'] > wallet: return reject('INSUFFICIENT_FUNDS')
    candidate = copy.deepcopy(profile)
    candidate['ship']['condition_bp'] = MAX_CONDITION_BP
    candidate['ship']['wear_fraction_bp'] = 0.0
    return 'REPAIRED', candidate, -terms['cost_minor'], None
