# Step 32 — Early dedicated capacity experiment

Task ID: `early-dedicated-capacity-experiment`.
Status: complete as an early measurement/architecture experiment, October 20, 2026.

## Harness and scope

`tools/CheckCapacity.ps1` runs a headless authority process, a separate observer
client process and one load-generator process. The generator maintains N-1 real
ENet client connections; the observer supplies the remaining connection. This is
not N full game/render processes. All traffic is restricted to 127.0.0.1; no
firewall, router, accounts or public services are changed.

The authority advances actual HandlingShip motion, turning clearance, hull
collision and fuel at 60 Hz. It receives 20 Hz helm input and two harmless,
sequenced fixture actions per second per client. Actions count accepted pulses;
they do not change money or cargo. About 20% of synthetic clients (at least one)
disconnect and rejoin seven seconds into each run. The server removes their old
hulls and assigns new temporary peer identities. No persistent account recovery
is claimed. Input silence orders neutral after 500 ms.

Dispersed ships use a 180 m grid. The crowded fixture uses 32 m lateral spacing,
80 m longitudinal spacing and three solid quays. Crowded hulls begin parallel,
clear of each other and the quays, then sail toward the end quay. Actual contact
is required for that case to pass. Some dispersed hulls steer across the grid.
All open water remains navigable. There are no hidden
shallows, grounding rules or changes to accepted handling.

Each case lasts about 19 seconds; the server records a 14-second window after
three seconds of warmup, including reconnect activity. Mean active connections
must exceed 95% of the requested count, allowing the bounded reconnect gaps.
Counts are 2, 10, 25, 50
and 100 total connections in each layout. These are short feasibility samples,
not sustained soak tests or minimum-hardware ratings.

## Relevance and network architecture

`ship_relevance.gd` builds a 350 m spatial grid and queries neighboring cells with
an exact 350 m distance check. Each owner receives itself plus nearby hulls.
Every snapshot is a complete relevant set, so removed/changed interest can be
identified without relying on a lost exit packet. Deterministic checks compare
all 100 queries against brute-force distance results, including negative cells,
and check entry/removal at the interest boundary.

The fixture uses compact arrays with peer ID, position, yaw, velocity and fuel;
each owner's header contains the last accepted input timestamp and action ID.
Motion uses unreliable ordered delivery; fixture actions and lifecycle requests
use reliable delivery. Godot's [MultiplayerPeer documentation](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html)
describes the polling and channel semantics used here. Object deserialization is
disabled by the default `bytes_to_var` path.

This experimental protocol is deliberately separate from the two-player menu
fixture. Its measurements do not include the existing dictionary-based cargo
snapshot format, full authentication, persistence, public services, world
streaming, heavy payloads, large fleets of detailed art or internet latency/loss.
The observer runs a real Godot client with a bounded 16-sample, 150 ms motion
buffer; the headless cases measure actual presentation positions numerically.
`-VisibleObserver` additionally renders the starter model in a simple test view.

## Measurement definitions

- `tick_ms`: elapsed authority work, including polling, input processing,
  production ship updates, interest selection, serialization and send queueing.
- `engine_physics_ms`: Godot's previous physics-process monitor, sampled each
  tick. `tick_period_ms` measures wall-clock tick spacing; neither is a render FPS.
- CPU: process CPU time divided by the sampled wall interval, reported as a
  percentage of **one core**. It may exceed 100% for multithreaded work.
- Memory: maximum sampled Windows working set, not an allocation/leak diagnosis.
- Bandwidth: serialized application bytes queued/received during the measurement
  window. UDP/IP/ENet headers, retransmission and other transport overhead are
  excluded. Large messages can fragment; loopback throughput is not an internet
  bandwidth guarantee.
- Observer: snapshot spacing, input acknowledgement age and maximum interpolated
  movement speed. The 150 ms presentation buffer is additional to acknowledgement
  age. No player steering-feel approval is inferred.

The three processes share this development computer, including load-generator
CPU/network overhead. Results must be repeated on intended hosting hardware.

## Repeatable commands

Full matrix: `tools/CheckCapacity.ps1 -Runtime Release` after a Release export.
Use `-Counts 25 -Layouts crowded -VisibleObserver` for a rendered client case.
`tools/Godot.ps1 -Mode CapacityCheck` runs a two-client crowded smoke case in the
editor and is included in the full project checks. Each run saves raw per-role
JSON, logs, sampled process metrics and a combined summary under
`../output/capacity-checks/`. Failed runs retain their evidence.

## Measured results and decisions

Pinned Windows Release, Intel Core i7-12700KF development host. Corrected matrix:
`Release-286c50b2c01147879734083a7fb2b26b`. Rendered repeat:
`Release-2ad42afe0afa4073a23fc691e8dac2aa`. Full numeric summaries are preserved in
`tools/baselines/capacity-step32.json` and the external evidence folders. Earlier
exploratory crowded runs had sideways hulls initially overlapping; those values
are superseded and excluded from this table.

| Connections | Layout | Work p95 / p99 ms | CPU, % one core | Peak MiB | Server out / in Mbps | Observer gap p95 ms |
| --- | --- | --- | --- | --- | --- | --- |
| 2 | dispersed | 0.17 / 0.21 | 19.7 | 82.5 | 0.065 / 0.024 | 56 |
| 2 | crowded | 0.18 / 0.22 | 21.0 | 83.0 | 0.065 / 0.024 | 56 |
| 10 | dispersed | 0.43 / 0.52 | 20.8 | 82.6 | 0.429 / 0.120 | 55 |
| 10 | crowded | 0.47 / 0.54 | 21.5 | 83.1 | 1.188 / 0.120 | 56 |
| 25 | dispersed | 0.83 / 0.98 | 21.4 | 82.7 | 1.998 / 0.299 | 55 |
| 25 | crowded | 1.08 / 1.25 | 21.1 | 83.1 | 6.986 / 0.299 | 56 |
| 50 | dispersed | 1.52 / 1.75 | 21.1 | 82.4 | 4.603 / 0.577 | 56 |
| 50 | crowded | 2.44 / 2.73 | 23.7 | 82.8 | 26.560 / 0.575 | 55 |
| 100 | dispersed | 3.11 / 3.52 | 26.0 | 82.7 | 9.772 / 1.144 | 56 |
| 100 | crowded | 6.28 / 6.58 | 33.8 | 83.4 | 71.154 / 1.143 | 56 |

All requested peak counts were reached. Mean active counts were 1.96, 9.92,
24.80, 49.56 and about 99.03 across the measurement windows, including reconnect
gaps. The 100-client runs had 120 joins; each crowded case recorded actual quay
contacts. Direct authority work stayed under 7.77 ms in the corrected matrix,
below the 16.67 ms 60 Hz budget. At 100 crowded, the sampled engine physics
monitor p95 was 7.96 ms. Wall-clock tick spacing still varied up to approximately
20.9 ms; a short local sample does not establish a hard real-time guarantee.

The relevance grid reduced sent record counts by 91.9% at 100 dispersed and
34.5% at 100 crowded relative to sending every hull to every owner. The most
crowded snapshot was **6,124 application bytes**, exposing a fragmentation and
egress risk that loopback cannot validate. Count 100 is **measured in this
fixture**, not approved as the production server limit. Counts above 100 are
untested, as are remote hosting hardware, WAN impairment and extended soaks.

The rendered 100-crowded repeat passed the bounded-motion and connection checks:
server work p95 6.03 ms; observer snapshot-gap p95 67 ms, maximum 163 ms; rendered
frame delta p95 13.33 ms with one maximum of 127.11 ms. Input acknowledgement age
was mean 64.64 ms, p95 227 ms, maximum 414 ms; the 150 ms presentation buffer is
additional. Maximum observed presentation speed was 4.49 m/s with no unbounded
jump. This is a responsiveness follow-up, not player approval of internet steering.
Window scheduling, render polling and packet backlog must be isolated before
attributing the long tail to any one cause.

### Architecture decision before expansion

Keep host-only 60 Hz ship physics and spatial relevance; do not scale the
two-player all-roster broadcast directly to 100 production players. Preserve all
collision-near entities; an arbitrary visible-ship cap must not hide blockers.
Dense nearby interest still approaches quadratic fan-out, despite the grid.

Schedule `bounded-replication-and-client-pacing` before the Step 42 foundation
gate or production multiplayer expansion, whichever comes first:

1. Separate rarely changing fuel/cargo metadata from 20 Hz motion. Add changed-
   state updates with periodic full keyframes and explicit interest entry/exit.
2. Pack bounded binary motion records and split updates into application packets
   no larger than a provisional 1,200 bytes. Bound assembly memory/time and reject
   incomplete/old revisions without partially applying cargo or chart transitions.
3. Keep own/collision-near motion at the required cadence; budget lower-priority
   distant updates. Measure actual transport overhead and select an egress budget
   against the intended host connection rather than treating 71 Mbps as free.
4. Measure client poll/send timing, foreground/background frame stalls and queue
   age separately. Use monotonic send deadlines and bounded newest-state queues;
   avoid accumulating obsolete motion behind render delays. Recheck rendered
   input-to-authority and presentation latency under load and WAN impairment.

Acceptance includes the same 100-crowded case, no hidden collision-near hulls,
correct full-state recovery after lost/delayed packets, bounded packet/queue sizes,
and p99 authority work below 12 ms on the test host. Target local rendered
acknowledgement p95 below 150 ms; report any remaining tail rather than masking it
with smoothing. Hosting budget and internet capacity remain separate later gates.

Validation: all 75 scripts compile, standard startup passes, all ten corrected
Release cases pass, the rendered 100-crowded repeat passes its stated assertions,
and the editor CapacityCheck smoke case passes. Existing gameplay has not been
retuned; the full suite now offers 25 stages, but the other unchanged stages were
not rerun for this isolated load harness.
