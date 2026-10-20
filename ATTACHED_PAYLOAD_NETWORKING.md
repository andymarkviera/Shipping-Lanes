# Attached-payload networking feasibility — Step 31

Local Multiplayer Test now includes **Host heavy locally**. In the other game
window choose Join locally. Each player receives the Blender heavy carrier and
its staged industrial load. Stop and order neutral, then Lower, Align (test),
Secure and Raise. Release requires the lowered deck and a stopped boat.
The ordinary Host locally option still uses starter container ships.

## Host authority and state ordering

Protocol 3 supports the two explicitly allowed ship definitions. CargoReplication
accepts only the current owner's commands for its heavy carrier. RPC sender
identity, session epoch, entity ID, monotonic command sequence and allowed action
are checked before calling the original stopped/alignment/clearance gates.
Host-local actions use the same validator. Replayed sequences cannot execute
again, including sequences for previously rejected operations.

Cargo commands use reliable channel 0. The development delay shim preserves
their submission order, including back-to-back Align/Secure, and does not
artificially drop reliable commands. Movement snapshots keep their documented
unreliable-ordered channel and loss profile.

Each ship snapshot carries its complete cargo state: stable session payload ID,
accepted-action version, attached flag, deck height/target, released-body world
transform and status text. IDs derive from the owning ship entity. Ship and
cargo state are accepted together, with epoch/roster/sequence and cargo-field
validation. A later complete snapshot repairs a dropped transition; clients
do not need an earlier attach event to reconstruct a load.

Client attachment/release is applied on the same 150 ms buffered timeline as
ship motion. Deck height interpolates while attachment ownership is unchanged;
ownership switches at the corresponding sample boundary. Attached visuals
have an identity local transform under the ship's cargo anchor. Released
visuals belong to the floating body's replicated world transform. Reparenting
reuses the existing visual, so it does not duplicate cargo meshes.

Only the host runs collision. Securing disables the floating collider and
enables the compound ship payload collider; releasing reverses ownership.
Client floating/ship collision layers remain disabled, and the carried shape
is never enabled by presentation. No dynamic body stacking or walking/passenger
controller is introduced.

## Reconnect scope

A reconnecting observer reconstructs the host's existing ship and attached
payload with the same IDs and correct local transform, including while turning.
As in Step 29, the disconnected guest's temporary ship/load are removed and
the returning guest gets a new ship. This is not persistent owned-cargo recovery;
authenticated guest identity and durable saves remain later work.

## Evidence

Two independent processes pass 15 host and 17 client assertions per profile,
in both editor and Windows Release. Profiles are normal loopback and the Step 30
shim: 100 ms each way, deterministic +/-20 ms jitter, every tenth movement
message dropped. Cargo commands are delayed but remain ordered/reliable.

Checks cover loaded late join, actual loaded turns, client-owned loading,
foreign/stale/invalid command rejection, duplicate sequence rejection, rapid
Align/Secure ordering, reconnect, release/reattachment and collision ownership.
The host's loaded ship physically sweeps into a high rail and stops; a query
with its cargo collider disabled clears the same rail. This verifies carried
collision while network presentation continues under the selected profile.

Release results: normal sampled 2,046 host / 1,871 client attached frames;
impaired sampled 2,175 / 1,946. Maximum measured cargo-anchor positional error
was 0.0 m in both profiles (acceptance tolerance 0.001 m). Release preserves
the authoritative world transform; the client matches it after moving the
ship independently. These are prototype measurements, not a universal network
quality or capacity guarantee. A native client view of the loaded turn and
the compact cargo controls was inspected.

Run `tools/Godot.ps1 -Mode CargoNetworkCheck` for both editor profiles. Exported
checks use `tools/CheckNetwork.ps1 -Runtime Release -Cargo`, optionally with
`-Profile impaired`. Localhost networking must be permitted by the environment.
Full regression suite now has 23 stages / 71 scripts.
