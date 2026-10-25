# Step 57 — First voyage gate (OPEN)

October 25, 2026. The local exported voyage checks pass, but the full roadmap gate
is NOT accepted. Do not advance to Step 58 or more cargo families yet.

## New repeatable local evidence

`tools/check_voyage.py --runtime release` now runs a consecutive Brindle–Slatewater–
Brindle transaction scenario, then reopens that save in two separate processes.
Each leg accepts one job, saves partial loading, completes loading, undocks,
simulates a loaded steering sample with periodic saves and fuel consumption,
docks, delivers and attempts duplicate delivery. Both payments and two receipts
survive restart with an empty hold and no active navigation target.

The steering sample runs the handling model in open water; fixture placement is
used for port approaches. This is not proof of a player physically navigating the
whole route, nor is it a two-peer cargo test. Andy's previously confirmed full
container trip remains the manual gameplay evidence; the latest docking/UI/map
changes still await his test.

Editor evidence ../output/voyage/684521fe; Release ../output/voyage/c0802b4f:
101 suite checks, 34 consecutive-voyage checks, fresh-process receipt verification,
and existing real process-kill recovery before/after loading and delivery commits.
134-script/startup check and Release export pass. Extended loaded sailing/reopen:
330 checkpoints, ../output/sailing-save/51484301. User save untouched.

## Integration gap that prevents full acceptance

The main menu opens Port Test as `features/ports/port_test.tscn`, with fixed local
preview captain/ship identities and a private SQLite voyage snapshot. Authenticated
public play uses `public_peer_session.gd`, `public_physics_world.gd` and
`public_client_presentation.gd`. The public path does not instantiate the port jobs,
loading/delivery services or their service HUD. Its ship replicas do not replicate
the local manifest. Passing standalone public economics or two-boat sailing tests
cannot substitute for the missing complete network cargo voyage.

Required next work, still within this gate:
1. Give test ports stable world locations and instantiate their collision/service
   anchors in the server's shared/rebased physics spaces and client presentation.
2. Bind docking/jobs/loading to authenticated account and ship identity. Replace
   preview-only identity with per-player authority; serialize berth contention.
3. Commit cargo/job/payment changes through the canonical public profile authority
   and fenced request/receipt identities. Never import local test rewards.
4. Replicate owned voyage/manifest state and expose the same service/HUD experience;
   pending/timeout UI reconciles before retry, without auto-resubmission.
5. Run two actual clients through two consecutive voyages, interrupt loading and
   payout, restart server/clients, and prove no duplicate cargo/payment or stale
   reservations. Then request Andy's gameplay feedback before calling gate passed.

## Save policy clarification

Existing D070 / SAVE_SLOTS.md defines three private development slots. The newer
Port Test has a separate single autosave at private_port_voyage. Public play uses
one canonical profile per account carried between servers, not those local slots.
This gate does not change slot counts, migrate progress or delete any save.

Recovery checkpoint for this audit: first-voyage-audit. This label does not imply
the gate passed. Next work remains the multiplayer port/voyage integration above.

## Fresh two-peer baseline

Exported dedicated server plus two actual DTLS clients passed 24 checks, including
hull contact, independent departure/save, full server restart, canonical boat/profile
restoration and two-boat roster visibility. Evidence:
../output/handoff/81248558/voyage-gate-peer-baseline.json.
This is sailing/restart evidence only, not two-peer port cargo delivery. The initial
restricted attempt could not connect to its isolated local PostgreSQL database;
the permitted local-network retry passed and cleaned up its test processes.
