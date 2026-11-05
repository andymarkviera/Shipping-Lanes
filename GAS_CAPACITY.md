# Gas capacity and terminal compatibility — Step 71

Task: `gas-capacity-and-terminal-compatibility`; decision D128. This step provides
validated definitions, manifest capacity and a read-only terminal compatibility
query. Delivery, quotes, timed transfer, UI and persistence are Step 72.

## Launch commodities

| Stable ID | Commodity | Required pipeline type |
| --- | --- | --- |
| `cargo_gas_lng` | LNG | `lng` |
| `cargo_gas_nitrogen` | Nitrogen | `industrial_cryogenic` |
| `cargo_gas_oxygen` | Oxygen | `industrial_cryogenic` |
| `cargo_gas_argon` | Argon | `industrial_cryogenic` |

This is our explicit launch set, not a claim to reproduce the research game's
catalog. Research section Gas reports five/seven types and differing ship lists.
LNG covers methane-based cargo here; a second methane commodity would be ambiguous.
Helium and hydrogen are excluded pending separately authored containment/interfaces.
There is no gas buy/sell market, oil pricing, conversion or free propulsion fuel.
The industrial interface is a gameplay capability class, not a real engineering
claim that these gases can share contaminated tanks or pipes.

## Units and segregation

`quantity_unit = cubic_meter`, display `m³`, and `capacity_pool = gas_tanks`.
Quantities and individual tank capacities are positive integers up to 1,000,000,000;
one m³ is the smallest supported quantity. Fractions, floats, booleans and implicit
unit conversions are rejected. Step 72 must preserve this precision or explicitly
revise the contract before introducing fractional transfers/settlement.

Ships author stable `gas_tanks` IDs, `capacity_cubic_meters`, `cargo_type_ids` and
`pipeline_type`. An aggregate `cargo_capacities.gas_tanks` shortcut is forbidden.
At most 256 tanks and 256 manifest batches are supported. IDs are nonblank strings
up to 128 characters. `single_commodity_per_tank` is the only mixing policy.
Same-commodity batches share a tank but keep provenance; different commodities
require different compatible tanks. Capacity is checked per tank before mutation.
Emptying a tank clears its assignment without adding cleaning or machinery wear.

Gas batches require `tank_id`; bulk keeps `hold_id`, containers neither. Gas cannot
use bulk holds. `tank_usage()` and `hold_usage()` remain separate even when authors
reuse a compartment name. `usage()` keeps count, grams and m³ in distinct pools.
DWT, visual dimensions, fuel tanks and container slot counts do not supply gas
capacity. Definitions and manifests remain copied/isolated from caller edits.

## Terminal capability contract

Berths author `gas_pipelines` keyed by stable pipeline ID. Each has explicit
`cargo_type_ids`, `pipeline_type`, `can_load` and `can_unload`; at least one direction
must be true. No pipeline is inferred from a port name or generic cargo service.
Registry validation rejects unknown/non-gas commodities, malformed capabilities,
duplicate references and commodity/interface mismatches transactionally.

`GasRules.transfer_error(ship, cargo, tank_id, berth, pipeline_id, direction)`
returns an empty string only for compatible definitions, ship/tank commodity
allowlists, matching commodity/tank/pipeline interfaces, berth/pipeline allowlists,
and an enabled `load` or `unload` direction. Unknown pipeline/tank/direction fails.
It has no mutation, clock, stock, payment or save effects. Physical docking,
ownership, current tank allocation/free capacity and operation revalidation remain
separate requirements. The future Step 72 service must call this capability query
and manifest validation at admission and completion; a manifest alone proves only
onboard capacity, not terminal permission. No gas operation is enabled by this step.

## Authored fixtures and scope

The data-only gas hull has one 400 m³ LNG tank and two 600 m³ industrial tanks.
A data-only terminal has one bidirectional pipeline of each interface. Fixtures
are not playable, purchasable or spawned; they reuse scene references solely for
catalog validation. Only the four cargo definitions join PrototypeCatalog; existing
ships/ports gain no gas capacity or pipelines. All new runtime resources are
explicitly exported. Existing public protocol 17, ticket 7, save schemas and UIDs
are preserved. No deferred player request or Step 72 lifecycle work is implemented.

Run the focused probe with pinned Godot 4.7.2:

```
Godot --headless --path . --script tools/gas_capacity_probe.gd
```

See PROGRESS.md for actual Linux evidence and remaining platform/manual gates.
