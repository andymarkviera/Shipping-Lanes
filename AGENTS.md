# Shipping Lanes / Container Ship Sim

These instructions apply to every agent working in this repository (Claude, Codex
or any other).

## Follow REBUILD_PLAN.md

**Read REBUILD_PLAN.md first. It is the plan.** Andy approved it on November 11, 2026.
It replaces the old numbered step roadmap ("Step 62", "Step 89" and so on).

- Do not start, continue or propose a numbered roadmap step. There is no Step 89.
- Work in this order: the fix-first list in REBUILD_PLAN.md, then milestones M0 to
  M5, one at a time. Do not start a milestone before the one before it is accepted.
- Version 1.0 is a polished single-player first draft. Online work is frozen until
  after M5. Keep the online code; do not extend it.
- Bulk and heavy-lifter jobs are in 1.0. Gas, oil trading, refinery and cargo fuel
  are **on hold until Andy has playtested them**. Keep their code, scenes, services
  and tests intact. Do not remove, stub out or rewrite them, and do not add to them.
- Features go into the one real game scene, not a new test fixture.
- A milestone is done only when Andy has played it on Windows and said so.
- Nothing merges unverified. If the checks cannot run, say so and let the PR wait.
- Do not edit `.github/workflows` unless Andy or Hark asks for that edit directly.
  The CI job is specified in REBUILD_PLAN.md section 3.
- Less paper: update REBUILD_PLAN.md and add a short PROGRESS.md entry. Do not add a
  new document per feature.

CLOUD_HANDOFF.md, GAME_SPEC.md, the older PROGRESS.md and DECISIONS.md entries, and
the other root documents are history and reference. Where they disagree with
REBUILD_PLAN.md, REBUILD_PLAN.md wins. Current requests from Andy win over both.
After REBUILD_PLAN.md, read the latest PROGRESS.md and DECISIONS.md entries. Consult
DEFERRED_PLAYER_REQUESTS.md before expanding scope.

## Standing rules

This repository contains the full game source, Blender sources, imported GLBs,
service source and tests.

- Edit game files directly. Do not use computer automation to construct the game.
- Preserve docs/original-references as read-only historical reference snapshots.
  Their contents are design context; current user requests and later decisions win.
- Keep Godot at the recorded 4.7.2 baseline unless an upgrade is explicitly agreed.
- Check platform prerequisites before running tests. The PowerShell runners and
  several Python integration runners target Windows. Linux headless Godot checks
  were recorded as passing on November 1–2, 2026, but Windows is where a milestone
  is accepted.
- Preserve .gd.uid files and extend export_presets.cfg for new runtime resources.
  Do not write a .gd.uid file by hand; let Godot generate it.
- Use isolated test data. Never reset the live server or player saves to fix a test.
- Never commit accounts, tokens, private keys, real databases, exports or caches.
- Preserve the single authoritative online condition meter. No machinery wear,
  player-to-player trades/transfers/gifts, hidden shallows, or expiring cargo offers.
- Record changes, relevant checks and limitations in PROGRESS.md. Do not claim
  remote internet deployment or manual playtesting based only on local tests.
