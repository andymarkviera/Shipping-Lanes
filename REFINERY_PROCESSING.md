# Refinery processing — Step 77

Step 78 adds a separate public authority and new private stock adapter; see
[Shared refinery stock](SHARED_REFINERY_STOCK.md). This document describes the
unchanged Step 77 private UI/save fixture.

Task ID: `refinery-processing`. One private refinery at Slatewater Works, built on
Step 76's oil fixture and SQLite account/lot transaction. Shared public stock,
concurrent withdrawal/pricing and fuel cargo loading/transport/sale remain Steps
78–79. No public endpoint or propulsion-fuel conversion is enabled.

## Run

Use exact Godot 4.7.2 and Python 3. Create a new isolated fixture explicitly:

```sh
python3 tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /path/to/new-refinery.sqlite --create --refinery
# Reopen the same file without --create; never reset a save to fix a failure.
python3 tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /path/to/new-refinery.sqlite --refinery
```

Buy crude through the existing quote/review flow, dock at Slatewater, refresh the
refinery's current lot, select positive integer millibarrels, and submit. The
panel displays yield, input/output bounds, processing rate, authoritative progress,
exact aboard crude, output stock, carried fraction and allocated crude cost.
1000 millibarrels equal one barrel; 1 millibarrel is the minimum input. Decimal
or sub-millibarrel API quantities are rejected, never rounded up. Trading still
uses whole barrels; fractional residue remains available for refining.

`--refinery-config /path/to/config.json` accepts Config fields only with
`--create --refinery`. Defaults: numerator 7, denominator 10, input capacity
200000, output capacity 1000000, rate 1000 millibarrels/second, and 10000 retained
submissions. Positive integer bounded values only, with numerator <= denominator
<= 10000. Defaults are provisional fixture tuning, not a pricing decision.
Configuration is stored once; reopening cannot override it. Existing Step 76
files lack the refinery table and fail closed when opened in refinery mode.
Opening a refinery-capable file without the flag runs oil only and pauses refining.
No automatic historical save conversion or database reset is provided.

## Conservation and save contract

For each completed submission with input `I`, prior fractional remainder `R`, and
saved yield `N/D`, output/remainder is `divmod(I*N + R, D)`. Thus cumulative output
is exactly `floor(total_completed_input*N/D)` and `0 <= R < D`. The remainder is
an integer numerator of a millibarrel, retained per account/facility across jobs,
new crude lots and restarts. Splitting inputs cannot increase output. No floats,
per-request rounding up, offline clock calculation or output from visual progress.

There is one processing slot, no queue. Input cannot exceed its configured bound.
Current stock plus reserved output cannot exceed the output bound. Submission
atomically debits the exact owned lot, allocates its acquisition cost, increments
profile revision, saves the processing job and records the original action receipt.
A failed/busy/full request consumes nothing. Unknown replies retain the identical
action and intent for retry; receipt lookup precedes revision/docking checks.
Changed reuse conflicts. The oil and refinery actions share the existing per-account
action-ID namespace, but each panel displays only its own receipt type.

The separate host clock advances saved elapsed milliseconds, capped at one second
per tick. Duration is `ceil(input_millibarrels*1000/rate)` milliseconds. Stock and
remainder credit together exactly once at completion. Late ticks conservatively
discard excess time; host downtime never processes crude. Reads only observe.
Restart resumes last committed progress; before/after-COMMIT crashes roll back or
retain the whole transition. Any clock failure fences the fixture until reopen.
The bounded job ledger reconstructs and validates stock, fractions, progress,
capacity and identity uniqueness on reads/writes. Exhaustion rejects new submissions;
no deduplication eviction creates a replay window. This small fixture validates
its retained history on each tick; it is not a production throughput design.

Original lot cost is paid once at purchase. Cumulative disposed cost is
`floor(original_cost * (sold_barrels*1000 + refined_millibarrels) /
(original_barrels*1000))`; each disposal allocates only the difference from prior
sold/refined cost. Remaining cost is the complement. Refining pays no wallet reward
and incurs no second acquisition debit. The completed job retains its input cost;
no cargo-fuel sale or profit is claimed before Step 79.

## Lifecycle and boundaries

| Event | Rule |
| --- | --- |
| Submit | Trusted local scene attests docking at Slatewater; owned lot/revision and capacity checked transactionally. |
| Repeated requests | Exact receipt replay; changed action payload rejected; new IDs still require available owned crude. |
| Close panel / focus / sailing away | Host processing continues; UI cannot advance, cancel or refund it. |
| Cancel / berth loss | No cancellation after custody transfer. Berth loss blocks new submission but permits receipt replay. |
| Crash / quit / restart | Last committed job/progress/stock/remainder retained; no offline time or automatic resubmission. |
| Save unavailable / unknown commit | Fail closed; uncertain submission retry retains identity. Clock failure requires reopen. |
| Sinking / switching / resale | Already submitted material is held by the refinery, no longer aboard. Existing oil fixture has no full sinking/fleet/handoff integration; no new such integration is claimed. |
| Content/configuration change | Saved configuration wins; unsupported/corrupt or missing state preserved and rejected. No migration. |
| Other accounts / private hosts | Stock/remainders scoped to account in one private file; other files isolated. No gifts/transfers. |
| Public server/scenery transition | Not wired for this private fixture; stable refinery identity is groundwork for Step 78. |
| Storage/ledger full | Reject atomically, retaining cargo and all replay identities. No expiry or hidden eviction. |

The ephemeral loopback bearer and local scene trust boundary are inherited from
Step 76. The fixture bridge must not be exposed as a player-facing public service.
No live saves, server deployment, game/ticket protocol change, playable oil hull,
new wear meter, transfers, hidden shallows or deferred features are introduced.

## Checks

```sh
python3 -m unittest services.refinery.test_processing services.oil_market.test_model \
  services.oil_market.test_settlement services.oil_market.test_interface -v
python3 tools/oil_market_fixture.py --godot /path/to/godot-4.7.2 \
  --db /path/to/new-probe.sqlite --create --refinery --refinery-probe
```

Use isolated XDG/APPDATA locations. The Python suite exercises actual SQLite
rollback, contention, reopen and owned subprocess death before/after submission
and completion commits. The actual Godot scene checks HTTP/private SQLite,
docking, fractions, hidden-panel completion, lost-reply retry and visual progress
independence. See PROGRESS.md for results and unrun platform/public/visual gates.
