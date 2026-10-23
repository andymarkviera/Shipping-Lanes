# Public browser sign-in and server selection

The Servers button opens public_entry.tscn. Without an installed public-services
configuration it shows that online services are not configured and offers a return
to the main menu. It does not create a fake server or open a browser automatically.
Play keeps the existing local development save behavior when no configuration is
installed; with a configuration it opens the same server-selection page. Local
handling, heavy-lifter and private multiplayer tests remain available.

The initial list is an operator-provided allowlist, not live discovery or an
online-player count. Sign In & Join opens the configured HTTPS authorization page
in the system browser. The game never collects a password. Email versus username,
external sign-in providers, registration and recovery are provider configuration
choices, not implemented password forms in the game.

## Protocol and identity boundary

The native Godot client generates a fresh 256-bit state and PKCE S256 verifier,
listens on the configured IPv4 loopback port only, and accepts one bounded callback
with matching state before its three-minute deadline. Duplicate query keys,
wrong state, wrong path and oversized/slow callback requests fail closed. A valid
code closes the listener before a bounded HTTPS token exchange. HTTPS endpoints
are operator-pinned beneath the configured issuer; redirects are disabled for
credential-bearing requests. Cancellation closes sockets/requests and invalidates
callbacks from the old attempt. No client secret is used.

The client ignores ID-token claims and discards refresh tokens. It uses the access
token only to request a connection ticket from the separately trusted HTTPS
service after verifying the selected game server's DTLS identity. The service
validates issuer, audience, signature and account enrollment. The game does not
assert an account identity from an unvalidated token. Access tokens are cleared
after ticket submission or any cancellation/failure, and nothing is persisted
for automatic sign-in. An account not enrolled for the build gets an explicit
message; sign-in never creates funded progress.

Admission hides the server-selection overlay, releases menu focus, and enters the
existing public boat scene. Disconnect returns to selection. Generic server
admission failures currently cover unavailable servers, occupied spawn positions,
and conflicting account ownership; finer server reason messages remain future work.
The actual browser window launch is OS.shell_open; headless tests substitute a
fixture browser only for navigating the provider, while Godot owns callback,
code exchange, token handling, ticket request and boat connection.

## Operator setup (not performed by this checkpoint)

Use services/public_authority/public-services.example.json as a placeholder guide,
not a working configuration. An operator must supply an HTTPS identity provider,
public client registration with S256 required and the exact callback URI
http://127.0.0.1:43821/callback (or its configured port), an approved authority
service and enrolled accounts, and approved game server certificates/fingerprints.
The native client must receive the shipping-service access-token audience.

Install the resulting PUBLIC configuration as user://public_services.json in the
Godot user-data directory. It contains public client/server addresses and trusted
public certificates only. Never put database credentials, server signing keys,
scoped server credentials, tokens or passwords there. Empty CA paths select system
trust; test/operator CA paths are optional. The sample uses .invalid hosts and
cannot connect until replaced. A busy callback port produces a retry message.

No persistent provider/service deployment, public enrollment, automatic refresh,
OS credential storage, live registry discovery or hosting/network changes are
included. The full public integration/capacity gate before Step 42 remains open.

Implementation references: Godot TCPServer and HTTPRequest official documentation:
https://docs.godotengine.org/en/stable/classes/class_tcpserver.html
https://docs.godotengine.org/en/stable/classes/class_httprequest.html

## Development validation

Run tools/public_handoff/login_probe.py --runtime editor or --runtime release
with the existing Python runtime (export Release first; do not rebuild it during
a test). It launches disposable services and navigates the real provider with a
test HTTP browser. The fixture password is never sent to Godot. Native callbacks
are tested for state/duplicate rejection, cancel/retry/timeout; real login tests
cover unenrolled rejection, ticket admission, helm control and departure release.
Only non-secret status diagnostics are retained; callback URLs are removed from
test reply artifacts during cleanup. The production browser-launch branch still
needs interactive visual acceptance. A localhost connection timeout in the first
native fixture runs was resolved with explicit IPv4 HTTPS endpoints matching the
services' 127.0.0.1 listeners, without changing certificate verification.
