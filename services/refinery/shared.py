"""Step 78 transaction model. Public storage owns time, stock and collection records.

Collection records are refinery custody, NOT aboard cargo or saleable goods (79).
No client credit/import/tick operation exists. Call inside the fenced account tx.
"""
import copy
import hashlib
import uuid
from dataclasses import asdict
from services.oil_market.model import MarketError, integer
from services.oil_market.settlement import encode, consume_lot, remaining_units, MAX_MONEY
from .processing import Config, REFINERY_ID, PORT_ID

OPERATIONS = ('refinery_snapshot', 'refinery_submit', 'refinery_quote', 'refinery_withdraw')
LIMIT = 10000


def require(ok, code):
    if not ok: raise MarketError(code)


def initial(realm, config=None):
    return dict(schema=2, realm=realm, refinery_id=REFINERY_ID,
                config=asdict(config or Config()), time_ms=0, jobs=[], owners={},
                withdrawals=[], quotes={}, fee_minor_per_barrel=1)


def validate_request(request):
    base = {'realm', 'op', 'account', 'epoch', 'generation', 'refinery_id'}
    extra = {'refinery_snapshot': set(),
             'refinery_submit': {'action_id', 'expected_revision', 'lot_id', 'input_millibarrels', 'port_id'},
             'refinery_quote': {'millibarrels', 'port_id'},
             'refinery_withdraw': {'action_id', 'expected_revision', 'quote_id', 'port_id'}}
    op = request.get('op')
    require(type(op) is str and op in extra and set(request) == base | extra[op], 'BAD_REQUEST')
    require(request['refinery_id'] == REFINERY_ID, 'UNKNOWN_REFINERY')
    for field in ('account', 'action_id', 'lot_id', 'quote_id', 'port_id'):
        if field in request:
            require(type(request[field]) is str and 0 < len(request[field]) <= 128, 'BAD_IDENTIFIER')
    for field in ('epoch', 'generation', 'expected_revision', 'input_millibarrels', 'millibarrels'):
        if field in request:
            require(integer(request[field], 1 if field in ('input_millibarrels', 'millibarrels') else 0, MAX_MONEY), 'BAD_INTEGER')


def owner():
    return dict(stock_millibarrels=0, remainder=0, processed_millibarrels=0)


def validate(state, realm):
    """Reconstruct credits and withdrawals; corrupt/missing state never reseeds."""
    try:
        require(type(state['schema']) is int and state['schema'] == 2 and state['realm'] == realm and
                state['refinery_id'] == REFINERY_ID, 'REFINERY_STATE_INVALID')
        config = Config(**state['config'])
        require(integer(state['time_ms'], 0, MAX_MONEY) and integer(state['fee_minor_per_barrel'], 0, 10**6), 'REFINERY_STATE_INVALID')
        require(type(state['jobs']) is list and len(state['jobs']) <= config.max_submissions and
                type(state['withdrawals']) is list and len(state['withdrawals']) <= LIMIT and
                type(state['quotes']) is dict and len(state['quotes']) <= LIMIT, 'REFINERY_STATE_INVALID')
        rebuilt, identities, reserved = {}, set(), 0
        for index, job in enumerate(state['jobs']):
            key = (job['account'], job['action_id'])
            require(all(type(v) is str and 0 < len(v) <= 128 for v in key) and key not in identities, 'REFINERY_STATE_INVALID')
            identities.add(key)
            own = rebuilt.setdefault(job['account'], owner())
            units = job['input_millibarrels']
            require(integer(units, 1, config.input_capacity_millibarrels), 'REFINERY_STATE_INVALID')
            output, remainder = divmod(units * config.yield_numerator + own['remainder'], config.yield_denominator)
            duration = (units * 1000 + config.rate_millibarrels_per_second - 1) // config.rate_millibarrels_per_second
            for field in ('output_millibarrels', 'remainder_after', 'duration_ms', 'allocated_cost_minor', 'started_ms', 'ready_ms'):
                require(integer(job[field], 0, MAX_MONEY), 'REFINERY_STATE_INVALID')
            require(type(job['lot_id']) is str and 0 < len(job['lot_id']) <= 128 and
                    job['output_millibarrels'] == output and job['remainder_after'] == remainder and
                    job['duration_ms'] == duration and job['ready_ms'] == job['started_ms'] + duration and
                    job['started_ms'] <= state['time_ms'], 'REFINERY_STATE_INVALID')
            if index:
                require(job['started_ms'] >= state['jobs'][index-1]['ready_ms'], 'REFINERY_STATE_INVALID')
            if job['status'] == 'complete':
                require(job['ready_ms'] <= state['time_ms'], 'REFINERY_STATE_INVALID')
                own['stock_millibarrels'] += output
                own['remainder'] = remainder
                own['processed_millibarrels'] += units
            else:
                require(job['status'] == 'processing' and index == len(state['jobs'])-1 and
                        job['ready_ms'] > state['time_ms'], 'REFINERY_STATE_INVALID')
                reserved += output
        consumed_quotes = set()
        for item in state['withdrawals']:
            key = (item['account'], item['action_id'])
            require(all(type(v) is str and 0 < len(v) <= 128 for v in key) and key not in identities, 'REFINERY_STATE_INVALID')
            identities.add(key)
            require(item['account'] in rebuilt and integer(item['millibarrels'], 1, config.output_capacity_millibarrels) and
                    integer(item['cost_minor'], 0, MAX_MONEY) and item['status'] == 'awaiting_loading', 'REFINERY_STATE_INVALID')
            quote = state['quotes'][item['quote_id']]
            require(quote['account'] == item['account'] and quote['millibarrels'] == item['millibarrels'] and
                    quote['cost_minor'] == item['cost_minor'] and quote['consumed'] and
                    item['quote_id'] not in consumed_quotes, 'REFINERY_STATE_INVALID')
            consumed_quotes.add(item['quote_id'])
            rebuilt[item['account']]['stock_millibarrels'] -= item['millibarrels']
        for key, quote in state['quotes'].items():
            require(type(key) is str and quote['id'] == key and type(quote['account']) is str and
                    type(quote['ship']) is str and quote['port_id'] == PORT_ID and
                    integer(quote['millibarrels'], 1, config.output_capacity_millibarrels) and
                    integer(quote['cost_minor'], 0, MAX_MONEY) and
                    quote['cost_minor'] == (quote['millibarrels'] * state['fee_minor_per_barrel'] + 999) // 1000 and
                    type(quote['consumed']) is bool and quote['consumed'] == (key in consumed_quotes), 'REFINERY_STATE_INVALID')
        for value in state['owners'].values():
            require(set(value) == set(owner()) and all(type(v) is int and v >= 0 for v in value.values()), 'REFINERY_STATE_INVALID')
        require(rebuilt == state['owners'] and all(v['stock_millibarrels'] >= 0 for v in rebuilt.values()) and
                sum(v['stock_millibarrels'] for v in rebuilt.values()) + reserved <= config.output_capacity_millibarrels,
                'REFINERY_STATE_INVALID')
        return config
    except (KeyError, TypeError, ValueError, OverflowError, AttributeError):
        raise MarketError('REFINERY_STATE_INVALID') from None


def advance(state, now):
    require(integer(now, 0, MAX_MONEY), 'BAD_REFINERY_CLOCK')
    state['time_ms'] = max(state['time_ms'], now)
    if state['jobs'] and state['jobs'][-1]['status'] == 'processing':
        job = state['jobs'][-1]
        if job['ready_ms'] <= state['time_ms']:
            own = state['owners'][job['account']]
            own['stock_millibarrels'] += job['output_millibarrels']
            own['remainder'] = job['remainder_after']
            own['processed_millibarrels'] += job['input_millibarrels']
            job['status'] = 'complete'


def execute(tx, realm, profile, request, clock, fault=lambda *_: None):
    validate_request(request)
    require(request['realm'] == realm, 'WRONG_REALM')
    op, account = request['op'], request['account']
    fingerprint = hashlib.sha256(encode({k: v for k, v in request.items() if k not in ('epoch', 'generation')}).encode()).hexdigest()
    if op in ('refinery_submit', 'refinery_withdraw'):
        prior = tx.receipt(account, request['action_id'])
        if prior:
            require(prior['fingerprint'] == fingerprint, 'ID_CONFLICT')
            return dict(prior['result'], duplicate=True)
    state = tx.refinery(REFINERY_ID)
    require(state is not None, 'REFINERY_UNAVAILABLE')
    config = validate(state, realm)
    advance(state, clock())  # Read central clock AFTER row lock; never sum server ticks.
    candidate = copy.deepcopy(profile['profile'])
    if op == 'refinery_snapshot':
        result = dict(ok=True, code='REFINERY', refinery_id=REFINERY_ID, config=state['config'],
                      time_ms=state['time_ms'], revision=profile['revision'], money=profile['money'],
                      owner=copy.deepcopy(state['owners'].get(account, owner())),
                      stock_millibarrels=sum(v['stock_millibarrels'] for v in state['owners'].values()),
                      jobs=[j for j in state['jobs'] if j['account'] == account][-1:],
                      collections=[w for w in state['withdrawals'] if w['account'] == account][-1:])
    else:
        # Docking is attested by the approved server, as for oil services. Never
        # expose this authority credential or accept player-supplied context.
        require(request['port_id'] == PORT_ID, 'DOCK_REQUIRED')
        require(candidate.get('recovery', {}).get('state') != 'pending' and candidate['ship'].get('condition_bp', 10000) > 0, 'RECOVERY_REQUIRED')
        if op != 'refinery_quote': require(profile['revision'] == request['expected_revision'], 'STALE_REVISION')
        own = state['owners'].get(account, owner())
        amount = 0
        if op == 'refinery_submit':
            require(len(state['jobs']) < config.max_submissions, 'REFINERY_LEDGER_FULL')
            require(not state['jobs'] or state['jobs'][-1]['status'] == 'complete', 'REFINERY_BUSY')
            units = request['input_millibarrels']
            require(units <= config.input_capacity_millibarrels, 'INPUT_CAPACITY')
            output, remainder = divmod(units * config.yield_numerator + own['remainder'], config.yield_denominator)
            require(sum(o['stock_millibarrels'] for o in state['owners'].values()) + output <= config.output_capacity_millibarrels, 'OUTPUT_CAPACITY')
            lot = next((c for c in candidate['cargo'] if c.get('id') == request['lot_id'] and c.get('definition') == 'cargo_oil' and c.get('ship') == candidate['ship']['id']), None)
            require(lot is not None, 'CARGO_NOT_OWNED')
            cost = consume_lot(lot, units, refining=True)
            if not remaining_units(lot): candidate['cargo'].remove(lot)
            duration = (units * 1000 + config.rate_millibarrels_per_second - 1) // config.rate_millibarrels_per_second
            job = dict(account=account, action_id=request['action_id'], lot_id=request['lot_id'],
                       input_millibarrels=units, output_millibarrels=output, remainder_after=remainder,
                       allocated_cost_minor=cost, duration_ms=duration, started_ms=state['time_ms'],
                       ready_ms=state['time_ms'] + duration, status='processing')
            state['owners'][account] = own
            state['jobs'].append(job)
            result = dict(ok=True, code='REFINERY_SUBMITTED', job=copy.deepcopy(job))
        elif op == 'refinery_quote':
            require(len(state['quotes']) < LIMIT, 'REFINERY_LEDGER_FULL')
            units = request['millibarrels']
            require(units <= own['stock_millibarrels'], 'INSUFFICIENT_STOCK')
            quote = dict(id=uuid.uuid4().hex, account=account, ship=candidate['ship']['id'],
                         port_id=PORT_ID, millibarrels=units,
                         cost_minor=(units * state['fee_minor_per_barrel'] + 999) // 1000, consumed=False)
            state['quotes'][quote['id']] = quote
            result = dict(ok=True, code='REFINERY_QUOTE', quote=copy.deepcopy(quote))
        else:
            require(len(state['withdrawals']) < LIMIT, 'REFINERY_LEDGER_FULL')
            quote = state['quotes'].get(request['quote_id'])
            require(quote is not None and quote['account'] == account, 'UNKNOWN_QUOTE')
            require(not quote['consumed'], 'QUOTE_CONSUMED')
            require(quote['ship'] == candidate['ship']['id'], 'SHIP_CHANGED')
            require(quote['millibarrels'] <= own['stock_millibarrels'], 'INSUFFICIENT_STOCK')
            require(profile['money'] >= quote['cost_minor'], 'INSUFFICIENT_FUNDS')
            amount = -quote['cost_minor']
            own['stock_millibarrels'] -= quote['millibarrels']
            quote['consumed'] = True
            collection = dict(account=account, action_id=request['action_id'], quote_id=quote['id'],
                              millibarrels=quote['millibarrels'], cost_minor=quote['cost_minor'], status='awaiting_loading')
            state['withdrawals'].append(collection)
            result = dict(ok=True, code='REFINERY_WITHDRAWN', collection=copy.deepcopy(collection))
        if op != 'refinery_quote':
            tx.settle(account, candidate, amount)
            fault('after_profile_write', request)
            result.update(action_id=request['action_id'], revision=profile['revision']+1,
                          amount=amount, wallet_minor=profile['money']+amount)
    validate(state, realm)
    tx.save_refinery(REFINERY_ID, state)
    fault('after_refinery_write', request)
    if op in ('refinery_submit', 'refinery_withdraw'):
        tx.save_receipt(account, request['action_id'], fingerprint, result)
    return result
