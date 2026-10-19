# Geographic contract feasibility

Completed October 19, 2026. This is a synthetic coordinate experiment, not a
physical world implementation, approved port catalog or durable save schema.

## Draft address

An address carries world_id (`world_coordinate_fixture`), content_revision (1),
latitude_deg [-90,90], longitude_deg [-180,180), altitude_m, heading_deg [0,360),
and frame (`meridian_tangent_v1`). Latitude/longitude/heading use scalar double
precision degrees. Altitude is meters relative to the future mean-water datum;
no physical radius, world scale, ocean heights or actual datum is chosen here.
Unknown worlds, revisions, frames, fields, nonfinite numbers and noncanonical
received coordinates are rejected. Normalization is explicit for authored input.
Port IDs, tile IDs and Godot scene positions are not geographic identity.

Longitude wraps exactly; latitude beyond a pole reflects and shifts the reference
meridian by 180 degrees. Heading is interpreted in the resulting frame; this
helper does not transport a moving ship's orientation across a pole. Runtime
orientation transport and seam handoff remain later physical/network experiments.

At an exact pole the address retains its reference longitude. The position alone
cannot recover that longitude or heading. Globe inversion accepts the retained
meridian as a hint at the axis; without it the documented default is zero.
An analytic east/up/north tangent basis avoids normalizing a zero cross product.
Heading zero follows the frame's north tangent, increasing toward east. This
frame is for geographic math; mapping it to the ship's art axes comes later.

## Projections and tests

The globe is a unit sphere: +Y north, +X at latitude/longitude zero, +Z at 90E.
The flat experiment is equirectangular: u wraps horizontally in [0,1), v runs
from north pole 0 to south pole 1. Poles span many flat longitudes but one globe
position. Neither projection is claimed as the final gameplay geometry.
Five synthetic markers include origin, opposite sides of the seam, and both poles.
An additional latitude/longitude grid checks near-pole and seam edge cases.

342 assertions pass in the pinned editor and exported Windows release:
- Canonical wrapping/reflection, finite inputs and invalid addresses.
- Scalar JSON and flat round trips within 1e-9 degrees.
- Float32 unit-globe round trips within 1e-5 degrees, retaining the pole meridian.
- Tangent frame determinant/orthonormality and heading within 1e-6.
- A 0.002-degree seam gap and a synthetic 360-degree longitude circuit.
- JSON retains altitude and heading along with geographic identity.

Godot wrapf snapped 179.999 to -180 in this build, failing the seam check.
Explicit double scalar wrapping fixed it. Approximate endpoint equality must
not be used to canonicalize persistent addresses. Globe vectors are derived,
never serialized in place of scalar coordinates.

JSON is an in-memory serialization fixture only. No file durability, packet
transport, world revision migration, live physics or real circumnavigation is
claimed. Full physical/precision proof remains Step 25 and
connected-world-network-feasibility. Local rendering origins/streaming frames
and pole orientation transport are still open decisions.

## Repeatable checks

From ShippingLanes:

```powershell
./tools/Godot.ps1 -Mode GeographyCheck
./tools/Godot.ps1 -Mode Export -Configuration Release
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -GeographyProbe
```

The release template rejects --scene path overrides. The exported probe instead
uses the application-owned `-- --geography-check` diagnostic route; normal startup
still opens the menu. The route instantiates the packaged test scene and exits
with a failure code on any failed assertion. No settings or player saves change.
The standard native release startup also passed. No user playtest is needed for
this mathematical prerequisite.
