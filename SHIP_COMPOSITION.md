# Reusable ship composition — Step 27

Both ships instantiate as self-contained runtime scenes. HandlingShip remains
the single propulsion and steering implementation; ShipHelm owns shared player
input, neutral/focus behavior, horn and menu routing. ShipAssembly creates each
instance's visual hull, camera focus, cargo anchor and feedback, and provides
shared collision, camera and wake construction.

ShipDefinition selects the visual asset and runtime scene separately and holds
hull dimensions, camera/wake sizing, cargo position and handling values.
The starter runtime uses the preserved Blender model with its existing handling
and 13 x 4 x 64 m collision proxy. Visual draft/bobbing remain presentation only.
The water surface is at the model's Y=0 waterline.

The heavy definition uses a 24 x 7.5 x 90 m hull proxy, wider wake and camera,
and gentler acceleration/turning. Its subclass retains only the special moving
deck, load ownership and helm availability behavior. The cargo anchor belongs
to its assembly; physical compound colliders remain direct children of the
body so movement and angular clearance queries continue to include them.
The staged payload follows the ship's initial parent-relative transform and is
cleaned up when the owning ship exits.

## Use and validation

Boat Handling Test and Heavy-Lifter Test use the runtime scenes. Other scenes
can instantiate either runtime without a PlayerControls service or fixed
external node paths; add a configured ShipHelm when player input is needed.
Definitions are copied by the controller for per-instance tuning isolation.

`tools/Godot.ps1 -Mode CompositionCheck` runs 60 assertions across both hulls,
each under translated/rotated, arbitrarily named parents. It exercises forward,
reverse and sideways solid-wall contacts, turning, independent component and
definition ownership, and staged-payload cleanup. Full project checks pass
19 stages / 61 scripts. Native Windows Release passes CompositionProbe (60)
and HeavyLifterProbe (32). A native starter scene capture was inspected.

Fuel, fleet ownership, rated cargo capacity and production multiplayer remain
later steps. This composition does not change the accepted starter motion
baseline or introduce shallow-water restrictions.
