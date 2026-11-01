# Ship rig authoring guide — Blender to Godot

Andy’s shipping game • October 18, 2026 • Agent instructions v0.1

## 1. How to use this file

Read this guide before generating or modifying a ship asset. It defines what the reusable model assembly needs, how to construct it in Blender, and how to integrate and validate it in Godot. It is a **new reference**; creating it does not edit the research, specification, roadmap, or map reference.

“Rig” here means a ship’s visual assembly, useful pivots, attachment points, collision specification, and integration contract. Most ships need **no armature, skin weights, or character skeleton**. A ship is primarily a rigid hull with separately animated mechanical pieces. Add bones only for a demonstrated need such as a selected flag technique; do not bone-rig the entire fleet by default.

The initial release uses ship controls only. Walking surfaces, passengers, interiors, furniture sockets, and character animation are optional later work, not mandatory first-ship requirements. Ro-Ro vehicles and rockets are later cargo expansions; their requirements are documented so assets can be prepared when those features are selected.

No ship, Blender script, or Godot import has been built or run as part of this document. The instructions below are the authoring contract and acceptance process. Pin the actual Blender and Godot versions when development starts and adapt exporter settings to those versions.

## 2. Non-negotiable separation

| Blender/source asset owns | Godot/gameplay owns |
| --- | --- |
| Hull geometry, deck, bridge/superstructure, visual mechanical parts | Selected authoritative physics body and movement controller |
| Materials and named paint surfaces | Per-owned-ship color/name/flag state and safe material overrides |
| Origins, mechanical pivots, empties/socket transforms | Socket lookup, runtime markers, interaction/service behavior |
| Animation of visual mechanical parts, if authored | Authoritative state, timing, collision synchronization, replay/reconnect state |
| Measured visual/cargo envelope and simplified collision authoring data | Actual collision shapes attached to the correct moving body |
| Low-detail asset variants and source provenance | Visibility ranges, instancing/batching, quality settings, network relevance |

Do not embed wallet, cargo payouts, account ownership, server IDs, or private save state in a mesh. Do not move the physics hull because a paint material or cargo animation changed. Model geometry is not an economy database.

## 3. Before making any geometry

For each new vessel, write a short asset brief:

1. Stable `ship_definition_id` and asset ID; cargo family or families.
2. Placeholder, prototype, or release-art status.
3. Target length, beam, empty draft, loaded draft, and air-draft envelope. Distinguish researched values from newly chosen game dimensions.
4. Gameplay capacity and units from the current ship definition. Hold count, DWT, mass, slots, barrels, and cubic meters are not interchangeable.
5. Required cargo/service sockets and moving mechanisms from the type matrix below.
6. A side/top/front silhouette reference, original geometry plan, and permitted asset sources.
7. Whether an existing model/controller convention already exists in the actual project. Preserve that convention rather than silently rotating a working fleet.

The first model is the **small container starter ship**. Start with its silhouette, a useful deck layout, a simple bridge, and visible container capacity. Approve one ship’s style and in-engine scale before producing a fleet. Do not generate every research ship at once.

## 4. Scale, axes, and origin

### Proposed project convention

Use metric authoring: **one Blender unit = one meter** and ordinarily one Godot unit = one meter. In Blender set Metric units, unit scale `1.0`, and verify dimensions numerically. This is a convention to enforce with a calibration export, not something a unit label alone guarantees.

Godot’s documented oriented-asset convention uses **+Z as model front**, while cameras look along -Z. This guide follows that oriented-asset convention:

| Direction | Blender source | Imported Godot model |
| --- | --- | --- |
| Up | +Z | +Y |
| Bow/model front | -Y | +Z |
| Stern/model rear | +Y | -Z |
| Port/left, viewed facing the bow | +X | +X |
| Starboard/right, viewed facing the bow | -X | -X |

Build a tiny asymmetrical calibration object with labeled bow, starboard, and top before a real hull. Export/import it and verify this convention with the pinned exporter. Do not assume an arbitrary downloaded model follows it.

Ship-local axes are independent of geographic/globe axes in the map reference. The controller must explicitly use model forward `+Z` under this contract. If the actual project already steers along `-Z`, use one documented visual adapter rotation and transform socket data through it, or choose the existing convention consistently. Do not make some ships +Z and others -Z by accident. A 180° visual correction must not invert helm, cargo, or collision anchors.

### Origin and waterline

- The export assembly root is at the hull centerline and the chosen **empty/reference waterline plane**. Blender source plane `Z = 0` becomes Godot local `Y = 0`.
- Choose a longitudinal reference such as the middle of the authored hull’s length, and record it. Do not move it after sockets and collision records are established without a coordinated update.
- Keel geometry extends below the reference waterline. Do not model only the visible above-water hull.
- Store empty and fully loaded waterline/draft offsets separately in the ship definition. The model origin is not an automatic center of mass.
- Physics center of mass, buoyancy sample points if used, and gameplay load effects are deliberately authored/tuned. Do not let a decorative antenna determine mass distribution.
- Track length/beam/height envelopes from actual geometry, including protruding superstructure and loaded cargo where relevant. Bridge/channel checks need the correct loaded and unloaded envelope, not just visual hull length.

Apply object rotation and scale to static meshes where appropriate so their exported scale is `(1,1,1)` and rotation matches the contract. **Do not indiscriminately apply Location to every object**: that can destroy intentional mechanical origins and socket transforms. Avoid negative/mirrored scale on exported objects; resolve mirrors in geometry.

## 5. Minimum assembly every ship needs

The hierarchy below is a naming table, not literal Blender collection-to-Godot conversion behavior. Collections organize Blender; an explicitly parented export Empty organizes the exported object hierarchy. Collection names alone do not guarantee runtime nodes.

| Source object/group | Requirement | Purpose |
| --- | --- | --- |
| `MODEL_<asset_id>` | Required root Empty | One identity-transform export parent at the documented origin |
| `MESH_hull` | Required | Main original low-poly hull, including underwater section |
| `MESH_deck` | Required, may share a static mesh with hull | Readable cargo/support deck |
| `MESH_superstructure` | Required visually unless vessel design differs | Bridge/helm-house silhouette; can be merged with other static parts for batching |
| `SOCKET_camera_follow` | Required Empty | Chase-camera reference near/above the ship; final camera offsets remain tunable |
| `SOCKET_helm_view` | Required Empty | Forward-facing ship-control view reference, not a walkable seat requirement |
| `SOCKET_name_port` and `SOCKET_name_starboard` | Required if both sides display names | Name/sign attachment transforms and dimensions |
| `SOCKET_flag` | Required for flag customization | Flag mount and local orientation |
| `SOCKET_service` | Required | Port-service interaction reference; berth eligibility still uses actual hull geometry |
| `SOCKET_engine_audio` and `SOCKET_horn_audio` | Required, can share one location initially | Spatial audio origins |
| `SOCKET_wake_port` and `SOCKET_wake_starboard` | Required for a powered ship’s effect setup | Wake/effect origins at the relevant waterline; effects are created in Godot |
| `SOCKET_exhaust_01` | Conditional | Funnel exhaust origin; omit for designs without exhaust |
| `PIVOT_rudder_01` + visual child | Conditional | Rudder rotation around a real hinge |
| `PIVOT_propeller_01` + visual child | Conditional | Visual propeller spin around its shaft |
| Collision specification or proxy set | Required | Simplified moving-hull collision separate from render detail |
| Cargo sockets/regions | Required for the declared cargo family | See type-specific matrix |
| Asset metadata | Required | Dimensions, stable IDs, materials, socket inventory, provenance, authoring/export versions |

Sockets are **authored Blender Empties**. The exporter/importer must preserve them as usable transforms; validate that it does. They may import as ordinary `Node3D` nodes. Do not assume every Empty becomes a Godot `Marker3D`. Resolve/import them into the game’s socket registry if Marker3D wrappers are needed.

Use a consistent socket orientation: +Z is forward and +Y is up **after import**, unless a socket’s purpose explicitly defines a different normal, such as a sign face or pipe connector. Record those exceptions. Verify sign normals and text readability on both sides rather than placing identical mirrored transforms blindly.

Missing required sockets must produce an actionable validation error, not a later null-reference crash. Optional visual sockets have explicit fallbacks or disabled effects.

## 6. Requirements by cargo family

| Ship family | Additional model/rig requirements | Integration rule |
| --- | --- | --- |
| Container | `SOCKET_cargo_origin`; container slot layout with stable slot IDs, orientations, stack limits, and visual envelope | Slots describe visuals. The authoritative manifest determines what is aboard; full physics per container is unnecessary while sailing. |
| Bulk | Hold volume/layout definitions, `SOCKET_hold_01` etc., hatch pivots if animated, optional fill-surface region | Hold count is not tonnage. Commodity fill visuals derive from quantity; they do not own it. |
| Oil tanker | Loading manifold connector(s), tank/deck visual identity, optional pipe/hose anchor | Commercial barrel capacity and acquisition lots stay in gameplay data. No need to model every internal tank. |
| Gas tanker | Gas-tank visual arrangement, manifold connector(s), tank/compartment IDs if gameplay separates them | Capacity uses cubic meters and explicit compatibility; decorative tank dimensions cannot silently set the economic capacity. |
| Cargo-fuel-capable tanker | Separate commodity capability in the ship definition; appropriate pipeline connector | Cargo fuel is separate from propulsion fuel. Never infer one tank from the other. |
| Heavy lifter | `SOCKET_payload_attach`, lowering/submerge presentation reference, supported payload envelope, deck/clearance geometry, reference positions for lowered/raised states | Attach a validated payload through the authoritative carry system. Do not use unconstrained stacks of full rigid bodies as the default. |
| Ro-Ro, later | Vehicle deck regions, ramp hinge pivots, open/closed ramp bounds, driveable collision specification, entry/exit anchors, representative-car spawn/despawn points | Commercial capacity is independent of the handful of drivable representative cars. Ramp geometry/collision must agree. |
| Mixed container/Ro-Ro, later | Independent container layout and vehicle/ramp definitions | Simultaneous capacities and services remain separate. |
| Rocket launcher, later | `SOCKET_rocket_mount`, tower/gantry pivots, launch-view camera reference, visual clearance envelope, optional recovery-deck/socket | Launch/payment state is authoritative gameplay. Animation, smoke, or camera events cannot decide rewards. |

Do not add unused machinery to every hull for “future proofing.” Add narrow optional capabilities and validate only those declared by that ship. A container starter does not need a rocket skeleton or car ramp.

Heavy-lifter ballast/submergence may move the entire visual hull relative to the reference sea plane or use a separate presentation transform, depending on the selected controller. Do not author the vessel as physically telescoping apart unless the actual design calls for it. The cargo attachment and relevant collision must move consistently with the selected system.

## 7. Blender construction procedure

### A. Set up the source

1. Create a new source file named after the stable asset ID, e.g. `starter_container_01.blend`. Record the actual Blender version.
2. Create source organization groups for `EXPORT`, `COLLISION_REFERENCE`, `REFERENCE`, and `PREVIEW`. Only intentionally exported objects enter the GLB export selection/collection.
3. Create `MODEL_starter_container_01` as the explicit assembly root Empty. Set its origin, rotation, and scale to the contract.
4. Add temporary length/beam/waterline guides. Keep modeling references and preview cameras/lights out of the export selection.
5. Start a metadata record with dimensions and required sockets. Use real authored values once measured, not copied guesses from a different ship.

### B. Build the hull silhouette

6. Model several longitudinal cross-sections: narrow bow, forward shoulder, midship, aft shoulder, and stern. Connect them with clean faces. Add a keel/underwater profile and deck boundary.
7. Use symmetry to author the hull efficiently, then resolve negative scales and apply/export geometry consistently. Keep a non-destructive source where useful.
8. Inspect side, top, bow, and stern views. The bow/stern must be visually distinct, and the hull must not look like an unshaped rectangular box once it becomes release art.
9. Add only enough curvature and beveling for the intended low-poly cartoon silhouette. Avoid spending geometry on tiny details invisible from the gameplay camera.
10. Ensure render faces have outward normals, remove accidental internal faces/duplicates, and fix visible holes. An intentionally open cargo hold is different from a broken hull mesh.

### C. Add reusable static modules

11. Build deck, bridge/superstructure, funnel where appropriate, mast, and simple railings as reusable components.
12. Use simple opaque window materials or dark window panels initially. Avoid full interior geometry and layered transparent glass for a helm-only first release.
13. Use repeated components in Blender for authoring efficiency; decide how they are merged/instanced in the runtime export based on draw-call measurements.
14. Keep gameplay-important holes and clearances in geometry, but represent cosmetic bolts/vents economically. Do not model unseen cabins just because the source ship has them.
15. For the starter ship, reserve the actual container deck envelope now; do not decorate through future container slots.

### D. Create pivots and sockets

16. For a moving rudder, ramp, hatch, tower, or crane, create a named parent Empty at the hinge/rotation center and parent the visual mesh to it. Test rotation locally before export.
17. Apply necessary geometry transforms before finalizing the mechanical hierarchy. Afterward, avoid operations that move a hinge’s origin to the world center.
18. Add the required named socket Empties. Parent them to the appropriate assembly/mechanism, not accidentally to a temporary reference object.
19. For signs/flags/connectors, establish correct face normals and local orientation. For cargo, establish stable IDs and clear local transforms.
20. Validate that sockets remain attached during any authored mechanical animation and survive export/import.

### E. Materials, UVs, and paint

21. Create a small named palette such as `MAT_hull_primary`, `MAT_hull_secondary`, `MAT_deck`, `MAT_superstructure`, `MAT_windows`, and optional `MAT_metal`. These are semantic roles, not a mandatory six-material minimum.
22. Give customizable regions stable semantic material assignments. Document which surfaces respond to primary/secondary paint. Do not rely only on the material’s array index if reimport may reorder surfaces.
23. Use exporter-compatible basic/PBR material properties or bake textures as needed. A complex Blender procedural node tree is not automatically reproduced in glTF/Godot.
24. UV unwrap when using textures, decals, atlases, or baked details. Separate material colors can suffice for simple flat surfaces, but they do not eliminate the need for name/flag texture mapping.
25. Prefer opaque surfaces and restrained material variation. Generate ship-name text/signs in Godot or on replaceable sign assets; do not bake Andy’s current chosen name into the hull texture.
26. Configure normals/shading deliberately. Triangulate the export result predictably, especially non-planar or complex faces. Preserve a convenient editable source before destructive export operations.

### F. Collision and envelopes

27. Author a few boxes or simple convex hull proxy regions around the hull rather than copy the full render mesh. Keep rails, ropes, and decorative protrusions out of ordinary hull collision unless gameplay requires them.
28. Record dimensions and local transforms for each proxy. Name source proxies `PROXY_hull_01`, etc.; they are authoring references, not automatic Godot collision suffix instructions.
29. Exclude proxies from the render GLB by default and create actual collision shapes from validated metadata in the Godot wrapper. If a separate proxy export is used, keep it distinct and prevent its meshes from rendering or creating nested bodies.
30. Measure empty/loaded hull envelopes and maximum cargo height. Store useful fit limits for spawn, docking, narrow passages, and Panama bridge clearance checks.

### G. Review and export

31. Review the ship in simple neutral lighting from the anticipated gameplay camera; approve silhouette before tiny detail.
32. Save the editable `.blend`. Export the intended assembly as `.glb` with correct units, hierarchy, materials, and optional animations.
33. Reimport in Godot and run the calibration, dimensions, sockets, collision, and repaint checks. Fix export/source problems before layering gameplay workarounds.

## 8. Cargo slot and attachment specification

Use the ship’s local origin and model-forward convention for every slot. A slot has a stable ID, position, orientation, visual container/payload type, and constraints. Runtime slot transforms must be converted through any visual adapter exactly once.

For ordinary container ships:

- Make a reusable container prefab. Do not permanently merge loaded containers into the empty hull mesh.
- Author a deck layout that supports the selected visual capacity, stack levels, and bridge visibility. Keep containers out of superstructure, funnels, and railings.
- Generate slot transforms from a recorded bay/row/tier layout when possible; irregular spaces can use explicit sockets.
- Use instances or batching where appropriate. Capacity need not equal one live physics body or one independent network entity per container.
- At distance, use simpler combined stack visuals or reduced detail according to measured needs. The manifest remains exact even when the display is simplified.

For heavy loads, an attachment socket defines the carried object’s reference transform, not proof it fits. Validate payload width/length/height, permitted mass, raising clearance, and loaded draft separately. Every payload should define its compatible pickup/attachment reference as well.

## 9. Collision and animation rules in Godot

Create **one intended movement/physics owner** for the ship. It may be a controlled physics body or force-driven body selected by the handling prototype; the asset must not force a different body type through an import hint.

Use primitive or simple convex shapes attached to that moving body. A full concave/static triangle-mesh collision is not the default moving-hull solution. Avoid imported nested `StaticBody3D`/`RigidBody3D` children that compete with the ship controller.

Godot import suffixes can generate bodies/collision automatically. They are useful only when their behavior is deliberately selected. For the baseline fleet, do not casually append `-col`, `-colonly`, `-rigid`, or `-vehicle` to render objects. `-col` generates static triangle-mesh collision; `-rigid` and `-vehicle` choose physics types. Build explicit collision in the ship wrapper from the chosen contract instead. Source preview helpers should normally be excluded from export, not assumed to vanish because they are in a Blender collection.

For a ramp or mechanism with moving collision, the visual mesh, collision representation, hinge, and state must remain synchronized. Animating only the visual creates invisible barriers. Teleporting a static collider each frame is not an assumed solution for a moving surface. Select the appropriate Godot body/animation integration when that feature is implemented and test it under authority and latency.

Simple propeller/rudder motion is cosmetic unless the handling model explicitly uses it. Keep a single owner of each animated property: either imported animation or the runtime controller, not both fighting over the same transform.

## 10. GLB export checklist

- Keep the editable Blender source and a reproducible export configuration.
- Export the explicit ship assembly and its required sockets; do not accidentally select only meshes and drop all Empties.
- Use `.glb` as the baseline runtime interchange format. Explicit export is preferred here so game import does not depend on Blender being installed on every recipient machine.
- Verify the expected unit scale and axis conversion using the calibration asset. Do not rotate the model 90° repeatedly in successive pipeline steps.
- Export compatible materials/textures. Review backface culling and avoid enabling two-sided rendering on every material as a workaround for broken normals.
- Exclude preview lights, cameras, reference images, dimension guides, collision-reference meshes, and hidden development geometry unless intentionally needed.
- Export mechanical animations only when required; name clips semantically and distinguish loops from one-shot operations. Omit armatures for rigid-only ships.
- Ensure modifiers produce the intended final geometry. Use predictable triangulation in the export result; check that modifiers do not destroy pivot or skinning assumptions.
- Record whether transforms/modifiers/animations were baked, the source/exporter version, and the exported asset revision.
- Do not assume every Blender-only constraint or procedural modifier survives as an equivalent Godot runtime behavior. Bake a supported result or implement that behavior in the runtime rig.

Avoid hard-coded exporter option names in reusable scripts without checking the pinned Blender API. Options and animation export behavior vary with versions. The actual export preset/script belongs with the source asset once tested.

## 11. Godot import and wrapper procedure

1. Put the `.glb` in the agreed asset folder and let Godot import it. Keep source `.blend` files outside automatic import paths if the explicit-GLB workflow is used.
2. Review the imported hierarchy and materials in the editor/Advanced Import Settings. Confirm that all required socket and pivot names survived and axes are correct.
3. Create a separate editable wrapper scene, for example `ship_starter_container_01.tscn`. Instance the imported model beneath its visual root. Do not build the ship’s gameplay directly inside generated import cache data.
4. Add the movement body/controller selected by the prototype, with its collision shapes under the correct owner. Keep the visual hierarchy separate from simulation authority.
5. Resolve required sockets by a stable asset contract/registry and report duplicate or missing names. Supply references to camera, cargo, audio, and customization components; do not scatter fragile deep node paths across the game.
6. Bind the immutable ship definition. Create separate per-owned-ship state for fuel, cargo, damage, paint, flag, and name.
7. For repainting, duplicate the relevant materials or use a verified per-instance override strategy. Imported materials and meshes can be shared; changing one ship must not recolor the whole fleet.
8. Add runtime name signs/flag appearance through the named sockets. Check both sides, mirrored UVs, readability, and flag orientation.
9. Generate cargo visuals from the manifest and slot layout. Remove cargo visuals when the manifest changes; do not save their nodes as duplicate cargo state.
10. Configure visibility, shadows, detail variants, instancing, and update rates after measuring the real scene. Do not make every mesh a network-synchronized entity.
11. Run the acceptance checks, then re-export a harmless model change and confirm it does not erase wrapper components or break sockets.

Conceptual wrapper ownership:

| Wrapper part | Responsibility |
| --- | --- |
| Ship root / selected physics body | Authoritative movement and collision ownership |
| Visual root | Imported GLB and purely presentational offsets/effects |
| Hull collision set | Primitive/convex shapes fitted to the hull |
| Socket registry | Validated transforms for cameras, cargo, service, audio, and signs |
| Cargo visual controller | Manifest-to-visual mapping and instance management |
| Appearance controller | Per-instance paint, name, flag, condition effects |
| Ship definition reference | Immutable dimensions, tuning, capacities, asset references |
| Runtime ship state | Owned ID, fuel/condition/cargo, permissions, saved appearance |

The exact node tree should follow the actual project’s selected body and controller. This table is not a second competing ship framework to build alongside working code.

## 12. Asset metadata contract

Each rig needs a small validated record, either a custom Resource plus import metadata or an equivalent authored interchange file. The following is a **valid JSON template**, not a complete runnable ship definition. Fill every required `null` from measured geometry before accepting a runtime-ready asset.

```json
{
  "schema_version": 1,
  "asset_id": "starter_container_01",
  "ship_definition_id": "ship_starter_container_01",
  "asset_revision": 1,
  "status": "template_not_runtime_ready",
  "source_file": "starter_container_01.blend",
  "runtime_file": "starter_container_01.glb",
  "blender_version": null,
  "godot_version_tested": null,
  "meters_per_unit": 1.0,
  "model_forward_godot": "+Z",
  "model_up_godot": "+Y",
  "origin_reference": "centerline_reference_empty_waterline",
  "length_m": null,
  "beam_m": null,
  "empty_draft_m": null,
  "loaded_draft_m": null,
  "max_air_draft_empty_m": null,
  "max_air_draft_loaded_m": null,
  "cargo_families": ["containers"],
  "required_sockets": [
    "SOCKET_camera_follow", "SOCKET_helm_view",
    "SOCKET_name_port", "SOCKET_name_starboard", "SOCKET_flag",
    "SOCKET_service", "SOCKET_engine_audio", "SOCKET_horn_audio",
    "SOCKET_wake_port", "SOCKET_wake_starboard", "SOCKET_cargo_origin"
  ],
  "material_roles": {
    "primary_paint": "MAT_hull_primary",
    "secondary_paint": "MAT_hull_secondary"
  },
  "cargo_layout_id": "layout_starter_container_01",
  "collision_spec_id": "collision_starter_container_01",
  "lod_variant_ids": [],
  "source_provenance": "original_agent_assisted_model",
  "validation_status": "pending_actual_export_and_playtest"
}
```

The origin reference must also have a measured longitudinal datum in the completed record. Collision specs contain shape type, dimensions/convex points, and local transforms in the imported ship frame. Cargo layouts contain slot IDs and transforms in that same frame. Registry IDs must resolve before the ship can spawn.

Bounds and collision should be measured after the export transform has been accounted for. Validate real dimensions against the metadata; trusting a stale number is insufficient for berth/bridge eligibility.

## 13. Agent-assisted Blender script requirements

When creating a model by script:

- Inspect the real available Blender version before using `bpy` APIs. Generate a self-contained repeatable build/export script and documented invocation; do not require Andy to manually assemble disconnected mesh snippets.
- Take asset ID, dimensions, palette, cargo layout, and selected capabilities as explicit inputs. Keep a deterministic seed for any decorative variation.
- Build/update only the script’s named asset collection/root. Do not wipe unrelated objects in an existing `.blend` file.
- Create the real parent hierarchy, named materials, sockets, pivots, and metadata in one consistent convention. Do not rely on collection names to create transform parents.
- Keep source edits and export generation separate enough to preserve hand-tuned work. A destructive regeneration must never silently overwrite a manually refined model.
- Save the source `.blend`, export `.glb`, and emit a short validation report of dimensions, objects, sockets, materials, and missing requirements.
- Include a way to regenerate a basic preview render when Blender is available. Rendered previews help visual review but do not substitute for Godot collision and reimport checks.
- Report exactly what ran. A generated script that has not been executed is not a delivered verified 3D asset.

Start with one small ship. Reusable hull sections, bridge modules, containers, funnels, and mast pieces can become authoring helpers after the first model is approved. Do not turn the first script into a giant procedural ship generator before the style and import contract work.

## 14. Performance and detail policy

The dedicated target is roughly 100 players, but asset budgets must come from measured visible ship counts and scene costs. One player does not necessarily mean one fully detailed hull visible at all times.

Track render triangles, material surfaces/draw calls, texture memory, shadow cost, collision complexity, active mechanisms, and container-instance counts for each asset. Set provisional budgets during the first two hulls, then test a crowded port and distant fleet. No arbitrary polygon number in this guide is a guarantee of performance.

Reduce unnecessary material boundaries and small mesh objects, simplify distant hulls, limit expensive transparency/shadows, batch repeated container visuals where useful, and disable cosmetic updates on irrelevant distant ships. LOD and network interest are separate concerns: reducing triangles alone does not reduce authoritative simulation cost.

Do not simplify collision so much that a wide visual hull passes through a pier. Do not optimize away important silhouettes, bridge clearance envelopes, or service attachment points.

## 15. Required acceptance checks

| Check | Passing result |
| --- | --- |
| Source reproducibility | Source, exporter configuration/script, versions, and provenance are available |
| Scale and axes | Calibration and measured dimensions agree in Blender and Godot; bow, top, port/starboard are correct |
| Origin and waterline | Reference plane/datum is documented; empty and loaded presentation behave predictably |
| Geometry/shading | No unintended holes, inverted faces, severe triangulation artifacts, or impossible cargo overlaps |
| Socket inventory | Every required name is unique and resolves after GLB import; optional fallbacks are explicit |
| Camera | Follow and helm views are usable without the hull or cargo obscuring the intended view |
| Pivots/animation | Mechanisms rotate at their hinges; state/collision remain synchronized where applicable |
| Collision | Correct moving-body ownership; pier impacts and grounding do not use accidental nested static bodies |
| Cargo visuals | Empty/partial/full loads match the selected layout and are reconstructed from manifest state |
| Paint/name/flag | Two owned copies can have different appearance without shared-material leakage |
| Clearances | Spawn, docking, passage, heavy-payload and bridge envelopes match measured assets |
| Networking | Visual/mechanical state follows authoritative state; import does not introduce new independent physics owners |
| Reimport | A controlled source change preserves gameplay wrapper, stable IDs, sockets, collision, and appearance behavior |
| Performance | Measured scene costs fit the current provisional/approved budget at relevant fleet density |
| Packaging | The exported game includes the required model/material assets and works without a recipient-side Blender installation |

For the container starter, finish empty sailing, partial/full cargo display, docking, repainting two copies independently, save/reload, and harmless reimport before calling the asset ready. For each special family, add its relevant load/ramp/payload/launch checks instead of ticking irrelevant skeleton or walking requirements.

## 16. Common failures to prevent

| Symptom | Check first |
| --- | --- |
| Ship sails backward | Model +Z versus controller -Z mismatch or an undocumented adapter |
| Ship imports tiny or enormous | Unit/export scale and unapplied object scales; measure actual bounds |
| Hull is sideways | Repeated axis conversion or wrong export orientation |
| Ramp/rudder orbits the ship | Incorrect parent pivot or origin damaged by applying Location |
| Missing cargo/camera markers | Empties excluded from export or names changed during authoring |
| All ships change paint together | Shared material mutation instead of per-instance appearance |
| Ship collides with invisible old hull | Duplicate/nested imported collision or stale proxy geometry |
| Bridge looks clear but collision blocks it | Static collider/clearance envelope does not match geometry |
| Cargo clips into bridge/funnel | Slot layout not measured against the actual hull/deck |
| Reimport removes gameplay changes | Gameplay edited into imported/generated data instead of the wrapper |
| Export differs from Blender preview | Unsupported material/constraint/modifier assumptions or different lighting |
| Many ships are unexpectedly expensive | Excess surfaces, tiny objects, transparency, shadows, individual container bodies, or uncontrolled cosmetic updates |

## 17. Official documentation and project choices

Documentation checked for this guide:

- [Godot: available 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) — GLB/glTF workflow and direct Blender import dependencies.
- [Godot: model export considerations](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html) — asset direction conventions, transforms, triangulation, and preview lighting differences.
- [Godot: node-type customization](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html) — automatic collision/body suffix behavior and the case for simple collision shapes.
- [Godot: import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html) — import controls and separate editable scene workflows.

The socket names, metadata schema, source hierarchy, and type requirements are **proposed project standards** authored here, not mandatory Godot features. Validate them against the actual project before implementation. Blender manual pages were not retrievable in this session; specific Blender exporter/API details must be checked against the installed version. This file does not claim those scripts or assets have already been tested.
