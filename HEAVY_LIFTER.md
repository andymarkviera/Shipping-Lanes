# Step 26 — Heavy-lifter feasibility prototype

## Try it

Main menu > HEAVY-LIFTER TEST. Use the four numbered buttons while stopped:
Lower deck, Align test payload, Secure payload, Raise deck. Then sail with your
saved boat controls. Lower again while stopped to release. RMB/wheel/C camera and
H horn use the existing input system; Esc returns to the menu.

Align test payload is deliberately a fixture aid: it places the staged floating
module over the stopped, lowered deck. It is not a loading crane, job acceptance
or production cargo-spawning feature. Actual attachment separately checks alignment,
low speed, neutral engine, deck endpoint and obstacle clearance.

## Blender art

Andy requested Blender authoring in the same style as the first boat. New faceted
geometry uses the original starter's seven semantic material datablocks: teal hull,
pale deck and house, dark windows, yellow rails/funnel and the existing secondary
hull color. The original starter file is hash-checked and never overwritten.

Editable source: art_sources/heavy_lifter_01/heavy_lifter_01.blend.
Three exported GLBs separate the hull, moving deck and industrial payload in
features/ships/heavy_lifter_01/. Godot imports them without needing Blender.
Authoring uses Blender 3.6.1, meters, -Y bow/+Z up exported as Godot +Z bow/+Y up.

Prototype dimensions: 90 m hull, 24 m beam, 18 x 48 m lift deck. Deck top moves
between -1.0 and +2.6 m at 1.2 m/s. Payload envelope is 14 x 8 x 32 m. These are
feasibility dimensions, not approved fleet specifications or rated tonnage.
Combined asset: 96 mesh objects, 1,176 triangles, seven material roles.

Build script: tools/build_heavy_lifter.py. It generates original geometry and
renders a preview. Re-running regenerates the heavy-lifter source; preserve any
future hand edits before using it. It never regenerates the starter boat.
The saved source has separate EXPORT_hull, EXPORT_deck and EXPORT_payload collections;
payload is staged 33 m to the side for inspection (GLB export occurs before staging).

## Physics and ownership

HeavyLifter extends the existing HandlingShip without changing starter tuning.
Conservative box proxies cover the belly, side pontoons, forehouse and moving deck.
The load starts as one floating static collision body. Securing disables that body,
parents its visual to the deck mount and activates one compound shape directly
under the ship. Releasing reverses ownership and preserves world pose. There is
no unstable stack of separate force-driven bodies or duplicate active collider.
The attached payload is carried through the production move-and-slide and angular
clearance checks, including high obstacles the empty hull could pass beneath.

Deck operations require speed below 0.05 m/s and neutral command/engine. Each lift
increment checks a swept deck/payload volume against other solid objects; a blocked
lift stops safely. An unsecured floating load cannot be raised through. Secured
cargo must be on the fully raised deck before engine thrust/steering is enabled.
Actual mass-based thrust, ballast, buoyancy and capacities are not invented here.

This is an isolated risk experiment, not the special-cargo job system or a production
ship-composition architecture. Network ownership, payload persistence, final service
controls and ratings remain later work. Model sockets/paint and reusable hull
composition are refined in Step 27. The starter prototype stays unchanged.
Heavy-lifter water uses the existing palette/quality system and a wider wake profile;
original wake dimensions remain the default for the starter fixture.

## Verification

HeavyLifterCheck covers rejected moving/misaligned/duplicate attachments, collision
ownership, blocked lift/recovery, real physics turning, unchanged relative payload
pose, high-obstacle collision, controlled release/reload and the actual UI buttons.
The full suite includes existing handling reference, collision, camera, water and
world-frame checks. Native Godot captures of loaded and turning states and the
Blender preview were inspected. No subjective user art approval is claimed.

Run tools/Godot.ps1 -Mode HeavyLifterCheck or tools/CheckProject.ps1 -Full.
Exported check: -Mode RunExport -Configuration Release -HeavyLifterProbe.
