# State ownership boundaries — Step 13

Completed October 19, 2026. SessionAuthority is a small in-memory owner of the
fixture player, ship, wallet and inventory. It is not an autoload/global manager;
each TestSession has one authority. Settings, UI navigation, input and definitions
keep their existing separate owners.

The request path is ApplicationMenu signal -> Main navigation adapter ->
TestSession.request_test_load -> SessionAuthority.request_test_load. UI supplies
only the revision it last displayed. The local adapter supplies the known player
and controlled ship; UI cannot choose a price, resulting balance or cargo amount.
A future authenticated network adapter must derive actor identity from the
connection/lease and call the same authority method, never trust a client actor ID.

The only action is a disposable debug load: fixture wallet 200 credits, price
100 credits, one test container per approval. These values are not approved
starting funds/prices/capacity or a real loading operation. Ship fuel is integer
milliliters, following Step 11; the older Step 10 isolated ShipState resource
example remains a separate non-authoritative data test.

Requests check actor, ship, owner, revision, funds and numeric limits before any
mutation. The complete next state is prepared and assigned once without awaits
or mid-update callbacks. Responses carry ok/code/message and a deep-copied view.
Rejected requests leave all state unchanged. Views/results cannot mutate the
stored wallet or nested inventory. Underscore-private fields are a code ownership
convention, not protection from malicious scripts running inside the same process.

Local and hosted-policy fixtures use exactly the same action method; hosted here
describes pause policy, not an implemented network connection. Repeating a stale
revision is rejected, but this is not durable operation-ID idempotency. The
versioned records, SQLite transactions, leases and receipt protocol are not yet
wired into this fixture. Do not describe in-memory publication as crash durability
or a completed multiplayer security boundary.

Return to title retains the authority object in the trusted in-memory Continue
handle while removing the session Node. Continue reuses that authority; it does
not deserialize/overwrite it from UI data. New Session discards it and creates
fresh fixture state. Closing the app loses it. Settings remain independent.
Future save/network imports require the validated and authorized restore path;
restore_continuation is never an untrusted-input API.

## Verification

21 session checks pass in editor and Windows Release: defensive copies, invalid
actors/ships/revisions, atomic approval, stale duplicate rejection, funds rejection
without partial changes, identical local/hosted action path, real UI button signal
and displayed response, in-memory Continue, inactive-screen dispatch gating, and
New Session reset. FlowCheck's repeated lifecycle/pause/focus tests still pass.
Native startup and the rendered test screen were inspected at 1152 x 648.

```powershell
./tools/Godot.ps1 -Mode SessionCheck
./tools/Godot.ps1 -Mode RunExport -Configuration Release -Headless -SessionProbe
```

Optional manual check: F5 -> Play -> Load test container. First two requests
succeed, third reports insufficient funds. Return to menu -> Continue preserves
state; New test session resets it. This is automated too; no user test is required.
Next task: simulation-lifecycle-and-clocks, including explicit timer ownership.
