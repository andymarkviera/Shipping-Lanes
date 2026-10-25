# Sailing save freeze — October 25, 2026

User play-test: cargo loaded successfully, but sailing triggered a save error and
froze the helm. Reopening restored position, then driving caused the same failure.
This supersedes the earlier blanket note that no play-test feedback had arrived;
it is partial feedback, not acceptance of all Step 51–53 behavior.

Reproduced with a read-only filesystem copy of the user's revision-218 voyage.
The original save was not modified. During simulated loaded steering the unmodified
handling code failed at tick 600 (10 seconds at 60 Hz). Its basis determinant had
drifted to 1.00002646446228. Normalizing only the copied pose made the same checkpoint
valid, isolating the cause from cargo, rewards and SQLite. Evidence:
../output/sailing-save/repro.log. The validator's rejection triggered the intended
save-error pause; this was not a throttle or loading failure.

Fix: orthonormalize each proposed yaw rotation before the hull collision query and
applying the transform. Repeated single-precision rotations no longer accumulate
scale error in the physical hull. Keep all save/berth validation and failure safeguards;
do not discard cargo, reset saves or permit malformed transforms. Existing accepted
checkpoints continue to load without migration. No handling tuning or visuals changed.

Added tools/check_sailing_save.py and a loaded steering/checkpoint regression scene.
It simulates five minutes of turning with 300 durable checkpoints, restores that
checkpoint, then steers the opposite way for 30 seconds and another 30 saves. Cargo
must remain unchanged. It can optionally consume an extracted checkpoint file; that
file and the copied player database stay outside the repository/source backup.

Verification: 130 scripts/import/startup; 134 handling cases; 39 Release heavy cases.
The player's copied save passes in editor (output/sailing-save/b6472b49) and Release
(output/sailing-save/6873e9f3). A new loaded voyage passes Release too
(output/sailing-save/36782328). Both Release scenarios complete 330 checkpoints.
The existing 48-case voyage suite and real loading/delivery crash-recovery sequences
also pass in Release (output/voyage/0ae67cb9). The exported game has been rebuilt.
User confirmation of this fix is still pending.

User also requested a cargo-loading animation for later. Record it under future
port/cargo presentation polish, after stable loading/delivery/lifecycle behavior.
Animation must follow authority progress and cancellation, never grant cargo or own
the timer. Current placeholder containers still appear at committed completion.
Step 54 remains the next roadmap task; this was a prerequisite bug fix.

Recovery tag: sailing-save-fix. Verified source backup:
../output/checkpoints/sailing-save-fix-2026-10-25.zip.
Preexisting project.godot customization remains untouched and outside the checkpoint.
