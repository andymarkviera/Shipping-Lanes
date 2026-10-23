# Foundation acceptance review — October 23, 2026

Step 42 remains open. This is a finite development gate before two test ports,
not production release acceptance. It supersedes the next-action ordering in the
October 22 review; historical measurements there remain historical.

| Boundary | Evidence and remaining work |
| --- | --- |
| Persistent development services/enrollment | LOCAL_ONLINE.md: restart-stable local accounts, ordinary dedicated entry and isolated client configuration. Browser trust/manual browser usability is still unverified. Do not install OS trust silently. |
| Public ownership and sailing | Current editor peer regression passes 55 checks (e4bb18bd), including two accounts, distinct hulls, peer/generation fences, stale-input handling, fuel, departure save/release, replacement and backend outage. |
| Shared collision/chart transitions | PUBLIC_SHARED_PHYSICS.md records 26 editor/26 Release checks. Existing proof, not rerun in this pass. Include two-hull collision in final combined foundation run. |
| Durability and restart | PUBLIC_DURABILITY.md: 26 editor/26 Release checks, periodic commits, process death, lease expiry, restart, graceful drain and outage reporting. Existing proof, not rerun here. |
| Network budget | PUBLIC_NETWORK_PACING.md and PUBLIC_NETWORK_IMPAIRMENT.md: bounded eight-peer frames and short controlled loss/latency/reorder/blackout. Current header grows four bytes for signed speed; 448 maximum serialized arguments remains below 1,200. Sustained whole-server workload and WAN/NAT remain unproven. |
| Public helm parity | Missing lateral intent repaired in this pass; saved thruster bindings now reach the authoritative hull. 11 editor/12 rendered Release checks (228f6975/d651e434). Menu, focus loss and timeout neutralize lateral input. No handling retune. |
| Spawn safety/usability | Overlapping saved spawns are refused and leases released without changing the canonical save. Specific occupied-spawn feedback and fresh sign-in retry are implemented; see PUBLIC_JOIN_FEEDBACK.md. General port/berth spawn allocation belongs to Step 44. |
| Command/motion feedback | Shared read-only throttle indicator added to local ShipHelm scenes, local/private network fixture and public presentation. Actual signed public motion comes from the server. Screenshot inspected; this is not player acceptance of stopping/pickup. |
| Existing cargo/economy boundaries | Prior local persistence/action proofs remain relevant; preserve prototype payload and receipt invariants in the final combined run. New job/loading systems are Steps 47–54, not pre-42 prerequisites. No player trading/transfers. |

## Remaining sequence

1. Completed: refused admissions now retain an allowlisted explanation and offer
   fresh sign-in retry without teleporting/overwriting saved boats. The occupied
   spawn test verifies the entire canonical profile is unchanged.
2. Run and record the combined two-account foundation scenario on the normal
   dedicated/player paths: spawn, sail, collide, consume fuel, leave/save, restart
   and reconnect, plus existing payload/receipt invariants. Reuse the proof runners;
   add only missing integration assertions. Record practical eight-peer workload
   limits and separate manual browser/deployment evidence gaps explicitly.
3. Accept or list concrete failures against Step 42, then begin Step 43's two ports.
   Do not quietly convert WAN hosting, 100-player support, new cargo families or
   final art into additional foundation prerequisites.

Neutral/stopping usability still needs its dedicated review before Step 46.
Heavy-loader pickup/reverse sticking remains unresolved and due before Step 50.
Wake/foam polish remains at 99–100. All open water remains navigable.
