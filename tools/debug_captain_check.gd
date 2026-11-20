extends SceneTree
## Patch 3.1.1 item 2: the admin-only "debug" captain name.
## Builds the server side the way dedicated_runtime.gd hello() does (a shared
## world, one game context per player) without a network, then checks:
## an admin key named "debug" gets infinite money and every ship; checkpoints
## still write the real money, fleet and ship; a non-admin named "debug" only
## gets the label; renaming restores the real money, fleet and own ship.
## Isolated data: a throwaway server-config.json under user://, no save store.
## Run: godot --headless --path . --script res://tools/debug_captain_check.gd
const GAME = preload("res://features/game/game.tscn")
const Runtime = preload("res://features/network/dedicated_runtime.gd")
const Progression = preload("res://features/game/progression.gd")
const ADMIN_INSTALL: String = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"
const OTHER_INSTALL: String = "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0"
const FOLDER: String = "user://debug_captain_check"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("DEBUG_CAPTAIN FAILED: " + label)
	return condition

func frames(count: int) -> void:
	for frame: int in count:
		await process_frame
		await physics_frame

func join(runtime: Node, world: Node3D, sender: int, install: String) -> Node3D:
	var context: Node3D = GAME.instantiate()
	context.runtime_role = "server"
	context.owner_id = sender
	context.shared_world = world
	context.docking.claims = world.docking.claims
	context.name = "Player%d" % sender
	root.add_child(context)
	runtime.player_keys[sender] = install.sha256_text()
	runtime.contexts[sender] = context
	return context

func run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var config: String = FOLDER.path_join("server-config.json")
	var file: FileAccess = FileAccess.open(config, FileAccess.WRITE)
	# Upper case on purpose, plus junk that must be ignored.
	file.store_string(JSON.stringify({"port": 24565, "bind": "0.0.0.0", "admin_keys": [ADMIN_INSTALL.sha256_text().to_upper(), "", "not-a-key", 5]}))
	file.close()
	var runtime: Node = Runtime.new()
	runtime.hosting = true
	runtime.load_admin_keys(config)
	expect(runtime.admin_keys == [ADMIN_INSTALL.sha256_text()], "admin_keys: one valid key read, junk ignored")
	var world: Node3D = GAME.instantiate()
	world.runtime_role = "world"
	world.name = "World"
	root.add_child(world)
	# As the hosting branch of dedicated_runtime.gd: the world has no HUD.
	world.voyage_hud.free()
	world.minimap.free()
	runtime.world = world
	await frames(2)
	var admin: Node3D = join(runtime, world, 2, ADMIN_INSTALL)
	var other: Node3D = join(runtime, world, 3, OTHER_INSTALL)
	await frames(3)
	expect(is_instance_valid(admin.ship) and is_instance_valid(other.ship), "two server contexts built")
	admin.reward_minor = 12345
	other.reward_minor = 777
	var real_fleet: Dictionary = admin.fleet.duplicate(true)
	var real_ship: String = admin.ship_kind
	var key: String = runtime.player_keys[2]
	runtime.apply_captain(2, "Andy")
	runtime.capture_player(2)
	var before: Dictionary = runtime.saves.players[key].voyage.duplicate(true)
	expect(not runtime.debug_active(2) and admin.reward_minor == 12345, "admin with a normal name: no overlay")
	# Admin renames to debug (any case): infinite money, every ship.
	runtime.apply_captain(2, "DeBuG")
	expect(runtime.debug_active(2), "admin named DeBuG: overlay on")
	expect(runtime.captains[2] == "DeBuG", "admin named DeBuG: the nameplate keeps the name")
	expect(admin.reward_minor == Runtime.DEBUG_CREDITS_MINOR, "admin named debug: infinite money")
	var all_ships: bool = true
	for kind: String in Progression.SHIPS: all_ships = all_ships and admin.fleet.has(kind)
	expect(all_ships, "admin named debug: owns every ship")
	expect(runtime.gameplay_state(admin).credits == Runtime.DEBUG_CREDITS_MINOR, "the client is sent the overlay money")
	admin.pay(5000000)
	runtime.tick_debug(2)
	expect(admin.reward_minor == Runtime.DEBUG_CREDITS_MINOR, "spending is topped back up")
	runtime.capture_player(2)
	var saved: Dictionary = runtime.saves.players[key].voyage
	expect(saved.credits == 12345 and saved.fleet == real_fleet and saved.ship == real_ship, "checkpoint in own ship writes the real money and fleet")
	expect(runtime.saves.players[key].captain == "DeBuG", "checkpoint keeps the captain label")
	# Sail a ship the captain does not really own.
	admin.ship_kind = "container_2"
	admin.heavy_mode = false
	expect(admin.select_port(admin.world_ports.find(admin.port)), "debug: switched to an unowned ship")
	await frames(2)
	runtime.capture_player(2)
	saved = runtime.saves.players[key].voyage
	expect(saved.ship == real_ship and saved.credits == 12345 and saved.fleet == real_fleet, "checkpoint in a debug ship writes the real voyage")
	# Non-admin named debug: label only.
	runtime.apply_captain(3, "debug")
	expect(not runtime.debug_active(3) and runtime.captains[3] == "debug", "non-admin named debug: label only")
	expect(other.reward_minor == 777 and other.fleet.size() == 1, "non-admin named debug: money and fleet unchanged")
	runtime.tick_debug(3)
	expect(other.reward_minor == 777, "non-admin: no top-up")
	# Rename: the real money, fleet and own ship come back.
	runtime.apply_captain(2, "Andy")
	await frames(2)
	expect(not runtime.debug_active(2) and runtime.debug_real.is_empty(), "rename: overlay off")
	expect(admin.reward_minor == 12345 and admin.fleet == real_fleet, "rename: real money and fleet restored")
	expect(admin.ship_kind == real_ship and admin.ship.definition.id == Progression.definition(real_ship).id, "rename: back in the captain's own ship (%s, %s)" % [admin.ship_kind, admin.ship.definition.id])
	runtime.capture_player(2)
	saved = runtime.saves.players[key].voyage
	expect(saved.credits == before.credits and saved.fleet == before.fleet and saved.ship == before.ship and saved.spent == before.spent, "rename: the save matches the one from before debug")
	# Unknown config: nobody is an admin.
	runtime.load_admin_keys(FOLDER.path_join("missing.json"))
	runtime.apply_captain(2, "debug")
	expect(not runtime.debug_active(2) and admin.reward_minor == 12345, "no server-config.json: debug is only a label")
	for node: Node in [admin, other, world]: node.queue_free()
	runtime.session.free()
	if runtime.actions is Node: runtime.actions.free()
	runtime.free()
	DirAccess.remove_absolute(config)
	DirAccess.remove_absolute(FOLDER)
	await frames(3)
	print("DEBUG_CAPTAIN CHECK: %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
