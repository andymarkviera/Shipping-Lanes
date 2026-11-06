extends VBoxContainer
## Read-only progress; only the trusted host clock advances processing.
const REFINERY_ID := "refinery_slatewater_01"
const PORT_ID := "port_slatewater_works"
var send: Callable
var port_context: Callable
var busy: bool = false
var pending: Dictionary = {}
var state: Dictionary = {}
var quantity: SpinBox
var summary: Label
var notice: Label
var progress: ProgressBar
var submit_button: Button
var refresh_button: Button
var poll_seconds: float = 0.0

func _ready() -> void:
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 200000
	quantity.step = 1
	quantity.value = 1000
	quantity.suffix = " millibarrels crude (1000 = 1 barrel)"
	add_child(quantity)
	progress = ProgressBar.new()
	add_child(progress)
	refresh_button = Button.new()
	refresh_button.text = "Refresh refinery / current oil lot"
	refresh_button.pressed.connect(inspect)
	add_child(refresh_button)
	submit_button = Button.new()
	submit_button.text = "Submit crude at Slatewater (irreversible)"
	submit_button.pressed.connect(submit)
	add_child(submit_button)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)

func _process(delta: float) -> void:
	if submit_button == null: return
	var context: Dictionary = port_context.call() if port_context.is_valid() else {}
	var retry: bool = not pending.is_empty()
	submit_button.text = "Retry original refinery submission" if retry else "Submit crude at Slatewater (irreversible)"
	submit_button.disabled = busy or not send.is_valid() or (not retry and (state.is_empty() or state.get("busy", false) or state.get("lots", []).is_empty() or not context.get("docked", false) or context.get("port_id", "") != PORT_ID))
	quantity.editable = not busy and not retry
	refresh_button.disabled = busy or retry or not send.is_valid()
	poll_seconds += delta
	if poll_seconds >= 1.0:
		poll_seconds = 0.0
		if visible and not busy and not retry and send.is_valid(): inspect()

func inspect() -> void:
	if busy or not pending.is_empty() or not send.is_valid(): return
	busy = true
	var result: Dictionary = await send.call({"op": "refinery_snapshot", "refinery_id": REFINERY_ID})
	busy = false
	if not result.get("ok", false):
		if result.get("code") != "SERVICE_BUSY": notice.text = "Refinery unavailable; previous progress may be stale."
		return
	state = result.duplicate(true)
	var config: Dictionary = state.config
	var owner: Dictionary = state.owner
	summary.text = "SLATEWATER REFINERY · yield %d/%d\nCargo fuel in storage: %d millibarrels (not propulsion fuel)\nFraction carried: %d/%d millibarrel · output bound %d\nInput bound %d · rate %d millibarrels/second\nNo withdrawal yet. Processing pauses while the host is stopped." % [int(config.yield_numerator), int(config.yield_denominator), int(owner.stock_millibarrels), int(owner.remainder), int(config.yield_denominator), int(config.output_capacity_millibarrels), int(config.input_capacity_millibarrels), int(config.rate_millibarrels_per_second)]
	quantity.max_value = int(config.input_capacity_millibarrels)
	for lot: Dictionary in state.lots:
		summary.text += "\nLot %s: %d millibarrels crude available" % [lot.id, int(lot.remaining_millibarrels)]
	progress.value = 0
	for job: Dictionary in state.jobs:
		progress.value = 100.0 * float(job.elapsed_ms) / float(job.duration_ms)
		summary.text += "\n%s · %s · %d crude → %d cargo fuel millibarrels\nAllocated crude cost: %d minor credits" % [job.action_id, job.status, int(job.input_millibarrels), int(job.output_millibarrels), int(job.allocated_cost_minor)]

func submit() -> void:
	if busy or not send.is_valid(): return
	if pending.is_empty():
		var context: Dictionary = port_context.call()
		if state.is_empty() or state.get("busy", false) or state.get("lots", []).is_empty() or not context.get("docked", false) or context.get("port_id", "") != PORT_ID: return
		pending = {"op": "refinery_submit", "refinery_id": REFINERY_ID, "action_id": Crypto.new().generate_random_bytes(16).hex_encode(), "expected_revision": int(state.revision), "lot_id": state.lots[0].id, "input_millibarrels": int(quantity.value)}
	busy = true
	var result: Dictionary = await send.call(pending.duplicate(true))
	busy = false
	if result.get("uncertain", false) or result.get("code", "") in ["REFINERY_UNAVAILABLE", "MARKET_UNAVAILABLE", "OUTCOME_UNKNOWN"]:
		notice.text = "Submission outcome unknown. Retry the identical request; restart recovers committed cargo and job."
		return
	pending.clear()
	notice.text = "Crude submitted once. No cancellation/refund; processing continues when this panel closes." if result.get("ok", false) else "Submission rejected: " + str(result.get("code", "INVALID_RESPONSE"))
	await inspect()
