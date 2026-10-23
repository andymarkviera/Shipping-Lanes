# Foundation acceptance — October 23, 2026

Step 42 PASSED for the bounded local development foundation. The combined normal
dedicated/player run exposed an in-flight save reparenting defect; it was repaired
and the complete scenario passed. Proceed to Step 43, two test ports. This is not
public release acceptance. Detailed evidence and limits: PUBLIC_FOUNDATION.md.

| Boundary | Current evidence |
| --- | --- |
| Combined two-player lifecycle | 41 Release checks in 85fb23a5: distinct boats, sailing, actual contact behavior, fuel, one player leaving, final save/drain, restart, unchanged canonical profiles and original ship IDs, complete restored roster. Includes deterministic in-flight reparent/save regression. |
| Eight-player development workload | 60.219 seconds, 61 complete-roster polls; six periodic saves per account, successful shutdown. Total dedicated CPU 0.236 core equivalents, sampled peak working set 91.55 MiB. Limits in PUBLIC_FOUNDATION.md. |
| Crash/outage durability | 26 fresh Release checks in 173de595 after the save fix: process death, committed recovery, restart, immediate reconnect, replacement race and truthful failed-drain reporting. |
| Collision/chart boundaries | 26 fresh Release checks in c6bbbf27, plus combined two-client contact. |
| Existing cargo/actions/persistence | 79 fresh Release persistence checks; 49 action checks and 34 impaired cargo checks. Nonempty payload/receipt fixtures are local; public loading/delivery remains later work. |
| Sign-in and retry | Prior current-code native entry: 23 integration + 16 provider checks in editor/Release (43c95f14/6535806f); specific refused admission and unchanged-save retry. Manual browser trust remains unverified. |
| Helm and impaired transport | PUBLIC_HELM.md and PUBLIC_NETWORK_IMPAIRMENT.md retain controls, finite-input fencing, loss/reordering/stale-state/blackout evidence. Public frame arguments are currently at most 448 bytes for eight hulls. |
| Persistent local operator setup | LOCAL_ONLINE.md provides reusable development enrollment/configuration and normal dedicated launch; no production deployment or trust installation. |

The eight-peer cap remains a development limit, not a promised production capacity.
WAN/NAT, long soaks, broader hardware and actual browser trust experience remain
explicit manual/unavailable checks; repeat workload checks as ports/cargo are added.
100 players is only an optional stress reference.

Next: Step 43's two independent port scenes/data definitions, followed by Step 44
spawn clearance and recovery anchors. Current occupied spawns fail safely rather
than teleporting saved ships. All open water remains navigable.

Neutral/stopping usability remains due before Step 46. Heavy-loader pickup and
reverse sticking remain unresolved and due before Step 50; automated attachment
checks do not override that player report. Wake/foam polish stays at 99–100.
No player-to-player trading or transfers.
