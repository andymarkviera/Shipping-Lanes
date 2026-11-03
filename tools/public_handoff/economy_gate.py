"""Repeatable Step 67 public progression using production receipt dispatch.
SQL/lease/physical docking are doubles, never a PostgreSQL or human playtest claim.
Feed metrics from tools/economy_gate_probe.gd (production handling/fuel at 60 Hz).
"""
import argparse
import copy
import datetime
import json
import math
from pathlib import Path
from test_ship_purchase import MemoryDB, ACCOUNT
from authority import Authority
import refueling
import repairs
import ship_purchase
import voyages
import wear

COASTAL = 'ship_coastal_container_01'
STARTER = 'ship_starter_container_01'


class Scenario:
    def __init__(self, reload_each=False):
        # Same new-player terms as local_online.py, no fixture_delivery test job.
        self.row = dict(money=20000, revision=0, profile=dict(version=1,
            ship=dict(id='starter', definition=STARTER, fuel_liters=800.0,
                      position=dict(latitude=0., longitude=0., heading=0.)),
            cargo=[], jobs=[], delivered=[]))
        self.db = MemoryDB(self.row)
        self.authority = Authority({})
        self.sequence = 0
        self.seconds = 0.
        self.reload_each = reload_each
        self.costs = dict(fuel=0, repair=0, recovery=0)
        self.legs = []
        self.unreplaced_fuel = 0.
        # Controlled database clock; loading is advanced, never bypassed.
        self.db.now = datetime.datetime(2026, 11, 2, tzinfo=datetime.timezone.utc)
        self.authority._now = lambda db: self.db.now

    def reload(self):
        snapshot = json.loads(json.dumps(dict(row=self.row, receipts=self.db.receipts,
                                             journal=self.db.journal, money=self.db.money)))
        now = self.db.now
        self.row = snapshot['row']
        self.db = MemoryDB(self.row)
        for key in ('receipts', 'journal', 'money'): setattr(self.db, key, snapshot[key])
        self.db.now = now
        self.authority = Authority({})
        self.authority._now = lambda db: self.db.now

    def advance(self, seconds):
        self.seconds += seconds
        self.db.now += datetime.timedelta(seconds=seconds)

    def call(self, op, **fields):
        self.sequence += 1
        request = dict(realm='public', op=op, account=ACCOUNT, epoch=1, generation=1,
                       action_id=f'gate_{self.sequence}', expected_revision=self.row['revision'], **fields)
        self.authority._validate(request)
        result = self.authority._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), request)
        if self.reload_each: self.reload()
        before = copy.deepcopy((self.row, self.db.money, self.db.journal))
        replay = self.authority._voyage(self.db, ACCOUNT, copy.deepcopy(self.row), request)
        assert replay.pop('duplicate') and replay == result
        assert before == (self.row, self.db.money, self.db.journal)
        assert self.row['money'] + self.db.money == 1020000
        return result

    def ok(self, op, **fields):
        result = self.call(op, **fields)
        assert result['ok'], result
        return result

    def loaded(self, route, index):
        port = voyages.PORTS[route]
        result = self.ok('voyage_accept', port_id=port, offer_id=f'container_seed_v1_{route}_{index}')
        job = result['job']
        assert self.call('voyage_load', port_id=port, job_id=job['id'])['code'] == 'LOADING_PENDING'
        assert self.call('voyage_accept', port_id=port, offer_id=f'container_seed_v1_{route}_0')['code'] == 'JOB_ALREADY_ACTIVE'
        self.advance(job['quantity'] * 5)
        self.ok('voyage_load', port_id=port, job_id=job['id'])
        return job['id']

    def motion(self, metric, fraction=1):
        # Trusted movement checkpoint modeled here; does not attest SQL or physical docking.
        ship = self.row['profile']['ship']
        ship['fuel_liters'] -= metric['fuel_liters'] * fraction
        assert ship['fuel_liters'] > 0, 'route must remain fueled'
        wear.apply(ship, metric['operating_seconds'] * fraction)
        self.advance(metric['seconds'] * fraction)
        if self.reload_each: self.reload()

    def service(self, port, fuel):
        # Replace consumed prepaid fuel so earnings cannot masquerade as net profit.
        liters = math.ceil(fuel)
        self.ok('refuel', port_id=port, liters=liters, unit_price_minor=refueling.UNIT_PRICE_MINOR)
        self.costs['fuel'] += liters * refueling.UNIT_PRICE_MINOR
        terms = repairs.quote(self.row['profile']['ship'])
        if terms['cost_minor']:
            self.ok('repair', port_id=port, condition_bp=terms['condition_bp'], cost_minor=terms['cost_minor'])
            self.costs['repair'] += terms['cost_minor']

    def deliver(self, metric, index):
        route = metric['leg']
        job = self.loaded(route, index)
        self.motion(metric)
        self.advance(2)  # existing 1 s docking + 1 s undocking transitions
        result = self.ok('voyage_deliver', port_id=voyages.PORTS[1-route], job_id=job)
        self.costs['recovery'] += result.get('recovery_repaid_minor', 0)
        self.service(voyages.PORTS[1-route], metric['fuel_liters'] + self.unreplaced_fuel)
        self.unreplaced_fuel = 0.
        self.legs.append(dict(route=route, quantity=index+1, gross_minor=result['job']['reward_minor'],
                              wallet_minor=self.row['money'], elapsed_seconds=round(self.seconds, 2)))
        assert self.call('voyage_deliver', port_id=voyages.PORTS[1-route], job_id=job)['code'] == 'JOB_NOT_ACTIVE'
        assert self.call('voyage_accept', port_id=voyages.PORTS[route],
                         offer_id=f'container_seed_v1_{route}_{index}')['code'] == 'OFFER_CLOSED'

    def upgrade(self, port):
        price = ship_purchase.CATALOG[COASTAL]['cost_minor']
        result = self.ok('ship_purchase', port_id=port, definition_id=COASTAL, cost_minor=price)
        owned = result['owned_ship']['id']
        self.ok('fleet_switch', port_id=port, ship_id=owned, slot=0)
        assert self.row['profile']['ship']['fuel_liters'] == 0
        self.ok('refuel', port_id=port, liters=250, unit_price_minor=refueling.UNIT_PRICE_MINOR)
        assert self.row['profile']['ship']['id'] == owned
        assert self.row['money'] >= 0
        assert self.row['money'] == 20000 + sum(leg['gross_minor'] for leg in self.legs) - sum(self.costs.values()) - price - 6250
        return dict(seconds=round(self.seconds, 2), voyages=len(self.legs), wallet_minor=self.row['money'],
                    operating_cost_minor=sum(self.costs.values()), costs=self.costs,
                    upgrade_minor=price, upgrade_fuel_minor=6250, legs=self.legs)


def progression(metrics, cautious=False, failure=False, reload_each=False):
    scenario = Scenario(reload_each)
    starter = [m for m in metrics if m['definition'] == STARTER]
    if failure:
        scenario.loaded(0, 2)
        scenario.motion(starter[0], .5)
        scenario.unreplaced_fuel = starter[0]['fuel_liters'] * .5
        ship = scenario.row['profile']['ship']
        incident = scenario.ok('impact', damage_bp=10000, fuel_liters=ship['fuel_liters'], position=ship['position'])
        assert incident['code'] == 'SHIP_SUNK'
        scenario.costs['recovery'] += -incident['amount']
        assert scenario.row['money'] == 0 and scenario.row['profile']['recovery_debt_minor'] == 5000
        incident_id = scenario.row['profile']['recovery']['id']
        scenario.ok('recover', incident_id=incident_id, slot=0)
        assert scenario.call('recover', incident_id=incident_id, slot=0)['code'] == 'NO_RECOVERY'
        # Recovery placement/access back to services is a declared 120 s planning allowance.
        scenario.advance(120)
    for trip in range(6):
        route = trip % 2
        index = trip // 2 if cautious else 2-trip//2
        scenario.deliver(starter[route], index)
        if scenario.row['money'] >= ship_purchase.CATALOG[COASTAL]['cost_minor'] + 6250:
            result = scenario.upgrade(voyages.PORTS[1-route])
            result['recovery_debt_minor'] = scenario.row['profile'].get('recovery_debt_minor', 0)
            return result
    raise AssertionError('Finite seed offers must reach a fueled first upgrade')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--metrics', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    metrics = json.loads(args.metrics.read_text())
    assert len(metrics) == 6
    assert {(m['definition'], m['leg']) for m in metrics} == {(key, leg) for key in ship_purchase.CATALOG for leg in range(2)}
    assert all(all(math.isfinite(m[k]) and m[k] > 0 for k in ('seconds', 'operating_seconds', 'fuel_liters', 'distance_m')) for m in metrics)
    results = {}
    for name, options in [('large_contract', {}), ('small_contracts', dict(cautious=True)),
                          ('sinking_recovery', dict(failure=True))]:
        result = progression(metrics, **options)
        assert result == progression(metrics, reload_each=True, **options), 'reload changed progression'
        results[name] = result
    assert 480 <= results['large_contract']['seconds'] <= 900
    assert 1200 <= results['small_contracts']['seconds'] <= 2100
    assert results['sinking_recovery']['recovery_debt_minor'] == 0
    # Like-for-like route must demonstrate the useful class role, not merely cheaper ownership.
    for leg in range(2):
        by_id = {m['definition']: m for m in metrics if m['leg'] == leg}
        assert by_id[COASTAL]['fuel_liters'] < by_id[STARTER]['fuel_liters'] * .82
        assert by_id[COASTAL]['seconds'] == by_id[STARTER]['seconds']
        assert 250 > by_id[COASTAL]['fuel_liters']
    # Record the same route/cost policy with the pre-gate price, without editing live data.
    tuned_price = ship_purchase.CATALOG[COASTAL]['cost_minor']
    try:
        ship_purchase.CATALOG[COASTAL]['cost_minor'] = 90000
        results['previous_900_credit_price'] = progression(metrics)
    finally:
        ship_purchase.CATALOG[COASTAL]['cost_minor'] = tuned_price
    if args.output: args.output.write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(results, indent=2))
    print('ECONOMY_PROGRESSION_PASS (three scenarios, replay every request, reload equivalence)')

if __name__ == '__main__': main()
