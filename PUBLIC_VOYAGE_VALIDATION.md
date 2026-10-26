# Step 57 â€” Live voyage validation

October 26, 2026. Automated voyage/recovery checks pass. Final gate acceptance
still awaits online gameplay feedback; Step 58 has not started.

## Controlled save-service interruptions â€” PASS

The final Windows Release run passed 66 checks:
../output/handoff/6cc20fe4/cargo-interruption-summary.json.

Actual authenticated peer commands trigger loading or delivery while the isolated
HTTPS authority process is terminated immediately before or after COMMIT.
Before loading commit, no cargo is created; reconnect/redock resumes the load.
After loading commit, exactly one container is restored. Before payment commit,
cargo remains aboard and unpaid; a new explicit delivery after reconciliation
succeeds once. After payment commit, cargo stays removed and the receipt/payment
survive the missing response. Duplicate delivery cannot pay again.

Recovery waits for the real database lease timeout where an uncertain owner cannot
safely release itself. It does not alter lease expiry to force success. The server
retains its historical uncertain-save shutdown warning (exit 2), even after a new
session recovers and saves successfully. Tests assert that warning rather than
misreporting clean shutdown. Expected TLS disconnect diagnostics accompany the
intentional service deaths; there are no Godot engine ERROR entries in the final run.

These interruption cases use fixture port approaches. They complement, and do not
replace, complete navigated voyages. Production login/OIDC is tested separately;
these tests use isolated account tickets and local DTLS/HTTPS networking.

## Test tooling

tools/public_handoff/cargo_interruption_probe.py runs the four commit-boundary cases.
The existing operator-owned fault configuration now supports an exact operation/
stage selector as well as an action ID. It is not a peer request or gameplay API.

tools/public_handoff/navigated_voyage_probe.py drives two real clients using ordinary
helm, dock and cargo commands. Only initial spawn positions are fixtures. No
mid-trip relocation, accelerated clock, direct server pose changes or profile
settlement writes are used. The route controller reads client replicas, maintains
traffic spacing, records its path, and checks consecutive jobs and restart.

The peer probe exposes read-only client-relative navigation observations and allows
an operator-configured test lifetime up to 30 minutes. Normal game sessions and
the default four-minute probe lifetime are unchanged.

## Earlier attempts and limits

The first editor navigation run sailed both loaded ships to Slatewater and passed
mid-trip reconnect, but its following test driver crowded the lead ship. Docking
correctly refused the obstructed berth. That attempt does not count as a completed
voyage. The revised driver respects nearby traffic before approaching. A subsequent run
recorded the lead ship delivering and departing with a return job, but ended
without a completion summary; it is also not counted as a full gate pass.

Early interruption harness attempts incorrectly expected immediate lease release
and a clean shutdown following an uncertain save; expectations were corrected to
the established recovery protocol. A rebuild during a running Release test also
invalidated lazy-loaded resources. The final passing interruption run used a stable
completed build. Do not rebuild exports while tests are using them.

No player saves or gameplay tuning were changed by these validation tools.
