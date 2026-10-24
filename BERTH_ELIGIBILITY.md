# Step 45 — Berth eligibility

Port Test now reports live berth readiness, including why an approach is rejected.
The reusable read-only evaluator checks requested service, ship/berth cargo support,
hull size, whole-hull containment, total speed (including reverse and sideways drift),
heading and physical clearance against hulls, shore and cargo. It excludes the
requesting hull from its own clearance query. It does not dock or move the ship.

BerthDefinition stores the thresholds: 0.15 m/s maximum speed, 10 degrees heading
error and 1 metre clearance on every side. The hull plus margin must fit entirely
inside the authored berth envelope. Numerical tolerances of 0.000001 m/s and
0.0001 degrees prevent float rounding from rejecting exact limits. Catalog
publication rejects malformed berth dimensions, pose and thresholds.

The preview currently requests container transfer for its starter boat. The same
rule accepts the heavy lifter's industrial transfer at Slatewater Works and rejects
it at Brindle Quay. Empty cargo selection supports non-cargo service checks.
This is readiness feedback, not an authorization or transaction. Step 46 must
recheck readiness on the authority when docking is requested, handle reservations
and docking state, and clear propulsion safely. Public-world port integration,
loaded-cargo clearance extensions and operation reservations remain later work.
No shallow-water restrictions, economy mutations or saved-position changes.

Validation: 114-script/startup check, CatalogCheck, FlowCheck and Release export
passed. Editor port suite passed 100 checks (output/ports/c87f903c). Final rendered
Release suite passed 105 (output/ports/97a7b200), including live preview readiness
and screenshot capture. Both ports were tested in original and translated/rotated
positions. Tests cover valid approaches, inclusive speed, reverse/lateral speed,
heading, partial containment, cargo/service mismatch, oversized hulls, invalid data,
other boats, self-exclusion and cargo blockers. The Brindle screenshot was inspected:
the opaque panel and readiness message fit without clipping.

Next: stop/neutral usability review before Step 46 docking. Heavy-loader pickup
repair remains before Step 50, and foam/wake polish remains scheduled later.
