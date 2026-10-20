# Propulsion fuel — Step 28

Both runtime ships consume propulsion fuel from their own ShipState.
PropulsionFuel calculates consumption; ShipDefinition owns capacity and rules.
Cargo fuel remains separate. Accepted starter motion constants are unchanged.

## Prototype policy

Burn per second = idle + absolute actual engine output times full-output burn
(times the reverse multiplier when astern) + absolute effective lateral order
times thruster burn. Lateral effectiveness uses the speed cutoff at tick start.
Actual engine output is sampled after its existing ramp update; commanded
throttle is not delivered output. No rounding occurs per tick. Simulation uses
the existing 60 Hz physics clock.

| Rule | Starter | Heavy carrier |
| --- | ---: | ---: |
| Capacity / full test-spawn tank | 1,000 L | 2,000 L |
| Full-output propulsion | 0.5 L/s | 1 L/s |
| Idle | 0.01 L/s | 0.02 L/s |
| Reverse multiplier | 1 | 1 |
| Full effective lateral thrust | 0.05 L/s | 0.1 L/s |

These are adjustable feasibility values, not approved voyage/economy balance.
Full ahead without thrusters gives roughly 32.7 minutes after ramp-up.
Capacity must be finite and positive; rates/multipliers finite and nonnegative.
Zero rates allow disabling individual contributions in authored configurations.

- Neutral afloat consumes idle fuel. Input focus loss orders neutral but does
  not pause the world; ramp-down and subsequent idle still consume.
- Explicit simulation pause freezes motion and consumption without wall-time
  catch-up. A future multiplayer menu must not imply a server pause.
- Docked ships cannot propel themselves. Default docked consumption is zero;
  the optional definition switch enables idle-only docked burn.
- Fuel clamps at zero. The final tick receives only its affordable fraction
  of engine/thruster acceleration. Empty clears powered orders; momentum, drag,
  collision and speed-dependent rudder remain. No emergency propulsion,
  teleport, automatic refill or forced stop is introduced.

## Test recovery and display

Both handling scenes show liters and empty/paused/docked status. Labelled test
tools empty the tank, add test fuel, toggle simulation pause and set a stopped
docked fixture state. The latter is not a berth transaction.

Test refueling requires speed <= 0.05 m/s, neutral command/engine/lateral order
and tank space. It rejects non-finite/negative amounts and clamps to capacity.
After coasting to a stop, Refuel (test) restores the tank and controls work again.
Each new test-scene instance starts full; this is not persistent production
recovery or a refueling entitlement. Heavy deck movement is outside propulsion
consumption in this prototype.

Paid refueling (Step 58), recovery (59), saves and authority remain later work.
Runtime liters retain double precision; the integer-milliliter save contract
is unchanged and is not written here.

## Evidence

FuelCheck passes 42 assertions in editor and native Windows Release: mixed
output at 30/60/144 Hz, reverse/idle/docked configuration, pause, invalid
time/refill, final partial tick, nonnegative fuel, coasting, refill gates,
capacity, restart, definition validation and both scenes' test controls.
A 120-tick ramp under actual 30/60/144 rendering caps ends at 999.475833333 L
in every run (tolerance 0.000001 L). Full checks pass 20 stages / 64 scripts,
including the unchanged 98-check handling regression. Native HUD inspected.

Run `tools/Godot.ps1 -Mode FuelCheck`; standalone verification uses
`-Mode RunExport -Configuration Release -FuelProbe`.
