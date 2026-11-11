# Heavy transport lifecycle — Step 82

Task `heavy-transport-lifecycle`. Builds on merged Steps 80–81. This is an explicitly
provisioned private host fixture connecting the existing HeavyStore ledger to the
actual lifter controls, not a public heavy-hull release or Step 83 presentation.
Historical Port Test saves and jobs remain separate and are not migrated.

## Run an isolated voyage

With the pinned Godot 4.7.2 executable and Python 3, from repository root:

```sh
python tools/heavy_transport_fixture.py --godot /path/to/godot --db /path/to/new-heavy.sqlite --create
```

Omit `--create` to reconnect to that same file. Creation is exclusive: it cannot
replace an existing save. The launcher binds a random loopback port and gives only
its owned Godot process an ephemeral bearer token through its environment. Run one
launcher per world file. This is trusted host simulation, not remote player input;
never expose this endpoint or use client-supplied navigation/evidence in public play.
Missing storage, definitions or navigation fences startup without a reset.

Claim the single nonexpiring block, lower, move the platform under its centre and
Raise. The fixture starts near the pickup. Sail to the offshore destination at
(-950, -1800) in the fixture's X/Z meter frame; the cargo anchor must be within
30 m horizontally. Stop and Lower to deliver. Step 83 adds waypoint guidance, cues
and payload variants: see HEAVY_JOB_PRESENTATION.md. The staging shortcut and free fuel fixture
controls are removed from this durable scene. The original lifter test retains them.

## Authority and attachment

Step 81's stopped, neutral, lowered, centre-over-platform and swept-obstacle checks
remain in force, including crooked pickup. The pickup guard first commits the
same job/payload identity and navigation to SQLite. Only a successful canonical
snapshot creates the attachment. Payload visuals are children of the fixed cargo
mount; their floating StaticBody collision is disabled and the carrier owns the
sole payload shape. No free rigid-body stacking is introduced.

The 100000 kg block uses a prototype 1000000 kg empty displacement. Forward,
reverse, thruster and turn acceleration scale by 1000000/1100000 when carried.
Visual hull draft increases 0.5 m; the planar hull/cargo collision frame remains
stable, with no depth tests or hidden shallows. Release/destruction removes these
effects. Catalog resources are not mutated. Existing fixtures opt out (zero payload
mass), preserving historical handling and saves. This is measured mass/visual-draft
behavior, not a buoyancy or wave-force model.

At the destination, lowering reaches the stopped lower limit before delivery.
The job, navigation, released attachment, wallet/debt, zone release and receipt
commit together. Only then does presentation remove the delivered block. An unknown
reply freezes the ship with its last visible custody; Retry reuses the original
request. The canonical snapshot, never an old receipt, rebuilds the scene. A crash
before commit restores carrying; after commit restores delivered, never pays again.

Navigation checkpoints run each active second using the profile revision as a
compare-and-swap guard; they cannot overwrite a newer economic transition. They
persist position/yaw, deck height/target, propulsion fuel and the single condition.
Failure fences play; reconnect restores the last durable position, stopped and
neutral, with no offline travel. Transition checkpoints are atomic with job state.
Interrupted deck travel resumes from the saved height and target. IDs and protocol
versions are unchanged. New navigation is an additive profile field, no database
schema migration; old service-only worlds remain readable but are not silently
converted into playable voyages without a valid host navigation record.

## Explicit lifecycle rules

| Event | Outcome |
| --- | --- |
| Claim | One immutable block, one active job, two reserved offshore zones; no expiry. |
| Pickup | Validate actual host geometry; commit before attachment. |
| Partial load | Indivisible block; no partial reward. |
| Cancel | Only before pickup; release reservations without payment. |
| Delivery/release | Only lowered, stationary and in destination; consume block and reward once. |
| Menu/quit/disconnect/crash/scenery teardown | Retain canonical identity and last committed navigation; no timeout or cancellation. Scene deletion removes only local nodes. |
| Requested despawn | Reject while pickup/carrying; finish or cancel first. No transfer/switch/resale of the active job. |
| Hull destruction | Host `destroy` attestation plus zero condition atomically marks the same job `failed`, consumes the block permanently, removes attachment and releases zones, with zero reward. |
| Hull recovery | Retain zero condition and ownership; never silently repair, refund, replace or spawn a healthy hull. Paid hull recovery and public admission remain existing separate systems, not a free fixture service. |
| Retry/outage | Preserve pending intent and stop. Reopen/replay the same action; no fallback or new replacement ID. |
| Missing/corrupt/incompatible state | Fail closed, preserve file. No reset or inferred placement. |
| Public handoff | Unsupported; do not import private jobs into public state. |
| Backup restoration | Operator must fence original writers; divergent restored worlds are not simultaneous authorities. |

Failed jobs retain a tombstone, as do delivered jobs; neither reoffers the block.
Claims before pickup may be cancelled and reclaimed under a new job identity.
The inherited 10000 economic-action receipt bound remains; checkpoints do not prune
receipts or create an unbounded checkpoint journal. Exhaustion fails closed.

## Reproduction and boundaries

```sh
python -m unittest services.heavy_load.test_private services.heavy_load.test_transport -v
python tools/heavy_transport_fixture.py --godot /path/to/godot --db /path/to/test.sqlite --create --probe carry
python tools/heavy_transport_fixture.py --godot /path/to/godot --db /path/to/test.sqlite --probe deliver
python tools/heavy_transport_fixture.py --godot /path/to/godot --db /path/to/test.sqlite --probe verify
```

Use a separate new file for `carry`, then `destroy`, then `failed`. Probes use real
Godot/HTTP/SQLite, cross-process reopen, an intentionally lost committed delivery
reply and exact retry. Python tests cover rollback, six new before/after-COMMIT
process deaths, stale checkpoints, invalid navigation, concurrent delivery,
permanent destruction and no healthy resurrection. They extend the Step 80
contention/crash tests. PROGRESS.md records actual results and unrun gates.
