class_name FuelTestControls
extends VBoxContainer
## Explicit development-only recovery; never a paid refueling service.
var ship: HandlingShip
var controls: PlayerControls
var status: Label
## Litres on board before "Empty tank (test)". Negative when the tank is not test-emptied.
## A test-emptied tank is for this visit only: saves keep the earlier level.
var fuel_before_test_empty: float = -1.0

func fuel_to_save() -> float:
	return fuel_before_test_empty if fuel_before_test_empty >= 0 and ship.state.fuel_liters <= 0 else ship.state.fuel_liters

func configure(body: HandlingShip, input: PlayerControls) -> void:
	ship = body
	controls = input
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	for caption: String in ["Empty tank (test)", "Refuel (test)", "Pause sim", "Dock (test)"]:
		var button: Button = Button.new()
		button.text = caption
		row.add_child(button)
		button.pressed.connect(func():
			match caption:
				"Empty tank (test)":
					if ship.state.fuel_liters > 0: fuel_before_test_empty = ship.state.fuel_liters
					ship.state.fuel_liters = 0
					ship.zero_throttle()
					ship.actual_throttle = 0
					ship.maneuver(0, 0)
					status.text = "Tank emptied for this visit only; it is not saved. Coast to a stop, then use Refuel (test)."
				"Refuel (test)":
					var added: float = ship.refuel(ship.definition.fuel_capacity_liters)
					if added > 0: fuel_before_test_empty = -1.0
					status.text = "Test fuel added: %.1f L" % added if added > 0 else "Refuel needs a stopped boat, neutral controls and tank space."
				"Pause sim":
					ship.simulation_paused = not ship.simulation_paused
					button.text = "Resume sim" if ship.simulation_paused else caption
				"Dock (test)":
					if ship.velocity.length() <= 0.05:
						ship.docked = not ship.docked
						ship.zero_throttle()
						ship.actual_throttle = 0
						ship.maneuver(0, 0)
						button.text = "Undock (test)" if ship.docked else caption
					else:
						status.text = "Stop before setting the docked test state."
			button.release_focus()
			controls.wait_for_release = true)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.text = "Fuel test tools only — paid port services come later."
	add_child(status)

static func readout(body: HandlingShip) -> String:
	var suffix: String = " · EMPTY — stop, then click Refuel (test)" if body.state.fuel_liters <= 0 else ""
	if body.simulation_paused: suffix = " · SIM PAUSED"
	elif body.docked: suffix = " · DOCKED"
	return "Fuel %.1f / %.0f L%s" % [body.state.fuel_liters, body.definition.fuel_capacity_liters, suffix]
