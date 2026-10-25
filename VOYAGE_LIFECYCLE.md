# Step 54 — Voyage lifecycle

Implemented October 25, 2026 for the local Port Test authority.

| Event | Result |
| --- | --- |
| Cancel unfinished container loading | Cancel operation, release lock and job; no cargo or payment. |
| Abandon loaded container job | Two clicks within five seconds; remove cargo and retain abandoned job record, no payout. |
| Cancel heavy pickup | Remove nearby floating load and active job, no payout. |
| Cancel while carrying heavy cargo | Refuse; deliver the load first. |
| Change ship with active job/cargo | Refuse before replacing the current ship. |
| Replacement spawn unavailable | Preserve current ship and voyage. |
| Leave/reopen | Existing durable snapshot restores progress, cargo and completed receipts. |
| Unfinished orphan accepted job on reopen | Release only verified unpaid, empty-manifest commitment and interrupt orphan operations. |
| Corrupt cargo, ambiguous settlement or unexplained credits | Refuse recovery; preserve checkpoint. |
| Future sinking/despawn | Trusted before_ship_removal hook forfeits container cargo without payout, cancels pending pickup, refuses carrying heavy cargo. Caller must honor failure before removal. |

Cancellation/abandonment builds and validates a candidate snapshot, commits it before
changing live state, and preserves cargo if the write fails. Snapshot version 2 adds
abandoned container records; valid version 1 saves remain readable. Database schema
is unchanged. Reconciliation never invents cargo or payment and retains strict
full-snapshot validation after the narrowly scoped repair.

Sinking gameplay is not implemented here (later damage work). The removal hook is
covered by tests but has no live sinking caller yet. Public multiplayer port/service
settlement remains a separate integration dependency; local tests do not prove it.

Validation: 131-script/startup check; 78 voyage suite checks in editor and exported
Release, plus real process termination before/after loading and delivery commits.
Editor evidence: ../output/voyage/fb1953a3; Release: ../output/voyage/04ea657b.
268 port/docking checks and rendered Release inspection passed:
../output/ports/c74e3ef3.

Andy confirmed an entire container delivery, successful heavy pickup, and the save
freeze fix. Wider alongside docking and this step still await his play-test.
Next: Step 55 voyage HUD. Minimap remains Step 56. Cargo-loading and mooring-rope
animations remain queued for later presentation polish.
