extends CanvasLayer
## Shared, read-only instruments; independent of helm/docking menu visibility.
var ship: HandlingShip
var panel: PanelContainer
var gauges = preload("res://features/feedback/vessel_gauges.gd").new()

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 20
	panel.offset_right = 220
	panel.offset_top = -96
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243642")
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(gauges)

func update_values(condition: float, fuel: float) -> void:
	gauges.update_values(condition, fuel)

func _process(_delta: float) -> void:
	if is_instance_valid(ship) and ship.state != null:
		update_values(ship.state.condition, ship.state.fuel_liters / maxf(1, ship.definition.fuel_capacity_liters))
