extends SceneTree
var failed: bool = false
var count: int = 0
func _initialize() -> void:
	check_folder("res://features")
	check_folder("res://tools")
	print("SCRIPT_CHECK_PASS (%d scripts)" % count if not failed else "SCRIPT_CHECK_FAILED")
	quit(1 if failed else 0)
func check_folder(path: String) -> void:
	for name: String in DirAccess.get_files_at(path):
		if name.ends_with(".gd"):
			count += 1
			var script: GDScript = load(path.path_join(name)) as GDScript
			if script == null or not script.can_instantiate():
				failed = true
				push_error("Invalid script: " + path.path_join(name))
	for name: String in DirAccess.get_directories_at(path):
		check_folder(path.path_join(name))
