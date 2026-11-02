"""Propulsion-only fuel purchases. Trusted server attests physical berth eligibility."""
import copy
import math

PORTS = ('port_brindle_quay', 'port_slatewater_works')
from ship_purchase import CATALOG
CAPACITIES = {key: row['fuel_capacity_liters'] for key, row in CATALOG.items()}
UNIT_PRICE_MINOR = 25  # Development economy: 0.25 credits per whole liter.


def transition(profile, request, wallet):
    fuel = profile['ship']['fuel_liters']
    capacity = CAPACITIES.get(profile['ship']['definition'])
    def reject(code): return code, profile, 0, None
    if request['port_id'] not in PORTS: return reject('NO_REFUEL_SERVICE')
    if capacity is None: return reject('WRONG_SHIP')
    if not math.isfinite(fuel) or not 0 <= fuel <= capacity: return reject('BAD_FUEL')
    if any(j.get('state') == 'loading' for j in profile['jobs']): return reject('LOADING_PENDING')
    if request['unit_price_minor'] != UNIT_PRICE_MINOR: return reject('QUOTE_CHANGED')
    quantity = request['liters']
    if fuel + quantity > capacity: return reject('TANK_SPACE')
    price = quantity * UNIT_PRICE_MINOR
    if price > wallet: return reject('INSUFFICIENT_FUNDS')
    candidate = copy.deepcopy(profile)
    candidate['ship']['fuel_liters'] = fuel + quantity
    return 'REFUELED', candidate, -price, None
