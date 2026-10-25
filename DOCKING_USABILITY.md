# Docking usability and one-job flow

October 24, 2026. User-requested correction before Step 51.

- Sailing HUD buttons, cargo list and its internal scrollbars no longer retain keyboard focus. Previously a cancelled click or keyboard focus navigation could cause PlayerControls to reject all helm/camera input until focus was manually released. Settings/menu and window-focus safety gates remain intact. This fixes an identified lock path; it does not claim every possible gameplay lock has been reproduced.
- Both berth envelopes widened from 28 to 36 metres. The padded 24-metre heavy hull previously had only one metre lateral tolerance and lost eligibility with tiny heading deviations. Full hull containment, low speed, heading and physical obstacle checks remain. Regression checks cover 3 metres off centre and 5 degrees off heading at both ports, including transformed ports. Position feedback now gives local port/starboard and ahead/astern distance to berth centre; no water markings.
- One active container job per captain, including across ships. Accepted/loading and loaded jobs count; retries cannot duplicate cargo. Heavy jobs already allow only one; the preview UI guards both families and prevents ship switching during an active job.
- Accepting a container job starts timed loading immediately. Failed starts release the job. Cancellation and interrupted loading remain safe. The separate Load button is removed. Heavy jobs retain the expressly requested nearby physical pickup and ocean drop-off.

Validation: 122-script/import/startup check; ControlsCheck; 134 HandlingCheck cases; 216 editor port/cargo checks; final rendered Release 220 checks at ../output/ports/4b745e41. Both final menu captures inspected. Restart checks exercise forward/reverse input from rest on both boats and verify every sailing HUD control, including scrollbars, is non-focusable. Loading tests cover automatic acceptance/start, cancellation, disconnect, lost docking, hidden UI, duplicate loading, single-job enforcement and delivery. Final export rebuilt.

Scope remains the local Port Test. Durable jobs, services and online port integration are still pending. Step 51 remains next. Step 52 supplies manifest-driven visible containers; add temporary minimap with destination/boat/ports to Step 56 navigation usability, before the Step 57 voyage gate. Keep it functional and simple; aesthetic polish later. No player-to-player transactions.

Recovery tag: docking-usability. Source backup: ../output/checkpoints/docking-usability-2026-10-24.zip. Preexisting project.godot changes remain untouched and excluded from the source checkpoint.
