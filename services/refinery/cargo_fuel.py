"""Cargo-only pipeline transfers, executed inside the fenced refinery transaction."""
import copy
from services.oil_market.model import integer
from services.oil_market.settlement import MAX_MONEY

CAPACITIES = {'ship_oil_prototype_01': 200000}  # millibarrels; fixture hull only
SALE_PORT = 'port_brindle_quay'
PRICE = 320  # Step 86: refining must beat selling the crude; prototype minor credits per barrel, frozen at acquisition
MUTATIONS = ('refinery_load', 'refinery_sell')


def require(value, code):
    from services.oil_market.model import MarketError
    if not value: raise MarketError(code)


def validate_lot(lot):
    require(lot.get('state') == 'aboard' and lot.get('definition') == 'cargo_fuel', 'CARGO_FUEL_INVALID')
    for key in ('id', 'ship', 'collection_id', 'refinery_id', 'origin_port'):
        require(type(lot.get(key)) is str and 0 < len(lot[key]) <= 128, 'CARGO_FUEL_INVALID')
    for key in ('acquired_millibarrels', 'remaining_millibarrels', 'sold_millibarrels',
                'handling_cost_minor', 'sold_cost_minor', 'proceeds_minor', 'price_minor_per_barrel'):
        require(integer(lot.get(key), 0, MAX_MONEY), 'CARGO_FUEL_INVALID')
    total, sold = lot['acquired_millibarrels'], lot['sold_millibarrels']
    require(total > 0 and sold < total and total == sold + lot['remaining_millibarrels'] and
            lot['sold_cost_minor'] == lot['handling_cost_minor'] * sold // total and
            lot['proceeds_minor'] == sold * lot['price_minor_per_barrel'] // 1000,
            'CARGO_FUEL_INVALID')


def transfer(state, candidate, account, request):
    """Return wallet delta and receipt. Never read or write propulsion fuel."""
    ship, cargo = candidate['ship'], candidate['cargo']
    capacity = CAPACITIES.get(ship['definition'], 0)
    require(capacity > 0, 'NO_CARGO_FUEL_CAPACITY')
    units = request['millibarrels']
    if request['op'] == 'refinery_load':
        require(not cargo and not any(j.get('state') not in ('delivered', 'abandoned', 'cancelled', 'canceled', 'failed') for j in candidate['jobs']), 'CARGO_BUSY')
        require(units <= capacity, 'CAPACITY_EXCEEDED')
        item = next((w for w in state['withdrawals'] if w['account'] == account and w['action_id'] == request['collection_id']), None)
        require(item is not None, 'COLLECTION_NOT_OWNED')
        quote = state['quotes'][item['quote_id']]
        require(quote['ship'] == ship['id'], 'SHIP_CHANGED')
        loaded = item.get('loaded_millibarrels', 0)
        require(units <= item['millibarrels'] - loaded, 'INSUFFICIENT_COLLECTION')
        cost = item['cost_minor'] * (loaded + units) // item['millibarrels'] - item['cost_minor'] * loaded // item['millibarrels']
        item['loaded_millibarrels'] = loaded + units
        item['status'] = 'loaded' if loaded + units == item['millibarrels'] else 'awaiting_loading'
        lot = dict(id=request['action_id'], definition='cargo_fuel', state='aboard', ship=ship['id'],
                   collection_id=item['action_id'], refinery_id=state['refinery_id'], origin_port=request['port_id'],
                   acquired_millibarrels=units, remaining_millibarrels=units, sold_millibarrels=0,
                   handling_cost_minor=cost, sold_cost_minor=0, proceeds_minor=0, price_minor_per_barrel=PRICE)
        cargo.append(lot)
        return 0, dict(code='CARGO_FUEL_LOADED', lot=copy.deepcopy(lot))
    lot = next((c for c in cargo if c.get('id') == request['lot_id'] and c.get('definition') == 'cargo_fuel' and c.get('ship') == ship['id']), None)
    require(lot is not None, 'CARGO_NOT_OWNED')
    validate_lot(lot)
    require(units <= lot['remaining_millibarrels'], 'INSUFFICIENT_CARGO')
    sold = lot['sold_millibarrels'] + units
    gross = sold * lot['price_minor_per_barrel'] // 1000 - lot['proceeds_minor']
    cost = lot['handling_cost_minor'] * sold // lot['acquired_millibarrels'] - lot['sold_cost_minor']
    debt = candidate.get('recovery_debt_minor', 0)
    require(integer(debt, 0, MAX_MONEY), 'CARGO_FUEL_INVALID')
    repayment = min(debt, max(1, gross // 2)) if gross and debt else 0
    if repayment: candidate['recovery_debt_minor'] -= repayment
    lot.update(remaining_millibarrels=lot['remaining_millibarrels']-units, sold_millibarrels=sold,
               sold_cost_minor=lot['sold_cost_minor']+cost, proceeds_minor=lot['proceeds_minor']+gross)
    result = dict(code='CARGO_FUEL_SOLD', lot=copy.deepcopy(lot), gross_minor=gross,
                  allocated_handling_cost_minor=cost, debt_repayment_minor=repayment)
    if not lot['remaining_millibarrels']: cargo.remove(lot)
    return gross - repayment, result
