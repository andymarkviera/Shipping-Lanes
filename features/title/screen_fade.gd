class_name ScreenFade
extends CanvasLayer
## Patch 2.7 item 4: a full-screen fade to the title sea's blue that outlives a
## scene change. It fades in, emits `covered`, and once the next scene has been
## up for a few frames (its load hitch hidden under the veil) fades back out
## and frees itself.

signal covered
## The title sea's royal blue, a shade deeper.
const COLOUR: Color = Color(0.0, 0.22, 0.66)
const REVEAL_SECONDS: float = 0.5
## Frames the next scene runs under the veil before it lifts.
const HOLD_FRAMES: int = 4
## Lift anyway if no scene change comes (a failed change must not leave it up).
const WAIT_LIMIT: float = 12.0

enum Phase { COVERING, WAITING, REVEALING }
var phase: Phase = Phase.COVERING
var cover_seconds: float = 0.4
var veil: ColorRect
var from_scene: Node
var held: int = 0
var waited: float = 0.0

## Starts a fade on the tree's root, so it survives `change_scene_to_file`.
static func cover(tree: SceneTree, seconds: float = 0.4) -> ScreenFade:
	var fade: ScreenFade = ScreenFade.new()
	fade.cover_seconds = maxf(seconds, 0.01)
	fade.from_scene = tree.current_scene
	tree.root.add_child.call_deferred(fade)
	return fade

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	veil = ColorRect.new()
	veil.color = COLOUR
	veil.modulate.a = 0.0
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

## Lift the veil now (used when the scene change is called off).
func reveal() -> void:
	phase = Phase.REVEALING

func _process(delta: float) -> void:
	# A load hitch must not make the fade jump.
	var step: float = minf(delta, 1.0 / 30.0)
	match phase:
		Phase.COVERING:
			veil.modulate.a = minf(veil.modulate.a + step / cover_seconds, 1.0)
			if veil.modulate.a >= 1.0:
				phase = Phase.WAITING
				covered.emit()
		Phase.WAITING:
			waited += step
			var scene: Node = get_tree().current_scene
			if scene != null and scene != from_scene: held += 1
			if held >= HOLD_FRAMES or waited >= WAIT_LIMIT: phase = Phase.REVEALING
		Phase.REVEALING:
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			veil.modulate.a = maxf(veil.modulate.a - step / REVEAL_SECONDS, 0.0)
			if veil.modulate.a <= 0.0: queue_free()
