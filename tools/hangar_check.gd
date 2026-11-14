extends SceneTree
## Patch 2.2 item 4: the boat hangar. In the real game scene: SHIPS opens a
## full-screen hangar over a running world; the ladder is the 15 container,
## bulk and heavy-lift ships (no gas or oil); arrows and keys cycle it and the
## stats always match the ship shown; the family filter works; Buy says what is
## missing when short, charges once on a double press; Select refuses with a
## reason when undocked and otherwise switches; Esc goes back without opening
## the menu. Every tier is bought and selected through the hangar, docks and
## sees a job board it can carry; the fleet and active ship survive a reload.
## Isolated save folder.
## Run: godot --headless --path . --script res://tools/hangar_check.gd

const FOLDER: String = "user://hangar_check"
const Progression = preload("res://features/game/progression.gd")
const Hangar = preload("res://features/game/boat_hangar.gd")
const HeavyJobs = preload("res://features/cargo/heavy_ocean_job.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("HANGAR FAILED: " + label)
	return condition

func wipe() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir != null:
		for file: String in dir.get_files(): dir.remove(file)

func settle() -> void:
	for frame: int in 3:
		await process_frame
		await physics_frame

func open_game() -> Node:
	set_meta("game_save_path", FOLDER + "/voyage.db")
	change_scene_to_file("res://features/game/game.tscn")
	for frame: int in 1200:
		await process_frame
		var scene: Node = current_scene
		if scene != null and scene.is_node_ready() and scene.get("persistence") != null and is_instance_valid(scene.persistence) and (scene.persistence.ready_to_save or scene.persistence.blocked):
			return scene
	expect(false, "Game scene opened")
	return null

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
	await settle()

func button_named(game: Node, title: String) -> Button:
	for node: Node in game.hangar.find_children("*", "Button", true, false):
		if (node as Button).text == title and (node as Button).is_visible_in_tree(): return node as Button
	return null

## Docks at the first port that takes this ship.
func dock_anywhere(game: Node) -> bool:
	for index: int in game.world_ports.size():
		if game.docking.state(1) == "docked": return true
		if not game.select_port(index): continue
		var ship: HandlingShip = game.ship
		await settle()
		ship.global_transform = game.port.berth_anchor.global_transform.translated_local(Vector3(0, 0, -30))
		ship.velocity = Vector3.ZERO
		await settle()
		if not game.docking.request_dock(1, game.service_id(), game.cargo_id()).ok: continue
		for frame: int in 400:
			await physics_frame
			if game.docking.state(1) == "docked": return true
	return false

func board_fits(game: Node, kind: String) -> bool:
	var tier: int = Hangar.tier_of(kind)
	# Patch 2.4 item 8: small boats take no jobs, and the board says so.
	if Hangar.family_of(kind) == "small": return game.job_cards.is_empty() and game.accept_reason().begins_with("Small boats take no cargo jobs")
	if game.job_cards.is_empty(): return false
	for card: Dictionary in game.job_cards:
		var fits: bool = false
		match Hangar.family_of(kind):
			# Container boards filter by count: a small bigger-tier job can fit.
			"container": fits = int(card.count) <= Progression.container_capacity(tier)
			"bulk": fits = int(Progression.bulk_job(card.id).get("tier", 9)) <= tier
			"heavy": fits = HeavyJobs.tier_of(card.id) <= tier
		if not fits: return false
	return true

func give(game: Node, minor: int) -> void:
	game.banked_minor += minor
	game.reward_minor += minor

func check_screen(game: Node) -> void:
	var hangar: CanvasLayer = game.hangar
	var ladder: Array[String] = Hangar.ladder()
	expect(ladder.size() == 18 and ladder.all(func(k: String) -> bool: return Progression.SHIPS.has(k) and Hangar.family_of(k) in ["container", "bulk", "heavy", "small"]), "The hangar ladder is the 15 container, bulk and heavy-lift ships and the 3 small boats, no gas or oil")
	expect(not hangar.is_open(), "The hangar starts closed")
	expect(await dock_anywhere(game), "The starter ship docks")
	await settle()
	for node: Node in game.find_children("*", "Button", true, false):
		if (node as Button).text == "SHIPS" and (node as Button).is_visible_in_tree(): (node as Button).pressed.emit()
	await settle()
	expect(hangar.is_open() and hangar.current() == "container" and not paused, "SHIPS opens the hangar on the active ship; the world is not paused")
	expect(hangar.models.size() == 18, "All 18 models are built once and cached (%d)" % hangar.models.size())
	expect(hangar.action_button.text == "Active" and hangar.action_button.disabled and hangar.name_label.text.contains("ACTIVE"), "The active ship is marked Active")
	# Cycle the whole ladder by the arrow key and the on-screen arrow; stats follow.
	for at: int in ladder.size() + 1:
		var kind: String = hangar.current()
		var shown: Node3D = hangar.models[kind]
		expect(kind == ladder[at % ladder.size()], "Step %d shows %s (got %s)" % [at, ladder[at % ladder.size()], kind])
		expect(shown.visible and hangar.models.values().filter(func(m: Node3D) -> bool: return m.visible).size() == 1, "Only %s's model is shown" % kind)
		expect(hangar.name_label.text.begins_with(str(Progression.SHIPS[kind].name).to_upper()) and hangar.stats_label.text.contains(Hangar.credits(int(Progression.SHIPS[kind].price_minor))) and hangar.stats_label.text.contains(Hangar.capacity_text(kind)) and hangar.stats_label.text.contains("%.0f kn" % Hangar.top_knots(Progression.definition(kind))), "Stats match %s" % kind)
		if at % 2 == 0: await key(KEY_RIGHT)
		else: button_named(game, ">").pressed.emit(); await settle()
	await key(KEY_LEFT)
	expect(hangar.current() == ladder[0], "Left steps back and wraps")
	# Filter.
	button_named(game, "Bulk").pressed.emit()
	await settle()
	expect(hangar.kinds == Progression.BULK_KINDS and hangar.current() == "bulk", "The Bulk filter shows the five bulk ships")
	await key(KEY_DOWN)
	expect(hangar.kinds == Progression.HEAVY_KINDS, "Down steps the filter to Heavy lift")
	await key(KEY_DOWN)
	expect(hangar.kinds == Progression.SMALL_KINDS and hangar.family_label.text.contains("boat 1 of 3"), "Down again steps the filter to the three Small boats")
	button_named(game, "All").pressed.emit()
	await settle()
	expect(hangar.kinds.size() == 18, "All shows the whole ladder again")
	# Short of money: Buy says how much more is needed and does nothing.
	hangar.set_family("container")
	hangar.step(1)
	var price: int = int(Progression.SHIPS.container_2.price_minor)
	var wallet: int = game.reward_minor
	expect(hangar.action_button.disabled and hangar.action_button.text == "Need %s more" % Hangar.credits(price - wallet), "Buy shows how much more is needed (%s)" % hangar.action_button.text)
	hangar.press_action()
	expect(not game.fleet.has("container_2") and game.reward_minor == wallet, "A short wallet buys nothing")
	# Esc goes back and does not open the menu.
	await key(KEY_ESCAPE)
	expect(not hangar.is_open() and not game.game_menu.is_open() and not paused, "Esc closes the hangar, not into the menu")

## Buys and selects every ship through the hangar, then docks and reads the board.
func check_every_tier(game: Node) -> String:
	var hangar: CanvasLayer = game.hangar
	var previous: String = game.ship_kind
	for kind: String in Hangar.ladder():
		if not expect(await dock_anywhere(game), "%s's predecessor docks before buying" % kind): return previous
		if kind != game.ship_kind:
			var price: int = int(Progression.SHIPS[kind].price_minor)
			give(game, price + 5000)
			var wallet: int = game.reward_minor
			hangar.open()
			hangar.set_family(Hangar.family_of(kind))
			while hangar.current() != kind: hangar.step(1)
			expect(hangar.action_button.text == "Buy · " + Hangar.credits(price) and not hangar.action_button.disabled, "%s offers Buy at its price" % kind)
			# A real player's clicks are seconds apart; headless steps are not.
			hangar.last_action_ms = -100000
			hangar.action_button.pressed.emit()
			hangar.action_button.pressed.emit()
			await settle()
			expect(game.fleet.has(kind) and game.reward_minor == wallet - price and game.ship_kind == previous, "A double press buys %s once and does not switch to it" % kind)
			expect(hangar.action_button.text == "Select" and hangar.is_open(), "%s now offers Select" % kind)
			# Past the double-press guard, as a player's next click would be.
			hangar.last_action_ms -= Hangar.ACTION_COOLDOWN_MS
			hangar.action_button.pressed.emit()
			await settle()
			expect(game.ship_kind == kind and game.ship.definition.id == Progression.definition(kind).id and not hangar.is_open(), "Select makes %s the active ship and returns to the game" % kind)
			# Undocked: Select on the previous ship is refused with the reason.
			hangar.open()
			if not hangar.kinds.has(previous): hangar.set_family("")
			while hangar.current() != previous: hangar.step(1)
			expect(hangar.action_button.disabled and hangar.status_label.text == "Dock at a port to switch ships.", "Select says why it cannot switch while under way (%s)" % hangar.status_label.text)
			hangar.close()
			previous = kind
		if not expect(await dock_anywhere(game), "%s docks somewhere" % kind): continue
		game.refresh_jobs()
		expect(board_fits(game, kind), "%s sees a job board it can carry at %s" % [kind, game.port.definition.id])
	return previous

func run() -> void:
	await process_frame
	wipe()
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var game: Node = await open_game()
	if game != null and expect(not game.persistence.blocked, "Isolated save opens"):
		await check_screen(game)
		var last: String = await check_every_tier(game)
		var wallet: int = game.reward_minor
		await settle()
		expect(game.persistence.checkpoint(), "The fleet saves")
		current_scene.queue_free()
		await settle()
		game = await open_game()
		if game != null:
			await settle()
			expect(game.ship_kind == last and game.fleet.size() == 18 and game.reward_minor == wallet, "A reload keeps the active ship, all 18 ships and the wallet (ship %s, fleet %d, wallet %d / %d)" % [game.ship_kind, game.fleet.size(), game.reward_minor, wallet])
	if current_scene != null:
		current_scene.queue_free()
		for frame: int in 3: await process_frame
	wipe()
	for failure: String in failures: push_error(failure)
	print("HANGAR_CHECK_PASS checks=%d" % checks if failures.is_empty() else "HANGAR_CHECK_FAILED %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
