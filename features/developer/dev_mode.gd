class_name DevMode
extends RefCounted
## The one developer switch (REBUILD_PLAN.md Simplify pass). Off by default.
## F3 toggles it (PlayerControls). Test-scene buttons, the developer overlay and
## extra readouts show only while it is on. It lasts until the game closes.
const GROUP: StringName = &"dev_mode_listeners"
static var enabled: bool = false

## Nodes in GROUP must have a dev_mode_changed() method. It is called at once.
static func set_enabled(tree: SceneTree, value: bool) -> void:
	enabled = value
	if tree != null: tree.call_group(GROUP, &"dev_mode_changed")

static func toggle(tree: SceneTree) -> void:
	set_enabled(tree, not enabled)
