# Step 56 — Service menu and navigation usability

Implemented October 25, 2026 for the local Port Test.

The opaque lower-right minimap shows both named ports, a bow-direction triangle,
and a gold job target with a dashed direct guide. The map automatically fits the
boat, ports and active target. Container target uses the accepted destination;
heavy target switches from the physical pickup to the saved ocean drop-off when
attached. Cancelling/abandoning removes the target; reopening reconstructs it.

Local north is +Z and east is -X, matching the existing helm heading convention.
This is a flat local test chart, not the geographic/world streaming projection.
The guide is not a collision-free path or autopilot: steer around solid quays.
No new water docking markings, hidden shallows or physics changes. Existing berth
readiness and grey/green Dock button remain the approach aids.

Service lists preserve the selected job ID across refreshes while it remains
available. Unavailable acceptance/delivery actions have visible reasons; pending
loading locks acceptance, refuel and repair with explanations. Dock rejection
messages are surfaced. Quantity and quoted reward remain on each job row; refuel
and repair are explicitly free test services, with capacity/condition in tooltips.
The chart ignores mouse input and does not steal helm focus.

The service calls here are synchronous local authority calls. There is no network
request or timeout to retry in this scene; UI refresh never resubmits any command.
Loading/recovery pending and save-failure states remain visible. Public network
port-service pending/timeout integration remains outstanding and must use existing
request identity/reconciliation before retry; no speculative auto-resubmit added.

Validation: 134-script/startup check; 101 voyage assertions in editor and exported
Release, plus real crash-before/after loading and delivery commits. Tests cover
selection retention, unavailable-action reasons, chart bounds and orientation,
container arrival target stability, heavy reload target and abandonment cleanup.
Editor voyage evidence ../output/voyage/25e7a921; Release ../output/voyage/76572b19.
270 rendered port checks in both runtimes; inspected loading/loaded layouts at
1152x648. Release captures ../output/ports/ef6f7ecd. User save untouched.

Recovery tag: local-navigation. Source archive:
../output/checkpoints/local-navigation-2026-10-25.zip.
Step 56 awaits user play-test. Next: Step 57 first voyage gate, reviewing the full
accept/load/sail/dock/deliver/reopen flow and separating local proof from public
multiplayer integration. Existing later animation/polish requests remain queued.
