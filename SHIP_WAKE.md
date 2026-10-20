# Step 23B — Stylized ship wake and hull foam

The handling prototype now has original pale foam crests behind moving ships,
a pulsing band along each side, and a curved leading-end foam band. Low speeds
produce thinner, quieter ripples; cruising speeds produce wider, brighter foam.
The bright ocean and muted coastal palettes both supply the foam color.

ShipWake reads actual world velocity, not throttle. Reverse changes the leading
end and wake origin; sideways drift emits from the trailing hull edge. Samples
stay in world space through turns, spread outward and fade over eight seconds.
A stopped ship emits nothing and its old trail expires. Teleports over 50 m clear
history. No navigation, collision, draft or camera state is written by the effect.

One ImmediateMesh and one transparent unshaded material per ship. History is
capped at 40 samples; Low emits every 0.55 s and Medium/High every 0.35 s. Maximum
geometry is 712 triangles per ship (40 samples plus side/front bands). Each frame
rebuilds this small presentation mesh. The foam shader shares the ocean wave
formula, clock and quality; solid hulls/docks occlude it through normal depth tests.
No scene-depth texture or external art assets are required.

This is a prototype fit for the 13 x 64 m box hull. Recalibrate width/length and
leading foam shape for real hull art; fleet-wide effects budgets and multiplayer
presentation still need later measurement. No shoreline surf, airborne spray,
water displacement or physical wave forces are implemented in this pass.

Verification: full 16-stage project suite passes, 51 scripts compile. Extended
WaterCheck passes 59 checks in editor and native OpenGL Windows Release, including
motion-based strength, reverse/lateral direction, world anchors, history cap,
teleport reset, expiry, all quality tiers and unchanged navigation. Native moving
wake capture reviewed and crest width increased for readability. User style
acceptance remains a visual preference to revisit during playtesting.
