# Step 20 — Stylized water presentation

The initial ocean uses Andy's latest reference direction: bright bold blue with
broad, pale flowing surface patterns. It is an original procedural Godot shader;
no texture or game asset was extracted from the reference. The earlier muted
coastal palette is preserved as a separate reusable resource for future areas.
Regional selection/blending is not implemented yet.

Open Boat Handling Test to see the water. In the main menu, Settings > Water
quality offers Low / Medium / High; save and reopen the handling test to apply.
Older preference files without this optional field default to Medium and retain
their other values. Unsupported/fractional quality values are rejected.

## Presentation boundary

OceanPresentation owns one opaque, unshaded PlaneMesh and a ShaderMaterial. The
world-space pattern uses warped cellular edges, slow drift, antialiasing and
reduced distant contrast. Medium/high add shallow visual vertex swells. No screen
refraction, reflection render targets, transparent depth sorting or water collider
is required. The 4 km plane is a local test surface, not the future global ocean.

ShipVisualMotion is a child of the ship body. Only visible hull meshes are below
it; the collision shape and camera focus remain siblings. Bob is bounded to
0.14 m, pitch to 0.12 degrees and roll to 0.22 degrees; Low reduces these to 40%.
No force, velocity, navigation position, fuel or network state is modified by
water or visual bobbing. The decorative patterns are not physical foam or wakes.
Physical waves, buoyancy, shoreline foam and detailed wakes remain separate work.

## Quality and palettes

| Mode | Surface | Mesh triangles | Pattern |
| --- | --- | --- | --- |
| Low | Flat | 2 | Curved drifting lines; fixed warp |
| Medium (default) | Two gentle swells, at most 0.27 m | 132,098 | Animated warp |
| High | Three swells, at most 0.31 m | 296,450 | Animated warp |

Low keeps the bold palette and readable line pattern while eliminating wave
geometry and reducing visible hull motion. All tiers use the same nine-neighbor
cell search in the fragment shader; quality scaling mainly reduces vertex work.
These are configured geometry costs, not a claim of measured minimum hardware
performance. Pattern edges fade between 180–650 m to limit distant sparkle.

WaterPalette exposes deep/surface/foam colors. bright_ocean.tres is active;
coastal_ocean.tres uses the earlier muted blue-green and soft foam tones.
apply_palette() updates material colors without touching gameplay state.
Each ocean instance owns its own material, so changes do not recolor all areas.

## Verification

WaterCheck passes 35 checks: legacy settings, invalid values, JSON round trips,
quality-dependent mesh/shader state, animated bounded hull motion, unchanged body,
collider and camera focus at every quality, palette switching, and save/cancel UI.
Full passes 14 stages and compiles 45 scripts; all 72 handling and 20 camera checks
remain passing. Windows Release WaterProbe also passes with native OpenGL rendering,
exercising shader compilation and all three tiers. Native Low/Medium/High and
settings captures were inspected; no GPU render errors were reported.

Use tools/Godot.ps1 -Mode WaterCheck. To exercise exported rendering, use
-Mode RunExport -Configuration Release -WaterProbe after Export.
