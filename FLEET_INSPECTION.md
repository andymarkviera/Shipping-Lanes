# Step 64 — Fleet inspection and comparison

Task ID: `fleet-inspection-and-comparison`.

In authenticated online play, dock and choose **FLEET / COMPARE** in dock services.
The left column initially follows the Ship Catalog selection; the right initially
shows the active owned ship. Either selector can inspect a catalog class or an
individual owned ship. Choose a cargo family to compare compatibility and capacity.
Close returns to dock services; opening comparison clears purchase confirmation.
Stale state, undocking, recovery, binding changes and disconnect close the view.
Disconnect also clears owned choices. Inspection never sends a purchase command.

## What the player sees

- Two visual previews using existing placeholder art in separate viewport worlds.
  The three container classes share their hull art, but retain separate statistics.
- Owned name (or Unnamed ship), class, stable owned ID, Yours/Active/Stored status,
  single condition, propulsion fuel and stored port. Rename and activation are not
  implemented here. New purchases remain stored as in Step 63.
- Total cargo capacity with units: six containers in container slots, or one module
  in a heavy payload slot. This is total capacity, not remaining free space.
- DWT and hold count explicitly unspecified, with an explanation that a mass rating,
  compartment count and cargo capacity are different quantities. No inferred values.
- Propulsion tank liters, full-output propulsion burn in L/s, forward acceleration
  in m/s² and turn limit in degrees/s. Propulsion fuel is not cargo fuel. These are
  current definition statistics, not guaranteed loaded speed or voyage range.
- Purchasable with server-quoted price, insufficient credits, storage full,
  temporarily unavailable, and unavailable prototype as distinct text states.
  Confirmation remains in Ship Catalog using the unchanged authoritative flow.
- Unsupported bulk/gas/oil/cargo-fuel families and incompatible container/heavy
  choices are explicit. The heavy-lifter preview is local prototype capability;
  there are no online heavy jobs or acquisition implied by that preview.

## Authority and persistence

`fleet_inspection.gd` projects the current peer's active ship and at most 100 stored
records. It excludes account IDs, jobs, receipts, manifests and private profile data.
The active condition/fuel come from the existing live ship state; stored values
come from canonical profile records. Names are bounded to 80 display characters.
An absent stored array means an empty stored fleet. Unknown definitions keep their
owned identity but show unavailable statistics/preview; no replacement save occurs.

The existing reliable, owner-addressed voyage snapshot includes the projection
only while docked. No new RPC or save schema is added: game protocol stays 15,
ticket protocol stays 7, Godot stays 4.7.2. Existing clients ignore the additive
field. Use matching updated clients/servers for inspection. The 101-record synthetic
fixture serializes to 15,171 JSON bytes (not an upper bound or network wire-size
claim); authenticated full-fleet bandwidth remains an acceptance measurement.

Preview scenes are visual-only, have processing disabled and use separate World3D
instances. Definition resources and the active hull are never changed. New scripts
are listed in the Windows export preset and retain their UID sidecars.

## Checks and backlog gates

Run with the pinned Godot and isolated XDG state:

```sh
Godot-4.7.2 --headless --path . --script res://tools/fleet_inspection_probe.gd
Godot-4.7.2 --headless --path . --script res://tools/ship_purchase_probe.gd
Godot-4.7.2 --headless --path . --script res://tools/repair_probe.gd
```

PROGRESS.md records the actual Linux results and existing platform limitations.
The service/UI probes use explicit authority doubles; local two-peer probes are not
proof of authenticated public traffic or real PostgreSQL transactions.

These unrun checks are backlog gates, not blockers to this draft implementation:

- Windows: pinned engine/PowerShell checks; Debug/Release client/server exports,
  exported resource/preview startup and existing UID/save compatibility.
- PostgreSQL: real fleet reload after purchase, restart/crash and duplicate purchase
  replay against the configured isolated HTTPS/database fixture stack.
- Keycloak: native login, two authenticated accounts seeing only their own fleet,
  interruption/reconnect/binding replacement and maximum-fleet payload behavior.
- Visual: rendered previews, model framing/lighting, scrolling and selector layout
  at supported resolutions/UI scales, long names/IDs, focus and HUD overlap.
- Andy's playtest: compare Starter/Coastal/Swift for a container job; distinguish
  total slots from DWT/holds and propulsion fuel; inspect two same-class purchases;
  recognize unavailable heavy acquisition and unsupported families; close without
  buying, retain names/IDs/condition through reconnect, and confirm single-job flow.

No live server deployment, production acceptance or manual playtest is claimed.
