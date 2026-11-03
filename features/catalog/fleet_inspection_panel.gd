extends PanelContainer
## Isolated, read-only comparison. Preview instantiates visual scenes, never runtime hulls.
const Inspection = preload("res://features/catalog/fleet_inspection.gd")
signal resale_requested(quote_id: String)
var sell: Button
var sale_confirmation: String = ""
signal activation_requested(ship_id: String)
var activate: Button
var confirmation: String = ""
var choices: Array = []
var choice_signature: String = ""
var family: OptionButton
var selectors: Array[OptionButton] = []
var descriptions: Array[Label] = []
var previews: Array[SubViewport] = []
var preview_ids: Array[String] = ["", ""]
var models: Array[Node3D] = [null, null]
var data: Dictionary = {}
var available: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 20; offset_right = -20; offset_top = 20; offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243642")
	for edge: String in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 12)
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	add_child(stack)
	var close := Button.new()
	close.text = "Close fleet inspection / comparison"
	close.pressed.connect(hide)
	stack.add_child(close)
	activate = Button.new()
	activate.text = "Activate selected owned ship (left column)"
	activate.pressed.connect(activate_selected)
	stack.add_child(activate)
	sell = Button.new()
	sell.pressed.connect(sell_selected)
	stack.add_child(sell)
	var cancel_sale := Button.new()
	cancel_sale.text = "Cancel sale review"
	cancel_sale.pressed.connect(func(): sale_confirmation = ""; refresh_details())
	stack.add_child(cancel_sale)
	var sale_policy := Label.new()
	sale_policy.text = "Sell empty stored ships at this port only. Finish all cargo/jobs first. Active ship retained. Fuel has no resale value."
	sale_policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(sale_policy)
	family = OptionButton.new()
	for title: String in Inspection.FAMILIES: family.add_item(title)
	family.item_selected.connect(func(_index: int): refresh_details())
	stack.add_child(family)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	scroll.add_child(columns)
	for index: int in range(2):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 300
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var selector := OptionButton.new()
		selector.fit_to_longest_item = false
		selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		selector.item_selected.connect(func(_value: int): refresh_details())
		column.add_child(selector)
		selectors.append(selector)
		var frame := SubViewportContainer.new()
		frame.custom_minimum_size = Vector2(300, 170)
		frame.stretch = true
		column.add_child(frame)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(300, 170)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		frame.add_child(viewport)
		previews.append(viewport)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.position = Vector3(85, 65, 100)
		camera.look_at(Vector3.ZERO)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 110
		camera.current = true
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -35, 0)
		viewport.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("385768")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.6
		viewport.add_child(environment)
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(description)
		descriptions.append(description)
	hide()

func refresh(snapshot: Dictionary, usable: bool) -> void:
	data = snapshot
	available = usable
	var next: Array = []
	for ship: ShipDefinition in Inspection.definitions(): next.append({"definition": ship.id})
	next.append_array(data.get("fleet", []))
	# Rebuild only identity/name choices, retaining each selection by owned ID or definition.
	var identity: Array = []
	for entry: Dictionary in next: identity.append([entry.get("id", "catalog:" + str(entry.definition)), entry.get("name", "")])
	var signature: String = JSON.stringify(identity)
	if signature != choice_signature:
		choice_signature = signature
		for selector: OptionButton in selectors:
			var previous: String = str(selector.get_item_metadata(selector.selected)) if selector.selected >= 0 else ""
			selector.clear()
			for entry: Dictionary in next:
				var ship: ShipDefinition = Inspection.definition(str(entry.definition))
				var title: String = ship.display_name if ship != null else "Unknown ship"
				var key: String = str(entry.get("id", "catalog:" + str(entry.definition)))
				if entry.has("id"): title = str(entry.get("name", "Unnamed ship")) + " · " + title + " · " + str(entry.id)
				else: title = "Catalog · " + title
				selector.add_item(title)
				selector.set_item_metadata(selector.item_count - 1, key)
				if key == previous: selector.select(selector.item_count - 1)
			if previous.is_empty() and selector == selectors[1] and next.size() > Inspection.definitions().size(): selector.select(Inspection.definitions().size())
	choices = next
	if visible: refresh_details()

func open(definition_id: String) -> void:
	confirmation = ""
	sale_confirmation = ""
	for index: int in range(selectors[0].item_count):
		if selectors[0].get_item_metadata(index) == "catalog:" + definition_id: selectors[0].select(index); break
	show()
	refresh_details()

func activate_selected() -> void:
	if activate.disabled: return
	var entry: Dictionary = choices[selectors[0].selected]
	if confirmation != str(entry.id):
		confirmation = str(entry.id)
		refresh_details()
		return
	confirmation = ""
	activation_requested.emit(str(entry.id))

func refresh_details() -> void:
	var selected_entry: Dictionary = choices[selectors[0].selected] if selectors[0].selected >= 0 and selectors[0].selected < choices.size() else {}
	var eligible: bool = available and selected_entry.has("id") and not selected_entry.get("active", false) and selected_entry.get("storage_port_id") == data.get("port") and int(data.get("cargo", 0)) == 0 and data.get("job", {}).is_empty()
	var terms: Dictionary = selected_sale()
	sell.disabled = not available or terms.is_empty()
	if sell.disabled or sale_confirmation != str(terms.get("id", "")): sale_confirmation = ""
	sell.text = "Select an eligible stored ship to sell"
	if not terms.is_empty():
		var gross: int = int(terms.value_minor)
		var debt: int = int(data.get("recovery_debt_minor", 0))
		@warning_ignore("integer_division")
		var repaid: int = mini(debt, maxi(1, gross / 2)) if gross > 0 else 0
		sell.text = ("Confirm sale" if not sale_confirmation.is_empty() else "Review sale") + " — gross %.2f · debt %.2f · wallet +%.2f" % [gross / 100.0, repaid / 100.0, (gross - repaid) / 100.0]
	activate.disabled = not eligible
	if not eligible or confirmation != str(selected_entry.get("id", "")): confirmation = ""
	activate.text = "Confirm activation — retain fuel and condition" if not confirmation.is_empty() else "Activate selected owned ship (left column)"
	for index: int in range(2):
		var selected: int = selectors[index].selected
		if selected < 0 or selected >= choices.size(): continue
		var entry: Dictionary = choices[selected]
		descriptions[index].text = Inspection.details(entry, Inspection.FAMILIES[family.selected], data, available)
		var id: String = str(entry.definition)
		if preview_ids[index] == id: continue
		preview_ids[index] = id
		if models[index] != null: models[index].free(); models[index] = null
		var ship: ShipDefinition = Inspection.definition(id)
		if ship == null: continue
		var scene: PackedScene = load(ship.scene_path)
		if scene == null: continue
		models[index] = scene.instantiate() as Node3D
		models[index].process_mode = Node.PROCESS_MODE_DISABLED
		previews[index].add_child(models[index])

func selected_sale() -> Dictionary:
	if selectors[0].selected < 0 or selectors[0].selected >= choices.size(): return {}
	var entry: Dictionary = choices[selectors[0].selected]
	for quote: Dictionary in data.get("resale_quotes", []):
		if quote.ship_id == entry.get("id", ""): return quote
	return {}

func sell_selected() -> void:
	if sell.disabled: return
	var terms: Dictionary = selected_sale()
	if terms.is_empty(): return
	if sale_confirmation != str(terms.id):
		sale_confirmation = str(terms.id)
		refresh_details()
		return
	sale_confirmation = ""
	sell.disabled = true
	resale_requested.emit(str(terms.id))
