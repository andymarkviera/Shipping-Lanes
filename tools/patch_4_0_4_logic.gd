extends RefCounted
## Patch 4.0.4 scene-free checks (issue #228). check_catalog.gd runs them in
## the Checks job; tools/patch_4_0_4_check.gd runs them too, plus the game
## scene (the plane HUD and a plane job flown end to end).
const Hud = preload("res://features/game/game_hud.gd")
const Boost = preload("res://features/ships/jetty_boost.gd")
const Look = preload("res://features/planes/plane_look.gd")
const Planes = preload("res://features/planes/plane_catalog.gd")
const PARTS: Array[String] = ["version", "compass", "boost_uses", "plane_parts"]
var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

## Runs every check; returns the failed labels (empty when all pass).
static func run_all() -> PackedStringArray:
	var suite: RefCounted = new()
	for part: String in PARTS: suite.call(part)
	return suite.failures

func version() -> void:
	var connection: GDScript = load("res://features/network/play_connection.gd")
	expect(connection.VERSION.naturalnocasecmp_to("4.0.4") >= 0, "VERSION is 4.0.4 or later (%s)" % connection.VERSION)

## Item 2: the HDG instrument. North is +Z and east is -X (globe_map), and
## FlightModel.heading() is atan2(forward.x, forward.z).
func compass() -> void:
	var cases: Dictionary = {"000° N": Vector3(0, 0, 1), "090° E": Vector3(-1, 0, 0), "180° S": Vector3(0, 0, -1), "270° W": Vector3(1, 0, 0), "045° NE": Vector3(-1, 0, 1)}
	for want: String in cases:
		var ahead: Vector3 = cases[want]
		var shown: String = Hud.compass(atan2(ahead.x, ahead.z))
		expect(shown == want, "a plane heading %s reads %s (%s)" % [ahead, want, shown])
	expect(Hud.compass(deg_to_rad(359.6)) == "000° N", "the heading wraps to 000 (%s)" % Hud.compass(deg_to_rad(359.6)))

## Item 4: the blaster's use count rises once per Shift, at the press, and
## not again when the charge becomes the blast.
func boost_uses() -> void:
	var power: Boost = Boost.new()
	expect(power.uses() == 0, "a fresh blaster has no uses")
	power.trigger()
	expect(power.uses() == 1, "Shift counts at once (charging)")
	power.advance(Boost.CHARGE_S + 0.01)
	expect(power.phase == "blast" and power.uses() == 1, "the blast is the same use")
	power.advance(Boost.BLAST_S + Boost.COOLDOWN_S + 0.1)
	expect(power.phase == "ready" and power.uses() == 1, "cooled down, still one use")
	power.trigger()
	expect(power.uses() == 2, "the next Shift is the second use")

## Item 1: PlaneLook.animate finds a model's moving parts once and keeps
## them (it searched the whole model every frame).
func plane_parts() -> void:
	for kind: String in Planes.ORDER:
		var model: Node3D = Look.model(kind)
		Look.animate(model, 0.5, true, 0.016)
		var parts: Variant = model.get_meta("anim_parts", null)
		expect(parts is Dictionary, "%s: the moving parts are cached" % kind)
		if parts is Dictionary:
			expect((parts.flames as Array).size() == model.find_children("JetFlame", "", true, false).size(), "%s: every jet flame is kept" % kind)
			expect(parts.props == model.find_child("Props", true, false), "%s: the propellers are kept" % kind)
		Look.animate(model, 0.9, false, 0.016)
		expect(model.get_meta("anim_parts") == parts, "%s: the second frame reuses them" % kind)
		model.free()
