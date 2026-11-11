extends SceneTree
## Fixed-step route benchmark using production handling/fuel, without collision or peers.
## SQL, rendered docking and human navigation remain separate acceptance gates.
const Hull = preload("res://features/handling/handling_ship.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows: Array = []
	for resource: String in ["starter_ship", "coastal_ship", "swift_ship", "harbor_ship"]:
		for leg: int in 2:
			var ship: HandlingShip = Hull.new()
			ship.definition = load("res://features/catalog/records/%s.tres" % resource)
			root.add_child(ship)
			ship.set_physics_process(false)
			ship.position = Vector3(0 if leg == 0 else 1500, 0, 70)
			var route: Array = [Vector2(0,350),Vector2(350,600),Vector2(1100,600),Vector2(1250,300),Vector2(1250,-300),Vector2(1500,-300)] if leg == 0 else [Vector2(1500,850),Vector2(1150,1100),Vector2(400,1100),Vector2(250,750),Vector2(250,-300),Vector2(0,-300)]
			var waypoint: int = 0
			var seconds: float = 0
			var operating: float = 0
			var distance: float = 0
			var stopping: bool = false
			while seconds < 1800:
				var heading: float = -rad_to_deg(ship.rotation.y)
				var speed: float = ship.forward_speed()
				var throttle: float = 0
				var rudder: float = 0
				if waypoint < route.size():
					var offset: Vector2 = route[waypoint] - Vector2(ship.position.x, ship.position.z)
					if offset.length() < 55:
						waypoint += 1
						continue
					var error: float = wrapf(rad_to_deg(atan2(-offset.x, offset.y)) - heading, -180, 180)
					var target: float = 3.5 if absf(error) > 25 else 8.0
					throttle = clampf(target / 10 + (target - speed) * .25, -.6, 1)
					rudder = clampf(error * .045 + rad_to_deg(ship.yaw_rate) * .5, -1, 1)
				elif not stopping:
					var ex: float = ship.position.x - (1500 if leg == 0 else 0)
					var desired: float = clampf(rad_to_deg(atan2(ex, maxf(45, 70-ship.position.z))), -25, 25)
					var error: float = wrapf(desired-heading, -180, 180)
					if ship.position.z > 25 and absf(ex) < 16 and absf(wrapf(heading,-180,180)) < 7:
						stopping = true
					else:
						var target: float = minf(3, maxf(1.1, (65-ship.position.z)/15))
						throttle = clampf(target / 10 + (target-speed)*.35,-.6,.6)
						rudder = clampf(error*.07 + rad_to_deg(ship.yaw_rate)*.7,-1,1)
				elif ship.velocity.length() < .01:
					break
				ship.command_throttle(throttle)
				ship.maneuver(rudder, 0)
				ship.advance_motion(DT)
				ship.position += ship.velocity * DT
				distance += ship.velocity.length() * DT
				if absf(ship.actual_throttle) > .001: operating += DT
				seconds += DT
			if seconds >= 1800 or ship.state.fuel_liters <= 0:
				push_error("Economy route failed: " + resource)
				quit(1)
				return
			rows.append({"definition":ship.definition.id,"leg":leg,"seconds":seconds,"operating_seconds":operating,"distance_m":distance,"fuel_liters":ship.definition.fuel_capacity_liters-ship.state.fuel_liters})
			ship.free()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--metrics="):
			var file := FileAccess.open(arg.trim_prefix("--metrics="), FileAccess.WRITE)
			if file == null:
				quit(1)
				return
			file.store_string(JSON.stringify(rows, "  "))
	print("ECONOMY_ROUTE_PASS ", JSON.stringify(rows))
	quit()
