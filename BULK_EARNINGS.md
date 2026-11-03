# Step 69 — Bulk earnings

Task ID: `bulk-earnings`. D126. Builds on Step 68's capacity fixture.

`features/cargo/bulk_earnings.gd` extends the existing container offer authority.
It supports authoritative offer publication, acceptance, docked loading into the
real `CargoManifest`, partial/full discharge, and settlement receipts. Bulk and
container jobs share one registry and its existing one-active-job guard. Offers
never expire. The full-delivery hook delegates unchanged container jobs to the
existing implementation. No ship purchase, public RPC, save schema or protocol
changes are introduced. Existing playable ships still cannot carry bulk.

This is an **in-memory authority model**, exercised using the two-hold bulk fixture.
It is not connected to the public PostgreSQL wallet or the current container-only
voyage snapshot/UI. Step 70 owns bulk service presentation and durable recovery;
this step does not claim authenticated bulk play, restart safety or deployment.
The model returns a `reward_minor` delta for the enclosing wallet transaction, like
container offers. A duplicate discharge returns its original receipt and **zero**
new delta. Do not credit the receipt's historical reward again on replay.

## Quote and distance

Trusted content authors call `publish` with a stable offer ID, commodity, integer
gram quantity, one explicit hold ID, origin/destination IDs, canonical geographic
port addresses, commodity rates and port modifiers. These are authority inputs,
not client-supplied prices, coordinates or docking assertions. Port IDs/hold
compatibility are validated by the existing manifest at acceptance and loading.
Each offer represents one batch in one hold; Step 68's multi-hold model remains
available, but this step does not silently split one offer across holds.

Distance is the shortest great-circle separation of the authored port endpoints
on the existing 100,000 m radius world, rounded to the nearest metre once at
publication (half metres round upward). Freeze that integer, the rate, both
modifiers and the total in the published nonexpiring quote. Later world/config
changes do not alter it. Neither the ship position nor its odometer, time at sea,
waypoints, detours, navigation distance or ETA enter settlement. Same-port routes
and routes rounding to zero metres are rejected. No hidden-shallows rule changes.

For cumulative discharged grams G, recorded direct metres D, rate R in minor
credits per tonne per nautical mile, and origin/destination modifiers O and T in
basis points:

```
earned_minor(G) = floor(G * D * R * O * T / 185200000000000000)
```

One tonne = 1,000,000 g, one NM = 1,852 m, one credit = 100 minor credits,
and 10,000 basis points = 1.0. Quantities retain the existing 1,000,000,000 g
batch limit. Rates must be integer 1–1,000,000; each explicit port modifier must
be integer 0–20,000. Missing/invalid rates or modifiers fail closed. Zero is an
explicit zero-paying modifier and is shown in the quote. No fallback multiplier
or implicit fee is applied. Offers and receipts are bounded to 4,096 each, without
receipt eviction. Quotes over the 9,000,000,000,000 minor-credit limit fail closed.

Integer quotient/remainder multiplication prevents int64 product overflow without
floating money arithmetic or intermediate monetary rounding. The probe compares
257 independent Python-integer rational vectors, including overflow rejection.
The display converts only for formatting; settlement uses integer terms.

`quote_text` explicitly labels **gross earnings**, includes both port modifiers,
and says fuel, repairs and recovery are separate costs. The displayed total
includes every modifier used by this earnings formula. It is not a net-profit
promise. `receipt_text` shows this discharge, remaining tonnes, current/cumulative
payments, original quote, recorded distance, rate and both modifiers. These text
formatters are ready for Step 70's UI; no new player-facing bulk panel is claimed.

## Partial discharge, replay and example

Loading is all-or-nothing at the origin after acceptance and capacity validation.
Discharge requires the recorded owner, owned ship, destination and authoritative
docked state, and the exact remaining batch/provenance. A positive integer gram
amount up to the remainder is allowed. Prepare and validate the new manifest
before publishing any settlement; failed requests change neither cargo nor ledger.
Manifest callbacks cannot reenter settlement. A partially discharged job stays
loaded/active and retains its hold and all original terms. Final discharge removes
the batch and closes the job. No other captain receives money or cargo.

Payment for each partial is `earned_minor(new cumulative G) - previously paid`.
Sub-cent fractions therefore carry forward implicitly in the cumulative formula.
The final total is rounded **down once** to a minor credit; any final fraction is
unpaid. One hundred small discharges cannot earn more or less than one discharge
of the same total. A fully discharged job cannot pay again. Reused action IDs
with changed intent fail; exact replay returns the original receipt without a
second reward delta. Capacity failure is checked before manifest publication.

Worked example using a direct distance of exactly 1,852 m:

- Grain: 123,456,789 g = 123.456789 t.
- Rate: 100 minor credits/t/NM = 1.00 credit/t/NM.
- Origin modifier: 11,000 bp (1.10); destination: 9,000 bp (0.90).
- Exact gross: 123.456789 × 1 × 1.00 × 1.10 × 0.90 = 122.22222111 credits.
- Displayed quote and final receipt total: **122.22 credits**.
- First discharge of 50 t: **49.50 credits**; 73.456789 t remains.
- Final discharge: **72.72 credits**; zero remains; cumulative **122.22**.

The executable probe checks that example against actual manifest mutations and
receipts, compares direct travel with a million-metre detour, exercises configuration
changes/replays/101 fragments, all four commodities, invalid quantities, capacity,
wrong port/ship/owner, tampered cargo, shared container jobs and callback reentry.

```sh
"$GODOT" --headless --path . --script tools/bulk_earnings_probe.gd
```

Run using the pinned Godot 4.7.2 after editor import. PROGRESS.md records the Linux
sweep and remaining Windows/PostgreSQL/Keycloak/rendered acceptance gates.
