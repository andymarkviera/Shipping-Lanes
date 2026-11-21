class_name CollisionRules
extends RefCounted
const HULL: int = 1 << 0
const SHORE: int = 1 << 1
const TRIGGER: int = 1 << 2
const CARGO_VISUAL: int = 1 << 3
const CHARACTER: int = 1 << 4
## Patch 2.1 item 4: a ship sliding into, sitting at or just leaving a berth.
## Other ships pass through it; it still meets the shore.
const DOCKED_HULL: int = 1 << 5
const SOLID_WATERCRAFT: int = HULL | SHORE
## Patch 2.2 item 1: 22 m/s covered container ship 5 (42 kn, 21.6 m/s).
## Patch 2.9 item 4: 103 m/s covers the offshore racer's 200 kn (102.9 m/s).
## move_and_slide sweeps the hull along each step (1.7 m at 60 Hz), so even a
## 0.1 m wall still stops it (tools/collision_probe.gd, "overspeed clamped").
## Patch 4.0 item 4: 520 m/s covers the Jetty's 1000 kn (514.4 m/s), 8.7 m a
## step at 60 Hz; the sweep still stops it at a thin wall (collision_probe).
## Patch 4.0.2: 830 m/s covers the Jetty's blaster boost (+60 %, 823 m/s),
## 13.8 m a step at 60 Hz, still swept by move_and_slide (patch_4_0_2_check).
const SUPPORTED_SPEED_MPS: float = 830.0

static func add_box_hull(body: CollisionObject3D, size: Vector3 = Vector3(13, 4, 64)) -> CollisionShape3D:
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "HullCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = 1.0
	body.add_child(collider)
	return collider
