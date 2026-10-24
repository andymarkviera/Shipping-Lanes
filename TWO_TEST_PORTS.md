# Step 43 — Two reusable test ports

Brindle Quay and Slatewater Works are independent port scenes with authoring-only
PortDefinition/BerthDefinition resources in features/ports. Both are published in
PrototypeCatalog alongside the earlier generic catalog fixture.

| Port | Berth | Planned service IDs | Quay |
| --- | --- | --- | --- |
| port_brindle_quay | berth_brindle_quay_01 | container_transfer, refuel | West/negative X, 140 m long |
| port_slatewater_works | berth_slatewater_works_01 | container_transfer, heavy_transfer, repair | East/positive X, 190 m long |

Brindle accepts cargo_test_container. Slatewater accepts that and
cargo_test_industrial. Capability strings describe planned services; they do not
perform loading, refueling, repairs or money transactions. Berth references and
cargo types are resolved through the existing definition registry.

Each local port frame has a spawn at (0,0,-180), approach at (0,0,-80), heading zero
(+Z bow). Berth centers are (0,0,70) and (0,0,95), respectively. Envelopes are
28x30x120 m and 28x30x170 m. Marker3D nodes materialize these data positions.
These are local scene coordinates, not assigned global world/save addresses.
There is no depth or hidden-grounding rule. The visible quay inner edge is 20 m
from the approach centerline; amber markers sit 42 m either side.

Original Godot box meshes provide a solid brown-gray quay, warehouse, container
placeholders, fuel store or industrial gantry. All solids use the shore collision
layer. The shared port script contains no economic state, network ownership,
reservations or gameplay transaction code. service_view returns copied arrays.
Individual port content does not own a sky, ocean, player or save; the test wrapper
composes those independently using existing water, ship, controls, camera and wake.

## Trying it

Main menu > PORT TEST. Choose either named port. Switching ports resets only the
disposable preview boat to its authored anchor. Saved keyboard controls, orbit,
zoom, throttle indicator and Esc-to-menu work as before. The compact opaque panel
identifies planned services and says no loading/saving. This preview does not read
or overwrite private slots and is not installed into the public server world yet.

## Verification

- 112 scripts/startup, existing CatalogCheck and FlowCheck pass.
- Editor ports probe: 18 checks, ../output/ports/864ed3b9.
- Final exported rendered probe: 21 checks, ../output/ports/25c28e0e.
- Checks independently instantiate each scene, validate catalog references and
  distinct IDs, inspect services without economy, protect authored arrays, confirm
  markers, verify solid visible quays and sample the starter hull envelope at 31
  points from each spawn to berth. Port switching resets the disposable boat.
- Exported screenshots port-0.png, port-1.png and port-menu.png were inspected in
  the final evidence folder. The capture uses an overview camera for port geometry;
  normal player preview uses the orbit camera. Menu controls fit the tested 1152x648
  viewport. Early captures preceded the compact panel and are superseded.

These are authored static approach checks, not Step 44's runtime spawn-volume,
reservation, other-hull, cargo-envelope or fallback/recovery policy. No manual
heavy-loader pickup acceptance is claimed. Step 43 is complete; next is Step 44.
