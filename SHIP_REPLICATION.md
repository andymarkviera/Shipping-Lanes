# Ship replication — Step 30

Local Multiplayer Test now lets both players sail, turn and use lateral thrust.
Open two game windows on this computer, host in one and join in the other.
Each window follows its own boat with the existing orbit/zoom camera. Saved
helm bindings apply; X orders neutral, focus/UI loss orders neutral, Escape
returns to the menu. Water wakes follow both ships. The live HUD shows speed,
engine order/output and replicated propulsion fuel.

## Authority and protocol

Protocol 2 reserves reliable channel 0 for membership, unreliable-ordered
channel 1 for helm intent and channel 2 for state. Both intents and snapshots
are sent at 20 Hz; host physics remains 60 Hz. Host-local input uses the same
validation function as remote input. The host alone runs collisions, engine
ramping, propulsion and fuel for both hulls. No client position or fuel update
can write authoritative state.

Input carries session epoch, entity ID, sequence, bounded throttle/rudder/
lateral orders and a client timestamp echoed only for timing. Ownership comes
from the RPC sender and host roster. Unknown entities, wrong epochs/owners,
non-finite values, out-of-range inputs, stale sequences and arrivals less than
10 ms apart are rejected. Missing valid input for 500 ms orders neutral and
clears rudder/thrusters; momentum and normal engine ramp-down remain.

Snapshots carry epoch, roster revision, increasing sequence, host timestamp,
position/yaw/velocity, order/output, rudder/lateral order, fuel and input ack.
The authority-only receiver validates sender, membership and field types before
updating presentation buffers. Client physics/collision are disabled. Roster
changes reconcile buffers, hulls and wakes; disconnect clears queued packets.

Clients retain at most 16 samples per entity and render 150 ms behind their
estimated host timeline, interpolating position, yaw and velocity. The minimum
observed clock offset anchors the timeline without assuming synchronized OS
clocks. An exhausted buffer holds the latest sample rather than extrapolating
unbounded movement. Initial state snaps once; subsequent motion interpolates.
No prediction or reconciliation is enabled in this prototype.

## Recorded impairment and measurements

The test-only outgoing application-message shim adds 100 ms each way with a
deterministic -20/0/+20/0 ms variation and drops every tenth input/snapshot.
Lifecycle messages remain unaffected. This is application-message impairment
over real two-process ENet, not an OS-level packet-loss or internet deployment
test. Queues cap at 128 packets. Normal interactive play disables the shim.

Windows Release measurements from this checkpoint:

| Profile | Input-to-snapshot acknowledgement mean / max | Snapshots | Largest render-to-latest-sample gap |
| --- | --- | ---: | ---: |
| Local, no added impairment | 19.3 / 21 ms | 219 | 0.69 m |
| 100 ms each way + jitter + 10% message loss | 228.3 / 283 ms | 194 | 0.68 m |

The acknowledgement metric includes input delivery, host scheduling and snapshot
delivery; it is not a raw transport ping. Only newly acknowledged inputs update
it. Presentation adds the 150 ms interpolation buffer. The test observes
bounded motion, correct turning and no >2 m gap from the newest received sample;
that gap is not error against the host's current position.

Decision: retain authoritative buffered movement for this slow-ship prototype.
Measured response and continuity do not yet justify prediction complexity.
Andy should still review remote steering feel; prediction can be revisited if
that review or higher-latency internet tests show a need. No universal latency
or packet-loss tolerance is claimed.

## Verification and scope

Normal profile: 10 host + 14 client assertions. Impaired profile: 11 host + 15
client assertions. Both profiles pass in editor and Windows Release using two
independent processes. Checks cover each helm's motion, ownership/epoch/bounds/
finite/sequence rejection, replicated fuel, disabled client physics, bounded
interpolation/queues, a 1.2-second input interruption and recovery. The Step 29
three-round lifecycle test remains included. A native two-boat sailing capture
was inspected. Wake processing is disabled before departed hulls are removed.

Use `tools/Godot.ps1 -Mode ReplicationCheck` for both editor profiles, or
`tools/CheckNetwork.ps1 -Runtime Release -Replication` and add `-Profile impaired`.
Localhost traffic must be permitted by the execution environment.

All communication remains loopback-only, with temporary identities and no
production accounts/saves. Cargo attachment replication is Step 31; world-frame
handoff, public transport security and internet play remain later work.
