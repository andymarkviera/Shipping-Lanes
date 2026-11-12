class_name DeveloperOverlay
extends CanvasLayer
## Read-only diagnostics. Never captures mouse or changes session state.
var enabled: bool = false
var panel: PanelContainer
var readout: Label
var _snapshot: Dictionary = {}
var _seconds: float = 0.0
var _frames: int = 0
var _frame_ms: float = 0.0

func _ready() -> void:
	layer = 90
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -340
	panel.offset_right = -16
	panel.offset_top = 150
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("14232e")
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	readout = Label.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_font_size_override("font_size",14)
	panel.add_child(readout)
	add_to_group(DevMode.GROUP)
	set_enabled(DevMode.enabled)

## Shown only in developer mode: F3, read by PlayerControls (see DevMode).
func dev_mode_changed() -> void:
	set_enabled(DevMode.enabled)

func set_enabled(value: bool) -> void:
	enabled = value
	panel.visible = value

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)

func _process(delta: float) -> void:
	_seconds += delta
	_frames += 1
	if _seconds >= 0.25:
		_frame_ms = _seconds * 1000.0 / _frames
		_seconds = 0.0
		_frames = 0
	if not enabled: return
	var fuel: Variant = _snapshot.get("fuel_ml")
	readout.text = "DEVELOPER  |  F3 to hide\nRole: %s\nShip: %s\nSpeed: %s\nThrottle: %s\nPosition: %s\nFuel: %s\nFrame interval: %s\nProcess CPU: %.2f ms" % [
		_snapshot.get("role","No session"), _snapshot.get("ship_id","—"),
		"Not connected" if _snapshot.get("speed_mps") == null else "%.2f m/s" % _snapshot.speed_mps,
		"Not connected" if _snapshot.get("throttle") == null else "%.2f" % _snapshot.throttle,
		"Not connected" if _snapshot.get("position_m") == null else str(_snapshot.position_m),
		"—" if fuel == null else "%.2f L (fixture)" % (float(fuel) / 1000.0),
		("Sampling…" if _frame_ms == 0.0 else "%.2f ms" % _frame_ms), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
