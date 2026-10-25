# Step 51 — In-flight voyage persistence

October 24, 2026. Local Port Test authority implementation, plus user-requested heavy pickup simplification.

## Heavy loader interaction

Lower the platform, reverse underneath the load, stop in neutral, then Raise.
The load centre must be over the platform (9 m sideways, 24 m longitudinally,
2 m vertically); heading is unrestricted. Attachment settles the load into its
safe deck slot without moving the ship. Physical clearance and stopped/deck checks
remain. Raise automatically attaches; Secure is removed from both test menus.
At a heavy job's ocean destination, Lower releases and completes the job automatically;
the Port Test no longer needs a Drop load button. Elsewhere Lower explains the
remaining destination requirement. The standalone fixture retains a manual Release
button because it has no job/drop-off rule. Wrong position produces an ordinary
positioning message, not a demand for 0.5 m / 3-degree alignment. Invisible completed
cargo no longer blocks raising the empty deck.

## Save scope and policies

Port Test now opens `user://worlds/private_port_voyage/voyage.db`. This separate local
save does not modify the existing private/public economy or authentication databases.
The whole authority checkpoint includes fixed accepted quotes, offer states, manifest,
operation records/locks, loading progress and sequence, active ship/port/pose,
fuel/condition, heavy pickup/drop target/attachment/deck travel and completed receipts,
and local test earnings. Both ports and scenery remain deterministic static content.

- Reserved/running/ready loading resumes at the saved elapsed time, with its dock
  reservation reconstructed and ownership rebound to the new runtime ship instance.
  Reserved operations start; ready operations commit once. No wall-clock progress
  accrues while closed. Partial loading creates no partial cargo.
- Cancellation or lost docking releases the incomplete job with no cargo/payout.
  An ordinary menu exit or window close saves before scene teardown cancels live
  objects. Reopening restores that saved in-flight operation.
- Completed loading restores the manifest and committed receipt together. Delivery
  restores the consumed batch, completed job and test credit total together.
- Heavy pickup location and random destination persist. Attached cargo restores as
  exactly one collider owner. Interrupted platform travel resumes; normal clearance
  checks can stop it. Completed heavy deliveries do not respawn cargo or pay twice.
- Ships restart stopped in neutral. Fully docked ships reconstruct their reservation;
  unfinished docking/undocking transitions restart underway, releasing transient holds.
- Relevant state transitions save at the end of the physics tick, before the next
  presentation frame. Pose/fuel/loading/deck progress checkpoints also occur once a
  second. Abrupt termination can lose up to that interval of motion/progress, but
  cannot split a committed cargo/job/reward transaction. Normal exits save immediately.

The SQLite transaction uses WAL and FULL synchronous writes with a revision check to
reject stale second writers. One bounded, checksummed, object-free Variant snapshot
preserves integer quantities and transforms without JSON precision/coercion issues.
Restore validates version/realm/identity, fixed quotes, compatibility/capacity,
one active job, manifest/receipt consistency, timing/locks, heavy job bounds and
receipt-derived credits before applying. Damaged/incompatible saves or write errors
pause gameplay and preserve the checkpoint rather than silently starting over.
There is no automatic reset or fallback to an older economic checkpoint.

This is a local persistent voyage, not completed public-server port integration.
The same validated snapshot supports authority reconnect reconstruction, but no
remote client may submit it as authoritative state. Public port placement, service
RPC ownership, disconnect/reconnect wiring and production settlement remain explicit
integration work. Loading/rewards here do not claim payment-backed production cargo.
No player-to-player transfers. Step 52 container visuals is next; Step 56 includes
the requested temporary minimap before the Step 57 first-voyage gate.

## Verification

126 scripts/import/startup and FlowCheck pass. Heavy tests pass 39 in editor and
Release, including real reverse approach, crooked pickup, collision ownership,
overhead obstruction, camera behavior and Raise UI. Final rendered Release port/cargo
suite passes 220 at `../output/ports/62c73de4`; menu capture inspected.

`tools/check_voyage.py` passes in editor and Release. Release evidence:
`../output/voyage/dea4dccd`. Its 41-case suite covers codec consistency, reserved/ready
boundaries, loading resume, real autosave initialization/reopening, hidden UI independence,
stale writers, corruption refusal, heavy lift resume and automatic ocean delivery.
Separate processes seed partial loading, terminate inside the SQLite save immediately
before and after COMMIT, then verify recovery: old progress before commit, exactly one
loaded batch afterward. Further separate-process delivery/reopen proves no duplicate
payment. Process-death markers verify the intended fault point was reached (Windows
self-termination may return zero). Export resource omissions found by the first Release
run were corrected and the final suites rerun successfully.

Recovery tag: in-flight-voyages. Verified source backup:
`../output/checkpoints/in-flight-voyages-2026-10-24.zip`.
Preexisting `project.godot` customization remains untouched and outside the source checkpoint.
