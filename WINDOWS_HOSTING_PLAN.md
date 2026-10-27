# Windows hosting and sign-in — requested follow-up

Andy confirmed a Windows server and wants to select it from the in-game server list,
join over LAN by local IP, and eventually allow internet players. Prepare a portable
Windows dedicated runtime together with the required account and canonical-save
services; the current development launcher uses machine-specific paths and is not
yet a distributable hosting package. Do not imply the Godot executable alone provides
authentication and saves. Provide Direct Connect for LAN testing as well as listing.

Google sign-in is the preferred proposed starting point, with email/password optional.
Public-domain, Google OAuth registration/redirects, TLS and sender configuration need
operator-specific values before activation. Link identities explicitly to one game
account; do not automatically merge accounts based solely on matching email strings.

Before public access: verify rate limits on authentication, registration and password
reset; non-enumerating responses; verified email where applicable; short-lived,
single-use reset tokens; secure sessions, expiry/revocation/logout; HTTPS; private
DB ports; firewall/router configuration; and abuse/error-path tests. Google handles
Google passwords/resets, but game endpoints and sessions still need protection.
No claim these public deployment controls are already complete. LAN first, internet
second; establish public reachability/CGNAT and domain details before public setup.

Welcome email explicitly deferred at Andy's latest request. Do not configure or send
welcome messages now. If added later, send once after successful account creation,
including federated Google accounts, using an approved sender/service.

No public ports, router settings, Google project or external email service were changed
by this planning record. ShippingLanes remains the existing local development setup.
