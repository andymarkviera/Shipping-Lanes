# Development review — October 22, 2026

Assessment: the architecture and build sequence remain suitable, but the foundation
is not finished and the game is not ready for public release. No restart or engine
change is indicated by this review. Protect the accepted handling and finish a
small integrated multiplayer foundation before expanding the cargo/world content.

## Coverage and evidence

| Roadmap range | Current interpretation |
| --- | --- |
| 01–15 | Contracts, definitions, settings, tooling and early storage/geography proofs recorded. Older setup-only prose is historical. |
| 16–28 | Playable handling, camera, water, reusable ships and fuel. Heavy-lifter fixture exists, but player pickup failure remains unresolved. Art and handling parameters are not all final. |
| 29–41 | Local networking, transactions, private saves/recovery and public identity/lease/handoff foundations implemented through bounded proofs. Public login, boat presentation and shared collision now connect real services to real Godot peers. |
| 42 | OPEN: integrated foundation acceptance and bounded networking remain due. Passing separate probes is not sufficient. |
| 43–57 | Next gameplay milestone: two ports, docking, container loading/delivery/payment and persistent first voyage. Not yet a complete earning loop. |
| 58–87 | Services, recovery, fleet progression and remaining cargo families, including full heavy jobs. Basic reported heavy pickup repair is due earlier, before 50. |
| 88–101 | World/navigation/streaming/content and performance. Preserve all-open-water policy; visible obstacles and berth clearance still matter. Foam/wake polish at 99–100. |
| 102–109 | Customization, onboarding and experience gate. Peer trading/transfers 103–105 excluded; achievements conditional. |
| 110–128 | Production operations, discovery, hardening, release checks. Earlier minimum server/login work supports development; it does not complete these rollout tasks. |
| 129–142 | Post-core vehicle and rocket expansion; not prerequisites for the first voyage. Walking/passenger/furniture remain deferred. |

Reviewed the original roadmap structure, local contract, feature inventory,
uncertainties, supplemental dependencies, progress and feedback records. Inspected
current public client entry, ownership/checkpoint, helm and disconnect paths.
This is a planning/targeted code review, not a full security or line-by-line audit.

Fresh checks: Godot Check passes 106 scripts and startup; FlowCheck passes;
PersistenceCheck passes 79 assertions across init/recover/verify/fallback/UI,
including process-kill recovery. Evidence directory:
../output/persistence-checks/Editor-875ed4a4e18841ab8bf98c66df9c2c42.

Reviewed recent recorded evidence (not rerun): native sign-in 18 integration +
16 provider checks in both editor and Release (b26b7a11/dadc09e4); public player
integration 65 + 16 in Release (0238235c); shared physics 26 per runtime
(3dd8d8a9/7edf5758). These use local controlled services and do not prove WAN
behavior, actual browser-window usability, production uptime or 100-player support.

## Findings and finite next steps

1. Persistent local service/account setup and joining remain unfinished. Current
   fixtures are disposable; ordinary Servers correctly shows an unconfigured
   message. Provide a repeatable bounded development setup/enrollment procedure,
   then verify two ordinary clients. Keep production hosting/discovery out of this
   task. New accounts need distinct safe starts; occupied saved positions currently
   fail safely but require usable feedback/retry policy.
2. Public spatial/fuel durability needs completion. public_ship_owner checkpoints
   on transfer and public_peer_session checkpoints on departure; there is no
   periodic sailing checkpoint in those paths. A process crash restores the last
   committed snapshot and can roll back later travel/fuel. Define a bounded loss
   interval, implement periodic checkpoints and graceful server shutdown, and test
   crash/restart, outage and stale-owner rejection. Durable receipts must remain
   independent of visual state and never replay accepted economic effects.
3. Network budget and responsiveness remain the major measured scale issue.
   Step 32's historical crowded fixture measured 71.154 Mbps application egress,
   6,124-byte snapshots and 227 ms rendered acknowledgement p95. These are not
   current public-runtime capacity results. The current bounded public roster and
   reliable helm path still need compact bounded updates, queue/deadline work and
   loss/latency testing. Re-measure the actual integrated path before setting a
   supported player limit; 100 remains a target.
4. Close the pre-42 integration checklist on the actual player/dedicated paths:
   two accounts spawn, sail, collide, consume fuel, lose connection, persist,
   restart/reconnect and transfer ownership without duplicate control or writes.
   Preserve the existing private path and prototype payload/receipt invariants.
   Track missing public thrusters explicitly; do not claim parity with local
   controls. New production cargo/job features belong to later cargo steps and
   cannot become circular prerequisites for this pre-cargo gate.
5. Proceed to the first complete two-port voyage after foundation acceptance.
   Keep neutral/stop usability before 46 and heavy pickup repair before 50.
   Expand cargo types, art and world only after this narrow loop works.

## Player feedback remains authoritative

Heavy loader cannot pick up its load; reversing into it can feel stuck while
forward travel afterward does not. Cause remains unverified. Automated attachment
fixtures do not establish that manual pickup works. Reproduce manual bow/stern
approaches, stop state, deck clearance and failed-action consistency; provide the
actual blocking reason and test pickup/secure/raise/release in applicable local
and multiplayer flows. Do not mark this resolved without reproducing the report.

Neutral/full-stop recognition remains scheduled before docking. Wake/foam are
accepted placeholders, with Zelda-inspired bold-blue/white-pattern polish at
99–100 before 109. No hidden shallows or player-to-player economy may return.

## Record hygiene and recovery

Corrected stale setup-only/current-entry wording and depth/grounding scope in local
planning files. Historical append-only entries remain dated evidence, not current
status. Original synced/attached references were not edited. No gameplay changed.
A verified Git source archive follows this review; the preexisting project.godot
working change is preserved locally and is not included in that Git archive.

## October 23 consolidated follow-through

Use FOUNDATION_ACCEPTANCE.md for the current acceptance checklist. Persistent local
setup, periodic durability, compact pacing and controlled impairment have since
been implemented and measured. This pass repairs public thrusters and adds the
requested throttle indicator. 100 players is an optional stress reference, not a
required target. Remaining work is clear refused-admission feedback and the combined
foundation acceptance scenario with explicit workload/manual evidence limits.
