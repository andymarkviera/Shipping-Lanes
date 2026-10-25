# Step 55 — Voyage interface

The local Port Test now has an opaque, read-only voyage panel showing the active
job stage, cargo actually aboard versus contracted quantity, destination distance,
quoted payment, next action, speed in knots, fuel in liters and condition. Container
destination comes from the accepted job, not whichever port happens to be nearest.
Heavy pickup and ocean drop-off use the job's actual locations and attachment state.
Loading shows authoritative progress; restoring and blocked saves override travel
instructions. Loading-completion notices no longer retain the accepted/loading text.

The existing dock service panel retains CARGO / REFUEL / REPAIR, current port,
voyage wallet, visible action notices and cancellation/abandonment controls. Previous
container and heavy delivery receipts are labelled LAST DELIVERY RECEIPT. The
throttle indicator and neutral assist are unchanged. No new water docking markings.

HUD refresh reads authority state and does not own timers, cargo, money or operations.
Buttons retain no keyboard focus; the new read-only panel ignores mouse input.
Existing authority guards plus a repeated-Accept regression prevent duplicate loads.
The interface is functional presentation, not final menu/art polish. Public multiplayer
port-service wiring remains outstanding; this step changes the local test voyage.

Validation: 132-script/startup check, 88 exported voyage suite checks plus real
before/after loading and delivery commit process-death recovery. Release evidence:
../output/voyage/89b05c85. Rendered Release port checks: 270, including pending and
loaded HUD captures, ../output/ports/332f081f. Inspected both loading and loaded
layouts at 1152x648. Earlier editor voyage and rendered port regressions also pass.
The user's save was not modified. Step 55 awaits user play-test; wider docking and
Step 54 feedback remain pending. Next: Step 56 minimap/navigation.
