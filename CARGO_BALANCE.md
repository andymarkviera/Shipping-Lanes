# Step 86 — Priority cargo balance

Task ID: `priority-cargo-balance`. D143. November 11, 2026. **Draft, UNVERIFIED:**
nothing in this step was executed on the cloud runner. The table was worked by
hand from recorded measurements; `tools/public_handoff/test_cargo_balance.py`
recomputes it and has not yet run.

## What is measured and what is not

- **Travel time, fuel and wear are the Step 67 starter-hull measurements** in
  ECONOMY_GATE.md: Brindle Quay → Slatewater Works, 530.18 s, 164 L (41.00) plus
  0.35 repair; return 653.22 s, 215 L (53.75) plus 0.45 repair. No new voyage was
  sailed for this step.
- The bulk, gas and oil fixtures use the starter hull's handling, so the same leg
  is applied to them. The effect of their cargo mass on fuel is not measured.
- **No heavy-lifter voyage has ever been measured.** Its rows show the reward only.
- Earnings are each family's own settlement arithmetic on the fixture offer.
- Time includes 2 s docking/undocking per leg, 5 s per container, 5 s per bulk/gas
  load or unload and 200 s of refining. Menus and human navigation are excluded.

Both fixture ports are 1,500 m apart (0.81 NM). All money is credits.

## Example voyages after tuning

| Family | Voyage | Cargo capital | Earned | Operating cost | Net | Time | Net/min |
|---|---|---:|---:|---:|---:|---:|---:|
| Containers | 1 container, one way | 0.00 | 250.00 | 41.35 | 208.65 | 537.18 s | 23.30 |
| Containers | 3 containers, one way | 0.00 | 750.00 | 41.35 | 708.65 | 547.18 s | 77.70 |
| Bulk | 123.46 t grain, one way | 0.00 | 791.93 | 41.35 | 750.58 | 542.18 s | 83.06 |
| Bulk | 123.46 t ore, one way | 0.00 | 1187.90 | 41.35 | 1146.55 | 542.18 s | 126.88 |
| Gas | 123 m³ LNG, one way | 0.00 | 986.25 | 41.35 | 944.90 | 542.18 s | 104.56 |
| Gas | 123 m³ oxygen, one way | 0.00 | 1479.38 | 41.35 | 1438.03 | 542.18 s | 159.13 |
| Oil | 200 barrels crude, one way | 270.00 | 60.00 | 41.35 | 18.65 | 532.18 s | 2.10 |
| Cargo fuel | 200 barrels out, refine, 140 barrels fuel back | 270.00 | 176.60 | 95.55 | 81.05 | 1387.40 s | 3.50 |
| Heavy | 60 t module | 0.00 | 450.00 | not measured | not measured | not measured | not measured |
| Heavy | 100 t block | 0.00 | 700.00 | not measured | not measured | not measured | not measured |
| Heavy | 150 t girder | 0.00 | 1000.00 | not measured | not measured | not measured | not measured |

"Earned" is the contract reward, or for oil and cargo fuel the sale minus the
purchase and refinery fee. Oil figures use a fresh market: buy at 1.35, sell crude
at 1.65, sell fuel at 3.20 per barrel.

## What changed

| Value | Before | After | Effect on the example |
|---|---:|---:|---|
| Bulk rates (limestone / grain / coal / ore), minor per tonne per NM | 80 / 100 / 120 / 150 | 640 / 800 / 960 / 1200 | Grain paid 98.99 (6.37 net/min); now 791.93 |
| Gas rates (argon / LNG / nitrogen / oxygen), minor per m³ per NM | 80 / 100 / 120 / 150 | 800 / 1000 / 1200 / 1500 | LNG paid 98.62; now 986.25 |
| Cargo fuel sale price, minor per barrel | 220 | 320 | The full chain lost 58.95 per round trip; now nets 81.05 |

Containers, oil market prices, refinery yield and fee, heavy rewards, fuel price,
repair cost and recovery fee are unchanged. Saved bulk and gas voyages keep their
frozen quotes; cargo fuel already aboard keeps the price frozen when it was loaded.

## Why each family is worth playing

- **Containers — the starter job.** No capital, runs on the starter hull, and the
  1–3 container sizes let a new player choose a short or a full trip. Flat pay per
  container regardless of distance.
- **Bulk — the steady step up.** Needs a bulk hull. Grain now pays slightly more
  per minute than a full container load and ore clearly more; limestone (633.54)
  is the low-value filler. Pay scales with direct distance and can be discharged
  in parts.
- **Gas — the specialist.** Needs a gas hull and a matching pipeline at both ends.
  The highest contract rates, about 25% above the equivalent bulk cargo.
- **Oil — trading on your own money.** The only family where the player buys the
  cargo. **It is not yet worth playing on its own:** a full tanker nets 18.65 one
  way, and returning empty costs 54.20, so a crude-only round trip loses 35.55.
- **Cargo fuel — the value-added chain.** Refining and carrying the fuel back now
  beats selling the crude, but at 3.50 net per minute it is far below the contract
  families.
- **Heavy — finite one-off lifts.** Large single rewards, no cargo capital, a
  dedicated lifter and careful positioning. Each payload is consumed once
  delivered. Not comparable per minute until a lifter voyage is measured.

## Open balance problem: oil and cargo fuel

The 200-barrel prototype tanker carries about 270 credits of crude, so no sensible
price makes a voyage pay like a contract. Matching containers would need fuel at
roughly 16 credits per barrel against crude at 1.35. The fix is scale, not price:
tanker capacity, the 200-barrel trade limit, the refinery input limit and the
fixture wallet would all need to rise together (about tenfold). That touches the
oil model, saved fixture worlds and many pinned test values, so it was not
attempted without a runner. Decide it with Andy before or at Step 88.

## Starter access

- A new profile (200 credits, 800 L, starter hull) can play **containers only**.
- Every other family needs its dedicated hull: bulk hull, gas hull, tanker (oil and
  cargo fuel), heavy lifter. None of these is on sale online yet.
- Until those hulls are sold online, each family stays reachable without purchase
  through its developer fixture, so the Step 87 playtest can cover all of them.
- Only oil needs cargo capital. The 200-credit starting wallet buys 151 barrels.
- Intended order once the hulls are placed online: containers, then bulk, then
  gas; the tanker as a side line; heavy lifts as occasional one-offs. Hull prices
  are not set here; set them when the hulls go online, with measured voyages.

## Reproduce

```sh
python3 tools/public_handoff/cargo_balance.py
python3 -m unittest discover -s tools/public_handoff -p 'test_cargo_balance.py'
```

The script needs no database or Godot. It imports the oil, cargo fuel and heavy
constants from `services/` and mirrors the bulk/gas rates from
`features/cargo/bulk_service.gd`; the test fails if those drift apart.

## Limits

- Fixture economies are separate: each family has its own private wallet and only
  containers are online. This table compares them on one route; it is not a
  shared-economy simulation.
- One short route. Bulk and gas pay by distance and containers do not, so the
  ranking will shift on longer routes at Step 88.
- Offers are finite and do not regenerate.
- Risk is not quantified. Sinking costs the 250-credit recovery fee in the online
  container game; the loss rules for each private family were not re-measured.
- No playtest. Andy has not accepted these values.
