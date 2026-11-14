class_name ShipAssembly
extends Node3D
## Per-instance components. No scene paths or external parent names are assumed.
var ship: HandlingShip
var visual: ShipVisualMotion
var focus: CameraFocus
var cargo_anchor: Node3D
var feedback: HandlingFeedback
var container_visuals: Node3D

func configure(body: HandlingShip) -> void:
	ship = body
	name = "ShipAssembly"
	visual = ShipVisualMotion.new()
	visual.name = "VisualRoot"
	visual.body = ship
	visual.configure_hull(ship.definition)
	add_child(visual)
	visual.add_child((load(ship.definition.scene_path) as PackedScene).instantiate())
	visual.set_process(ship.definition.visual_bobbing)
	container_visuals = preload("res://features/cargo/container_visuals.gd").new()
	container_visuals.name = "CargoVisuals"
	visual.add_child(container_visuals)
	container_visuals.configure(ship.state.manifest, ship.definition)
	focus = CameraFocus.new()
	focus.name = "CameraAnchor"
	focus.position.y = 5
	focus.hull_radius = ship.definition.camera_radius_m
	focus.collision_body = ship
	add_child(focus)
	cargo_anchor = Node3D.new()
	cargo_anchor.name = "CargoAnchor"
	cargo_anchor.position = ship.definition.cargo_anchor_m
	add_child(cargo_anchor)
	feedback = HandlingFeedback.new()
	add_child(feedback)

static func box_collision(body: HandlingShip, size: Vector3, center: Vector3) -> CollisionShape3D:
	var collider: CollisionShape3D = CollisionRules.add_box_hull(body, size)
	collider.position = center
	return collider

func create_camera(parent: Node, controls: PlayerControls) -> OrbitCameraRig:
	var rig: OrbitCameraRig = OrbitCameraRig.new()
	parent.add_child(rig)
	rig.set_focus(focus)
	rig.distance_order = ship.definition.camera_distance_m
	rig.bind_controls(controls)
	return rig

func create_wake(ocean: OceanPresentation) -> ShipWake:
	var wake: ShipWake = ShipWake.new()
	wake.ship = ship
	wake.ocean = ocean
	visual.ocean = ocean
	wake.half_length = ship.definition.wake_half_length_m
	wake.half_width = ship.definition.wake_half_width_m
	ocean.get_parent().add_child(wake)
	return wake
