# Simulation lifecycle and clocks — Step 14

Completed October 19, 2026. A session-owned ten-second operation now demonstrates
explicit time and teardown rules. It changes no cargo, money or ship properties.
It is not an implemented loading/refinery system or a durable operation queue.

## Clock ownership and semantics

SimulationClock belongs to SessionAuthority. TestSession supplies process-local
Time.get_ticks_usec() samples; the UI only reads a copied status. No Timer node,
UI animation, system UTC or computer calendar advances an operation. This is a
20 Hz operation clock (50 ms ticks), not a selection of ship physics tick rate.
Integer microseconds retain remainder between frames rather than rounding each
frame to milliseconds. Default time scale is 1:1 with accepted active time.

The first sample establishes a baseline. Duplicate/backward samples grant no
extra time; a backward sample does not reset the baseline. Each update accepts
at most 250 ms (five ticks). Excess is recorded as discarded_us and never queued
for later catch-up. This deliberately bounds debugger stalls/system-suspend gaps;
a long gap can credit at most 250 ms, not hours of offline progress. Under a slow
server below four updates per second simulation time will run slower than real
time. Revisit this policy with performance/hosting evidence, not silently.

For future persisted records, clock_ms, started_world_ms, due_world_ms and
completed_world_ms are elapsed authoritative world milliseconds, not Unix time.
The test uses an exact deadline and completes once at clock_ms >= due_world_ms;
completed_world_ms records that deadline. Actual tick delivery can occur on the
following frame. Raw process monotonic samples never persist across processes.
A future checkpoint must preserve tick remainder alongside elapsed world time if
subtick precision is required; Step 11 world records currently sketch only whole
milliseconds. Extend/version and validate them before real persistence.

UTC may later support audit display or backend-owned public deadlines; it cannot
be substituted for this clock. There is no UTC input in this simulation API.
Private hosted fixture work has no offline catch-up. Public shared refinery and
market time still needs backend authority and its separately implemented policy;
local host clock samples cannot authorize public progress.

## Lifecycle decisions

| Event | Test operation behavior |
| --- | --- |
| Hosted session opens pause/settings or loses window focus | Clock keeps advancing; local helm input is blocked |
| Offline-only test fixture pauses | Samples maintain baseline but grant no ticks; remainder is preserved |
| Menu contents are hidden/shown | No timer creation/reset or completion side effect |
| Return to title | Session stops processing; authority/clock/deadline explicitly transfer to in-memory Continue |
| Continue | Same authority resumes; baseline reanchors so time on title gives no progress |
| New Session, including from title | Old pending test is explicitly canceled; new authority starts idle at time zero |
| Session removed without transfer / application teardown | Pending work is canceled; no orphan callback or timer remains |
| Application closed then restarted | Disposable fixture is gone; no disk resume or offline gain |

Returning to title ends/suspends this local fixture. It does not claim that a real
public server should stop when a client leaves. Future server lifetime must be
independent of client scene ownership and dispatch authenticated requests into
the same authority boundary. Scene streaming must keep session authority alive
or explicitly transfer it; no incidental UI timer is permitted to own jobs.

Only the trusted in-memory continuation handle carries the authority object;
it is never saved or accepted from a client. New requests cannot reset a running
test deadline. Starting another test after completion is allowed; each run has
its own once-only completion count. This is not durable operation-ID replay safety.

## Checks and optional preview

22 clock/lifecycle checks pass in the pinned editor and exported Windows Release:
subtick accumulation, exact boundaries, paused time, backward/duplicate samples,
stall limits, reanchor, actor/duplicate-start rejection, copied views, exact and
once-only completion, unchanged economy, hosted settings, offline pause, title
suspension/Continue, replacement and app teardown. Existing 21 session checks
and repeated FlowCheck tests pass. Native release startup and a 1152 x 648 test
screen capture were inspected.

```powershell
./tools/Godot.ps1 -Mode ClocksCheck
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -ClocksProbe
```

Optional: F5 -> Play -> Start 10-second test. The countdown is read-only UI.
No user test is required. Save/resume across application restarts, global job
scheduling, network time synchronization and persisted operation execution remain
later tasks. Next is Step 15, development-tools-and-checks (confirm roadmap scope).
