# Step 60 — Single boat condition and icon HUD

Andy replaced the original separate engine/hull/machinery wear design. One canonical
`ship.condition_bp` now represents collision damage and gradual use. There is no
machinery condition or degradation of the heavy loader's lifting equipment.

## Operating clock and tuning

Only the authoritative online hull counts simulated physics seconds while fueled,
undocked, unpaused, actively owned and applying engine throttle or lateral propulsion.
Neutral idle, docking, offline time, fenced ownership and recovery do not count.
The online menu does not pause the server: any remaining actual propulsion ramp-down
still counts. No wall-clock catch-up occurs after reconnect or restart.

Initial tuning is 100 basis points (1%) per active hour. Fractional basis points are
persisted so short sessions/checkpoints cannot discard wear. `wear.py` owns the rate
and a 10% wear-only floor. Wear never heals pre-existing damage below the floor and
never sinks a boat by itself; a collision can still sink it. These are provisional
playability choices, not researched realism claims.

Above 50% condition, propulsion is unchanged. Below it, forward/reverse thrust scales
linearly toward 75% at zero. Steering, lateral thrusters, cargo capacity and lifting
equipment do not degrade. Neutral snap and stopping assistance remain unchanged.

## Persistence and authority

Every normal 10-second checkpoint saves simulated operating time, fractional wear,
condition, fuel and pose atomically behind the existing revision/lease guard. Replayed
stale checkpoints cannot apply wear again. An impact settles pending operating time
and collision damage in its existing receipt transaction. Pending impact reconciliation
retains that intent. Paid recovery restores the same meter and clears its fraction.
No new peer RPC accepts wear, condition or clock values. Optional trusted-server
fields preserve old test clients; ticket protocol 7 and game protocol 13 unchanged.
Restart the backend and game server together to activate the new clock.

As with position/fuel, a full process loss can lose uncheckpointed operating time.
No profile reset or schema migration. Existing condition is preserved, with healthy
and zero-fraction defaults for older profiles. Local Port Test remains its existing
separate fixture; online heavy-loader integration remains future work. Do not add
machinery wear when integrating it.

## Presentation and roadmap change

The online driving HUD uses original vector engine and fuel-pump silhouettes in one
opaque panel. No labels or numbers on these gauges. Amber condition and aqua fuel
fill from bottom to top; as values decrease the fill drops, retaining the outline.
Fuel transaction quantities/prices remain visible in REFUEL. Exact condition text
has been removed from the cargo status panel. This is an initial visual pass.

This supersedes Step 60's component split and Step 61's separate damage/wear meters.
Step 61 may polish feedback for this single condition instead. Step 62 remains paid
repair of the same condition, with authority-owned settlement; not implemented here.

## Validation

27 isolated real HTTPS/PostgreSQL checks passed in `../output/handoff/f0df5bae`:
rate, fractions, service restart, replay, invalid time, impact combination, floor,
sinking and paid recovery. Ten Godot runtime checks passed for the operating clock
and propulsion curve. Full/half/low rendered gauges inspected in
`../output/wear-hud-preview.png`. Further peer regression recorded in PROGRESS.md.
Manual player feedback is still pending; no local player save was changed.


## Step 61 follow-up: shared gameplay HUD

The earlier online-only presentation scope is superseded. Gauges now sit bottom-left
in a shared overlay for active local/online gameplay, including Port Test, both boat
types and port services. No gauges on the main menu where there is no active boat.
Local fixtures display their existing condition/fuel state; this UI change does not
add online degradation or paid recovery to those fixtures. Visual warning thresholds
(25% condition, 15% fuel) do not affect economic or handling rules. Hull rust remains
optional later art work. Windows hosting/security follow-up is tracked separately.
