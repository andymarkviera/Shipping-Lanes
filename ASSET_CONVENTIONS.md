# Ship asset conventions

Step 07 — October 18, 2026. Starter preparation and reproducible import are
complete. This is an asset prototype, not a sail-ready ship or approved release art.

## Coordinates and ownership

- One Blender and Godot unit represents one metre. Blender +Z up and -Y bow
  become Godot +Y up and +Z bow. Port is +X; starboard is -X. Ship forward is
  distinct from a Godot camera's local -Z viewing direction.
- Assembly root: identity transform at hull midpoint/centerline and reference
  empty waterline. Godot Y=0 is that plane; keel reaches Y=-3.2. This is not an
  automatic physics center of mass. Loaded draft remains undecided.
- A tiny asymmetrical calibration GLB checks bow/port/starboard/up and metre
  scale through the same exporter. No compensating wrapper rotations are used.
- Required attachments use `SOCKET_`. Their local +Z faces forward and +Y up,
  except names: +Z faces outward (+X port, -X starboard). Rudder and propeller
  retain separate pivots. Imported socket positions and normals are checked.
- The editable wrapper owns stable asset/definition IDs, VisualRoot and a convex
  hull Shape3D reference. The GLB owns geometry/materials/sockets only. No physics
  body is imported or selected here. Step 16 attaches the reference to the chosen
  movement body; Step 21 proves impacts. Rails and upper fittings are not included
  in the simple hull collision; clearance rules must use full visual envelopes.

## Source and measurements

The Downloads original remains unchanged. A byte-identical editable copy is
tracked at `art_sources/starter_container_01/starter_container_01.blend`.
`art_sources/.gdignore` prevents automatic Blender import. SHA-256:
`C5113240F9149996F1F8B6452E57FC04890F8A9AAE79FED904AE6139B8B5FE06`.
The earlier `../output/starter_container_01/` source differs; its metadata and
generator were consulted as context, not substituted for Andy's supplied file.

Blender 3.6.1 / Godot 4.7.2 are tested. Export appends the named collection into
a disposable factory scene and never saves over the source. It enables Auto
Smooth for existing weighted-normal modifiers and corrects sign normals there.
Preview cargo/corrugation, source collision boxes, default Cube, cameras and
lights are excluded. Modifiers are evaluated; animations are omitted.

| Measurement | Result |
| --- | --- |
| Hull length / beam | 64 m / 13 m |
| Reference keel depth | 3.2 m |
| Full empty visual envelope | 64.08363 m long × 13.2 m wide × 17.2 m tall |
| Highest empty point above waterline | 14.0 m |
| Geometry | 79 meshes; 2,728 evaluated triangles; 7 material roles |
| Attachments | 12 unique sockets; rudder and propeller pivots |
| Cargo evidence | 24 visual slot positions; gameplay capacity undecided |

`features/ships/starter_container_01/asset_manifest.json` stores measured bounds,
socket/slot positions and convex hull points in Godot coordinates. Do not adopt
the older metadata's proposed 24 TEU capacity or 4 m loaded draft as game rules.

Material roles are hull primary/secondary, deck, superstructure, windows, metal
and trim. Preserve semantic names for later customization. These are opaque PBR
materials without textures. Later per-owned-ship painting must duplicate relevant
materials and prove no leakage between instances. Prototype regression limits:
100 meshes, 8 materials, 20,000 triangles; these do not establish fleet performance.

## Rebuild, check and inspect

From `ShippingLanes`, with PowerShell 7:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 3.6\blender.exe' --background --factory-startup --disable-autoexec --python .\tools\export_starter.py --python-exit-code 1
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Import
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode AssetCheck
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Run -Scene res://features/ships/starter_container_01/inspection.tscn
```

Close the static inspection window when done. It uses the coastal water swatch
on a flat plane, without sailing, waves or buoyancy. F5 still launches Main.
Godot can import the checked-in GLBs without a recipient-side Blender installation.

The exporter verifies source hash and Blender version. Future edits require a
preserved source revision, inspection, deliberate pin update and repeated checks.
Do not overwrite hand-tuned source using an unrelated old generation script.
Tracked `.glb.import` settings use unit scale 1, no automatic collision/type
suffixes, no animation import and no baked-light classification. `.godot/` is ignored.
Wrapper/inspection/IDs remain separate from generated GLBs, manifest and hull shape.

Reimport proof: append `-- --revision-note step07-reimport-proof` to the Blender
command to change only exported root metadata, then import/check. The GLB changed
while wrapper/collision hashes and all axis/socket checks remained valid.
Re-exporting the baseline reproduced its original GLB hash. Both preserved source
copies retained their original SHA-256. A native 1152×648 preview was inspected.

## Remaining acceptance

Andy reviews silhouette before fleet art. Source is user-supplied; a related local
generator claims original agent-assisted geometry, but the supplied file differs,
so final distribution provenance is not certified here. Movement, loaded draft,
collision behavior, cargo display, per-instance paint, gameplay camera, saved
ownership, exported asset packaging and fleet performance remain later tasks.
The Main-only Step 06 export does not include this separate inspection asset.
