# Wider alongside docking — October 25, 2026

User confirms the sailing-save freeze is fixed and heavy-loader pickup now works
and is enjoyable. New request: enlarge the docking area, allow docking right against
the quay, and remember mooring-rope animations for later.

Both authored berth envelopes widen from 36 to 64 metres. Brindle length grows from
120 to 180 metres; Slatewater from 170 to 230. Whole-hull containment still applies,
so these are envelope dimensions rather than a ship-centre radius. Speed/heading,
service compatibility, ownership and single-berth reservation rules are unchanged.
No water markings were added.

The one-metre padded query remains for other boats and cargo. Shore clearance now
uses the actual hull envelope with a one-centimetre inset per face to distinguish
surface contact from penetration. A stopped boat may therefore moor alongside the
quay without leaving the former empty buffer. Actual hull/shore physics are unchanged;
penetrating dock structures remains ineligible. Docking does not teleport the ship.

Verification: editor and exported Release port/cargo suites pass 261 checks.
Added contact and penetration cases for both hulls at both ports, including translated/
rotated ports, a larger side/longitudinal approach, and actual dock/undock beside the
quay. Test transforms wait for physics synchronization; the inserted-obstacle fixture
holds its ship still so depenetration cannot remove the obstruction before evaluation.
Existing wrong-service, moving-ship, other-hull/cargo obstruction and reservation checks
remain. Final Release evidence: ../output/ports/133ed93b.
The 48-case voyage suite plus loading/delivery crash recovery passes in Release:
../output/voyage/44e357ba. Export rebuilt. No save migration or user save edits.

Later port presentation polish: animate mooring ropes tying up after docking is
confirmed and releasing on undock. Rope visuals must follow authoritative docking
state, handle cancellation/reconnect cleanly, and not own the dock reservation or
restrict controls independently. Cargo-loading animation is also still queued.
Step 54 remains the next roadmap task. This docking change awaits user play-test.

Recovery tag: alongside-docking. Verified source backup:
../output/checkpoints/alongside-docking-2026-10-25.zip.
Preexisting project.godot customization remains untouched and outside this checkpoint.
