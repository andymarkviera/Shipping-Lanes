# Compact public snapshots and input pacing

The current public development server retains its eight-peer cap. Snapshots now
combine owner speed/fuel/input acknowledgement and the complete nearby roster in
one unreliable-ordered update at 10 Hz, replacing separate owner and dictionary
roster updates at 5 Hz. The shared authoritative simulation and save rules remain
unchanged. Collision-relevant ships are not removed to meet a packet budget.

The fixed codec uses a 32-byte header and 40 bytes per hull: binary UUID, 64-bit
connection generation, three float32 local coordinates and float32 yaw. Eight
boats occupy 352 payload bytes; measured serialized RPC arguments occupy 444
bytes. The sender refuses arguments above 1,200 bytes. This is an application
serialization bound, not a measured complete UDP/DTLS packet size.

The decoder validates version/count/exact length, sequence, fuel, finite numbers,
local range and unique IDs/generations before applying any state. The recipient
binding and its presence in the roster are checked; stale ticks cannot refresh
either presentation or owner status. Each frame is complete, so a lost frame does
not require a baseline, chunk assembly or retransmitted delta. Stationary peers
still receive a freshness heartbeat. A larger capacity may justify delta updates
and separately scheduled metadata, but those are not needed to fit this cap.

Helm traffic is unreliable ordered with the existing generation/sequence/rate
checks. Newest commands supersede earlier ones; stale commands remain rejected.
The client uses a monotonic 100 ms send deadline and sends at most one command
when invoked after a stall. It never catches up by transmitting accumulated old
commands. The server's missing-input neutral behavior remains. Admission/tickets
remain reliable. Matching client/server builds are required; this is a development
wire-format change, not a promise of compatibility with older exports.

## Measurements and limits

The codec probe compares equivalent eight-hull data against a conservative old
serialization estimate: 4,440 argument bytes/second per recipient at 10 Hz versus
at least 6,620 at the old 5 Hz, a reduction of about 33%, while doubling update
frequency. This is a same-data serialization calculation, not a before/after WAN
capture. Transport overhead is excluded from both.

The eight-client probe uses distinct fixture-enrolled identities, actual DTLS
peers and the Release runtime. It measures aggregate snapshot argument bytes,
client-local send-to-ack timestamps, snapshot-building work and geographic-group
synchronization work. The latter two are not total server frame/physics time.
The clients are headless; numbers do not establish rendered input latency or
internet quality. Test runners use fixture tickets, not a new OIDC login proof.

An initial externally polled measurement reported 172 ms p95 including test-runner
polling delays. The final probe timestamps send and acknowledgement inside the
same client clock to remove that observation delay. Keep both evidence records;
do not compare different measurement definitions as a claimed optimization win.

Twenty-three codec checks exercise size, precision, truncation, count/version,
NaN, duplicate identity, invalid generation/range and independent later frames.
The peer regression covers two accounts, shared collision, replacement/stale
control, disconnect saves, outage fencing and input focus/freshness behavior.
The eight-peer probe checks complete relevance, packet bound, actual movement,
skipped/late command sequences and no catch-up send burst.

Remaining gate work: controlled latency/loss/reordering and sustained rendered
client measurements, complete transport overhead, representative total server
work/soak and the integrated foundation scenario. This checkpoint does not close
Step 42 or certify eight-player internet support. 100 players is optional stress
research, not an acceptance requirement.

Run tools/public_handoff/pacing_probe.py --runtime release after exporting. The
codec scene is tools/compact_network_probe.tscn, or use --compact-network-check
as an exported game user argument. Evidence paths/results are in PROGRESS.md.
