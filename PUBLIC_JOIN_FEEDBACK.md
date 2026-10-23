# Refused admission and retry feedback

The public server now sends a small allowlisted refusal code over reliable DTLS
RPC before closing a rejected connection. Occupied saved positions explain that
another boat is too close, the saved position is unchanged, and the player should
wait for clearance before signing in again. Other codes cover game version,
fresh sign-in, admission busy, account busy/transfer and save-service failure.
Unexpected backend details are not forwarded to the player.

Rejected peers have no live hull and cannot resubmit on the rejected challenge.
They remain in a busy pending entry for at most three seconds so an immediate
server disconnect does not discard the reliable message. The ordinary client
closes after receiving it; the existing server timeout removes noncooperating
peers. Disconnect cleanup preserves the reason. New browser sign-in clears it
before becoming busy; new transport connection also resets it. Deferred close
checks the challenge so old work cannot close a new attempt.

The existing Sign In & Join button becomes available again on refusal. Retrying
uses fresh browser state, token exchange, connection challenge and one-use ticket.
There is no automatic retry loop or reuse of credentials. Missing transport or
certificate verification still falls back to a reachable-server message, without
asserting that a saved position is occupied when the game does not know that.

Game admission protocol is 9; use matching exported client/server builds. HTTPS
service ticket protocol stays 7 and snapshot codec stays version 2. An explicit
wrong admission version is tested with the current RPC schema; very old builds
with incompatible Godot RPC tables may fail earlier with a generic connection
message. Delivery over a prolonged outage is not guaranteed by the three-second
window. No OS trust changes, server deployment or spawn teleporting were added.

## Verification

The real native login integration now creates a stationary blocking boat, signs
in a second enrolled account through the actual entry screen, checks the retained
message/overlay/cleared token, compares the entire canonical profile plus revision,
and verifies a released lease. It then removes the blocker and signs in again to
sail through the normal dedicated entry. It caught and fixed a stale-reason retry
bug during this pass. The fixture uses a real local provider with an HTTP test
browser, not a human-operated browser window.

The peer regression additionally checks wrong protocol, invalid ticket, clearing
an old refusal on reconnect and receiving the occupied-spawn reason. Remaining
foundation work is listed in FOUNDATION_ACCEPTANCE.md.

Final results: 23 native-login integration checks plus 16 provider checks in each
runtime, editor ../output/handoff/43c95f14/login-summary.json and Release
../output/handoff/6535806f/login-summary.json. Editor peer regression passes 60
checks at ../output/handoff/1ed3c65d/peer-summary.json. Script check (109), startup,
FlowCheck and Release export pass. Final logs contain no script/parse errors.
Initial failed retry evidence c94d9498 is retained, superseded by the passing runs.
