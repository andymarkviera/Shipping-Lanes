"""Step 86 priority cargo balance: one example voyage per family, in integers.

Travel time, fuel and wear are the Step 67 starter-hull measurements recorded in
ECONOMY_GATE.md; nothing is sailed here. Earnings use each family's own settlement
arithmetic. Money is minor credits, time is centiseconds. Run from anywhere:

    python3 tools/public_handoff/cargo_balance.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from services.heavy_load.private import PAYLOADS
from services.oil_market.model import Config
from services.refinery import cargo_fuel

BRINDLE, SLATEWATER = 'port_brindle_quay', 'port_slatewater_works'
# Measured starter legs: 530.18 s / 164 L + 0.35 repair, 653.22 s / 215 L + 0.45 repair.
OUT_CS, OUT_COST = 53018, 164 * 25 + 35
BACK_CS, BACK_COST = 65322, 215 * 25 + 45
DOCK_CS = 200            # 1 s docking + 1 s undocking per leg
SERVICE_CS = 500         # one container, or one bulk/gas load or unload
DISTANCE_M = 1500        # direct separation of the two fixture ports
MODIFIERS = 11000 * 9000  # Brindle and Slatewater basis points
CONTAINER_REWARD = 25000  # services/public_authority/voyages.py, per container
# Mirrors seed_offers() in features/cargo/bulk_service.gd; the test compares them.
BULK_RATES = dict(grain=800, coal=960, ore=1200, limestone=640)
GAS_RATES = dict(lng=1000, nitrogen=1200, oxygen=1500, argon=800)
BULK_GRAMS, GAS_M3 = 123456789, 123
BARRELS = 200            # prototype tanker capacity and largest single trade
YIELD = (7, 10)          # refinery default yield
FEE_PER_BARREL = 1       # refinery withdrawal fee
REFINE_CS = BARRELS * 100  # 1000 millibarrels per second


def bulk(rate): return BULK_GRAMS * DISTANCE_M * rate * MODIFIERS // 185200000000000000
def gas(rate): return GAS_M3 * DISTANCE_M * rate * MODIFIERS // 185200000000


def oil():
    """Fresh-market quotes for a full tanker: (purchase, crude sale, fuel sale, fee)."""
    cfg = Config()
    volume = BARRELS * cfg.volume_effect_minor // cfg.max_trade_barrels
    buy = (cfg.base_minor + cfg.port_offsets[BRINDLE] + volume) * BARRELS
    sell = (cfg.base_minor + cfg.port_offsets[SLATEWATER] - volume) * BARRELS
    fuel_mb = BARRELS * 1000 * YIELD[0] // YIELD[1]
    return buy, sell, fuel_mb * cargo_fuel.PRICE // 1000, (fuel_mb * FEE_PER_BARREL + 999) // 1000


def row(family, voyage, earned, capital=0, cost=OUT_COST, cs=None):
    net = None if cs is None else earned - cost
    return dict(family=family, voyage=voyage, capital=capital, earned=earned,
                cost=None if cs is None else cost, cs=cs, net=net,
                per_minute=None if cs is None else net * 6000 // cs)


def rows():
    leg = OUT_CS + DOCK_CS
    buy, sell, fuel, fee = oil()
    found = [
        row('containers', '1 container', CONTAINER_REWARD, cs=leg + SERVICE_CS),
        row('containers', '3 containers', 3 * CONTAINER_REWARD, cs=leg + 3 * SERVICE_CS),
        row('bulk', 'grain', bulk(BULK_RATES['grain']), cs=leg + 2 * SERVICE_CS),
        row('bulk', 'ore', bulk(BULK_RATES['ore']), cs=leg + 2 * SERVICE_CS),
        row('gas', 'lng', gas(GAS_RATES['lng']), cs=leg + 2 * SERVICE_CS),
        row('gas', 'oxygen', gas(GAS_RATES['oxygen']), cs=leg + 2 * SERVICE_CS),
        row('oil', 'crude one way', sell - buy, capital=buy, cs=leg),
        row('cargo_fuel', 'crude out, refine, fuel back', fuel - fee - buy, capital=buy,
            cost=OUT_COST + BACK_COST, cs=OUT_CS + BACK_CS + 2 * DOCK_CS + REFINE_CS),
    ]
    # No heavy-lifter voyage has been measured: reward only, no time or cost.
    return found + [row('heavy', terms['payload_definition'], terms['reward_minor'])
                    for terms in PAYLOADS.values()]


def credits(minor):
    if minor is None: return 'not measured'
    return '%d.%02d' % divmod(minor, 100)


def table():
    lines = ['| Family | Voyage | Cargo capital | Earned | Operating cost | Net | Time | Net/min |',
             '|---|---|---:|---:|---:|---:|---:|---:|']
    for r in rows():
        time = 'not measured' if r['cs'] is None else '%d.%02d s' % divmod(r['cs'], 100)
        lines.append('| %s | %s | %s | %s | %s | %s | %s | %s |' % (
            r['family'], r['voyage'], credits(r['capital']), credits(r['earned']),
            credits(r['cost']), credits(r['net']), time, credits(r['per_minute'])))
    return '\n'.join(lines)


if __name__ == '__main__': print(table())
