# Step 42 foundation acceptance — October 23, 2026

The bounded local development foundation passes after fixing an in-flight save
lifecycle defect. Proceed to Step 43's two reusable test ports. This is not public
release, internet-hosting certification, or acceptance of the reported heavy-loader
pickup behavior. The practical public development cap remains eight.

## Combined scenario and defect

The new foundation_probe.py uses the normal exported dedicated entry, two actual
DTLS player processes and saved input actions. One player renders graphics at a
60 fps cap. Accounts/tickets are fixtures: the native OIDC entry was separately
verified in PUBLIC_JOIN_FEEDBACK.md, including blocked-spawn retry.

Both boats spawn 100 m apart, sail bow-to-bow, consume fuel and stop at contact
while forward orders remain applied. Six successive contact observations show
neither crosses the other; minimum observed center separation was 64.019 m for
64 m long hulls. The independent physics probe also observes actual slide contact.
They reverse apart before saving, honoring the current conservative spawn exclusion.
One leaves while the second remains connected; the server then drains, saves and
releases both accounts. A fresh dedicated process restores both original ship IDs,
complete profiles and revisions, and both players see the two-boat roster again.

Initial run ba1ca0a3 failed shutdown after this mixed lifecycle. Authority HTTPRequest
nodes lived inside hull owners; moving owners between physics viewports/session
parents could cancel in-flight requests on tree exit, leaving their awaiting save
unfinished. Requests now live under the stable scene-tree root and are freed on
completion. Existing callers still await pending operations before freeing owners.
A deterministic regression starts a real HTTPS checkpoint, confirms it is in flight,
then reparents the owner and verifies completion plus lease release. Drain timeouts
now log pending departure/join counts without credentials or account data.

Final combined and workload evidence: ../output/handoff/85fb23a5/foundation-summary.json,
41 checks. The initial failed evidence is retained, not counted as a pass. No new
protocol version, dependencies, physics retuning or cargo gameplay were required.

## Eight-player measurement

Normal dedicated Release process, eight moving clients on loopback, one rendered
client, local PostgreSQL/HTTPS authority; recorded i7-12700KF/RTX 3070 development
machine (ENVIRONMENT.md). Other game test suites had finished before the measured
load window. Background machine activity was not isolated.

| Measurement | Result |
| --- | --- |
| Sailing sample | 60.219 seconds; 61 all-client polls |
| Fresh nearby roster | All eight clients retained eight hulls at every poll |
| Periodic saves | Six committed revisions per account during the sample |
| Total dedicated-process CPU | 0.236 core equivalents, about 23.6% of one core |
| Empty dedicated baseline | 0.229 core equivalents over a short 3-second sample |
| Peak sampled working set | 91.55 MiB |
| Peak sampled private bytes | 50.19 MiB |
| Private-byte change | +0.059 MiB over the window |
| Rendered recent process delta p95/max | 16.666 / 16.666 ms at the imposed 60 fps cap |
| Shutdown | Successful final saves and release for all eight accounts |

CPU comes from Windows kernel+user process counters across all dedicated threads;
it excludes the separate database, authority service and client processes. Memory
is sampled, not an allocation/leak proof. The rendered timing is the latest bounded
600 process-delta samples, not whole-run latency or a hardware-independent fps
promise. No meaningful speedup is claimed relative to the very short idle sample.
No bandwidth number is inferred from CPU. Compact snapshot and loss/reordering
measurements remain in PUBLIC_NETWORK_PACING.md and PUBLIC_NETWORK_IMPAIRMENT.md;
the current snapshot maximum is 448 serialized argument bytes after signed speed.

This supports retaining eight as the development limit, not raising it or promising
production capacity. Repeat on actual hosting hardware with the future port/cargo
workload; a minute is not a long-duration soak or internet/NAT test.

## Other foundation safeguards

- Release persistence: 79 checks including process-kill recovery, cargo and duplicate
  purchase receipt protection; ../output/persistence-checks/Release-c74523fe2e4c4a4fa6605e1f50582579.
- Release shared physics: 26 checks for contact, chart merge/split/rebase and safe
  spawn refusal; ../output/shared-physics/c6bbbf27.
- Release action authority: 22 host + 27 client checks;
  ../output/network-checks/Release-normal-85095b3979f54945872965ace1b3c69b.
- Release impaired cargo fixture: 15 host + 19 client checks, no attachment error;
  ../output/network-checks/Release-impaired-a65102021a794754804b2730ac72c79b.
- Current script check: 109 and startup pass; Release export passes.

The combined public sailing profiles contain no cargo jobs; the nonempty prototype
payload and transaction checks above are separate existing local fixtures. These
do not establish public port loading/delivery, which belongs to Steps 47–54.
Automated cargo attachment is not acceptance of the user's failed manual heavy
pickup. No player-to-player transfers are added.

## Explicit limits and next work

Manual browser/OS trust usability, real internet joining/NAT, broader hardware,
long soaks and production operations remain unverified and tracked. No OS trust
was installed. Existing safe spawn rejection can require another boat to move;
Step 44 will provide deterministic port spawn/recovery anchors. No hidden shallows.

Next: Step 43, two small data-driven reusable ports with distinct IDs, original
placeholder names/shapes, spawn anchors, berth definitions, service capabilities
and open-water approaches. Keep port scenes separate from economy logic. Then
Step 44 clearance/recovery anchors. Stop/neutral usability remains due before 46,
reported heavy pickup repair before 50, and wake/foam polish at 99–100.

Fresh post-fix durability regression: 26 Release checks at
../output/handoff/173de595/durability-summary.json. Process death/lease expiry,
committed recovery, clean shutdown/reconnect, replacement/shutdown race and backend
outage all pass. Final foundation/durability Godot logs have no script errors.
