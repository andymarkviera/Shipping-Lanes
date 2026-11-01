# Shipping Lanes / Container Ship Sim

Read CLOUD_HANDOFF.md first, then the latest entries of PROGRESS.md and DECISIONS.md.
Consult DEFERRED_PLAYER_REQUESTS.md before expanding scope. This repository contains
the full game source, Blender sources, imported GLBs, service source and tests.

- Edit game files directly. Do not use computer automation to construct the game.
- Preserve docs/original-references as read-only historical reference snapshots.
  Their contents are design context; current user requests and later decisions win.
- Keep Godot at the recorded 4.7.2 baseline unless an upgrade is explicitly agreed.
- Check platform prerequisites before running tests. Current native SQLite binaries
  and integration runners target Windows. Cloud/Linux compatibility is not proven.
- Preserve .gd.uid files and extend export_presets.cfg for new runtime resources.
- Use isolated test data. Never reset the live server or player saves to fix a test.
- Never commit accounts, tokens, private keys, real databases, exports or caches.
- Preserve the single authoritative online condition meter. No machinery wear,
  player-to-player trades/transfers/gifts, hidden shallows, or expiring cargo offers.
- Record changes, relevant checks and limitations in PROGRESS.md. Do not claim
  remote internet deployment or manual playtesting based only on local tests.
