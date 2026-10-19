# Application flow — Step 09

The visible title is **Container Ship Sim**, following Andy's menu reference.
The internal project name remains Shipping Lanes so existing preferences keep
loading from the same user-data location. No boat or ocean background is added.

## Try it

Run the main project or `./tools/Godot.ps1 -Mode Run`.
- Play creates a fresh local menu/session fixture. Sailing is not implemented.
- Servers explains the current lack of connected servers and offers local testing.
  Future Play is quick-join; Servers will expose the server browser.
- Fleet is visibly disabled until fleet management exists.
- Escape opens/resumes the session menu. Settings returns to its originating menu.
- Return to menu removes the active session. Continue test session restores an
  in-memory snapshot; it is available only until the application closes.
- New test session resets session state without resetting saved preferences.
- Exit or the window close button ends the process. Continue is not a disk save.

## Ownership and pause

Main owns boot/title/servers/playing/paused/settings transitions and one disposable
TestSession under World. UI is constructed once. Teardown removes the session
immediately before scheduling destruction, avoiding duplicate active worlds.
TestSession's elapsed value is solely a flow-test fixture, not the authoritative
world clock, economy, gameplay save, or network transport.

The normal local fixture uses the future hosted pause policy: the session keeps
processing behind menus. An offline-only test fixture stops its local updates.
No transition sets SceneTree.paused. Future server/network nodes must retain
this independent processing policy. No multiplayer deployment is claimed.

Menus select an initial keyboard target; standard Tab/arrows/Enter navigate.
Playing releases GUI focus. Focus loss opens the session menu and releases the
mouse; focus return never resumes automatically. Right mouse captures only from
active gameplay input, releases on button-up, and is released by every transition
or focus loss. PlayerControls requires held keys/buttons to be released before
fresh ship input. Settings retains Escape-to-cancel-binding behavior.

## Verification

`./tools/Godot.ps1 -Mode FlowCheck` covers twelve start/return/continue/new cycles,
snapshot restoration, a single active session, UI stability, settings retention,
hosted/offline pause behavior, settings return routing, keyboard focus, Escape,
mouse capture release, and focus loss. `-Mode ControlsCheck` passes unchanged.
Native title and pause renders were inspected at 1152 x 648. Minimum window size
remains 960 x 640. Accessibility and wider display validation remain later work.

Release export startup passes. The explicitly loaded test_session script is an
export root alongside Main and default preferences; a first standalone run caught
its omission before correction. No real server discovery, network reconnect,
persisted gameplay Continue, world simulation or ship controller is present yet.
