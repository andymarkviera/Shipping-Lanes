# Step 38 — Save slots and recovery interface

Completed October 21, 2026. Local Saves replaces the disabled Fleet placeholder
on the title menu. Three fixed private development slots keep this interface
bounded while reconnect/authentication work proceeds. These are alternative local
worlds, not online profiles; they cannot import progress into public accounts.

## Behavior

- The original `user://worlds/private_development` remains slot 1. Slots 2 and 3
  use `private_slot_2` and `private_slot_3` alongside it. All retain the development
  realm contract; they are independent database files, not transferable rewards.
- Empty, existing, incompatible, damaged/recoverable, and incomplete recovery
  states have distinct messages. Existing saves are fully validated on load.
  Listing uses a native SQLite connection with query-only enabled, checks the
  world header and spatial record, and does not migrate or rewrite progression.
  The binding's separate read_only VFS cannot read these WAL stores reliably;
  native connections retain SQLite's normal journal/recovery housekeeping.
- CREATE & PLAY explicitly creates the first empty selected slot. NEW GAME IN
  EMPTY SLOT refuses any occupied directory or file. No delete/reset command is
  provided. An unavailable main save does not become an empty replacement.
- USE SELECTED SLOT routes Play and menu-entered Boat Handling Test to that slot.
  Switching ends the prior local authority and clears its continuation. Selection
  survives scene changes for this application run; a fresh launch defaults to
  slot 1 and the other saved worlds remain selectable. Preferences are untouched.
- Recovery requires an existing checkpoint backup and an empty destination. The
  confirmation explicitly says money, cargo and ship progress return to the
  backup's time. The native backup API copies into the destination; validation
  must succeed before selecting it. Original main/backup progression is preserved.
- A `recovery.pending` marker blocks normal loading until the copied database
  validates and finalization succeeds. An interrupted/failed copy remains
  unavailable and occupied, never a fresh wallet. No automatic cleanup deletes
  it. With all slots occupied, recovery/new-game creation stops with a message;
  broader slot management is deferred rather than silently removing a save.
- Folder creation failures appear in the interface without claiming success.
  Existing save/autosave result messages continue to report actual outcomes.

## Verification

`tools/Godot.ps1 -Mode SlotsCheck` and `tools/CheckSlots.ps1 -Runtime Release`
run 38 checks against isolated APPDATA using the actual menu. They cover creation,
selection, recovery confirmation, preserved newer original money versus older
backup money, continuation isolation, overwrite refusal, incompatible schemas,
damaged checkpoints, missing mains, interrupted-copy markers, an unwritable
folder path blocked by an unrelated file, and unchanged preferences.

The interrupted-copy check constructs the marker state; it is not a new physical
process-kill experiment. Previous migration/persistence crash suites remain intact.
The folder failure fixture is a real filesystem obstruction, not a Windows ACL
permission matrix. Headless UI checks verify behavior, not a rendered art review.

Accepted evidence under `../output/slots-checks/`:

- `Editor-284ce81e89544fb5b88f513c9d514a65`
- `Release-b214ede454f3418486d44a62b7b84573`

All 87 GDScripts compile; application flow and existing 79-check persistence and
190-check migration suites pass in the editor. Release export and normal startup
pass. Full now offers 31 stages. Network performance/physics are unchanged and
were not retested. Next: Step 39 reconnect/lifecycle, followed by the recorded
authentication and multiplayer authority/performance gates.
