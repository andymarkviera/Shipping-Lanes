# Definitions and stable IDs — Step 10

Small custom Resources describe ships, cargo types, ports and berths. The catalog
contains one starter ship, one test container, one test harbor and one test berth.
The existing `ship_starter_container_01` ID is preserved. Other IDs are explicitly
prototype-only; names and resource paths are not persistent identities.

DefinitionRegistry validates the complete candidate catalog before publishing it.
It rejects duplicate/invalid IDs, null/unsupported records, empty required fields,
missing or wrong-type references, repeated references, missing ship scenes, and
inconsistent port/berth ownership. Failed replacement leaves the prior catalog
available. Main validates at boot and stops on invalid content.

Shared definitions are authoring data, with no fuel, cargo inventory or owner.
The registry privately stores deep copies and returns defensive copies; callers
must not mutate the source Resources or access its internal dictionary. ShipState
uses a definition ID and separately owns instance ID, fuel and deep-copied cargo.
Two instances can resolve the same definition while carrying different state.
This is a data foundation, not a save schema or authoritative mutation API.

No price, capacity, starting fuel, mass, port position, clearance or handling
values have been approved here. Test fuel amounts and container counts are only
isolation fixtures. Numeric units, bounds, durability and protocol validation
remain their scheduled tasks. Registry validity is not berth compatibility or
physical-world validation. The test port has no world geometry.

## Checks and use

Run `./tools/Godot.ps1 -Mode CatalogCheck` from ShippingLanes. It checks independent
ship fuel/nested cargo, no caller/source aliasing, lookup isolation, invalid
references/duplicates, retained valid state after rejection, and the existing
ship wrapper's definition metadata. ControlsCheck and FlowCheck also pass.

Catalog scripts/records and the ship scene are explicit export roots. The first
release validation exposed lost packed-string reference fields; typed Array[String]
fields and matching Resource values pass both editor and exported boot validation.
A Windows release launch passes with the full catalog validated, not just parsed.

## Requested settings refinement

The settings panel uses a fully opaque background. Both sliders use continuous
values (no 0.05 snapping); sensitivity retains a two-decimal readout and volume
has no number. Existing Save/Cancel persistence and validation remain intact.
ControlsCheck covers opacity, continuous values and readout presence. A native
1152 x 648 capture was inspected at ../output/checks/step-10-settings.png.

## Next prerequisites

Before Step 11 (save-and-protocol-contracts), BUILD_DEPENDENCIES.md requires
geographic-contract-feasibility and private-storage-dependency-proof. Neither is
completed by these placeholder definitions; execute those before durable schemas.
