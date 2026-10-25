# Step 52 — Manifest-driven container visuals

October 24, 2026. User authorized this step while explicitly noting that Step 51
has not yet been personally play-tested. Automated verification is not user acceptance.

Container ships now show one temporary container per loaded manifest unit. Accepting
and partially loading a job shows no cargo until loading commits. Delivery/removal
updates the deck immediately. Reopening a saved voyage derives the same slots from
the manifest; no duplicate visual objects, slot state or meshes enter the save.

The starter uses six centres from the existing Blender asset's first-tier sockets
(B01/B02, three lanes each). A reusable ContainerLayout resource specifies these
positions, dimensions and a muted rust/teal/ochre palette. Containers have simple ribs
and door bars and share one mesh in a bounded MultiMesh per ship. The layout sits
under the hull's visual bobbing/roll root; it adds no collision bodies, mass, handling
changes or save mutations. Manifest change signals update the instance count rather
than polling/copying cargo every frame. Separate ships have independent visibility.

The current jobs offer one to three containers. Six-container captures are a capacity
fixture, not a new job type or permission to accept multiple jobs. The existing heavy
loader's industrial payload remains its own physical lift visual and does not receive
container boxes. Later compatible hulls can author their own ContainerLayout; do not
invent container compatibility for the industrial-only heavy loader.

This is wired into the local manifest-backed runtime ships and saved Port Test voyage.
Public world manifest replication/service integration remains outstanding; this does
not claim that server cargo snapshots already populate the new local manifest.
Temporary geometry is intentionally simple; aesthetic polish remains later work.

Validation: 128-script/import/startup and CatalogCheck pass. Editor and final rendered
Release port/cargo suites pass 234 checks, including empty/partial/full counts,
rejected over-capacity updates, partial removal, deterministic transforms, independent
ships, no physics bodies and no duplicate instance nodes. Empty/three/six-container
captures inspected; final Release evidence: ../output/ports/9ed2a9a7.
Voyage suite passes 44 checks plus separate-process crash/reload/delivery checks in
editor and Release (../output/voyage/c147974b), now asserting no phantom cargo during
partial loading, one visible container after restored completion and none after delivery.
No save-format change. Export includes the new visual code and layout resource.

Next: Step 53 delivery/payout authority and receipt requirements, building on the
existing local test delivery. Step 56 still includes the requested temporary minimap.
Step 51 remains awaiting Andy's play-test feedback; retain its recovery and heavy
pickup behavior unless that feedback calls for correction.

Recovery tag: container-visuals. Verified source backup:
../output/checkpoints/container-visuals-2026-10-24.zip.
Preexisting project.godot customization remains untouched and outside this source checkpoint.
