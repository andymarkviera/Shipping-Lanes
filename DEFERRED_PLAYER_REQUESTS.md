# Deferred player requests — October 25, 2026

Status: planned, not implemented. Original roadmap numbers stay stable. This
supplement records Andy's latest preferences without editing the attached Library
roadmap. Step 57's full online voyage gate remains the immediate priority.

| Request | Placement | Scope and completion criteria |
|---|---|---|
| Globe minimap | Step 93, Map and waypoints; follow-up to temporary Step 56 chart | Replace the flat local chart with an actual globe view, not merely a circular flat minimap. Show ship, ports and active destination using canonical geography; provide readable local zoom and indicate targets on the far side. Apply to online and local play. Check seam/pole transitions and small-screen readability. |
| Earth's curvature | Step 88 world layout decision, implemented with Steps 89–90 streaming, verified at 98/101 | Render a curved ocean/horizon and consistent distant-object placement/occlusion. Existing spherical navigation and tangent physics charts are groundwork, not proof of visible curvature. Select game-world radius/travel times deliberately: this request does not mandate literal Earth-sized distances or Earth's continents. Preserve local collision, docking, attached cargo, saves and online agreement. Any radius/content change needs deliberate migration. |
| Slightly blurry distant objects | Step 96 environment, verified at 97–98 and accessibility at 122 | Use gentle distance haze/softening with optional subtle far-distance blur. Keep nearby ships, docks and UI sharp and distant navigation landmarks readable. Compare against the Zelda references; avoid an aggressive all-scene depth-of-field effect. Provide quality and reduced-effects options. |
| Zelda-inspired overall look and better reference pictures | Add art-direction brief before Step 88; apply during 91/96/99, finalize at 123 | Wind Waker HD is the primary reference based on Andy's earlier sea image: bold blue ocean, graphic foam, simple readable shapes, stylized shading and soft horizon atmosphere. Preserve regional muted coastal colors. Create original ships, ports and art guided by this style. Gather reference views for daytime sea, bow foam, stern wake, coast/rocks and evening lighting before replacing assets. |
| Better bow ripples and foam | Step 96 water/environment follow-up to Step 20; profile at 98, polish at 123 | Separate bow displacement, hull-contact foam and stern wake. Scale with actual water-relative movement, hull shape, turning, reverse and stopping, not just throttle. Keep current effects as placeholders until this pass. Test loaded/empty ships and remote replicas; effects must not control collisions or job state. |
| One local save and Restart Progress | Add save-UX follow-up after Step 67, before Step 68; revisit at 108/122 | Supersedes the three selectable private development slots as the intended player-facing design. One active local progression save, Continue and an explicitly confirmed Restart Progress. Plan migration/consolidation of development slots and separate Port Test progress without silently discarding either. Preserve settings; keep backup/recovery and crash-safe reset behavior. SQLite journal/backup files do not count as extra player slots. This local reset does not reset the canonical online profile. Do not delete or reset any existing save during planning. |
| Angled docking cutscene | Step 91 port authoring/presentation, final polish at 123; follow-up to 19/46 | Brief skippable angled view triggered by server-confirmed docking, coordinated with later mooring ropes and cargo-loading animation. Camera returns safely on skip, menu, disconnect, cancellation and reconnect. No repeated scene on routine state refresh, no new persistent input lock, and no pause of the online world. Reduced-motion/disable option at 122. |
| Boat rocks left/right when turning; consider waves | Add handling-presentation follow-up after Step 67, before Step 68; waves evaluated at 96 | Start with subtle damped visual roll based on speed/turn rate and a stable camera option. Keep physics/cargo anchors coherent; do not disturb neutral stopping or docking. Evaluate gentle visual wave-driven roll/pitch/heave at 96. Actual wave forces remain a separate measured gameplay decision requiring buoyancy, heavy pickup, docking, saving and multiplayer tests before adoption. |

## Reference picture shortlist

Selected October 25, 2026. Use reference pages and original-resolution images for
visual comparison; these are not game assets to import.

- [Wind Waker HD daytime sailing screenshot](https://www.cinemablend.com/games/Legend-Zelda-Wind-Waker-HD-Screenshots-Go-Sailing-58093.html):
  bright sea, graphic white water patterns and boat wake.
  [Direct image](https://cdn.mos.cms.futurecdn.net/8yB8swbuuAnTS3nVuqCWDM.jpg).
- [Wind Waker HD coastal sailing](https://zeldauniverse.net/guides/the-wind-waker/walkthrough/chapter-19-triforce-shard-4-the-ghost-ship/):
  ocean/boat/nearby-island composition and white wake.
  [Direct image](https://zeldauniverse.net/wp-content/uploads/2021/01/Screenshot-2538-1536x864.jpg).
- [Wind Waker HD screenshot gallery](https://www.palaiszelda.com/thewindwaker/screenshots.php):
  compare daytime with moonlit sea and keep foam readable under different light.
  [Moonlit sailing image](https://www.palaiszelda.com/images/z10/shots_hd/hd_shot10.png).
- [Wind Waker HD promotional screenshot collection](https://zeldawiki.wiki/wiki/Category:The_Wind_Waker_HD_Promotional_Screenshots):
  source for higher-resolution art studies; includes 1920x1080 images.
  [E3 press-kit screenshot record](https://zeldawiki.wiki/wiki/File:TWWHD_E3_1.png).

The earlier user-supplied rocky-coast image remains the regional muted-palette
reference. This shortlist favors the already chosen Wind Waker direction rather
than treating every Zelda game's distinct visual style as interchangeable.

## Scheduling and acceptance

Do not reopen completed steps as though these requests were already implemented.
Use the follow-ups above, retain step numbering, and keep existing one-job,
dock-first, no-player-transfer and no-hidden-shallows decisions. Development
tests may keep isolated save fixtures even when the player-facing menu has one
local save. Complete Step 57 before this deferred work; art reference planning is
recorded now so later world/port assets follow a consistent direction.


## Single condition / aesthetic gauges — October 26, 2026

Step 60 changed by explicit user request: one condition shared by impact damage and
gradual wear, never separate machinery degradation. Engine silhouette and fuel-pump
icons share the HUD, with lowering colored fill and no labels. Step 61 should polish
this unified feedback instead of adding separate damage/wear meters. Step 62 repairs
this same condition. Heavy-loader lifting equipment must remain unaffected.
