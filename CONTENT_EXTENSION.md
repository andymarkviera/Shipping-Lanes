# Content extension rehearsal — Step 85

Status: draft, UNVERIFIED. Nothing in this step was executed (see PROGRESS.md).

One commodity, one conventional ship and one port were added with the existing
definition tools. No transaction, save or generic ship-controller logic changed.

| Record | ID | Files |
|---|---|---|
| Commodity | `cargo_bulk_salt` (Salt, grams, bulk holds) | `features/catalog/records/bulk_salt.tres` |
| Ship | `ship_harbor_container_01` (Harbor container ship) | `features/catalog/records/harbor_ship.tres` |
| Port | `port_cinder_point` + `berth_cinder_point_01` | `features/ports/cinder_point.tres`, `cinder_point_berth.tres`, `cinder_point.tscn` |

All values are prototype tuning pending Andy's review. The ship reuses the
starter hull scene and container layout; the port reuses `test_port.gd`.

## Where configuration is sufficient

Every new record needs a line in `PrototypeCatalog.RECORDS` (append only: several
checks address early rows by index) and in `export_presets.cfg`. After that:

- **Commodity in an existing family.** The record alone makes it valid in
  manifests, save-record references and bulk quotes. Listing it in a hull's
  `cargo_type_ids` and `bulk_holds` (done for `bulk_ship.tres`) lets that hull
  carry it. Capacity, one-commodity-per-hold, partial discharge and settlement
  apply unchanged.
- **Conventional container ship.** The record gives handling, fuel, capacity,
  camera and wake. Adding rows to `services/public_authority/ship_catalog.json`,
  `resale_values.json` and `repair_costs.json` makes it purchasable, storable,
  switchable, repairable, refuelable and resellable online: the Python services
  and the Godot quote, inspection and fleet code all read those files.
- **Port and berth.** The records and a scene using `test_port.gd` give geometry,
  anchors, berth envelope, services, spawn and recovery positions. The port
  validates, resolves in save records and manifests, and can be an origin or
  destination of authored bulk quotes. Display names everywhere come from the
  record.

## Accidental hard-coded IDs found and fixed

- Online hull allow-lists in `public_fleet_service.gd` and
  `public_authority_client.gd` named three ship IDs. Both now ask the ship
  catalog, as the Python services already did. Without this the new ship could be
  bought but never activated, and its profile would be rejected.
- Bulk and gas commodity lists in `bulk_earnings.gd` were literal. They now come
  from cargo records by capacity pool, in catalog order (unchanged for existing
  commodities).
- Port names were chosen by comparing IDs in `delivery_service.gd`,
  `public_cargo_panel.gd`, `port_test.gd`, `local_minimap.gd`,
  `fleet_inspection.gd` and `oil_market_panel.gd`. Any third port would have been
  labelled "Slatewater Works". They now use `PrototypeCatalog.display_name` /
  `short_name`.
- `test_port.gd` chose its landmark by port ID. It is now the scene property
  `landmark` (`fuel_store` on Brindle Quay; geometry is unchanged).
- Checks that counted three ships: `ship_purchase_probe.gd`,
  `test_ship_purchase.py`, `economy_gate.py` and `economy_gate_probe.gd`.

## Where new behavior genuinely needs code

- **Placing a port in a world.** Cinder Point is not in Port Test or the public
  world. Both worlds are two-port by construction: `port_test.gd` positions,
  `voyage_snapshot.gd` / `voyage_lifecycle.gd` save validation by port index,
  `public_port_catalog.gd` addresses and spawn geometry, the two-row dock snapshot
  in `public_peer_session.gd`, `fleet_slots.json`, and the `PORTS` tuples in
  `voyages.py`, `refueling.py`, `repairs.py` and `ship_purchase.py`. Changing them
  alters saves and the protocol, so it belongs with the Step 88 world layout
  decision, not this rehearsal.
- **Seeded offers.** Container, bulk and gas offers and their rates are seeded in
  code (`container_offers.gd`, `bulk_service.gd`) and saved checkpoints are
  validated against those seeds. Salt can be quoted by an authority but no seeded
  salt job exists; adding one needs a deliberate seed/save version.
- **Bulk/gas service panel** lists four commodity names and fixed hold names by
  index, so salt is not selectable in that UI.
- **A new cargo family, unit or capacity pool** needs manifest rules, a validator
  branch in `definition_registry.gd` and a service, as gas did.
- **A non-container hull online.** `public_port_authority.gd` checks berths with
  `container_transfer` / `cargo_test_container`, `voyages.py` creates
  `cargo_test_container` cargo, and fuel is bounded at 1000 L in
  `public_authority_client.gd`, `public_snapshot_codec.gd` and
  `public_voyage_service.gd`. A ship with a larger tank needs those bounds read
  from its definition.
- **Fixture identities left as they are:** two-port oil market and refinery
  constants, heavy-lifter mode checks in Port Test and local/private sessions,
  `LocalWorldSave.CARGO_ID`, and the `cargo_test_container` unit rule in
  `record_contract.gd` (it should follow the cargo record's `quantity_unit`, but
  that is save-contract logic and was not changed here).
- **New art.** A distinct hull needs its own scene, collision and container layout.

## Check

`godot --headless --path . --script tools/content_extension_probe.gd` with an
isolated user-data directory; expect `CONTENT_EXTENSION_PASS ... failures=0`.
It covers registry validation, save-record contracts, a salt quote/load/partial
discharge, a container voyage on the new hull, and the port scene and names.
