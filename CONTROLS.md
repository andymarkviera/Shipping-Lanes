# Controls and local settings

Step 08 — October 18, 2026. Open **Controls & settings** from the startup screen,
or press Escape. Select a key to rebind it, then **Save & close**. Cancel/Escape
discards unsaved changes; Escape first cancels an active key capture. Reset
defaults changes the draft only until saved. Duplicate bindings are rejected.

## Default actions

| Action | Default |
| --- | --- |
| Increase throttle / decrease or reverse throttle | W / S |
| Steer left / right | A / D |
| Thruster left / right | Q / E |
| Brake command / zero throttle | Space / X |
| Recenter camera | C |
| Interact / map / horn | F / M / H |
| Pause or settings | Escape, reserved |
| Camera orbit / zoom | Hold right mouse / scroll wheel |

Keyboard bindings use physical key positions, with English key names shown.
Single letters, digits, function keys and supported navigation keys are editable;
modifier combinations and controller/gamepad bindings are not implemented.
Mouse orbit/wheel defaults are fixed for this foundation. These are named input
actions for later controllers, not implemented sailing or map features.
Throttle ramp/braking rules remain Steps 16–18; the gameplay camera is Step 19.
Walking is deliberately omitted under the confirmed helm-only scope.

Master volume, camera sensitivity, camera Y inversion and fullscreen are saved
with bindings. Volume/fullscreen apply on Save. Sensitivity/inversion transform
camera-motion requests; the future camera will consume those requests. The
current main window has a 960×640 minimum to keep the settings panel usable.
Broader UI scaling/accessibility and gameplay pause/session flow remain later work.

## Code boundary

`InputPreferences` is the small defaults/validation Resource.
`features/settings/default_preferences.tres` is the tracked defaults asset.
`PlayerControls`, owned by Main, installs named InputMap actions and is the sole
vehicle-input boundary. Future controllers use its `action_strength`,
`steering_axis`, `command_requested` and `camera_motion_requested`, rather than
polling raw Input or hard-coding keyboard keys.

Ship context starts inactive. A later active session explicitly calls
`set_ship_context(true)`. Menus call `set_menu_open`; focused GUI controls and
application focus loss also block input. After a menu/context/focus transition,
all mapped controls must be released before fresh vehicle input is accepted.
Consumed GUI events never emit vehicle commands. This only gates local input;
it does not pause the SceneTree or assume authority over an online server.

## Persistence and validation

Local preferences use versioned plain JSON at `user://preferences.json`, with
validated types/ranges, known actions and unique keys. No Resource/script is
loaded from the saved file. Missing/invalid/future-version files fall back to
defaults and display a notice; invalid contents remain until an explicit Save.
Writes stage to `.tmp` before rename; failure retains active settings and reports
an error. This is a local preferences file, not an economic save or migration
system. The launcher uses the isolated data directory in `ENVIRONMENT.md`.

From the project folder:

```powershell
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Import
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode ControlsCheck
pwsh -NoProfile -File .\tools\Godot.ps1 -Mode Run
```

The headless suite uses uniquely named temporary preferences, never the player's
settings. It checks save/reload/replacement, malformed and unsupported data,
write failure, duplicate bindings, old/new keys, inactive context, UI save/cancel,
capture conflicts, Escape handling, held keys across menus/focus, volume application
and camera request scaling/inversion. Temporary test preferences are removed.

The Windows release export also starts cleanly. Its explicit resource selection
includes Main and default preferences: the initial Main-only selection omitted
that script-loaded Resource, which standalone testing caught and corrected.
Screenshot: `../output/checks/step-08-settings.png`; test log:
`.godot/controls-check.log`. A real boat/controller is not part of this milestone.

Step 09 adds application-level navigation and mouse ownership; see
[APPLICATION_FLOW.md](APPLICATION_FLOW.md). Escape now opens the session menu
while playing. Settings can be reached from the title or session menu.

Step 10 makes the settings panel opaque and sliders continuous. Only camera
sensitivity shows a numeric readout. Save/Cancel behavior is unchanged.

Ctrl+F3 toggles the read-only developer overlay. This chord is separate from
single-key rebindable gameplay actions; it does not take mouse/keyboard focus.
