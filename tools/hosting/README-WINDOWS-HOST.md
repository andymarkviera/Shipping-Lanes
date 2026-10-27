# Shipping Lanes — Windows invited-player host preview

Same dedicated runtime for LAN and internet routes. This is a test hosting bundle,
not the finished public sign-up service. Two randomly generated test accounts are
provided. Google sign-in, self-registration, password-reset email, automatic account
linking, certificate renewal, and welcome email are NOT enabled. Welcome email is
explicitly deferred. Do not advertise this as production-ready public hosting.

## Transfer and first setup

Extract the entire ZIP to a local NTFS folder such as C:\ShippingLanesHost. Keep the
whole folder together. No Godot editor, Python, Java, Docker or PostgreSQL installation
is needed. Use Windows x64. Run as your normal hosting user (PostgreSQL initialization
must not run as Administrator); keep using the same Windows user for saved data.
Do not run in Program Files, a synced/cloud folder or a network share.

Read CHATGPT-SERVER-HANDOFF.md on the destination PC. Edit host-settings.json BEFORE
Setup. `host` is a stable hostname (e.g. your chosen DuckDNS name) or fixed IP, with
no https:// or port. `lan_ip` is the server PC's private IPv4 address. The ports are
TCP 8443 for browser sign-in/tickets and UDP 24560 for the game. Backends bind only
to 127.0.0.1. Choose unused ports; do not blindly kill other services.

In PowerShell, from the extracted folder:

```powershell
.\Host.ps1 -Action Check
.\Host.ps1 -Action Setup
.\Host.ps1 -Action Start
```

If script execution is blocked, use a process-scoped execution-policy allowance only
after reviewing the scripts. Do not weaken the machine-wide policy. Start returns
immediately; wait for HOST_READY in the newest Logs/*.log. Check its matching error
log if startup fails. The first setup extracts Keycloak and can take a minute.
Setup refuses to overwrite existing data. Failed setup must be investigated rather
than deleting a folder that may already contain player progress.

Generated usernames/passwords are in output/local-online/hosted/login-info.txt.
They are private; distribute each person's credentials individually. Never send the
server folder after setup to players. The generated Client/ folder is the shareable
client package: public configuration/certificate, game, and launcher only. Do not
include Client/PlayerData when redistributing a used client folder.

```powershell
# On a player PC, from the generated Client folder:
.\Launch-Client.ps1 -Connection LAN
# Or for the configured hostname / remote connection:
.\Launch-Client.ps1 -Connection Internet
```

In the game choose SERVERS, the configured server, SIGN IN & JOIN. Sign-in opens in
a browser. These launchers isolate player settings from the normal Port Test save.
LAN chooses the local game IP; Internet chooses the hostname. Both use the same
approved server ID, login issuer and account/save. This is a configured list, not
a public discovery service. Arbitrary unapproved Direct Connect is not implemented.

## Local IP and DuckDNS together

DuckDNS supplies DNS, not port forwarding or a tunnel. Use a DHCP reservation so the
server's local IP stays stable. Keep one stable login hostname: changing the issuer
later can change identity mappings. If using DuckDNS eventually, choose it before
Setup. Inside the house, configure local DNS to resolve that hostname to the server's
LAN IP, or use router NAT loopback if supported. A deliberate hosts-file entry on
test client PCs is another temporary option. Do not add entries without approval.
The LAN entry uses local IP for game traffic but login still uses the stable hostname.
No claim of cross-machine or external reachability until those are actually tested.

## Certificates and internet rollout

The preview generates a private self-signed certificate, valid for 90 days, covering
the chosen host plus loopback. The game explicitly pins it; it never disables TLS.
A normal browser will not automatically trust this private certificate. Establish
trust deliberately on test PCs after verifying the certificate through a trusted
channel. No automatic OS trust installation or warning bypass is provided.
A publicly trusted certificate and tested renewal/rotation plan are required before
opening this to the general public. The current launcher does not yet automate that.
Do not delete/recreate the setup to renew a certificate; preserve identities and data.

For invited remote testing, prefer a private VPN or explicit source-IP allowlists.
General-public forwarding remains a deployment gate pending certificate setup,
Google/account enrollment, provider production storage, reset-email controls if
email login is enabled, and security/abuse tests. Keycloak currently uses persistent
dev-file storage, suitable here for previews, not the chosen production database.
When the gate is complete, forward only the configured game UDP port and HTTPS TCP
port to this PC, with corresponding scoped Windows Firewall rules. NEVER forward
PostgreSQL, the internal authority port, Keycloak backend/admin or callback port.
The browser callback listens on EACH PLAYER PC's loopback; it is never a router rule.
CGNAT/double NAT may require an ISP public IP, a VPN or different hosting connectivity.

Current protections: certificate-pinned game transport, native OAuth PKCE and state,
short access-token lifetime, Keycloak temporary account lockout, front-door request
limits, bounded workers/body sizes/timeouts, and no externally routed admin or game
mutation endpoint. These do not prove resistance to internet-scale denial of service.
JWKS is pinned at server startup; provider key rotation currently requires a restart.

## Stop, saves, backups

```powershell
.\Host.ps1 -Action Stop
```

Wait for HOST_STOP_CONFIRMED. Server logs should contain PUBLIC_SERVER_DRAINED.
The server saves every 10 seconds and performs a final save/release on normal stop.
Forced power/process loss can lose the last uncommitted interval. Do not close/kill
services manually during saving. Stop before backing up the entire
output/local-online/hosted folder. Protect backups: they contain credentials, keys,
accounts and progress. Restore under the same Windows user or deliberately repair
ACLs; do not discard data to fix a permissions error. Do not move a running host.
Keep clients/server versions matched. Existing development/Port Test saves from the
build PC are not included. This is a separate realm with separate test progress.

## References for the deployment gate

Official Keycloak hostname, proxy and production guidance:
https://www.keycloak.org/server/hostname
https://www.keycloak.org/server/reverseproxy
https://www.keycloak.org/server/configuration-production

Network note: this preview binds IPv4. Publish/use an A record; do not publish an
AAAA record for it without implementing and testing IPv6 listeners. For same-PC
checks use 127.0.0.1 rather than localhost, which can resolve to IPv6 first.
