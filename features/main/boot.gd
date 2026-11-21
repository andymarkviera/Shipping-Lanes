extends Node
## Route before instantiating menus, settings, audio or local-save readers.
func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var network: bool = OS.has_feature("dedicated_server") or OS.has_feature("server") or args.has("--server") or args.has("--connect")
	# Patch 4.0.5 item 2: error and crash reports, for every client run (not the server).
	if not (OS.has_feature("dedicated_server") or OS.has_feature("server") or args.has("--server")):
		ErrorReports.install(get_tree())
	var scene: String = "res://features/network/dedicated_runtime.tscn" if network else "res://features/main/main.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)
