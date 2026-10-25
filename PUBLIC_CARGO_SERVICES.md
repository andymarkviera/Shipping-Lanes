# Online cargo services — Step 57 integration

October 25, 2026. Functional prototype; full first-voyage gate remains OPEN.

## Player flow

Authenticated container-ship players dock, open CARGO, select one job, wait for
loading, undock and deliver at the named destination port. The opaque voyage panel
shows cargo aboard, destination/distance, quoted payment, wallet and the last paid
receipt. Loading locks undocking. Cancelling loading pays nothing; abandoning
loaded cargo requires a second explicit click and pays nothing. Nearby players
see loaded container counts on ship replicas.

Public heavy-loader jobs, refuel/repair service integration, minimap integration,
cargo animations and aesthetic polish are not part of this milestone. Existing
local Port Test services and save policy are unchanged.

## Authority and recovery

Game protocol 11 requires matching client/server builds; authority ticket protocol
stays 7. Reliable peer commands bind to the authenticated sender's ship, epoch,
generation and increasing sequence. The server derives account, active job and
actual docked port, and validates physical docking before asserting a port to the
canonical authority. Clients cannot submit prices, quantities or account identities.

A per-owner voyage lock serializes inspect/action/reconcile against checkpointing
and departure. The backend continues to own loading readiness and atomic cargo/
payment/receipt settlement. Server wall-clock readiness only schedules attempts;
the backend database clock makes the final decision. Disconnect releases the berth;
a loading job resumes after reconnect and redocking at its origin.

Unknown transport outcomes fence the owner. UI waits and offers reconnect guidance,
without automatically resubmitting an uncertain action. Reconciliation installs
the current inspected profile, not an old receipt's profile. One active job remains
enforced by the backend. No player transfers or local-save reward imports.

Owned voyage state is sent reliably every 500 ms, with at most six offers and
cargo counts for at most eight nearby ships. Container meshes are presentation
only. This new cargo stream is separate from existing ship/port packet metrics;
those metrics should not be treated as total session bandwidth until this stream
is included. Development capacity remains eight; this is not a large-server claim.

## Verification

Pinned Godot 4.7.2: 138-script/startup check and final Windows Release export pass.
Final Release cargo probe passes 38 checks using isolated PostgreSQL/HTTPS,
the normal dedicated-server entry and two actual DTLS clients. Covers dock-only
acceptance, loading/undock lock, reconnect during loading, own/nearby container
replication, restart, actual UI delivery, duplicate-delivery protection, canonical
wallet/cargo/receipt persistence and clean runtime logs.
Evidence: ../output/handoff/31c2114c/cargo-peer-summary.json.
Rendered loading and paid-receipt screenshots were inspected for readability.

Release shared physics: 37 checks, ../output/shared-physics/86f5b2cf.
Release local voyage: 101 suite + 34 round-trip assertions, fresh-process repeat
verification and loading/payout before/after-commit recovery, ../output/voyage/58f2053d.
Earlier editor cargo behavior passed but exposed transient command-file reads in
the test harness. The harness now retries incomplete JSON without consuming it;
the final Release run above is clean.

The cargo probe uses operator-owned fixture approach positions between phases.
It does NOT prove a complete navigated voyage. Next: two consecutive navigated
voyages with two actual peers, live interruption coverage, and user gameplay
feedback before accepting Step 57. Prior backend crash evidence remains recorded
in PUBLIC_VOYAGE_CONTRACTS.md; it is not a substitute for the live voyage gate.

Recovery tag: public-cargo-services.
Verified source backup: ../output/checkpoints/public-cargo-services-2026-10-25.zip.
