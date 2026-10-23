# Public network impairment checks

This checkpoint adds a bounded, loopback-only test relay around actual encrypted
Godot DTLS datagrams. It neither decrypts traffic nor changes authentication,
certificate validation, snapshots, authority or save behavior. The ordinary server
and public player scene are used with fixture-issued account tickets. This is not
an additional browser/OIDC proof and does not change gameplay.

The relay applies independent 7% random drops, uniformly distributed 20–100 ms
one-way delay, an additional 200 ms delay on every eleventh received datagram,
and a duplicate on every seventeenth eligible datagram. These scheduling rules
produce actual reordering, measured in the evidence. A fixed random seed makes
the rule sequence reproducible, but OS scheduling and datagram timing still vary.
It then drops all traffic briefly, including queued traffic, before restoring an
unimpaired connection. Only one loopback client endpoint and one owned server are
relayed. The delayed queue is capped at 512 datagrams.

## What passes

- An authenticated client joins through the opaque relay; a second nearby account
  joins directly. Both remain represented through the impairment phase.
- Commands continue to move the server-owned ship. Applied snapshot ticks and
  acknowledged input sequences never move backward despite reordering/duplicates.
- During the blackout, stale client presentation is removed and helm readiness is
  disabled. The server neutralizes missing input while retaining the healthy owner.
  Neutral command is not an instant physical stop.
- Restoring traffic reconstructs the complete nearby roster and preserves the
  existing binding. The latest command works again without duplicate admission.
- Departure commits actual fuel/position and releases the lease. Stable ship,
  money and cargo identity remain intact.

The Release test uses the native graphics backend with a hidden window and a
60 fps test cap. Frames drawn are asserted; this is graphics-enabled execution,
not a visual inspection or human acceptance of handling. The second client and
server are headless. Headless editor tests run separately. Windows UDP reset
notifications after an owned endpoint closes are handled as expected cleanup;
other relay failures propagate to the test rather than silently passing.

## Final evidence — October 23, 2026

Editor: ../output/handoff/87f895d7/impairment-summary.json (17 checks).
Release rendered: ../output/handoff/97044f47/impairment-summary.json (18 checks).
Metrics are in impairment-metrics.json alongside each summary.

| Sample | Headless editor | Rendered Release |
| --- | ---: | ---: |
| Impaired observation duration | 10.625 s | 10.625 s |
| Distinct acknowledged sequences sampled | 24 | 44 |
| Sampled send-to-ack age p95 / max | 287 / 296 ms | 399 / 415 ms |
| Engine process delta p95 | 6.896 ms | 16.667 ms |
| Bidirectional relayed UDP payload rate during impairment | 2,544 B/s | 2,793 B/s |
| Dropped / duplicated / reordered datagrams (cumulative) | 16 / 11 / 26 | 17 / 14 / 30 |
| Peak delayed queue | 6 | 6 |

Acknowledgement age uses the client send timestamp and the received snapshot's
acknowledgement timestamp, sampling distinct sequences observed by the runner.
Not every sent command is sampled/acknowledged independently: latest-state input
is intentionally allowed to supersede older commands. These are short empirical
samples, not a hard latency bound or input-to-visible-motion measurements.
Engine process delta is not a full GPU/frame-time benchmark. UDP payload counts
include encrypted transport overhead but exclude UDP/IP/link headers; the cumulative
maximum of 1,231 bytes includes handshake/control traffic and is not a snapshot-only
size. The earlier 1,200-byte rule bounds serialized snapshot arguments, not every
encrypted transport datagram. No stronger network-MTU claim is made.

Initial runs had expected endpoint-reset exceptions in the relay cleanup and
sampled repeated acknowledgements. These were corrected in the harness. The first
uncapped hidden rendered run also showed a larger latency tail; the final run uses
a controlled 60 fps cap. Do not claim a gameplay performance improvement from
changes to the test setup or measurement method.

## Remaining foundation work

These tests close the short controlled loss/reordering/blackout evidence gap for
the bounded path. They do not certify internet hosting or close Step 42 by themselves.
The integrated two-peer foundation acceptance must still reconcile safe saved-spawn
feedback, public control parity, manual browser trust/play usability, sustained
load/total-server work and any remaining blocking issues. Longer outages that cause
full disconnect, real WAN/NAT, multiple hardware configurations and sustained
capacity/soak tests remain separate coverage. Preserve the existing recovery and
ownership tests; do not substitute this short relay scenario for those gates.

Run the managed Python executable with tools/public_handoff/impairment_probe.py
--runtime editor, or --runtime release --rendered after exporting the final build.
The fixture stops its own processes and retains evidence; ordinary saves are untouched.
