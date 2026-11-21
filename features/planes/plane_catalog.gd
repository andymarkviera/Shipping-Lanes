extends RefCounted
## Patch 4.0 item 9: the planes a captain can buy (from Levels.PLANE_UNLOCK_LEVEL,
## level 1 since Patch 4.0.1), cheapest first. Prices in hundredths of a credit. No state lives here.
## Flight numbers (SI units) feed features/planes/flight_model.gd: mass, wing
## area, full thrust, the lift curve (cl0 + cl_alpha * angle of attack, up to
## stall_deg), parasite and induced drag, control rates and the take-off
## (rotate) speed. Fuel is in litres; refuelling is at airports only.
## capacity: passengers or parcels aboard; `jobs`: the plane job kinds it flies.
## Patch 4.0.1 item 4: the Fighter jet is recreation only, like the Jetty: no
## cargo, no jobs, a small tank, and the fastest thing in the game (more than
## twice the Cargo jet's top speed). Item 5: the Cargo jet's engines are
## turbofans ("fan2": nacelles with spinning front fans, no flames).
const PLANES = {
	"plane_prop": {"name": "Bush prop", "price_minor": 4000000, "fuel_l": 14.0, "burn_lps": 0.03,
		"mass_kg": 1100.0, "wing_m2": 16.0, "thrust_n": 3600.0, "cl0": 0.3, "cl_alpha": 5.0, "stall_deg": 15.0,
		"cd0": 0.045, "induced_k": 0.05, "pitch_dps": 40.0, "roll_dps": 90.0, "yaw_dps": 20.0, "rotate_mps": 30.0,
		"capacity": 4, "jobs": ["pax", "pkg"], "length_m": 8.5, "span_m": 11.0, "colour": "e2574c", "engines": "prop1"},
	"plane_turboprop": {"name": "Regional turboprop", "price_minor": 25000000, "fuel_l": 60.0, "burn_lps": 0.08,
		"mass_kg": 15000.0, "wing_m2": 60.0, "thrust_n": 52000.0, "cl0": 0.3, "cl_alpha": 5.2, "stall_deg": 14.0,
		"cd0": 0.032, "induced_k": 0.045, "pitch_dps": 22.0, "roll_dps": 50.0, "yaw_dps": 12.0, "rotate_mps": 50.0,
		"capacity": 24, "jobs": ["pax", "pkg"], "length_m": 22.0, "span_m": 27.0, "colour": "3d9be0", "engines": "prop2"},
	"plane_jet": {"name": "Cargo jet", "price_minor": 120000000, "fuel_l": 300.0, "burn_lps": 0.25,
		"mass_kg": 60000.0, "wing_m2": 180.0, "thrust_n": 260000.0, "cl0": 0.25, "cl_alpha": 5.4, "stall_deg": 13.0,
		"cd0": 0.024, "induced_k": 0.04, "pitch_dps": 14.0, "roll_dps": 35.0, "yaw_dps": 8.0, "rotate_mps": 70.0,
		"capacity": 40, "jobs": ["pkg"], "length_m": 40.0, "span_m": 38.0, "colour": "f2f2f2", "engines": "fan2"},
	"plane_fighter": {"name": "Fighter jet", "price_minor": 300000000, "fuel_l": 90.0, "burn_lps": 0.22,
		"mass_kg": 12000.0, "wing_m2": 38.0, "thrust_n": 180000.0, "cl0": 0.08, "cl_alpha": 4.8, "stall_deg": 17.0,
		"cd0": 0.016, "induced_k": 0.06, "pitch_dps": 55.0, "roll_dps": 200.0, "yaw_dps": 20.0, "rotate_mps": 72.0,
		"capacity": 0, "jobs": [], "length_m": 16.0, "span_m": 10.0, "colour": "8a96a8", "engines": "afterburner"},
}
const ORDER: Array[String] = ["plane_prop", "plane_turboprop", "plane_jet", "plane_fighter"]
## Prices at the airport, in hundredths of a credit.
const FUEL_MINOR_PER_LITER: int = 300
## Repair: this share of the plane's price per 1 % of condition (in basis points of the price).
const REPAIR_BP_PER_PERCENT: int = 20
## Patch 4.0 item 12: a crash is a full rebuild: the repair bill for 100 %.
const CRASH_REPAIR_PERCENT: int = 100

static func entry(kind: String) -> Dictionary:
	return PLANES.get(kind, {})

## Credits (minor) to repair `percent` of a plane's condition.
static func repair_minor(kind: String, percent: int) -> int:
	return int(PLANES[kind].price_minor) * REPAIR_BP_PER_PERCENT / 10000 * maxi(0, percent)

## Top speed in level flight at full thrust (where thrust meets parasite drag), m/s.
static func top_speed(kind: String) -> float:
	var p: Dictionary = PLANES[kind]
	return sqrt(float(p.thrust_n) / (0.5 * 1.225 * float(p.wing_m2) * float(p.cd0)))

## Slowest speed the wing holds the plane up at (clean, at the stall angle), m/s.
static func stall_speed(kind: String) -> float:
	var p: Dictionary = PLANES[kind]
	var cl_max: float = float(p.cl0) + float(p.cl_alpha) * deg_to_rad(float(p.stall_deg))
	return sqrt(2.0 * float(p.mass_kg) * 9.81 / (1.225 * float(p.wing_m2) * cl_max))

## Seconds of flight a full tank gives at full throttle.
static func endurance_s(kind: String) -> float:
	return float(PLANES[kind].fuel_l) / float(PLANES[kind].burn_lps)
