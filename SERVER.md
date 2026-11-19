# Shipping Lanes Server

Install on a Windows x64 server PC: download
`Shipping-Lanes-Server-Windows-x64.zip` from the latest full release in
[Shipping-Lanes-Server-Releases](https://github.com/andymarkviera/Shipping-Lanes-Server-Releases/releases/latest).
Extract the whole ZIP into a permanent, writable folder, outside OneDrive and
Program Files. Open `LaunchServer.cmd`, click **Start**, and wait for
**Running (UDP listening)**. Godot 4.7.2 and the launcher are included; no editor,
Python or GitHub token is needed. Closing the launcher leaves the server running;
use **Stop** and wait for the final checkpoint before shutting down the PC.

With the server stopped, edit `server-config.json` beside `LaunchServer.cmd` if
needed. The default gameplay port is **UDP 24565**; `port` is configurable and
`bind` normally stays at its supplied all-interfaces value. Allow inbound UDP on
that port in Windows Defender Firewall. Gameplay needs no TCP port.

For internet play, Hark sets up the playit.gg account and a **generic UDP tunnel**
with Andy's approval. Run the playit agent as a Windows service on this PC and
point its tunnel at this PC's local server port. No router forwarding is needed.
Put the tunnel's public address in the local config's `public_address` for the
launcher display. Hark configures the tunnel host and public port in the game
feed's `server.json`; the display field alone does not change where Play connects.
Never put a home IP, real tunnel address, token or player data in source control.
**Tunnel offline** means the launcher cannot see the playit process; a listening
server or running agent alone does not prove friends can connect.

To update, tell players to disconnect, open the Server Launcher and click
**Check for updates**, then **Update available**. It downloads and verifies the
ZIP, gracefully stops/checkpoints, verifies a saves backup, swaps version folders
and starts again. Saves migrate before listening. Keep clients and server on the
same release tag. Keep this installation folder; do not extract updates over it
or replace `server-config.json`. If an update fails, keep the data and inspect
the launcher message and `logs/`; do not reset saves or downgrade migrated data.

**Open saves folder** opens `saves/` beside `LaunchServer.cmd`, outside `versions/`.
`saves/world.json` holds all multiplayer progress. Automatic checkpoints run every
minute, on disconnect and on graceful shutdown. The server keeps five checkpoint/
migration copies in `saves/backups/<old_schema>-<date>/`; the launcher keeps five
verified update copies in `backups/<old_version>-<date>/saves/`. With the server
stopped, copy `saves/` and `server-config.json` to another disk for your own backup.
After a crash, inspect logs and confirm no server process remains before manually
removing a stale `saves.lock` folder. Never delete `saves/` to clear that guard.
Hard termination can lose progress since the last completed checkpoint.
