extends CanvasLayer
## Read-only command indicator; neutral does not brake the moving hull.
var slider: HSlider
var motion: Label
var order_label: Label
var ship: HandlingShip

func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -145
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 10)
	panel.add_theme_stylebox_override("panel", style)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	order_label = Label.new()
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(order_label)
	slider = HSlider.new()
	slider.min_value = -1
	slider.max_value = 1
	slider.step = 0
	slider.tick_count = 3
	slider.ticks_on_borders = true
	slider.editable = false
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(slider)
	var labels: Label = Label.new()
	labels.text = "Reverse       | Neutral |       Forward"
	labels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(labels)
	motion = Label.new()
	motion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(motion)
	update_values(0, 0, 0)

func update_values(order: float, speed: float, forward: float) -> void:
	slider.value = order
	order_label.text = "Throttle: %s" % ("Neutral" if is_zero_approx(order) else "%+.0f%%" % (order * 100))
	var direction: String = "Nearly stopped"
	if speed >= 0.05:
		direction = "Forward" if forward > 0.03 else ("Reverse" if forward < -0.03 else "Sideways drift")
	motion.text = "%s · %.2f kn" % [direction, speed * 3600.0 / 1852.0]
	if is_zero_approx(order) and speed >= 0.05: motion.text += " · Coasting"

func _process(_delta: float) -> void:
	if is_instance_valid(ship): update_values(ship.commanded_throttle, ship.velocity.length(), ship.forward_speed())
