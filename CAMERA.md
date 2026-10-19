# Step 19 — Orbit camera

In Boat Handling Test, hold the right mouse button and drag to orbit, scroll to
zoom, and press C to recenter behind the ship. Recenter follows the saved binding.
Camera sensitivity and vertical inversion use the existing saved preferences.
The camera follows heading and position smoothly; orbit is an offset relative to
the target's heading. Recenter restores the aft angle/elevation, retaining zoom.

Mouse capture ends on right-button release, focus loss, blocked input, or scene
exit. Menus cannot start an orbit. Focus restoration uses the existing release-
held-keys gate. The camera never changes ship motion or throttle.

## Focus interface and limits

Attach CameraFocus to any target, position it at a useful visual center, assign
its hull_radius and optional collision_body, then pass it to OrbitCameraRig with
set_focus(). bind_controls() connects the existing input boundary. No specific
ship node name/path or handling class is required. Tests use 16 m and 80 m hulls;
the current 64 m box uses a 34 m radius and a focus 5 m above its origin.

Minimum zoom is max(8 m, 1.3 × hull radius); maximum is max(60 m, 8 × radius).
Pitch is bounded to 0.12–1.25 radians. Zoom steps multiply by exp(±0.12).
Position, yaw, pitch and zoom use exponential smoothing at 5 /s, updated on the
physics tick. First focus initializes the rig. Switching focus preserves current
camera state and blends toward the new target and its zoom bounds. A missing or
freed focus leaves the last view stable and releases mouse capture.

A 0.75 m sphere sweep from the smoothed focus toward the desired camera position
avoids solid geometry, excluding the focused hull. The near plane is 0.2 m.
Obstacles shorten the arm immediately for safety; recovery is smoothed. Collision
may temporarily put the camera closer than the requested zoom minimum. If the
smoothed focus itself intersects geometry during a switch, the previous view is
held until the focus exits. This is a static-pier prototype, not proof against
arbitrary moving geometry enclosing the camera or target.

## Verification

CameraCheck passes 20 checks in editor and exported Windows Release: both hull
sizes, zoom/pitch bounds, target switching and convergence, real mouse orbit and
wheel events, recenter, capture release, focus/menu blocking, tall-pier avoidance,
recovery, and missing target. Full passes 13 stages, including 72 handling checks
and compilation of 41 scripts. Native aft/orbit captures were visually inspected.

Run tools/Godot.ps1 -Mode CameraCheck, or use -Mode RunExport -Configuration
Release -Headless -CameraProbe after exporting. There is no gameplay target-
switching menu yet; the focus interface and test exercise that capability.
