"""Shared transactional contract. Call only inside the account/storage transaction.

No fallback owner, remote feed, player-supplied time, prices or capacity. The
prototype hull remains operator-fixture-only until its gameplay integration.
"""
import copy
import hashlib
import json
from dataclasses import asdict
from .model import Config, Market, MarketError, Quote, integer

MAX_MONEY = 9_000_000_000_000
OPERATIONS = ('oil_snapshot', 'oil_quote', 'oil_accept')
CAPACITIES = {'ship_oil_prototype_01': 200}


def encode(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False)


def initial(realm, now, config=None):
    return dump(Market(realm, config, start=now), {}, 0)


def dump(market, bindings, sequence):
    config = {k: getattr(market.config, k) for k in Config.__dataclass_fields__}
    config['port_offsets'] = dict(config['port_offsets'])
    return dict(schema=1, realm=market.realm, market_id=market.market_id, config=config,
                time=market._time, tick=market._tick, version=market._version,
                pressure=dict(market._pressure), bindings=bindings, sequence=sequence)


def restore(state, realm):
    # Only storage writes this envelope. Fail closed on schema/realm corruption.
    if state['schema'] != 1 or state['realm'] != realm:
        raise MarketError('MARKET_STATE_INVALID')
    market = Market(realm, Config(**state['config']), start=state['time'])
    market.market_id = state['market_id']
    market._tick, market._version = state['tick'], state['version']
    market._pressure = dict(state['pressure'])
    market._quotes = {k: Quote(**v['quote']) for k, v in state['bindings'].items()}
    return market


def validate(request):
    op = request.get('op')
    common = {'realm', 'op', 'account', 'epoch', 'generation'}
    extra = {'oil_snapshot': set(),
             'oil_quote': {'port_id', 'side', 'barrels', 'lot_id'},
             'oil_accept': {'action_id', 'expected_revision', 'quote_id', 'quote_version', 'port_id'}}
    if op not in extra or set(request) != common | extra[op]:
        raise MarketError('BAD_REQUEST')
    for name in ('quote_version', 'expected_revision', 'epoch', 'generation'):
        if name in request and not integer(request[name], 0, MAX_MONEY):
            raise MarketError('BAD_INTEGER')
    for name in ('account', 'action_id', 'quote_id', 'port_id', 'lot_id'):
        if name in request and (type(request[name]) is not str or len(request[name]) > 128 or
                                (not request[name] and name != 'lot_id')):
            raise MarketError('BAD_IDENTIFIER')
    if op == 'oil_quote':
        if request['side'] not in ('buy', 'sell') or not integer(request['barrels'], 1, 200):
            raise MarketError('INVALID_MARKET_REQUEST')
        if (request['side'] == 'buy') != (request['lot_id'] == ''):
            raise MarketError('BAD_LOT')


def inventory(profile, wallet, quote, lot_id):
    """One current purchased lot, preserved in canonical cargo (including sinking).

    Cumulative integer allocation retains Step 73's fragmentation-neutral basis;
    no changes to its historical SQLite codec or player UI.
    """
    data = copy.deepcopy(profile)
    ship = data['ship']
    if data.get('recovery', {}).get('state') == 'pending' or ship.get('condition_bp', 10000) <= 0:
        raise MarketError('RECOVERY_REQUIRED')
    capacity = CAPACITIES.get(ship['definition'], 0)
    if not capacity:
        raise MarketError('NO_OIL_CAPACITY')
    cargo = data['cargo']
    if quote.side == 'buy':
        if cargo or any(j.get('state') not in ('delivered', 'abandoned', 'cancelled', 'canceled', 'failed') for j in data['jobs']):
            raise MarketError('CARGO_BUSY')
        if quote.barrels > capacity:
            raise MarketError('CAPACITY_EXCEEDED')
        if wallet < quote.total_minor:
            raise MarketError('INSUFFICIENT_FUNDS')
        lot = dict(id=quote.id, definition='cargo_oil', state='aboard', ship=ship['id'],
                   acquired_barrels=quote.barrels, remaining_barrels=quote.barrels,
                   acquisition_cost_minor=quote.total_minor, origin_port=quote.port,
                   acquired_quote=asdict(quote), sold_barrels=0, sold_cost_minor=0,
                   proceeds_minor=0)
        cargo.append(lot)
        return data, -quote.total_minor, dict(lot), 0
    lot = next((c for c in cargo if c['id'] == lot_id and c.get('definition') == 'cargo_oil' and c.get('ship') == ship['id']), None)
    if lot is None or quote.barrels > lot['remaining_barrels']:
        raise MarketError('CARGO_NOT_OWNED')
    sold = lot['sold_barrels'] + quote.barrels
    allocated = lot['acquisition_cost_minor'] * sold // lot['acquired_barrels']
    cost = allocated - lot['sold_cost_minor']
    lot.update(sold_barrels=sold, sold_cost_minor=allocated,
               remaining_barrels=lot['remaining_barrels'] - quote.barrels,
               proceeds_minor=lot['proceeds_minor'] + quote.total_minor)
    receipt_lot = dict(lot)
    if not lot['remaining_barrels']:
        cargo.remove(lot)
    debt = data.get('recovery_debt_minor', 0)
    repayment = min(debt, max(1, quote.total_minor // 2)) if debt else 0
    if repayment:
        data['recovery_debt_minor'] -= repayment
    return data, quote.total_minor - repayment, dict(receipt_lot, allocated_cost_minor=cost), repayment


def execute(tx, realm, profile, request, clock, fault=lambda *_: None):
    """tx locks singleton after the caller locks account; writes commit together.

    Public lock order: server -> lease -> profile -> market -> game. No reverse
    acquisitions. Receipt lookup precedes expiry/revision so reconnect can recover.
    """
    validate(request)
    if request['realm'] != realm:
        raise MarketError('WRONG_REALM')
    account, op = request['account'], request['op']
    fingerprint = hashlib.sha256(encode({k: v for k, v in request.items()
                                      if k not in ('epoch', 'generation')}).encode()).hexdigest()
    if op == 'oil_accept':
        prior = tx.receipt(account, request['action_id'])
        if prior:
            if prior['fingerprint'] != fingerprint:
                raise MarketError('ID_CONFLICT')
            return dict(prior['result'], duplicate=True)
    state = tx.market()  # blocking lock, never start a replacement on missing data
    if state is None:
        raise MarketError('MARKET_UNAVAILABLE')
    market = restore(state, realm)
    # Read authority time AFTER the shared market lock. Clamp clock rollback to
    # durable high water; clients cannot extend expiry by submitting timestamps.
    now = max(state['time'], clock())
    bindings = copy.deepcopy(state['bindings'])
    before = market._version
    result = None
    if op == 'oil_snapshot':
        result = dict(ok=True, code='OIL_MARKET', market=market.snapshot(now))
    elif op == 'oil_quote':
        quote = market.quote(request['port_id'], request['side'], request['barrels'], now)
        inventory(profile['profile'], profile['money'], quote, request['lot_id'])
        bindings = {k: v for k, v in bindings.items() if v['quote']['expires_at'] > now}
        bindings[quote.id] = dict(account=account, ship=profile['profile']['ship']['id'],
                                  lot_id=request['lot_id'], quote=asdict(quote))
        result = dict(ok=True, code='OIL_QUOTE', quote=asdict(quote))
    else:
        binding = bindings.get(request['quote_id'])
        if binding is None or binding['account'] != account:
            raise MarketError('UNKNOWN_QUOTE')
        quote = Quote(**binding['quote'])
        if quote.version != request['quote_version'] or quote.port != request['port_id']:
            raise MarketError('QUOTE_CHANGED')
        if now >= quote.expires_at:
            raise MarketError('QUOTE_EXPIRED')
        if profile['revision'] != request['expected_revision']:
            raise MarketError('STALE_REVISION')
        if binding['ship'] != profile['profile']['ship']['id']:
            raise MarketError('SHIP_CHANGED')
        candidate, amount, lot, repayment = inventory(profile['profile'], profile['money'], quote, binding['lot_id'])
        if not 0 <= profile['money'] + amount <= MAX_MONEY:
            raise MarketError('OVERFLOW')
        market.record_simulated_trade(quote, now)
        del bindings[quote.id]
        tx.settle(account, candidate, amount)
        fault('after_profile_write', request)
        result = dict(ok=True, code='OIL_SETTLED', action_id=request['action_id'],
                      revision=profile['revision'] + 1, amount=amount, quote=asdict(quote),
                      lot=lot, recovery_repaid_minor=repayment, market_version=market._version)
    sequence = state['sequence'] + 1
    result['market_sequence'] = sequence
    tx.save_market(dump(market, bindings, sequence), dict(sequence=sequence, op=op,
                   before_version=before, version=market._version, time=now,
                   account=account, action_id=request.get('action_id'), quote_id=result.get('quote', {}).get('id')))
    fault('after_market_write', request)
    if op == 'oil_accept':
        tx.save_receipt(account, request['action_id'], fingerprint, result)
    return result
