extends RefCounted
## Patch 4.0.2 (Andy's follow-up on #224): the Jetty's Shift BLASTER BOOST.
## Shift starts a short charge; then the blast fires and the Jetty runs about
## 60 % faster for BLAST_S seconds; then the boost cools down for COOLDOWN_S
## before it can be used again. HandlingShip owns one of these and is the only
## place the speed changes (the server's hull online, the local hull offline);
## JettyFx reads the phase for the flame, the glow and the sound.
## Phases: "ready" -> "charge" -> "blast" -> "cooldown" -> "ready".
const CHARGE_S: float = 0.6
const BLAST_S: float = 2.5
const COOLDOWN_S: float = 6.0
## +60 % of the hull's speed while the blast holds.
const SPEED_GAIN: float = 0.6
## The blast kicks in over KICK_S and eases back over EASE_S at its end.
const KICK_S: float = 0.15
const EASE_S: float = 0.35
## Only the Jetty has the blaster.
const KINDS: Array[String] = ["ship_small_jetty_04"]

var phase: String = "ready"
## Seconds spent in the current phase.
var clock: float = 0.0
## How many blasts have fired (for the effects and the checks).
var blasts: int = 0

static func eligible(definition: Resource) -> bool:
	return definition != null and KINDS.has(str(definition.get("id")))

func available() -> bool:
	return phase == "ready"

## Starts the charge. False while charging, blasting or cooling down.
func trigger() -> bool:
	if phase != "ready": return false
	phase = "charge"
	clock = 0.0
	return true

## Stops everything at once (docked, out of fuel, ship changed). A blast that
## already fired still has to cool down.
func cancel() -> void:
	if phase == "charge":
		phase = "ready"
		clock = 0.0
	elif phase == "blast":
		phase = "cooldown"
		clock = 0.0

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or phase == "ready": return
	clock += delta
	if phase == "charge" and clock >= CHARGE_S:
		clock -= CHARGE_S
		phase = "blast"
		blasts += 1
	if phase == "blast" and clock >= BLAST_S:
		clock -= BLAST_S
		phase = "cooldown"
	if phase == "cooldown" and clock >= COOLDOWN_S:
		clock = 0.0
		phase = "ready"

## The speed multiplier now: 1 outside the blast, 1 + SPEED_GAIN while it holds.
func factor() -> float:
	if phase != "blast": return 1.0
	var rise: float = smoothstep(0.0, KICK_S, clock)
	var fall: float = smoothstep(BLAST_S, BLAST_S - EASE_S, clock)
	return 1.0 + SPEED_GAIN * minf(rise, fall)

## 0..1: how far the charge has built (1 through the blast).
func charge() -> float:
	if phase == "charge": return clampf(clock / CHARGE_S, 0.0, 1.0)
	return 1.0 if phase == "blast" else 0.0

## 0..1: the blast's strength for the flame (eases out like the speed).
func blast() -> float:
	return (factor() - 1.0) / SPEED_GAIN

## Patch 4.0.4 item 4: boosts started so far, counting a charge under way
## (it rises once per Shift, at the press). The server sends it in the
## captain's status row; other clients start the replica's charge when it
## rises, so its flame, glow and sound play for everyone.
func uses() -> int:
	return blasts + (1 if phase == "charge" else 0)
